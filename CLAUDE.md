# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project: AMux — tmux Wrapper for Claude Session Management

AMux is a tmux wrapper whose primary purpose is acting as a **Claude Session Manager** inside a terminal environment. It lets Claude instances running in various tmux sessions send structured notifications back to tmux so the user can monitor session state at a glance.

## Core Goals

1. **Status bar visibility** — the tmux status bar must show at a glance:
   - Which windows contain a AMux (Claude) session
   - Which sessions need human attention: errors, interactive prompts, or completed jobs

2. **Visual pane highlighting** — clear visual distinction between:
   - The currently active pane (within a AMux-managed session)
   - Panes running Claude vs. plain shell panes

3. **Notification system** — Claude processes inside sessions can signal state changes (e.g., "waiting for input", "job done", "error") that bubble up to the status bar without requiring the user to switch windows.

## Design Constraints

- **Terminal-only, Linux-compatible**: All implementation must use standard POSIX/terminal primitives — tmux, shell scripts, escape codes, named pipes, or similar. No macOS-specific (`osascript`, `terminal-notifier`) or Windows-specific mechanisms.
- **No external GUI dependencies**: Everything must work over SSH in a headless Linux environment.
- **tmux-native**: Prefer tmux built-ins (`set-option`, `display-message`, `run-shell`, hooks like `after-new-window`) over external tooling where possible.

## Architecture (Planned)

```
amux/
├── amux.sh          # Main entry point / wrapper around tmux
├── lib/
│   ├── notify.sh    # API for Claude sessions to emit state notifications
│   ├── status.sh    # Builds the tmux status-left/status-right strings
│   └── hooks.sh     # tmux hook registrations (session-created, etc.)
├── tmux.conf        # AMux tmux config (sourced alongside user config)
└── CLAUDE.md
```

### Notification Flow

Claude session → `notify.sh <session> <state>` → writes to a shared state store (e.g., a temp file or tmux variable per session) → `status.sh` reads state store and renders status bar segments → tmux `status-interval` refreshes the bar.

State values: `idle`, `waiting` (needs input), `error`, `done`.

### Status Bar Segments

Each window with a AMux session gets a colored indicator; windows needing attention are highlighted (e.g., bold/color change). The active pane border style changes when inside a AMux-managed session.

## Key tmux Concepts Used

- `set -g status-right` / `status-left` with `#(...)` shell interpolation for dynamic content
- `set-hook` for reacting to window/session lifecycle events
- `select-pane -P` / `set -g pane-active-border-style` for pane visual highlighting
- `tmux set-environment` / `tmux show-environment` for per-session state storage
