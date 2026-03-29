# AMux — Agent Mux

**在 tmux 里管理多个 AI Agent session 的工具。**

> 🚧 **当前支持：Claude Code**。AMux 的设计目标是支持所有主流 AI coding agent，更多 agent 的集成正在规划中。

---

## 中文

### 为什么做这个？

用 Claude Code 工作时，常常需要同时跑多个 session——一个在写代码，一个在跑测试，一个在处理另一个任务。问题是：**你不知道哪个 session 完成了，哪个在等你操作，哪个出错了**。你只能不停地切换窗口去检查。

AMux 解决这个问题。它让每个 Claude session 能够主动通知 tmux，把状态实时显示在状态栏上。你坐在任意一个窗口里，一眼就能看到所有 Claude session 的情况。

### 功能

- **Window 自动命名**：有 Claude 在跑的窗口，名字自动加前缀，一眼可辨
- **状态前缀**：
  - `[C]` — Claude 空闲
  - `[C🔧]` — 正在调用工具
  - `[C✅]` — 完成，等待你的下一步指令
  - `[C❗]` — 需要你操作（权限确认、输入等）
- **弹出通知**：当你在其他窗口工作时，完成或需要交互会短暂弹出提示
- **读过即清除**：切换到该窗口，`✅` 和 `❗` 自动消失
- **纯 terminal**：不依赖 macOS / Windows 特有机制，SSH 远程环境同样适用

### 安装

**一键安装：**

```bash
git clone https://github.com/cheney-yan/amux.git ~/.amux && bash ~/.amux/install.sh
```

安装脚本全自动完成以下四步：
1. 让所有脚本可执行
2. 检测当前 shell，自动写入对应的 profile（`~/.zshrc` / `~/.bashrc` 等）
3. 在 `~/.tmux.conf` 末尾追加 AMux source（不覆盖已有配置）
4. 将 Claude Code hooks 合并进 `~/.claude/settings.json`（不覆盖已有配置）

### 手动配置

在 shell profile 里加：
```bash
export AMUX_DIR="$HOME/.amux"
```

在 `~/.tmux.conf` 末尾加：
```bash
if-shell '[ -n "$AMUX_DIR" ]' 'source-file "$AMUX_DIR/tmux-addon.conf"'
```

### 使用方式

安装完成后，**正常启动 tmux 即可**，无需做任何额外操作。

当你在某个 pane 里运行 `claude`，AMux 会自动检测到，并更新那个窗口的名字和状态。

### 要求

- tmux 3.0+
- bash 4.0+（macOS 自带的 bash 是 3.x，建议用 zsh 或 `brew install bash`）
- python3（用于安装时合并 Claude Code settings，安装后不再需要）
- `jq`（可选，用于解析 Claude 通知消息，没有也能工作）

---

## English

### Why does this exist?

When working with AI coding agents, you often run multiple sessions simultaneously — one writing code, one running tests, one handling another task. The problem: **you don't know which session finished, which one needs your input, and which one hit an error**. You end up constantly switching windows to check.

AMux solves this. It lets each agent session actively notify tmux, displaying live status in the status bar. Wherever you are, you can see the state of every agent session at a glance.

> **Agent support**: Claude Code is currently supported. Support for additional agents (Gemini CLI, Codex, etc.) is planned — contributions welcome.

### Features

- **Automatic window naming**: Windows running Claude get a prefix automatically
- **Status prefixes**:
  - `[C]` — Claude idle
  - `[C🔧]` — Tool call in progress
  - `[C✅]` — Done, waiting for your next instruction
  - `[C❗]` — Needs your attention (permission prompt, input required, etc.)
- **Pop-up notifications**: Brief status bar alerts when you're in another window
- **Read-to-dismiss**: Switch to a window and `✅` / `❗` clear automatically
- **Terminal-only**: No macOS / Windows dependencies — works over SSH

### Installation

**One-liner:**

```bash
git clone https://github.com/cheney-yan/amux.git ~/.amux && bash ~/.amux/install.sh
```

The installer is fully automatic:
1. Makes all scripts executable
2. Detects your current shell and writes `AMUX_DIR` to the appropriate profile (`~/.zshrc`, `~/.bashrc`, etc.)
3. Appends an AMux source line to `~/.tmux.conf` (non-destructive)
4. Merges Claude Code hooks into `~/.claude/settings.json` (non-destructive)

### Manual setup (without the installer)

Add to your shell profile:
```bash
export AMUX_DIR="$HOME/.amux"
```

Add to the end of `~/.tmux.conf`:
```bash
if-shell '[ -n "$AMUX_DIR" ]' 'source-file "$AMUX_DIR/tmux-addon.conf"'
```

### Usage

After installation, **just use tmux normally** — no extra steps required.

When you run `claude` in any pane, AMux detects it automatically and updates that window's name and status prefix.

### Requirements

- tmux 3.0+
- bash 4.0+ (macOS ships with bash 3.x — zsh or `brew install bash` recommended)
- python3 (only needed during install for merging Claude Code settings)
- `jq` (optional — used to parse Claude notification messages)

### How it works

AMux has two parts:

**1. Process detection** (`lib/status.sh`, runs every 2 seconds via tmux `status-interval`):
Scans all pane PIDs and their child processes for `claude` in the command line. When found, renames the window with the appropriate prefix.

**2. Claude Code hooks** (`lib/hooks/`, configured in `~/.claude/settings.json`):
Claude Code fires `PreToolUse`, `Stop`, and `Notification` hooks during its lifecycle. AMux hooks write state into tmux pane options (`@amux_state`), which are read by the status scanner to update the window prefix.

Each hook explicitly targets `$TMUX_PANE` so multiple Claude sessions never interfere with each other.

### License

MIT
