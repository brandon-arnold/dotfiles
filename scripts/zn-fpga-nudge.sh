#!/bin/bash
# Nudge ZN-FPGA Claude Code workers to keep going.
# Sends a nudge to any active Claude Code session in the zn-fpga tmux.
# Safe to run if tmux or windows don't exist — just exits quietly.

# Window 0/1 = orchestrator, 2 = WS2, 3 = WS3, 4 = WS4, 5 = WS5, 6 = WS6

for win in 1 2 3 4 5 6; do
    # Check if the window exists and has Claude Code running (not a bare shell)
    pane_output=$(tmux capture-pane -t "zn-fpga:${win}" -p 2>/dev/null | tail -20)
    [ -z "$pane_output" ] && continue

    # Only nudge if Claude Code is at an idle prompt (❯), not mid-task
    if echo "$pane_output" | grep -q '❯' && ! echo "$pane_output" | grep -q 'Waiting for task\|esc to interrupt'; then
        tmux send-keys -t "zn-fpga:${win}" 'Re-read your CLAUDE.md and doc/status.md. Confirm you are following all Hard Rules before continuing work. Keep going.' Enter
    fi
done
