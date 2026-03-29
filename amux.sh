#!/usr/bin/env bash
# amux.sh — AMux: tmux wrapper for Claude session management
# Usage: amux.sh [tmux args...]

AMUX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AMUX_DIR

exec tmux -f "$AMUX_DIR/tmux.conf" "$@"
