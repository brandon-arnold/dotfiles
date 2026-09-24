#!/bin/sh
# display-hibernate.sh — force a DRM modeset after resuming from hibernation.
#
# Problem (observed 2026-08-30, Framework Laptop 16, AMD 890M / DCN 3.5):
# resuming from S4 brings the display engine back with no live scanout. amdgpu
# resumes cleanly — PSP, SMU and DMUB all report success, no errors — and sway,
# DRM and the driver all report the output active, powered and at its full mode.
# But the panel is only updated when a damage event forces a page flip, so the
# screen looks black except while typing or moving the pointer.
#
# A full modeset tears down and rebuilds the stream, restoring continuous
# scanout. The refresh rate is irrelevant: 165Hz -> 60Hz -> 165Hz fixed it, and
# 165Hz stayed clean afterwards. Only the modeset itself matters.
#
# This is NOT the amdgpu IPS idle-power hang. amdgpu.dcdebugmask=0x800 is
# already applied for that and was confirmed active in /proc/cmdline when this
# occurred, so the two are independent failures with a similar signature.
#
# Sleep hooks run as root with no session, so this locates the running sway IPC
# socket and re-enters the owning user's session to issue the swaymsg calls.
#
# Scope is deliberately narrow: hibernate paths only. Plain suspend is not known
# to hit this, and a modeset on every wake would cost a visible flicker for no
# reason. Add "suspend" to the case below if it turns out to be affected too.

set -u

[ "${1:-}" = "post" ] || exit 0

case "${2:-}" in
    hibernate|suspend-then-hibernate) ;;
    *) exit 0 ;;
esac

command -v jq >/dev/null 2>&1 || {
    logger -t display-hibernate "jq not found; skipping modeset"
    exit 0
}

# Let the compositor finish its own resume handling first.
sleep 2

for sock in /run/user/*/sway-ipc.*.sock; do
    [ -S "$sock" ] || continue

    uid=$(stat -c %u "$sock" 2>/dev/null) || continue
    user=$(id -nu "$uid" 2>/dev/null) || continue

    run() { runuser -u "$user" -- env SWAYSOCK="$sock" "$@"; }

    outputs=$(run swaymsg -t get_outputs 2>/dev/null) || continue
    [ -n "$outputs" ] || continue

    # name <TAB> current-mode <TAB> alternate-mode.
    # Prefer an alternate at the SAME resolution so the desktop is not resized
    # and the window layout is preserved; fall back to any other mode.
    echo "$outputs" | jq -r '
        .[] | select(.active) |
        .current_mode as $c |
        ( [ .modes[]
            | select(.width == $c.width and .height == $c.height
                     and .refresh != $c.refresh) ]
          + [ .modes[] | select(.width != $c.width or .height != $c.height) ]
        ) as $alts |
        select($alts | length > 0) |
        [ .name,
          "\($c.width)x\($c.height)@\($c.refresh/1000)Hz",
          "\($alts[0].width)x\($alts[0].height)@\($alts[0].refresh/1000)Hz"
        ] | @tsv' |
    while IFS="$(printf '\t')" read -r name cur alt; do
        [ -n "$name" ] || continue
        logger -t display-hibernate "modeset $name: $cur -> $alt -> $cur"
        run swaymsg "output $name mode $alt" >/dev/null 2>&1
        run swaymsg "output $name mode $cur" >/dev/null 2>&1
    done
done

exit 0
