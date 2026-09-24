#!/bin/bash
# Nudge ZN-FPGA workstreams to write status reports.
# Fires hourly. Only workstream 4.
#
# Submission trick: Claude Code's input widget detects bracketed-paste blocks
# and treats embedded newlines / trailing Enters arriving within the paste
# window as paste content, not as a submit. So we paste the text via the
# tmux buffer, wait past the paste-detection window, then send Enter on its own.

for win in 4; do
    pane_output=$(tmux capture-pane -t "zn-fpga:${win}" -p 2>/dev/null | tail -20)
    [ -z "$pane_output" ] && continue

    if echo "$pane_output" | grep -q '❯' && ! echo "$pane_output" | grep -q 'esc to interrupt'; then
        MSG="Append a new status entry to ws_report.md in your worktree root. Do NOT overwrite previous entries — append below them so the file becomes a chronological log. Format for the new entry:
---
LAST_UPDATED: $(date -Iseconds)
STATE: (running_sim | idle | blocked | investigating | compiling)
CURRENT_TASK: (one line)
FINDINGS: (bullet list of discoveries this session, empty if none)
COMMITS: (any commits made, empty if none)
BLOCKED_ON: (nothing, or what you need)
NEXT: (what you will do next)
Then re-read your CLAUDE.md and doc/status.md and keep working."

        tmux set-buffer -- "$MSG"
        tmux paste-buffer -t "zn-fpga:${win}" -d
        sleep 0.5
        tmux send-keys -t "zn-fpga:${win}" Enter
    fi
done
