#!/usr/bin/env bash
# Hook: Stop — Claude finished, waiting for user input

[ -z "$TMUX" ] && exit 0
[ -z "$TMUX_PANE" ] && exit 0

tmux set-option -p -t "$TMUX_PANE" @amux_state "done" 2>/dev/null

win_id=$(tmux display-message -t "$TMUX_PANE" -p '#{window_id}' 2>/dev/null)     || exit 0
win_idx=$(tmux display-message -t "$TMUX_PANE" -p '#{window_index}' 2>/dev/null) || exit 0
win_name=$(tmux display-message -t "$TMUX_PANE" -p '#{window_name}' 2>/dev/null)

tmux set-option -t "$win_id" @amux_win_alert "1" 2>/dev/null

# Only notify if user is in a different window
active_win=$(tmux display-message -p '#{window_id}' 2>/dev/null)
if [ "$active_win" != "$win_id" ]; then
    tmux list-clients -F '#{client_name}' 2>/dev/null | while read -r client; do
        tmux display-message -c "$client" -d 2000 "✅  W${win_idx} · ${win_name}" 2>/dev/null
    done
    # Bell in that window so #F shows "!" as a persistent reminder
    tmux send-keys -t "$win_id" '' 2>/dev/null   # wake up the window
    printf '\a' | tmux load-buffer - 2>/dev/null || true
fi

bash "$AMUX_DIR/lib/status.sh" &
tmux refresh-client -S 2>/dev/null
