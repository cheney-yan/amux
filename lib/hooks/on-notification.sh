#!/usr/bin/env bash
# Hook: Notification — Claude needs user attention (question, permission, error)
# Receives JSON on stdin: {"message": "..."}

[ -z "$TMUX" ] && exit 0
[ -z "$TMUX_PANE" ] && exit 0

# Extract message from JSON if jq available
if command -v jq &>/dev/null; then
    notif_msg=$(cat | jq -r '.message // empty' 2>/dev/null | cut -c1-60)
else
    notif_msg=""
fi

tmux set-option -p -t "$TMUX_PANE" @amux_state "waiting" 2>/dev/null

win_id=$(tmux display-message -t "$TMUX_PANE" -p '#{window_id}' 2>/dev/null)     || exit 0
win_idx=$(tmux display-message -t "$TMUX_PANE" -p '#{window_index}' 2>/dev/null) || exit 0
win_name=$(tmux display-message -t "$TMUX_PANE" -p '#{window_name}' 2>/dev/null)

tmux set-option -t "$win_id" @amux_win_alert "1" 2>/dev/null

# Always notify for "waiting" — Claude needs you regardless of where you are
if [ -n "$notif_msg" ]; then
    msg="❗  W${win_idx} · ${win_name} · ${notif_msg}"
else
    msg="❗  W${win_idx} · ${win_name} · needs input"
fi

tmux list-clients -F '#{client_name}' 2>/dev/null | while read -r client; do
    tmux display-message -c "$client" -d 8000 "$msg" 2>/dev/null
done

bash "$AMUX_DIR/lib/status.sh" &
tmux refresh-client -S 2>/dev/null
