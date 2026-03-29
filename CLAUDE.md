# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project: AMux — Agent Mux

AMux is a minimal tmux add-on for managing multiple AI agent sessions. It auto-detects Claude Code processes in tmux panes and updates the status bar and window names to reflect each session's state.

## Design Constraints

- **Add-on only**: AMux adds one `source-file` line to `~/.tmux.conf`. It does not replace or wrap tmux.
- **Terminal-only, Linux-compatible**: No macOS/Windows-specific mechanisms. Works over SSH.
- **bash 3.x compatible**: macOS ships bash 3.2. No `declare -A`, no bash 4+ features. Use `awk` for aggregation.
- **BSD awk compatible**: No `gensub`, no `asorti`. Use `sort` externally for ordering.

## File Structure

```
amux/
├── install.sh          # Installer: shell profile, ~/.tmux.conf, ~/.claude/settings.json
├── tmux-addon.conf     # Sourced from ~/.tmux.conf — all tmux UI config lives here
├── lib/
│   ├── status.sh       # Runs every 2s via tmux status-right #(...); scans panes + renders alerts
│   └── hooks/
│       ├── on-stop.sh          # Claude Code Stop hook → state=done
│       ├── on-notification.sh  # Claude Code Notification hook → state=waiting
│       ├── on-pre-tool.sh      # Claude Code PreToolUse hook → state=tool
│       └── on-window-focus.sh  # tmux after-select-window hook → clears alerts on visit
└── README.md
```

## How It Works

**Detection** (`lib/status.sh`, every 2s):
- `tmux list-panes` → get shell PIDs → `pgrep -P <pid>` → `ps -o command=` → grep for `claude`
- When found: rename window to `[C] <name>`, set `@amux_has_claude` window option

**State machine** (via Claude Code hooks):
- `PreToolUse` → `@amux_state=tool` → window prefix `[C🔧]`
- `Stop` → `@amux_state=done` → window prefix `[C✅]`, brief pop-up notification
- `Notification` → `@amux_state=waiting` → window prefix `[C❗]`, persistent pop-up
- User switches to window → `on-window-focus.sh` resets `done`/`waiting` → back to `[C]`

**Isolation**: every hook targets `$TMUX_PANE` explicitly so multiple Claude sessions never interfere.

## Key tmux Concepts

- `set-option -p -t "$TMUX_PANE"` — pane-scoped option, per-session isolated
- `set-option -t "$win_id" @amux_*` — window-scoped option
- `pane-border-format` with `#{@amux_state}` — live pane title
- `#(lib/status.sh)` in `status-right` — shell interpolation, runs every `status-interval`
- `set-hook -g after-select-window` — fires when user switches windows
