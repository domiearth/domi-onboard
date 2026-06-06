#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────────────────────
# DOMI onboarding — macOS
# Usage: curl -fsSL <raw-url> | bash
#    or: bash onboard-macos.sh
# ──────────────────────────────────────────────────────────────

DOMI_PROJECT_DIR="$HOME/project"
DOMI_ONBOARD_URL="https://raw.githubusercontent.com/domiearth/domi-onboard/main/onboard-macos.sh"
DOMI_PLAYBOOK_URL="https://raw.githubusercontent.com/domiearth/domi-onboard/main/TUTOR_PLAYBOOK.md"

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

# ── 4b. sshpass (required by hub-relay) ─────────────────────

info "Checking sshpass..."
if need_cmd sshpass; then
  info "Installing sshpass via Homebrew..."
  brew install hudochenkov/sshpass/sshpass
fi
ok "sshpass installed"

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
info "domi-claude-plugins — DOMI governance plugins (REQUIRED)"
info "Registering DOMI marketplace (private — requires domiearth org access)..."

if claude plugin marketplace list 2>/dev/null | grep -q "domi-claude-plugins"; then
  ok "DOMI marketplace already registered"
else
  claude plugin marketplace add https://github.com/domiearth/domi-claude-plugins
  ok "DOMI marketplace registered"
fi

info "Installing DOMI plugins from marketplace..."
for plugin in stack-guard entity-guard domi-init schema-change hub-relay project-protect domi-guide; do
  info "  Installing $plugin..."
  claude plugin install "${plugin}@domi-claude-plugins" 2>/dev/null \
    || warn "  $plugin install skipped (may already be installed)"
done
ok "domi-claude-plugins done"

# ── 9b. AgentHUB connection setup ───────────────────────────

echo ""
info "AgentHUB connection setup — host/user/password"
echo "  Enter the hub host/user from your DOMI onboarding contact (Corey)."
echo "  Don't have it yet? Just press Enter on all three to SKIP — you can"
echo "  run hub-setup.sh later. (The host is an IP/hostname, NOT a command.)"
echo ""

if [[ -n "${DOMI_NONINTERACTIVE:-}" ]]; then
  HUB_HOST="" HUB_USER="" HUB_PASS_INPUT=""
else
  read -r -p "  Hub host: " HUB_HOST </dev/tty
  read -r -p "  Hub user: " HUB_USER </dev/tty
  read -r -s -p "  Hub password: " HUB_PASS_INPUT </dev/tty
  echo ""
fi

if [[ -z "$HUB_HOST" || -z "$HUB_USER" || -z "$HUB_PASS_INPUT" ]]; then
  warn "Host/user/password incomplete — skipping AgentHUB config. Run hub-setup.sh later to configure."
elif [[ ! "$HUB_HOST" =~ ^[A-Za-z0-9._:-]+$ ]]; then
  # Guards against pasting a URL/command into the host field (e.g. a curl line).
  warn "Hub host '$HUB_HOST' doesn't look like a hostname/IP — skipping AgentHUB config. Run hub-setup.sh later."
else
  info "Testing connection to ${HUB_USER}@${HUB_HOST}..."
  if sshpass -p "$HUB_PASS_INPUT" ssh -o ConnectTimeout=5 \
     -o StrictHostKeyChecking=accept-new -o LogLevel=ERROR \
     "${HUB_USER}@${HUB_HOST}" "echo ok" &>/dev/null; then
    ESC_PASS=$(printf '%s' "$HUB_PASS_INPUT" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null \
      || printf '"%s"' "$HUB_PASS_INPUT")
    cat > "$HOME/.domi-hub.json" <<EOF
{
  "host": "$HUB_HOST",
  "user": "$HUB_USER",
  "password": $ESC_PASS
}
EOF
    chmod 600 "$HOME/.domi-hub.json"
    ok "AgentHUB credentials saved to ~/.domi-hub.json"
  else
    warn "Connection test failed — credentials NOT saved. Run hub-setup.sh after fixing network."
  fi
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
echo "  Plugins (via domi-claude-plugins marketplace):"
echo "    stack-guard    ✅  TECH_STACK.md enforcement"
echo "    entity-guard   ✅  Local vs Global/MT-DAO boundary"
echo "    domi-init      ✅  repo bootstrap with CLAUDE.md templates"
echo "    schema-change  ✅  datahouse cross-repo coordination"
echo "    hub-relay      ✅  SSH bridge to AgentHUB"
[[ "${INSTALL_WORKBENCH:-}" =~ ^[yY]$ ]] && echo "    claude-workbench     ✅ (mentor, kanban, chat)"
echo ""
echo "  Next steps:"
echo "    1. Open Claude Desktop and sign in"
echo "    2. Run: cd $DOMI_PROJECT_DIR && gh repo clone domiearth/foreman"
echo "    3. Run: cd foreman && claude   # start your first session"
echo "    4. (If skipped above) run hub-setup.sh to configure AgentHUB later"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── 11. Guided first session (optional) ─────────────────────
# Hand off into a live Claude Code session that tutors the new hire through
# the claude CLI and gh (clone a project), one step at a time. Skipped when
# non-interactive or if the claude CLI isn't on PATH yet.

# Tutor source, in priority order:
#   1. domi-guide plugin (canonical) — re-enterable any time later with /guide,
#      remembers progress in ~/.domi-guide.json, can jump to single chapters
#   2. local TUTOR_PLAYBOOK.md copy (clone / offline fallback)
#   3. published TUTOR_PLAYBOOK.md from GitHub
#   4. short inline prompt
_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
if claude plugin list 2>/dev/null | grep -q "domi-guide"; then
  TUTOR_PROMPT="/guide all"
elif [[ -n "$_script_dir" && -r "$_script_dir/TUTOR_PLAYBOOK.md" ]]; then
  TUTOR_PROMPT="$(cat "$_script_dir/TUTOR_PLAYBOOK.md")"
else
  TUTOR_PROMPT="$(curl -fsSL "$DOMI_PLAYBOOK_URL" 2>/dev/null || true)"
fi
if [[ -z "${TUTOR_PROMPT// }" ]]; then
  TUTOR_PROMPT="你是 DOMI 新人 onboarding 導師,請用繁體中文一步一步帶我(一次一步,等我回覆再繼續)熟悉:Claude Desktop 與 Claude Code CLI 的差別、設定 Claude Desktop(登入資訊請我聯絡 Corey)、用 gh 把 domiearth/foreman clone 到 ~/project、以及 git repo / agent / agent workspace 的關係。"
fi

if [[ -z "${DOMI_NONINTERACTIVE:-}" ]] && command -v claude &>/dev/null; then
  echo ""
  printf '  Start a guided Claude session to learn the claude CLI + gh? [Y/n] '
  read -r START_TUTORIAL </dev/tty
  if [[ ! "$START_TUTORIAL" =~ ^[nN]$ ]]; then
    info "Launching guided session — follow along, type /exit when done."
    echo ""
    exec claude "$TUTOR_PROMPT" </dev/tty
  fi
  info "Skipped guided session. Start anytime: open any claude session and type  /guide"
fi
