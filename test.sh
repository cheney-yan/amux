#!/usr/bin/env bash
# test.sh — spin up a AMux test/dev environment
#
# Creates a tmux session with:
#   Window 1 "code"       — edit AMux source files
#   Window 2 "claude-sim" — simulate a Claude pane (test notifications)
#   Window 3 "shell"      — plain shell (no AMux role, for contrast)

AMUX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SESSION="amux-test"

# ── Tear down existing session ────────────────────────────────────────────────
tmux kill-session -t "$SESSION" 2>/dev/null

# ── Start session via AMux ────────────────────────────────────────────────────
"$AMUX_DIR/amux.sh" new-session -d -s "$SESSION" -n "code" -x "$(tput cols)" -y "$(tput lines)"

# Window 1: code — open project in $EDITOR (fallback to vim)
tmux send-keys -t "$SESSION:code" "cd '$AMUX_DIR' && ${EDITOR:-vim} ." Enter

# Window 2: claude-sim — a pane that acts as a Claude session
"$AMUX_DIR/amux.sh" new-window -t "$SESSION" -n "claude-sim"
tmux send-keys -t "$SESSION:claude-sim" "
source '$AMUX_DIR/lib/notify.sh'
amux_activate
echo ''
echo '=== AMux Claude Simulator ==='
echo 'This pane is now marked as a Claude pane (cyan border above).'
echo ''
echo 'Try these commands:'
echo '  amux_notify waiting   # → yellow border, W2:INPUT in status bar'
echo '  amux_notify error     # → red border,    W2:ERR in status bar'
echo '  amux_notify done      # → green border,  W2:DONE in status bar'
echo '  amux_notify idle      # → cyan border,   back to normal'
echo ''
" Enter

# Window 3: shell — plain shell for contrast
"$AMUX_DIR/amux.sh" new-window -t "$SESSION" -n "shell"
tmux send-keys -t "$SESSION:shell" "echo 'Plain shell — no AMux role. Border is white when active.'" Enter

# ── Focus on the simulator window ─────────────────────────────────────────────
"$AMUX_DIR/amux.sh" select-window -t "$SESSION:claude-sim"

# ── Attach ────────────────────────────────────────────────────────────────────
"$AMUX_DIR/amux.sh" attach-session -t "$SESSION"
