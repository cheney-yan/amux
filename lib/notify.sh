#!/usr/bin/env bash
# lib/notify.sh — AMux notification API
#
# Source this file in a Claude session, then call amux_notify to update state.
# States: idle | waiting | error | done
#
# Usage:
#   source /path/to/amux/lib/notify.sh
#   amux_activate [title]  # mark this pane as Claude; optionally name the window
#   amux_set_title <title> # update window name (e.g. current task summary)
#   amux_notify waiting    # signal that input is needed
#   amux_notify done       # signal job completion
#   amux_notify error      # signal an error
#   amux_notify idle       # reset to idle

amux_activate() {
    [ -z "$TMUX" ] && return 0
    local title="${1:-}"
    tmux set-option -p @amux_role "claude" 2>/dev/null
    tmux set-option -p @amux_state "idle" 2>/dev/null
    # Mark the window so window-status-format can read it
    local win_id
    win_id=$(tmux display-message -p '#{window_id}' 2>/dev/null)
    tmux set-option -t "$win_id" @amux_has_claude "1" 2>/dev/null
    # Rename the window so it's identifiable from any pane
    if [ -n "$title" ]; then
        amux_set_title "$title"
    else
        amux_set_title "claude"
    fi
    _amux_sync_win_alert
    tmux refresh-client -S 2>/dev/null
}

# Update the window name to reflect current Claude session title/task.
# Call this whenever the Claude task changes.
amux_set_title() {
    [ -z "$TMUX" ] && return 0
    local title="${1:-claude}"
    # Disable auto-rename for this window so our name sticks
    tmux set-option -w automatic-rename off 2>/dev/null
    tmux rename-window "$title" 2>/dev/null
}

amux_notify() {
    local state="${1:-idle}"
    [ -z "$TMUX" ] && return 0

    # Validate state
    case "$state" in
        idle|waiting|error|done) ;;
        *) echo "amux_notify: unknown state '$state'" >&2; return 1 ;;
    esac

    tmux set-option -p @amux_state "$state" 2>/dev/null
    _amux_sync_win_alert
    tmux refresh-client -S 2>/dev/null
}

# Internal: set a window-level alert flag if any pane in this window is non-idle.
# This lets window-status-format show a marker without running a shell per window.
_amux_sync_win_alert() {
    local win_id
    win_id=$(tmux display-message -p '#{window_id}' 2>/dev/null) || return

    local alert=0
    while IFS= read -r pane_state; do
        case "$pane_state" in
            waiting|error|done) alert=1; break ;;
        esac
    done < <(tmux list-panes -t "$win_id" -F '#{@amux_state}' 2>/dev/null)

    tmux set-option -t "$win_id" @amux_win_alert "$alert" 2>/dev/null
}

# Auto-activate if AMUX_AUTO_ACTIVATE is set (useful in shell profiles)
if [ "${AMUX_AUTO_ACTIVATE:-0}" = "1" ]; then
    amux_activate
fi
