#!/usr/bin/env bash
# install.sh — Install AMux into the user's environment (fully automatic)

set -e
AMUX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ok()   { printf '\033[32m  ✓ %s\033[0m\n' "$*"; }
skip() { printf '\033[33m  · %s\033[0m\n' "$*"; }
err()  { printf '\033[31m  ✗ %s\033[0m\n' "$*"; }
step() { printf '\n\033[1m%s\033[0m\n' "$*"; }

echo ""
echo "  AMux — Agent Mux installer"
echo "  AMUX_DIR: $AMUX_DIR"

# ── 1. Permissions ────────────────────────────────────────────────────────────
step "1. Scripts"
chmod +x "$AMUX_DIR/install.sh"
chmod +x "$AMUX_DIR"/lib/hooks/*.sh "$AMUX_DIR/lib/status.sh"
ok "All scripts are executable"

# ── 2. Shell profile ──────────────────────────────────────────────────────────
step "2. Shell profile"

# Detect current shell profile
case "${SHELL##*/}" in
    zsh)
        PROFILE="$HOME/.zshrc"
        ;;
    bash)
        if [ -f "$HOME/.bashrc" ]; then
            PROFILE="$HOME/.bashrc"
        else
            PROFILE="$HOME/.bash_profile"
        fi
        ;;
    fish)
        PROFILE="$HOME/.config/fish/config.fish"
        ;;
    *)
        PROFILE="$HOME/.profile"
        ;;
esac

EXPORT_LINE="export AMUX_DIR=\"$AMUX_DIR\""

if grep -q "AMUX_DIR" "$PROFILE" 2>/dev/null; then
    skip "AMUX_DIR already in $PROFILE"
else
    printf '\n# AMux\n%s\n' "$EXPORT_LINE" >> "$PROFILE"
    ok "Added AMUX_DIR to $PROFILE"
fi

# ── 3. tmux config ────────────────────────────────────────────────────────────
step "3. tmux config (~/.tmux.conf)"
TMUX_CONF="$HOME/.tmux.conf"
[ -f "$TMUX_CONF" ] || touch "$TMUX_CONF"

if grep -q "amux" "$TMUX_CONF" 2>/dev/null; then
    skip "~/.tmux.conf (already configured)"
else
    printf '\n# AMux\nif-shell '"'"'[ -n "$AMUX_DIR" ]'"'"' '"'"'source-file "%s/tmux-addon.conf"'"'"'\n' "$AMUX_DIR" >> "$TMUX_CONF"
    ok "Added AMux source to ~/.tmux.conf"
fi

# ── 4. Claude Code hooks ──────────────────────────────────────────────────────
step "4. Claude Code hooks (~/.claude/settings.json)"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
mkdir -p "$HOME/.claude"

if ! command -v python3 &>/dev/null; then
    err "python3 not found — skipping (add hooks manually from $AMUX_DIR/.claude/settings.json)"
else
    result=$(python3 - "$CLAUDE_SETTINGS" "$AMUX_DIR" <<'PYEOF'
import json, sys, os

settings_file, amux_dir = sys.argv[1], sys.argv[2]

config = {}
if os.path.exists(settings_file) and os.path.getsize(settings_file) > 0:
    try:
        with open(settings_file) as f:
            config = json.load(f)
    except json.JSONDecodeError:
        pass

config.setdefault("hooks", {})

amux_hooks = {
    "Stop":         f"{amux_dir}/lib/hooks/on-stop.sh",
    "Notification": f"{amux_dir}/lib/hooks/on-notification.sh",
    "PreToolUse":   f"{amux_dir}/lib/hooks/on-pre-tool.sh",
}

changed = False
for hook_type, cmd in amux_hooks.items():
    config["hooks"].setdefault(hook_type, [])
    already = any(
        any(h.get("command", "") == cmd for h in entry.get("hooks", []))
        for entry in config["hooks"][hook_type]
    )
    if not already:
        config["hooks"][hook_type].append({
            "matcher": "",
            "hooks": [{"type": "command", "command": cmd}]
        })
        changed = True

if changed:
    with open(settings_file, "w") as f:
        json.dump(config, f, indent=2)
    print("merged")
else:
    print("present")
PYEOF
)
    case "$result" in
        merged)  ok "Merged AMux hooks into ~/.claude/settings.json" ;;
        present) skip "~/.claude/settings.json (hooks already present)" ;;
        *)       err "Unexpected error merging Claude settings" ;;
    esac
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo "  ─────────────────────────────────────"
ok "AMux installed"
echo ""
echo "  Activate now:"
printf '    source %s\n' "$PROFILE"
echo "  Then reload tmux (or start a new session):"
echo "    tmux source ~/.tmux.conf"
echo ""
