#!/usr/bin/env bash
# Hook: after-select-window — clear alerts when user switches to a window

[ -z "$TMUX" ] && exit 0

win_id=$(tmux display-message -p '#{window_id}' 2>/dev/null) || exit 0
alert=$(tmux show-option -t "$win_id" -v @amux_win_alert 2>/dev/null)

[ "$alert" != "1" ] && exit 0

# Clear window-level alert flag
tmux set-option -t "$win_id" @amux_win_alert "0" 2>/dev/null

# Reset done/waiting panes back to idle — tool state is left alone (still working)
while IFS=' ' read -r pane_id state; do
    case "$state" in
        done|waiting)
            tmux set-option -p -t "$pane_id" @amux_state "idle" 2>/dev/null ;;
    esac
done < <(tmux list-panes -t "$win_id" -F '#{pane_id} #{@amux_state}' 2>/dev/null)

tmux refresh-client -S 2>/dev/null
