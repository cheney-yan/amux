#!/usr/bin/env bash
# Hook: PreToolUse — Claude is about to call a tool (still working)

[ -z "$TMUX" ] && exit 0
[ -z "$TMUX_PANE" ] && exit 0

if command -v jq &>/dev/null; then
    input=$(cat)
    tool=$(echo "$input" | jq -r '.tool_name // empty' 2>/dev/null)
else
    input=$(cat)
    tool=$(echo "$input" | grep -o '"tool_name":"[^"]*"' | cut -d'"' -f4)
fi

tmux set-option -p -t "$TMUX_PANE" @amux_state "tool" 2>/dev/null
[ -n "$tool" ] && tmux set-option -p -t "$TMUX_PANE" @amux_tool "$tool" 2>/dev/null

win_id=$(tmux display-message -t "$TMUX_PANE" -p '#{window_id}' 2>/dev/null) || exit 0
tmux set-option -t "$win_id" @amux_win_alert "0" 2>/dev/null
bash "$AMUX_DIR/lib/status.sh" &
tmux refresh-client -S 2>/dev/null
