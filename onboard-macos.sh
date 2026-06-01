#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────────────────────
# DOMI onboarding — macOS
# Usage: curl -fsSL <raw-url> | bash
#    or: bash onboard-macos.sh
# ──────────────────────────────────────────────────────────────

DOMI_PROJECT_DIR="$HOME/project"

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
    warn "Press Enter after installing, or Ctrl+C to skip..."
    read -r
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
printf '  Install claude-workbench? [y/N] '
read -r INSTALL_WORKBENCH

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
for plugin in stack-guard entity-guard domi-init schema-change hub-relay; do
  info "  Installing $plugin..."
  claude plugin install "${plugin}@domi-claude-plugins" 2>/dev/null \
    || warn "  $plugin install skipped (may already be installed)"
done
ok "domi-claude-plugins done"

# ── 9b. AgentHUB connection setup ───────────────────────────

echo ""
info "AgentHUB connection setup — host/user/password"
echo "  (Ask your DOMI onboarding contact for the hub host/user.)"
echo "  (Leave host or password blank to skip — run hub-setup.sh later.)"
echo ""

read -r -p "  Hub host: " HUB_HOST
read -r -p "  Hub user: " HUB_USER
read -r -s -p "  Hub password: " HUB_PASS_INPUT
echo ""

if [[ -z "$HUB_HOST" || -z "$HUB_USER" || -z "$HUB_PASS_INPUT" ]]; then
  warn "Host/user/password incomplete — skipping AgentHUB config. Run hub-setup.sh later to configure."
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
