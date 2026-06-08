#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────────────────────
# DOMI onboarding — macOS 12 (Monterey) 專用
#
# 為什麼有這支:macOS 12 被 Homebrew 列為 Tier 3,沒有預編好的 bottle,`brew
# install gh` 會把 Go 從原始碼編譯(十幾分鐘~一小時)。本 script **不用 Homebrew**,
# 改用官方 `.pkg` / binary 安裝 git(Xcode CLT)、Node、gh,避開漫長編譯。
#
# macOS 13+ 請用 onboard-macos.sh(走 Homebrew,較簡單)。
# Usage: curl -fsSL <raw-url> | bash   或   bash onboard-macos-12.sh
# ──────────────────────────────────────────────────────────────

DOMI_PROJECT_DIR="$HOME/project"
DOMI_ONBOARD_URL="https://raw.githubusercontent.com/domiearth/domi-onboard/main/onboard-macos-12.sh"

info()  { printf '\033[1;34m[INFO]\033[0m  %s\n' "$*"; }
ok()    { printf '\033[1;32m[OK]\033[0m    %s\n' "$*"; }
warn()  { printf '\033[1;33m[WARN]\033[0m  %s\n' "$*"; }
fail()  { printf '\033[1;31m[FAIL]\033[0m  %s\n' "$*"; exit 1; }
have()  { command -v "$1" &>/dev/null; }

# ── stdin / TTY guard(同 onboard-macos.sh:被 pipe 時重抓自己 + 接終端機)──
if [[ ! -t 0 && -z "${DOMI_ONBOARD_REEXEC:-}" ]]; then
  if [[ -r /dev/tty ]]; then
    _self="$(mktemp "${TMPDIR:-/tmp}/onboard-macos-12.XXXXXX.sh")"
    if curl -fsSL "$DOMI_ONBOARD_URL" -o "$_self"; then
      exec env DOMI_ONBOARD_REEXEC=1 bash "$_self" </dev/tty
    fi
    rm -f "$_self"
    warn "Could not re-fetch script for interactive run; continuing non-interactively."
  fi
  export DOMI_NONINTERACTIVE=1
fi

# macOS 版本提醒
_osver="$(sw_vers -productVersion 2>/dev/null || echo "?")"
info "macOS $_osver — 走「不用 Homebrew」的 macOS 12 安裝路徑。"
case "$_osver" in
  13.*|14.*|15.*|1[6-9].*) warn "你其實是 macOS 13+,建議改用 onboard-macos.sh(更簡單)。仍可繼續。" ;;
esac

# ── 1. git(Xcode Command Line Tools)──────────────────────
info "Checking git (Xcode Command Line Tools)..."
if have git && git --version &>/dev/null; then
  ok "git $(git --version | awk '{print $3}') already installed"
else
  info "Installing Xcode Command Line Tools (會跳一個安裝視窗,按「安裝」)..."
  xcode-select --install 2>/dev/null || true
  if [[ -z "${DOMI_NONINTERACTIVE:-}" ]]; then
    warn "等那個視窗裝完(幾分鐘),完成後按 Enter 繼續..."
    read -r </dev/tty
  fi
  have git || fail "git 還沒裝好 — 等 Command Line Tools 裝完再重跑本 script。"
  ok "git $(git --version | awk '{print $3}')"
fi

# ── 2. Node.js(官方 universal .pkg,避開 brew 編譯)─────────
info "Checking Node.js..."
if have node; then
  ok "node $(node --version) already installed"
else
  info "Fetching Node LTS (official .pkg)..."
  NODE_LTS=$(curl -fsSL https://nodejs.org/dist/index.json \
    | python3 -c 'import json,sys; print([r["version"] for r in json.load(sys.stdin) if r["lts"]][0])')
  info "  LTS = $NODE_LTS — 下載官方安裝檔(需要 sudo 密碼裝)..."
  _pkg="$(mktemp -d)/node.pkg"
  curl -fsSL "https://nodejs.org/dist/${NODE_LTS}/node-${NODE_LTS}.pkg" -o "$_pkg"
  sudo installer -pkg "$_pkg" -target / && ok "node $(node --version) installed" \
    || fail "node .pkg 安裝失敗 — 手動下載:https://nodejs.org/en/download"
  rm -f "$_pkg"
fi
NODE_MAJOR=$(node --version | sed 's/^v//; s/\..*//')
(( NODE_MAJOR >= 18 )) || fail "Node >= 18 required (found $(node --version))."

# ── 3. GitHub CLI(官方 .pkg,避開 brew 的 Go 源碼編譯)──────
info "Checking GitHub CLI..."
if have gh; then
  ok "gh $(gh --version | head -1 | awk '{print $3}') already installed"
else
  info "Fetching gh latest (official .pkg)..."
  GH_PKG_URL=$(curl -fsSL https://api.github.com/repos/cli/cli/releases/latest \
    | python3 -c 'import json,sys; a=json.load(sys.stdin)["assets"]; print(next(x["browser_download_url"] for x in a if x["name"].endswith("macOS_universal.pkg")))' 2>/dev/null || echo "")
  if [[ -n "$GH_PKG_URL" ]]; then
    _pkg="$(mktemp -d)/gh.pkg"
    curl -fsSL "$GH_PKG_URL" -o "$_pkg"
    sudo installer -pkg "$_pkg" -target / && ok "gh installed" \
      || warn "gh .pkg 安裝失敗 — 手動:https://github.com/cli/cli/releases/latest"
    rm -f "$_pkg"
  else
    warn "找不到 gh 官方 .pkg — 手動下載:https://github.com/cli/cli/releases/latest"
  fi
  have gh || fail "gh 還沒裝好,請手動安裝後重跑。"
fi

# ── 4. Claude Code CLI(npm,與 macos.sh 相同)──────────────
info "Checking Claude Code CLI..."
if have claude; then
  ok "claude CLI already installed"
else
  info "Installing Claude Code CLI via npm..."
  npm install -g @anthropic-ai/claude-code && ok "claude CLI installed" \
    || warn "claude install failed — npm install -g @anthropic-ai/claude-code"
fi

# ── 5. Claude Desktop(手動,macOS 12 brew cask 不可靠)──────
info "Claude Desktop..."
if [[ -d "/Applications/Claude.app" ]]; then
  ok "Claude Desktop already installed"
else
  warn "請手動下載安裝 Claude Desktop:https://claude.ai/download"
  if [[ -z "${DOMI_NONINTERACTIVE:-}" ]]; then
    warn "裝好後按 Enter 繼續(或 Ctrl+C 跳過)..."
    read -r </dev/tty
  fi
fi

# ── 6. GitHub auth ──────────────────────────────────────────
info "Checking GitHub auth..."
if gh auth status &>/dev/null; then
  ok "Already authenticated to GitHub"
else
  info "請依畫面登入 GitHub(選 HTTPS + web browser)..."
  gh auth login
fi

# ── 7. Project dir + 7b. 個人 agent repo ────────────────────
info "Setting up project directory: $DOMI_PROJECT_DIR"
mkdir -p "$DOMI_PROJECT_DIR"

info "Cloning your personal agent repo..."
GH_HANDLE=$(gh api user --jq '.login' 2>/dev/null || echo "")
if [[ -z "$GH_HANDLE" ]]; then
  warn "讀不到你的 GitHub 帳號 — 跳過。之後:gh repo clone domiearth/agent-<你的帳號>"
elif [[ -d "$DOMI_PROJECT_DIR/agent-$GH_HANDLE/.git" ]]; then
  ok "agent-$GH_HANDLE already cloned"
elif gh repo view "domiearth/agent-$GH_HANDLE" &>/dev/null; then
  gh repo clone "domiearth/agent-$GH_HANDLE" "$DOMI_PROJECT_DIR/agent-$GH_HANDLE" \
    && ok "cloned agent-$GH_HANDLE — your personal workspace" \
    || warn "clone failed — retry: gh repo clone domiearth/agent-$GH_HANDLE"
else
  warn "個人 agent repo domiearth/agent-$GH_HANDLE 還沒建 — 找 Corey(domi-init);先用 /hub run 也行。"
fi

# ── 8. domi-claude-plugins(個人機三件套)───────────────────
echo ""
info "domi-claude-plugins — personal-machine plugins (REQUIRED)"
if claude plugin marketplace list 2>/dev/null | grep -q "domi-claude-plugins"; then
  ok "DOMI marketplace already registered"
  # Re-run = update: refresh marketplace so newer plugin versions are visible.
  claude plugin marketplace update domi-claude-plugins 2>/dev/null || true
else
  claude plugin marketplace add https://github.com/domiearth/domi-claude-plugins \
    && ok "DOMI marketplace registered" || warn "marketplace add failed (need domiearth org access)"
fi
for plugin in individual-agent hub-relay domi-guide; do
  info "  Installing / updating $plugin..."
  # install = no-op if present; update = bump an already-installed plugin to latest.
  claude plugin install "${plugin}@domi-claude-plugins" 2>/dev/null || true
  claude plugin update  "${plugin}@domi-claude-plugins" 2>/dev/null || true
done
ok "domi-claude-plugins done"

# ── 9. AgentHUB 連線(委派 hub-setup.sh)────────────────────
echo ""
info "AgentHUB connection setup"
HUB_SETUP=$(ls "$HOME"/.claude/plugins/cache/domi-claude-plugins/hub-relay/*/scripts/hub-setup.sh 2>/dev/null | sort -V | tail -1)
if [[ -n "${DOMI_NONINTERACTIVE:-}" ]]; then
  info "Non-interactive — 之後用 /hub setup 設定。"
elif [[ -n "$HUB_SETUP" ]]; then
  info "Launching hub-setup (host / user / password / 你的 GitHub 帳號)..."
  echo "  還沒拿到 hub 資訊?全部按 Enter 跳過,之後再跑。"
  bash "$HUB_SETUP" </dev/tty || warn "hub-setup 跳過/失敗 — 之後:bash $HUB_SETUP"
else
  warn "找不到 hub-setup.sh(plugin 沒裝成功)— 之後 /hub setup 設定。"
fi

# ── 10. Summary ─────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ok "DOMI onboarding (macOS 12) complete!"
echo "    git $(git --version | awk '{print $3}') · gh $(gh --version | head -1 | awk '{print $3}') · node $(node --version) · claude ✅"
echo "  Plugins: individual-agent · hub-relay · domi-guide"
echo ""
echo "  Next: 1) 登入 Claude Desktop(帳號找 Corey)"
if [[ -n "${GH_HANDLE:-}" && -d "$DOMI_PROJECT_DIR/agent-$GH_HANDLE/.git" ]]; then
  echo "        2) cd $DOMI_PROJECT_DIR/agent-$GH_HANDLE && claude"
else
  echo "        2) gh repo clone domiearth/agent-<你的帳號>,再 cd 進去 claude"
fi
echo "        3) session 內貼上  /domi-guide:guide all  開始教學"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── 11. Guided first session ────────────────────────────────
TUTOR_DIR="$DOMI_PROJECT_DIR"
[[ -n "${GH_HANDLE:-}" && -d "$DOMI_PROJECT_DIR/agent-$GH_HANDLE/.git" ]] && TUTOR_DIR="$DOMI_PROJECT_DIR/agent-$GH_HANDLE"
if [[ -z "${DOMI_NONINTERACTIVE:-}" ]] && have claude; then
  echo ""
  printf '  Start the guided tutorial now? [Y/n] '
  read -r START_TUTORIAL </dev/tty
  if [[ ! "$START_TUTORIAL" =~ ^[nN]$ ]]; then
    echo ""
    echo "  ✅ Claude session 開啟後,把這一行整段複製貼上按 Enter:"
    echo "        /domi-guide:guide all"
    echo "  (顯示 Unknown command → domi-guide 沒裝成功,找 Corey)"
    echo ""
    cd "$TUTOR_DIR" && exec claude </dev/tty
  fi
  info "Skipped. 之後:開 claude session 貼上  /domi-guide:guide all"
fi
