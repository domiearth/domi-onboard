#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────────────────────
# DOMI onboarding — macOS
#
# Usage:
#   bash onboard-macos.sh [-t GH_TOKEN] [-h HUB_HOST]
#   curl -fsSL <raw-url> -o ~/onboard.sh && bash ~/onboard.sh -t <token> -h 192.168.0.141
#
#   -t / --token            共用帳號的 GitHub PAT(私有 marketplace + repo 都靠它)。
#                           省略則讀環境變數 DOMI_GH_TOKEN,再省略則隱藏輸入(不進 history)。
#   -h / --host             AgentHUB LAN 位址(預設 192.168.0.141);傳給 hub-setup。
#   --host-tailscale        AgentHUB Tailscale 位址(預設 100.72.24.53);傳給 hub-setup。
#   -u / --user             hub ssh 帳號(預設 domi);傳給 hub-setup。
#   -p / --password         hub ssh 密碼;傳給 hub-setup。省略則 hub-setup 隱藏輸入。
#   注意:token / 密碼寫在指令列會留在 shell history。要乾淨就別帶,讓它隱藏輸入。
# ──────────────────────────────────────────────────────────────

DOMI_PROJECT_DIR="$HOME/project"
DOMI_ONBOARD_URL="https://raw.githubusercontent.com/domiearth/domi-onboard/main/onboard-macos.sh"

# ── helpers ──────────────────────────────────────────────────

info()  { printf '\033[1;34m[INFO]\033[0m  %s\n' "$*"; }
ok()    { printf '\033[1;32m[OK]\033[0m    %s\n' "$*"; }
warn()  { printf '\033[1;33m[WARN]\033[0m  %s\n' "$*"; }
fail()  { printf '\033[1;31m[FAIL]\033[0m  %s\n' "$*"; exit 1; }

need_cmd() {
  if command -v "$1" &>/dev/null; then
    ok "$1 already installed ($(command -v "$1"))"
    return 1
  fi
  return 0
}

# ── stdin / TTY guard ────────────────────────────────────────
# When launched as `curl … | bash`, stdin is the *pipe carrying this script*,
# not the keyboard. Two things break:
#   1. every interactive `read` below has nothing to read from; and
#   2. any child process that touches stdin (the Homebrew installer, the Go
#      source build on old macOS, sudo) eats the un-parsed remainder of this
#      script — which is exactly the "hang + script source dumped to terminal"
#      symptom on macOS 12.
# Fix: if our stdin isn't a terminal, re-fetch ourselves to a real file and
# re-exec with the controlling terminal (/dev/tty) as stdin. If there's no
# terminal at all (CI / nested pipe), fall through in non-interactive mode and
# skip the prompts instead of blocking.
if [[ ! -t 0 && -z "${DOMI_ONBOARD_REEXEC:-}" ]]; then
  if [[ -r /dev/tty ]]; then
    _self="$(mktemp "${TMPDIR:-/tmp}/onboard-macos.XXXXXX.sh")"
    if curl -fsSL "$DOMI_ONBOARD_URL" -o "$_self"; then
      exec env DOMI_ONBOARD_REEXEC=1 bash "$_self" "$@" </dev/tty
    fi
    rm -f "$_self"
    warn "Could not re-fetch script for interactive run; continuing non-interactively."
  fi
  export DOMI_NONINTERACTIVE=1
fi

# ── arg parsing (-t token / -h hub host) ─────────────────────
GH_TOKEN_ARG="${DOMI_GH_TOKEN:-}"
HUB_HOST_ARG=""
HUB_HOST_TS_ARG=""
HUB_USER_ARG=""
HUB_PASS_ARG=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -t|--token)                   GH_TOKEN_ARG="${2:-}"; shift 2 ;;
    -h|--host)                    HUB_HOST_ARG="${2:-}"; shift 2 ;;
    --host-tailscale|--tailscale) HUB_HOST_TS_ARG="${2:-}"; shift 2 ;;
    -u|--user)                    HUB_USER_ARG="${2:-}"; shift 2 ;;
    -p|--password|--pass)         HUB_PASS_ARG="${2:-}"; shift 2 ;;
    --help)                       echo "Usage: bash onboard-macos.sh [-t GH_TOKEN] [-h HUB_HOST] [--host-tailscale TS] [-u HUB_USER] [-p HUB_PASS]"; exit 0 ;;
    *)                            warn "Unknown argument: $1"; shift ;;
  esac
done

# ── 0. Homebrew ──────────────────────────────────────────────

info "Checking Homebrew..."
if need_cmd brew; then
  info "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Add brew to PATH for Apple Silicon
  if [[ -f /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
fi

# ── 1. Git ───────────────────────────────────────────────────

info "Checking git..."
if need_cmd git; then
  info "Installing git..."
  brew install git
fi
ok "git $(git --version | awk '{print $3}')"

# ── 2. GitHub CLI ────────────────────────────────────────────

info "Checking GitHub CLI..."
if need_cmd gh; then
  info "Installing GitHub CLI..."
  brew install gh
fi
ok "gh $(gh --version | head -1 | awk '{print $3}')"

# ── 3. Node.js (required by Claude Code CLI) ────────────────

info "Checking Node.js..."
if need_cmd node; then
  info "Installing Node.js LTS..."
  brew install node@22
  brew link --overwrite node@22
fi
NODE_VER=$(node --version)
NODE_MAJOR=${NODE_VER#v}
NODE_MAJOR=${NODE_MAJOR%%.*}
if (( NODE_MAJOR < 18 )); then
  fail "Node.js >= 18 required (found $NODE_VER). Run: brew install node@22"
fi
ok "node $NODE_VER"

# ── 4. Claude Code CLI ──────────────────────────────────────

info "Checking Claude Code CLI..."
if need_cmd claude; then
  info "Installing Claude Code CLI via npm..."
  npm install -g @anthropic-ai/claude-code
fi
ok "claude CLI installed"

# ── 5. Claude Code Desktop ──────────────────────────────────

info "Checking Claude Desktop..."
if [[ -d "/Applications/Claude.app" ]]; then
  ok "Claude Desktop already installed"
else
  info "Installing Claude Desktop..."
  if brew install --cask claude 2>/dev/null; then
    ok "Claude Desktop installed via Homebrew"
  else
    warn "Auto-install failed. Please download manually:"
    warn "  https://claude.ai/download"
    if [[ -z "${DOMI_NONINTERACTIVE:-}" ]]; then
      warn "Press Enter after installing, or Ctrl+C to skip..."
      read -r </dev/tty
    fi
  fi
fi

# ── 6. GitHub authentication ────────────────────────────────

# 共用帳號:用 PAT 登入(--with-token),省去每個人各自跑 web 流程。
# token 來源優先序:-t 參數 → DOMI_GH_TOKEN 環境變數 → 隱藏輸入(不進 history)。
info "Checking GitHub auth..."
if [[ -z "$GH_TOKEN_ARG" && -z "${DOMI_NONINTERACTIVE:-}" ]] && ! gh auth status &>/dev/null; then
  info "貼上共用帳號的 GitHub PAT(輸入不會顯示,也不會留在 history)..."
  read -r -s -p "  GitHub PAT: " GH_TOKEN_ARG </dev/tty; echo ""
fi
if [[ -n "$GH_TOKEN_ARG" ]]; then
  printf '%s' "$GH_TOKEN_ARG" | gh auth login --with-token \
    && ok "GitHub 已用 token 登入(共用帳號)" \
    || fail "Token 登入失敗 — 檢查 PAT(建議 fine-grained、只授權 domi-claude-plugins 的 Contents: Read)。"
  gh auth setup-git 2>/dev/null || true   # 讓 git clone 私有 repo 走 gh 憑證
  # 持久化唯讀 token 給 plugin 自動更新器「自我內含」使用:domi-guide 背景 worker 會讀它
  # export GH_TOKEN,即使 gh 被清/未裝/在乾淨環境也照樣更新,不再靜默吃 stale cache。
  # chmod 600、絕不進任何 git。建議搭配 fine-grained、單 repo、唯讀 PAT 把外洩風險降到最低。
  AU_DIR="$HOME/.claude/.domi-autoupdate"; mkdir -p "$AU_DIR"
  ( umask 177; printf '%s' "$GH_TOKEN_ARG" > "$AU_DIR/gh-token" )
  ok "已存唯讀 token 供 plugin 自動更新(~/.claude/.domi-autoupdate/gh-token,chmod 600)"
elif gh auth status &>/dev/null; then
  ok "Already authenticated to GitHub"
else
  info "沒有 token — 改用互動式登入(選 HTTPS + web browser)..."
  gh auth login
fi

# ── 7. Project directory ────────────────────────────────────

info "Setting up project directory: $DOMI_PROJECT_DIR"
mkdir -p "$DOMI_PROJECT_DIR"

# ── 7b. Personal agent repo (your "drawer") ─────────────────
# Each person now OWNS their personal agent repo on THEIR OWN GitHub account as
# agent-self-<handle> (was: a shared domiearth/agent-<handle> org repo we cloned).
# Keeps personal drawers off the org (cost + clear ownership). One-time migration:
# if a legacy domiearth/agent-<handle> (or a local clone) exists, we copy its data
# into the new repo and commit + push. individual-agent plugin governs it.
info "Setting up your personal agent repo (on your own GitHub account)..."
GH_HANDLE=$(gh api user --jq '.login' 2>/dev/null || echo "")
NEW_REPO="agent-self-$GH_HANDLE"
NEW_DIR="$DOMI_PROJECT_DIR/$NEW_REPO"
LEGACY_REPO="agent-$GH_HANDLE"
LEGACY_DIR="$DOMI_PROJECT_DIR/$LEGACY_REPO"
if [[ -z "$GH_HANDLE" ]]; then
  warn "Could not read your GitHub handle (gh not authenticated?) — skipping."
  warn "  Create later: gh repo create <your-handle>/agent-self-<your-handle> --private"
elif [[ -d "$NEW_DIR/.git" ]]; then
  ok "$NEW_REPO already set up"
elif gh repo view "$GH_HANDLE/$NEW_REPO" &>/dev/null; then
  # Already created on a previous run / another machine — just clone it.
  gh repo clone "$GH_HANDLE/$NEW_REPO" "$NEW_DIR" \
    && ok "cloned $NEW_REPO — your personal workspace" \
    || warn "clone failed — retry later: gh repo clone $GH_HANDLE/$NEW_REPO"
else
  # Create it fresh under YOUR account, migrating legacy data if any exists.
  mkdir -p "$NEW_DIR" && ( cd "$NEW_DIR" && git init -q )
  MIG_SRC=""
  if [[ -d "$LEGACY_DIR/.git" ]]; then
    MIG_SRC="$LEGACY_DIR"
  elif gh repo view "domiearth/$LEGACY_REPO" &>/dev/null; then
    info "Found legacy domiearth/$LEGACY_REPO — migrating its data..."
    MIG_SRC="$(mktemp -d)/$LEGACY_REPO"
    gh repo clone "domiearth/$LEGACY_REPO" "$MIG_SRC" &>/dev/null || MIG_SRC=""
  fi
  [[ -n "$MIG_SRC" ]] && rsync -a --exclude='.git' "$MIG_SRC"/ "$NEW_DIR"/ 2>/dev/null \
    && info "Migrated data from $LEGACY_REPO."
  ( cd "$NEW_DIR" \
      && git add -A \
      && { git diff --cached --quiet && printf '# %s\n\nDOMI personal agent drawer — notes / reports / drafts. Owner-only.\n' "$NEW_REPO" > README.md && git add README.md || true; } \
      && git commit -q -m "init $NEW_REPO${MIG_SRC:+ (migrated from $LEGACY_REPO)}" \
      && git branch -M main ) \
    && gh repo create "$GH_HANDLE/$NEW_REPO" --private --source="$NEW_DIR" --remote=origin --push \
         -d "DOMI personal agent drawer ($GH_HANDLE)" \
    && ok "created + pushed $NEW_REPO${MIG_SRC:+ (migrated from $LEGACY_REPO)}" \
    || warn "create/push failed — finish later: cd $NEW_DIR && gh repo create $GH_HANDLE/$NEW_REPO --private --source=. --remote=origin --push"
fi

# ── 8. claude-workbench (optional) ──────────────────────────

echo ""
info "claude-workbench — Kirin's productivity plugins (mentor, kanban, chat)"
if [[ -n "${DOMI_NONINTERACTIVE:-}" ]]; then
  INSTALL_WORKBENCH="n"
  info "Non-interactive — skipping claude-workbench (re-run in a terminal to install)."
else
  printf '  Install claude-workbench? [y/N] '
  read -r INSTALL_WORKBENCH </dev/tty
fi

if [[ "$INSTALL_WORKBENCH" =~ ^[yY]$ ]]; then
  info "Registering claude-workbench marketplace..."
  if claude plugin marketplace list 2>/dev/null | grep -q "claude-workbench"; then
    ok "claude-workbench marketplace already registered"
    # Re-run = update: refresh marketplace so newer plugin versions are visible.
    claude plugin marketplace update claude-workbench 2>/dev/null || true
  else
    claude plugin marketplace add https://github.com/kirinchen/claude-workbench
    ok "claude-workbench marketplace registered"
  fi

  info "Installing / updating workbench plugins (mentor, kanban, chat)..."
  for plugin in mentor kanban chat; do
    info "  Installing / updating $plugin..."
    # install = no-op if present; update = bump an already-installed plugin to latest.
    claude plugin install "${plugin}@claude-workbench" 2>/dev/null || true
    claude plugin update  "${plugin}@claude-workbench" 2>/dev/null || true
  done
  ok "claude-workbench done"
else
  info "Skipping claude-workbench"
fi

# ── 9. domi-claude-plugins (required, via marketplace) ─────

echo ""
info "domi-claude-plugins — personal-machine plugins (REQUIRED)"
info "Registering DOMI marketplace (private — requires domiearth org access)..."

if claude plugin marketplace list 2>/dev/null | grep -q "domi-claude-plugins"; then
  ok "DOMI marketplace already registered"
  # Re-run = update: refresh marketplace so newer plugin versions are visible.
  claude plugin marketplace update domi-claude-plugins 2>/dev/null || true
else
  claude plugin marketplace add https://github.com/domiearth/domi-claude-plugins
  ok "DOMI marketplace registered"
fi

# Personal machines install ONLY these three. The governance guards
# (stack-guard / entity-guard / schema-change / project-protect / domi-init)
# run on the AgentHUB, not here — cross-repo work goes through hub-relay and the
# hub enforces them server-side. See domi-claude-plugins README (install matrix)
# + GO_LIVE_CHECKLIST.md §1.
info "Installing / updating DOMI plugins from marketplace..."
for plugin in individual-agent hub-relay domi-guide; do
  info "  Installing / updating $plugin..."
  # install = no-op if present; update = bump an already-installed plugin to latest.
  claude plugin install "${plugin}@domi-claude-plugins" 2>/dev/null || true
  claude plugin update  "${plugin}@domi-claude-plugins" 2>/dev/null || true
done
ok "domi-claude-plugins done"

# ── 9b. AgentHUB connection setup (delegates to hub-relay's hub-setup.sh) ──
# Single source of truth: hub-setup.sh handles host/user/password + your GitHub
# account, dual-host (LAN/Tailscale) failover, and SSH_ASKPASS auth — so no
# sshpass dependency here. (host/user/creds from Corey.)
echo ""
info "AgentHUB connection setup"
HUB_SETUP=$(ls "$HOME"/.claude/plugins/cache/domi-claude-plugins/hub-relay/*/scripts/hub-setup.sh 2>/dev/null | sort -V | tail -1)
HUB_ARGS=()
[[ -n "$HUB_HOST_ARG" ]]    && HUB_ARGS+=(--host "$HUB_HOST_ARG")
[[ -n "$HUB_HOST_TS_ARG" ]] && HUB_ARGS+=(--host-tailscale "$HUB_HOST_TS_ARG")
[[ -n "$HUB_USER_ARG" ]]    && HUB_ARGS+=(--user "$HUB_USER_ARG")
[[ -n "$HUB_PASS_ARG" ]]    && HUB_ARGS+=(--password "$HUB_PASS_ARG")
[[ -n "${GH_HANDLE:-}" ]]   && HUB_ARGS+=(--github "$GH_HANDLE")
if [[ -n "${DOMI_NONINTERACTIVE:-}" ]]; then
  info "Non-interactive — skipping. Configure later: /hub setup (or run hub-setup.sh)."
elif [[ -n "$HUB_SETUP" ]]; then
  info "Launching hub-setup (host / user / password / your GitHub account)..."
  echo "  Don't have the hub host/creds yet? Press Enter through to skip — run it later."
  bash "$HUB_SETUP" ${HUB_ARGS[@]+"${HUB_ARGS[@]}"} </dev/tty || warn "hub-setup skipped/failed — run later: bash $HUB_SETUP"
else
  warn "hub-relay hub-setup.sh not found (plugin install may have failed)."
  warn "  Configure later from any Claude session with: /hub setup"
fi

# ── 10. Summary ─────────────────────────────────────────────

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ok "DOMI onboarding complete!"
echo ""
echo "  Installed:"
echo "    git          $(git --version | awk '{print $3}')"
echo "    gh           $(gh --version | head -1 | awk '{print $3}')"
echo "    node         $(node --version)"
echo "    claude CLI   $(claude --version 2>/dev/null || echo 'installed')"
echo "    Claude Desktop  $(test -d /Applications/Claude.app && echo '✅' || echo '❌ manual install needed')"
echo ""
echo "  Plugins (personal machine, via domi-claude-plugins marketplace):"
echo "    individual-agent ✅  your personal repo behaviour + /note"
echo "    hub-relay        ✅  /hub — work on hub-side project agents"
echo "    domi-guide       ✅  /guide interactive tutorial"
[[ "${INSTALL_WORKBENCH:-}" =~ ^[yY]$ ]] && echo "    claude-workbench     ✅ (mentor, kanban, chat)"
echo ""
echo "  Next steps:"
echo "    1. Open Claude Desktop and sign in (account from Corey)"
if [[ -n "${GH_HANDLE:-}" && -d "$NEW_DIR/.git" ]]; then
  echo "    2. Your personal workspace: cd $NEW_DIR && claude"
else
  echo "    2. Create your personal repo: gh repo create <your-handle>/agent-self-<your-handle> --private"
fi
echo "    3. New here? The guided tour starts next — or type /guide anytime."
echo "    4. (If skipped above) run /hub setup to configure AgentHUB later"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── 11. Guided first session (optional) ─────────────────────
# Auto-start the tutorial: open an interactive session in the personal repo and
# seed a NATURAL-LANGUAGE prompt that asks Claude to run /domi-guide:guide all —
# so the tutor greets the user proactively (no "paste this yourself" step the
# welcome banner would scroll past).
#
# Why a natural-language prompt (not the slash command directly): a startup
# prompt STARTING WITH `/` is parsed as a command and HANGS the interactive
# session on some Macs. A plain-text prompt (first char ≠ `/`) is handled as a
# normal message — Claude then runs the command itself. Verified: this triggers
# the tutorial opening; plugin-missing → Claude reports it (we ask it to).
TUTOR_DIR="$DOMI_PROJECT_DIR"
if [[ -n "${GH_HANDLE:-}" && -d "$NEW_DIR/.git" ]]; then
  TUTOR_DIR="$NEW_DIR"   # start in your personal repo
fi
TUTOR_PROMPT="請用 /domi-guide:guide all 指令開始 DOMI 新人互動教學;全程繁體中文,先自我介紹 + 列出全部主題 + 問我準備好了沒,再等我回覆。若找不到該指令,請直接告訴我 domi-guide plugin 沒裝成功、要找 Corey。"

if [[ -z "${DOMI_NONINTERACTIVE:-}" ]] && command -v claude &>/dev/null; then
  echo ""
  printf '  Start the guided tutorial now? [Y/n] '
  read -r START_TUTORIAL </dev/tty
  if [[ ! "$START_TUTORIAL" =~ ^[nN]$ ]]; then
    info "Launching tutorial — 導師會主動開場。/exit 離開;之後任何 session 打 /guide 可續。"
    echo ""
    cd "$TUTOR_DIR" && exec claude "$TUTOR_PROMPT" </dev/tty
  fi
  info "Skipped. 開 claude session 後打 /guide 開始教學。"
fi
