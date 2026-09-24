#!/bin/bash
# Nudge ZN-FPGA orchestrator (window 1) to collate workstream reports.
# Fires every 30 minutes at :15 and :45, offset from the workstream nudge.

pane_output=$(tmux capture-pane -t "zn-fpga:1" -p 2>/dev/null | tail -20)
[ -z "$pane_output" ] && exit 0

if echo "$pane_output" | grep -q '❯' && ! echo "$pane_output" | grep -q 'esc to interrupt'; then
    tmux send-keys -t "zn-fpga:1" "Orchestrator check-in. Read ws_report.md from each worktree (zn-fpga-ws2 through zn-fpga-ws6). For each one that exists, note what changed. Then:
1. If any contain significant findings, update doc/status.md.
2. Append a timestamped entry to doc/orchestrator_log.md with a 1-line summary per workstream (what they did, what they found, any state changes). If nothing changed for a workstream, write 'no change'.
3. Do not message or redirect workstreams.
4. If nothing changed across all workstreams, just append '## <timestamp> No changes.' and stop." Enter
fi
