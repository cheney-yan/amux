#!/usr/bin/env bash
# install.sh — Install AMux into the user's environment
#
# Usage:
#   bash install.sh          # interactive (shows what to add manually)
#   bash install.sh --yes    # auto-write to shell profile (like nvm --install)

set -e
AMUX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUTO_WRITE=0
[[ "$*" == *"--yes"* ]] && AUTO_WRITE=1

ok()   { printf '\033[32m  ✓ %s\033[0m\n' "$*"; }
skip() { printf '\033[33m  · %s\033[0m\n' "$*"; }
err()  { printf '\033[31m  ✗ %s\033[0m\n' "$*"; }
step() { printf '\n\033[1m%s\033[0m\n' "$*"; }
dim()  { printf '\033[2m  %s\033[0m\n' "$*"; }

echo ""
echo "  AMux — Agent Mux installer"
echo "  AMUX_DIR: $AMUX_DIR"

# ── 1. Permissions ────────────────────────────────────────────────────────────
step "1. Scripts"
chmod +x "$AMUX_DIR/amux.sh" "$AMUX_DIR/test.sh" "$AMUX_DIR/install.sh"
chmod +x "$AMUX_DIR"/lib/hooks/*.sh "$AMUX_DIR/lib/status.sh"
ok "All scripts are executable"

# ── 2. Shell profile ──────────────────────────────────────────────────────────
step "2. Shell profile"

# Detect shell and pick profile file
case "${SHELL##*/}" in
    zsh)  PROFILE="$HOME/.zshrc" ;;
    bash) PROFILE="$HOME/.bash_profile" ; [ -f "$HOME/.bashrc" ] && PROFILE="$HOME/.bashrc" ;;
    *)    PROFILE="" ;;
esac

EXPORT_LINE="export AMUX_DIR=\"$AMUX_DIR\""

if [ -n "$PROFILE" ] && grep -q "AMUX_DIR" "$PROFILE" 2>/dev/null; then
    skip "AMUX_DIR already in $PROFILE"
elif [ "$AUTO_WRITE" = "1" ] && [ -n "$PROFILE" ]; then
    printf '\n# AMux\n%s\n' "$EXPORT_LINE" >> "$PROFILE"
    ok "Added to $PROFILE"
else
    echo ""
    echo "  Add the following line to your shell profile (~/.zshrc, ~/.bashrc, etc.):"
    echo ""
    printf '    \033[36m%s\033[0m\n' "$EXPORT_LINE"
    echo ""
    dim "(run with --yes to do this automatically)"
fi

# ── 3. tmux config ────────────────────────────────────────────────────────────
step "3. tmux config"
TMUX_CONF="$HOME/.tmux.conf"
SOURCE_LINE="source-file \"$AMUX_DIR/tmux-addon.conf\""

[ -f "$TMUX_CONF" ] || touch "$TMUX_CONF"

if grep -q "amux" "$TMUX_CONF" 2>/dev/null; then
    skip "~/.tmux.conf (already configured)"
else
    printf '\n# AMux\nif-shell '"'"'[ -n "$AMUX_DIR" ]'"'"' %s\n' "\"$SOURCE_LINE\"" >> "$TMUX_CONF"
    ok "Added AMux source to ~/.tmux.conf"
fi

# ── 4. Claude Code hooks ──────────────────────────────────────────────────────
step "4. Claude Code hooks"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
mkdir -p "$HOME/.claude"

if ! command -v python3 &>/dev/null; then
    err "python3 not found — skipping Claude hooks merge"
    echo "     Manually add hooks from: $AMUX_DIR/.claude/settings.json"
else
    result=$(python3 - "$CLAUDE_SETTINGS" "$AMUX_DIR" <<'PYEOF'
import json, sys, os

settings_file = sys.argv[1]
amux_dir = sys.argv[2]

# Load existing settings
config = {}
if os.path.exists(settings_file) and os.path.getsize(settings_file) > 0:
    try:
        with open(settings_file) as f:
            config = json.load(f)
    except json.JSONDecodeError:
        pass

config.setdefault("hooks", {})

amux_hooks = {
    "Stop":        f"{amux_dir}/lib/hooks/on-stop.sh",
    "Notification": f"{amux_dir}/lib/hooks/on-notification.sh",
    "PreToolUse":  f"{amux_dir}/lib/hooks/on-pre-tool.sh",
}

changed = False
for hook_type, cmd in amux_hooks.items():
    config["hooks"].setdefault(hook_type, [])
    # Check if this command is already present anywhere in this hook type
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
echo "  Next steps:"
echo "    1. source ~/.zshrc          (or open a new terminal)"
echo "    2. tmux source ~/.tmux.conf (or start a new tmux session)"
echo ""
