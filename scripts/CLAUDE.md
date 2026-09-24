# ~/scripts — agent instructions

This project is Brandon's system scripts, part of the yadm-managed dotfiles repo
(repo root is `~`). Machine details, script inventory, and the running log of what
has been debugged here live in this project's memory directory —
`~/.claude/projects/-home-brandon-scripts/memory/`. Read `MEMORY.md` there first.

**This file is deliberately NOT yadm-tracked.** It is laptop-local. If you want it
on goatbox-lab, copy it by hand; do not `yadm add` it.

## secondbrain responsibility

Durable knowledge produced by work in this project belongs in
`~/Dropbox/secondbrain/`. **Invoke the `secondbrain` skill before your first read or
write there** — it carries the method, and secondbrain's own contract is not
auto-injected here because cwd is `~/scripts`.

The only thing this file adds to the skill is *which files this project's work lands
in*, so you update the file that already owns the subject instead of creating a
sibling next to it.

### Which secondbrain files this project owns

Route through `_INDEX.md` rather than trusting this list to stay current, but these
are the ones system work here normally lands in:

| File | Holds |
|-----------------------------------------------|--------------------------------------------------------|
| `02_areas/infrastructure/README.md`            | machine roster, standing rules, known-broken            |
| `02_areas/infrastructure/workstation.md`       | goatboxter-fw16 itself                                  |
| `02_areas/infrastructure/fw16-gpu-migration.md`| the 2025-12-07 Radeon RX 7700S → RTX 5070 swap          |
| `02_areas/infrastructure/hibernate-resume-fw16.md` | hibernate/resume, BROKEN, NVIDIA VRAM + WiFi-on-resume |
| `02_areas/infrastructure/backups.md`           | the backup story `backup` / `system-backup` implement   |
| `02_areas/infrastructure/networking.md`        | nftables, iwd/NM, .bant hosts                           |
| `03_resources/tools/scripts-inventory.md`      | what the scripts in this directory are                  |

Tasks from this project go to `~/Dropbox/Documents/EmacsOrg/agenda/personal.org`
under `* IT`, tagged `:IT:`. The skill covers the rest of the routing.

## Host-specific memory is per-host and has drifted

`~/.claude/projects/-home-brandon-scripts/memory/` does **not** sync — goatbox-lab
has its own store. Same standing rule as secondbrain: apply every memory correction
on **both** hosts, index line included, and check whether the other host already has
a memory on the subject before writing a new one.

## Working style

The feedback files in project memory are binding, in particular:

- `feedback-shell-and-edits.md` — discrete one-per-line commands, **no `&&` chains**
  (fingerprint sudo breaks them); don't edit things when Brandon is only asking a question.
- `feedback-pre-sudo-explain.md` — explain what a `sudo` command will change **before**
  presenting it. The password prompt must never be the first signal that something
  administrative is happening.
- `feedback-minimal-deviation.md` — follow official Arch/vendor docs; deviate minimally.
- `feedback-trust-brandons-firsthand-knowledge.md` — his firsthand knowledge of his own
  machines is primary evidence. Assume your tool snapshot is stale before contradicting him.
