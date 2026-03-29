#!/usr/bin/env bash
# Hook: after-select-window — clear alerts when user switches to a window
# $1 = window_id, expanded by tmux at hook-fire time (reliable even with -b)

[ -z "$TMUX" ] && exit 0

win_id="${1:-}"
[ -z "$win_id" ] && exit 0
alert=$(tmux show-option -t "$win_id" -v @amux_win_alert 2>/dev/null)

if [ "$alert" = "1" ]; then
    # Clear state FIRST so status.sh sees idle and renames window correctly
    tmux set-option -t "$win_id" @amux_win_alert "0" 2>/dev/null
    while IFS=' ' read -r pane_id state; do
        case "$state" in
            done|waiting)
                tmux set-option -p -t "$pane_id" @amux_state "idle" 2>/dev/null ;;
        esac
    done < <(tmux list-panes -t "$win_id" -F '#{pane_id} #{@amux_state}' 2>/dev/null)
fi

# Async scan — no blocking delay on window switch
bash "$AMUX_DIR/lib/status.sh" &
tmux refresh-client -S 2>/dev/null
