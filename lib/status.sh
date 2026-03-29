#!/usr/bin/env bash
# lib/status.sh — AMux window name manager
#
# Triggered every status-interval seconds via tmux status-right #(...).
# Scans all panes for Claude processes and updates window name prefixes.
# Does not output anything to the status bar — window names carry all state.

[ -z "$TMUX" ] && exit 0

# ── Claude detection ──────────────────────────────────────────────────────────
pane_has_claude() {
    local shell_pid="$1"
    for child_pid in $(pgrep -P "$shell_pid" 2>/dev/null); do
        if ps -o command= -p "$child_pid" 2>/dev/null | grep -qi "claude"; then
            return 0
        fi
    done
    return 1
}

# ── Determine window prefix based on pane states ──────────────────────────────
_amux_prefix() {
    local win_id="$1"
    local worst="idle"
    local rank=0

    while IFS=' ' read -r pane_pid pane_state; do
        pane_has_claude "$pane_pid" || continue
        case "$pane_state" in
            waiting) [ $rank -lt 4 ] && worst="waiting" && rank=4 ;;
            done)    [ $rank -lt 3 ] && worst="done"    && rank=3 ;;
            tool)    [ $rank -lt 2 ] && worst="tool"    && rank=2 ;;
            idle)    [ $rank -lt 1 ] && worst="idle"    && rank=1 ;;
        esac
    done < <(tmux list-panes -t "$win_id" -F '#{pane_pid} #{@amux_state}' 2>/dev/null)

    case "$worst" in
        waiting) echo "[C❗]" ;;
        done)    echo "[C✅]" ;;
        tool)    echo "[C🔧]" ;;
        *)       echo "[C]"   ;;
    esac
}

# ── Scan all windows and update names ─────────────────────────────────────────
while IFS=' ' read -r win_id win_name; do
    has_claude=0

    while IFS=' ' read -r shell_pid; do
        if pane_has_claude "$shell_pid"; then
            has_claude=1
            break
        fi
    done < <(tmux list-panes -t "$win_id" -F '#{pane_pid}' 2>/dev/null)

    prev=$(tmux show-option -t "$win_id" -v @amux_has_claude 2>/dev/null)

    if [ "$has_claude" = "1" ]; then
        prefix=$(_amux_prefix "$win_id")

        # Strip any existing [C...] prefix to get base name
        if [[ "$win_name" =~ ^\[C[^]]*\]\ (.*) ]]; then
            base="${BASH_REMATCH[1]}"
        else
            base="$win_name"
        fi

        tmux set-option -t "$win_id" @amux_has_claude "1" 2>/dev/null
        tmux set-option -t "$win_id" @amux_base_name "$base" 2>/dev/null

        desired="${prefix} ${base}"
        [ "$win_name" != "$desired" ] && tmux rename-window -t "$win_id" "$desired" 2>/dev/null

    elif [ "$has_claude" = "0" ] && [ "$prev" = "1" ]; then
        base=$(tmux show-option -t "$win_id" -v @amux_base_name 2>/dev/null)
        tmux set-option -t "$win_id" @amux_has_claude "0" 2>/dev/null
        tmux rename-window -t "$win_id" "${base:-$win_name}" 2>/dev/null
    fi

done < <(tmux list-windows -a -F '#{window_id} #{window_name}' 2>/dev/null)
