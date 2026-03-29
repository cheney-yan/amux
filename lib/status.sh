#!/usr/bin/env bash
# lib/status.sh — AMux status bar segment + window name manager
#
# Runs every status-interval seconds via #(...) in tmux status-right.
# Side effect: renames windows to prepend [C] when Claude is detected.

[ -z "$TMUX" ] && exit 0

# ── Claude detection ──────────────────────────────────────────────────────────
# Check if a shell PID has a child process running Claude
pane_has_claude() {
    local shell_pid="$1"
    for child_pid in $(pgrep -P "$shell_pid" 2>/dev/null); do
        if ps -o command= -p "$child_pid" 2>/dev/null | grep -qi "claude"; then
            return 0
        fi
    done
    return 1
}

# ── Scan all windows and update names ─────────────────────────────────────────
_amux_prefix() {
    # Return [C], [C⚙], [C⏰], or [C❗] based on worst state across Claude panes
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

while IFS=' ' read -r win_id win_name; do
    has_claude=0

    # Check each pane in this window for Claude process
    while IFS=' ' read -r shell_pid; do
        if pane_has_claude "$shell_pid"; then
            has_claude=1
            break
        fi
    done < <(tmux list-panes -t "$win_id" -F '#{pane_pid}' 2>/dev/null)

    prev=$(tmux show-option -t "$win_id" -v @amux_has_claude 2>/dev/null)

    if [ "$has_claude" = "1" ]; then
        # Determine correct prefix: [C] or [C*]
        prefix=$(_amux_prefix "$win_id")

        # Strip any existing [C...] prefix to get base name
        if [[ "$win_name" =~ ^\[C[^]]*\]\ (.*) ]]; then
            base="${BASH_REMATCH[1]}"
        else
            base="$win_name"
        fi

        tmux set-option -t "$win_id" @amux_has_claude "1" 2>/dev/null
        tmux set-option -t "$win_id" @amux_base_name "$base" 2>/dev/null

        # Only rename if the prefix changed
        desired="${prefix} ${base}"
        [ "$win_name" != "$desired" ] && tmux rename-window -t "$win_id" "$desired" 2>/dev/null

    elif [ "$has_claude" = "0" ] && [ "$prev" = "1" ]; then
        # Claude exited — restore original name
        base=$(tmux show-option -t "$win_id" -v @amux_base_name 2>/dev/null)
        tmux set-option -t "$win_id" @amux_has_claude "0" 2>/dev/null
        tmux rename-window -t "$win_id" "${base:-$win_name}" 2>/dev/null
    fi

done < <(tmux list-windows -a -F '#{window_id} #{window_name}' 2>/dev/null)

# ── Render status bar alerts ──────────────────────────────────────────────────
state_rank() {
    case "$1" in
        error)   echo 3 ;;
        waiting) echo 2 ;;
        done)    echo 1 ;;
        *)       echo 0 ;;
    esac
}

declare -A win_worst
declare -A win_claude

while IFS='|' read -r win_idx role state; do
    [ "$role" = "claude" ] || continue
    win_claude[$win_idx]=1
    rank=$(state_rank "$state")
    current_rank=$(state_rank "${win_worst[$win_idx]:-idle}")
    if (( rank > current_rank )); then
        win_worst[$win_idx]="$state"
    fi
done < <(tmux list-panes -a -F '#{window_index}|#{@amux_role}|#{@amux_state}' 2>/dev/null)

output=""
for win_idx in $(echo "${!win_claude[@]}" | tr ' ' '\n' | sort -n); do
    state="${win_worst[$win_idx]:-idle}"
    case "$state" in
        error)   output+="#[fg=colour196,bold][W${win_idx}:ERR]#[default] " ;;
        waiting) output+="#[fg=colour226,bold][W${win_idx}:INPUT]#[default] " ;;
        done)    output+="#[fg=colour46,bold][W${win_idx}:DONE]#[default] " ;;
        idle)    output+="#[fg=colour39][W${win_idx}:◆]#[default] " ;;
    esac
done

printf '%s' "${output% }"
