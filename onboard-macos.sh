#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────────────────────
# DOMI onboarding — macOS
# Usage: curl -fsSL <raw-url> | bash
#    or: bash onboard-macos.sh
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
      exec env DOMI_ONBOARD_REEXEC=1 bash "$_self" </dev/tty
    fi
    rm -f "$_self"
    warn "Could not re-fetch script for interactive run; continuing non-interactively."
  fi
  export DOMI_NONINTERACTIVE=1
fi

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

info "Checking GitHub auth..."
if gh auth status &>/dev/null; then
  ok "Already authenticated to GitHub"
else
  info "Please authenticate with GitHub..."
  gh auth login
fi

# ── 7. Project directory ────────────────────────────────────

info "Setting up project directory: $DOMI_PROJECT_DIR"
mkdir -p "$DOMI_PROJECT_DIR"

# ── 7b. Personal agent repo (your "drawer") ─────────────────
# gh is installed + authenticated by now, so clone the person's own
# agent-<handle> repo first — it's their home base (notes / reports / drafts;
# individual-agent plugin governs it). Cross-repo work goes via /hub run.
info "Cloning your personal agent repo..."
GH_HANDLE=$(gh api user --jq '.login' 2>/dev/null || echo "")
if [[ -z "$GH_HANDLE" ]]; then
  warn "Could not read your GitHub handle (gh not authenticated?) — skipping."
  warn "  Clone later with: gh repo clone domiearth/agent-<your-handle>"
elif [[ -d "$DOMI_PROJECT_DIR/agent-$GH_HANDLE/.git" ]]; then
  ok "agent-$GH_HANDLE already cloned"
elif gh repo view "domiearth/agent-$GH_HANDLE" &>/dev/null; then
  gh repo clone "domiearth/agent-$GH_HANDLE" "$DOMI_PROJECT_DIR/agent-$GH_HANDLE" \
    && ok "cloned agent-$GH_HANDLE — your personal workspace" \
    || warn "clone failed — retry later: gh repo clone domiearth/agent-$GH_HANDLE"
else
  warn "Personal agent repo domiearth/agent-$GH_HANDLE not found yet."
  warn "  Ask Corey to create it (domi-init). You can still work via /hub run."
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
  else
    claude plugin marketplace add https://github.com/kirinchen/claude-workbench
    ok "claude-workbench marketplace registered"
  fi

  info "Installing workbench plugins (mentor, kanban, chat)..."
  for plugin in mentor kanban chat; do
    info "  Installing $plugin..."
    claude plugin install "${plugin}@claude-workbench" 2>/dev/null \
      || warn "  $plugin install skipped (may already be installed)"
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
else
  claude plugin marketplace add https://github.com/domiearth/domi-claude-plugins
  ok "DOMI marketplace registered"
fi

# Personal machines install ONLY these three. The governance guards
# (stack-guard / entity-guard / schema-change / project-protect / domi-init)
# run on the AgentHUB, not here — cross-repo work goes through hub-relay and the
# hub enforces them server-side. See domi-claude-plugins README (install matrix)
# + GO_LIVE_CHECKLIST.md §1.
info "Installing DOMI plugins from marketplace..."
for plugin in individual-agent hub-relay domi-guide; do
  info "  Installing $plugin..."
  claude plugin install "${plugin}@domi-claude-plugins" 2>/dev/null \
    || warn "  $plugin install skipped (may already be installed)"
done
ok "domi-claude-plugins done"

# ── 9b. AgentHUB connection setup (delegates to hub-relay's hub-setup.sh) ──
# Single source of truth: hub-setup.sh handles host/user/password + your GitHub
# account, dual-host (LAN/Tailscale) failover, and SSH_ASKPASS auth — so no
# sshpass dependency here. (host/user/creds from Corey.)
echo ""
info "AgentHUB connection setup"
HUB_SETUP=$(ls "$HOME"/.claude/plugins/cache/domi-claude-plugins/hub-relay/*/scripts/hub-setup.sh 2>/dev/null | sort -V | tail -1)
if [[ -n "${DOMI_NONINTERACTIVE:-}" ]]; then
  info "Non-interactive — skipping. Configure later: /hub setup (or run hub-setup.sh)."
elif [[ -n "$HUB_SETUP" ]]; then
  info "Launching hub-setup (host / user / password / your GitHub account)..."
  echo "  Don't have the hub host/creds yet? Press Enter through to skip — run it later."
  bash "$HUB_SETUP" </dev/tty || warn "hub-setup skipped/failed — run later: bash $HUB_SETUP"
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
if [[ -n "${GH_HANDLE:-}" && -d "$DOMI_PROJECT_DIR/agent-$GH_HANDLE/.git" ]]; then
  echo "    2. Your personal workspace: cd $DOMI_PROJECT_DIR/agent-$GH_HANDLE && claude"
else
  echo "    2. Clone your personal repo: gh repo clone domiearth/agent-<your-handle>"
fi
echo "    3. New here? The guided tour starts next — or type /guide anytime."
echo "    4. (If skipped above) run /hub setup to configure AgentHUB later"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── 11. Guided first session (optional) ─────────────────────
# Open an interactive Claude session in the user's personal repo so they can
# start the tutorial by typing /guide.
#
# IMPORTANT: Claude Code has NO way to run a slash command at startup —
# `claude "/guide all"` is parsed as an unknown command. Slash commands only
# resolve when typed INSIDE an interactive session. So we drop the user into
# a clean interactive session and tell them to type /guide (not auto-run it).
TUTOR_DIR="$DOMI_PROJECT_DIR"
if [[ -n "${GH_HANDLE:-}" && -d "$DOMI_PROJECT_DIR/agent-$GH_HANDLE/.git" ]]; then
  TUTOR_DIR="$DOMI_PROJECT_DIR/agent-$GH_HANDLE"   # start in your personal repo
fi

if [[ -z "${DOMI_NONINTERACTIVE:-}" ]] && command -v claude &>/dev/null; then
  echo ""
  printf '  Start a guided Claude session now? [Y/n] '
  read -r START_TUTORIAL </dev/tty
  if [[ ! "$START_TUTORIAL" =~ ^[nN]$ ]]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  ✅ Session 開啟後,輸入這一行開始新人教學:"
    echo ""
    echo "        /guide"
    echo ""
    echo "  (之後任何 session 都能再打 /guide 從上次進度繼續;/exit 離開)"
    echo "  ⚠️ 若 /guide 顯示 Unknown command:domi-guide plugin 沒裝成功 →"
    echo "     claude plugin install domi-guide@domi-claude-plugins  (或找 Corey)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    cd "$TUTOR_DIR" && exec claude </dev/tty
  fi
  info "Skipped guided session. Start anytime: open a claude session and type  /guide"
fi
