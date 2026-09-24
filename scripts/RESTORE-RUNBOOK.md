# Restoring goatboxter-fw16 onto the new Framework 16

Written 2026-09-24, for the migration that day. Everything here is readable
with `less` from the Arch live USB; nothing in it needs a network.

The script has been validated in a QEMU VM. It has **never run against real
hardware**. Expect to read output rather than watch a progress bar.

---

## Before you touch the new machine

**BIOS, on the new machine.** Neither of these is in any backup, and the second
one stops Sway from starting:

- iGPU UMA carve-out → **32 GB** (a fresh board defaults lower)
- NVIDIA → **Hybrid** mode
- Optional: Thunderbolt security → **none**, which saves authorising the drive
  by hand. Otherwise `boltctl list` then `boltctl authorize <uuid>` on the live
  system — `bolt` *is* on the ISO, contrary to the older note in secondbrain.

**Check the new primary drive is not smaller than the old one.** Phase 2 replays
a partition table whose last partition ends near the end of the disk, so fewer
raw sectors breaks it. Larger is fine — reclaim the slack later with `pvresize`.

```sh
blockdev --getsz /dev/nvme0n1     # and compare against the old machine's
```

---

## What is on which drive

| Thumb drive | Thunderbolt drive |
|---|---|
| the Arch ISO, nothing else | `20260924-12h21/` — the image set, ~333 GB |
| | `system-restore` — 17 KB, self-contained |
| | `downloads.tar` — 29 GB |
| | `steam.tar` — 365 GB, optional |

`system-restore` is staged separately because it normally lives inside
`arch-home.fsa`, which you cannot read until after you have used it.

Everything the restore calls — `fsarchiver`, `lvm2`, `efibootmgr`, `sfdisk`,
`mkfs.ext4`, `blkid` — ships on the ISO. Verified against its package list.

---

## The run

```sh
# after booting the ISO, with the Thunderbolt drive mounted at /mnt/tb
bash /mnt/tb/system-restore /mnt/tb/20260924-12h21
```

Add `--yes-i-understand-this-wipes-both-drives` to skip all ten confirmations.
Do not, the first time.

### The phases, and what "good" looks like

| | Phase | Watch for |
|---|---|---|
| 0 | Locate and validate backup | checksums verified. It refuses to start if anything is missing — let it |
| 1 | Identify target NVMe drives | **the one place to be slow.** It asks you to map each drive to its role. Get this wrong and you wipe the wrong disk |
| 2 | Restore partition tables | fails here if the new drive is smaller. See above |
| 3 | Initialise swap | quick |
| 4 | Restore LVM layout | `vgcfgrestore` rebuilds the VG, all LVs and their UUIDs |
| 5 | Restore filesystems | the long one, ~15-20 min for 333 GB off Thunderbolt |
| 6 | Format non-backed-up volumes | **makes `steam`, `dropbox` and `downloads` empty.** Intended |
| 7 | Mount restored system | at `/mnt/restore`, home at `/mnt/restore/home` |
| 8 | Regenerate initramfs | chroots and runs `mkinitcpio`. Needed — the initramfs carries the LVM config |
| 9 | Restore rEFInd EFI boot entry | see below |
| 10 | Verification | |

---

## Phase 9 is the one that historically bites

The EFI boot entry lives in **NVRAM, not on the disk**. A machine with fresh
NVRAM and perfectly cloned partitions reports *no bootable device*, and it looks
exactly like a bad backup when it is not.

Two things now guard against it:

1. `efibootmgr --create ... --loader '\EFI\refind\refind_x64.efi'`. Single
   backslashes — it had doubled ones until today, which would have written a
   path the firmware could not follow.
2. A copy at `\EFI\BOOT\BOOTX64.EFI`, the removable-media path firmware tries
   when it has no working boot variable. **With this in place, a wrong or
   missing NVRAM entry can no longer strand you.**

After Phase 9, `efibootmgr -v` output is printed. Read it. The loader path
should have single backslashes and the PARTUUID should match the restored ESP.

---

## Before rebooting — still on the live USB

Dropbox and Insync come back **linked**, with their file index intact, pointing
at a `~/Dropbox` that Phase 6 just emptied. A linked client meeting an empty
folder is how people push mass deletions to the cloud, and that cloud copy is
the only copy of `~/Dropbox` — it is in neither backup.

```sh
mv /mnt/restore/home/brandon/.dropbox        /mnt/restore/home/brandon/.dropbox.old
mv /mnt/restore/home/brandon/.config/Insync  /mnt/restore/home/brandon/.config/Insync.old
```

Both then start unlinked on first boot; sign in and they download fresh.

`arch-dropbox` is not mounted during the restore, so these paths are directly
reachable — no chroot needed.

---

## After first boot

```sh
sudo tar --numeric-owner -xf /mnt/tb/downloads.tar -C /home/brandon/Downloads
sudo tar --numeric-owner -xf /mnt/tb/steam.tar     -C /home/brandon/steam
```

Extract **before** launching Steam. If you launch it first it will see an empty
library and may drop the registration — not destructive, and fixed with
Settings → Storage → Add Drive pointed at `/home/brandon/steam/SteamLibrary`.
Saves live in `~/.local/share/Steam/userdata`, which came back with home.

If `steam.tar` was skipped, rsync it from the old machine instead — that data is
still sitting on its drive, untouched.

### The Sway trap, if the dGPU is not in this machine

`~/.zshenv` hardcodes `WLR_DRM_DEVICES=/dev/dri/card2`. DRM indices are assigned
at probe time, so without the NVIDIA card the iGPU is not reliably `card2`, and
Sway exits to a console. Select by driver instead:

```sh
for _c in /dev/dri/card*; do
  _drv=/sys/class/drm/${_c##*/}/device/driver
  if [ -e "$_drv" ] && [ "$(basename "$(readlink -f "$_drv")")" = amdgpu ]; then
    export WLR_DRM_DEVICES="$_c"; break
  fi
done
unset _c _drv
```

Escape hatch: rEFInd's **"Boot to terminal"** entry is already in
`refind_linux.conf`.

---

## If it goes wrong

**The old machine still works.** It keeps its own drives and everything on
them — run Claude there, with network and full context, rather than fighting
the live USB.

**The NAS holds the same image set.** `system-restore` documents it as a source:

```sh
mount -t nfs truenas.bant:/mnt/tank/... /mnt/nas
bash system-restore /mnt/nas/PcBackup/goatboxter-fw16/20260924-12h21
```

Slower than Thunderbolt, but it means a failed drive copy is not the end.

**Nothing you have done is destructive to the old machine.** Its drives stay in
it, and the restore only ever writes to the new machine's.

### To run Claude from the live USB anyway

Ethernet first, then:

```sh
pacman -Sy nodejs npm
npm install -g @anthropic-ai/claude-code
cp -r /mnt/tb/dot-claude ~/.claude     # staged credentials; no browser here
```

Stage `~/.claude/` onto the Thunderbolt drive before you start, or this step has
no way to authenticate.
