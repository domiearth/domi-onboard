#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────────────────────
# DOMI AgentHUB onboarding — Ubuntu 22.04+ / 24.04 LTS
#
# Installs the dev toolchain on the AgentHUB itself (the centralized
# Ubuntu server every DOMI agent / contributor SSH-es into).
#
# Idempotent: detects what's already installed; only installs what's missing.
# Two sections:
#   Part A — User-level installs (no sudo)   — node / pnpm / uv / rust
#   Part B — System-level installs (needs sudo prompt at runtime)
#            — build-essential / shellcheck / sshpass / postgresql-client / etc.
#
# Usage:
#   bash scripts/onboard-agenthub.sh
# ──────────────────────────────────────────────────────────────

info()  { printf '\033[1;34m[INFO]\033[0m  %s\n' "$*"; }
ok()    { printf '\033[1;32m[OK]\033[0m    %s\n' "$*"; }
warn()  { printf '\033[1;33m[WARN]\033[0m  %s\n' "$*"; }
fail()  { printf '\033[1;31m[FAIL]\033[0m  %s\n' "$*"; exit 1; }

have() { command -v "$1" &>/dev/null; }

DOMI_ONBOARD_URL="https://raw.githubusercontent.com/domiearth/domi-onboard/main/onboard-agenthub.sh"

# ── stdin / TTY guard ────────────────────────────────────────
# Intended usage is `bash onboard-agenthub.sh` from a clone, but if someone
# pipes it (`curl … | bash`) stdin becomes the script itself — and child
# processes (apt, the piped installers) can then consume the un-parsed
# remainder. Re-fetch to a real file and re-exec with the terminal as stdin;
# fall through unattended if there's no controlling terminal.
if [[ ! -t 0 && -z "${DOMI_ONBOARD_REEXEC:-}" && -r /dev/tty ]] && have curl; then
  _self="$(mktemp "${TMPDIR:-/tmp}/onboard-agenthub.XXXXXX.sh")"
  if curl -fsSL "$DOMI_ONBOARD_URL" -o "$_self"; then
    exec env DOMI_ONBOARD_REEXEC=1 bash "$_self" </dev/tty
  fi
  rm -f "$_self"
fi

LOCAL_BIN="$HOME/.local/bin"
CARGO_BIN="$HOME/.cargo/bin"
mkdir -p "$LOCAL_BIN"

# Ensure user-level bin dirs are in PATH for this script's session
for d in "$LOCAL_BIN" "$CARGO_BIN"; do
  case ":$PATH:" in
    *":$d:"*) ;;
    *) export PATH="$d:$PATH" ;;
  esac
done

# ─── Part A: User-level installs (no sudo) ───────────────────

info "── Part A — User-level dev runtime ──"

# A1. Node.js LTS (binary tarball → ~/.local/node-vX.Y.Z-linux-x64)
info "Checking Node.js..."
if have node; then
  ok "node $(node --version) already installed"
else
  info "Installing Node.js LTS..."
  NODE_LTS=$(curl -fsSL https://nodejs.org/dist/index.json \
    | jq -r '[.[] | select(.lts != false)][0].version')
  info "  Latest LTS: $NODE_LTS"
  TMP=$(mktemp -d)
  curl -fsSL "https://nodejs.org/dist/${NODE_LTS}/node-${NODE_LTS}-linux-x64.tar.xz" \
    -o "$TMP/node.tar.xz"
  tar -xJf "$TMP/node.tar.xz" -C "$HOME/.local/"
  for f in "$HOME/.local/node-${NODE_LTS}-linux-x64/bin"/*; do
    ln -sf "$f" "$LOCAL_BIN/$(basename "$f")"
  done
  rm -rf "$TMP"
  ok "node $(node --version) installed"
fi

# A2. pnpm via corepack
info "Checking pnpm..."
if have pnpm; then
  ok "pnpm $(pnpm --version) already installed"
else
  info "Activating pnpm via corepack..."
  corepack enable
  corepack prepare pnpm@latest --activate
  ok "pnpm $(pnpm --version) installed"
fi

# A3. uv (Python toolkit manager) via official installer
info "Checking uv..."
if have uv; then
  ok "uv $(uv --version) already installed"
else
  info "Installing uv..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
  ok "uv $($HOME/.local/bin/uv --version) installed"
fi

# A4. Rust toolchain via rustup
info "Checking Rust..."
if have cargo || [[ -x "$HOME/.cargo/bin/cargo" ]]; then
  CARGO="${CARGO:-$HOME/.cargo/bin/cargo}"
  have cargo && CARGO=$(command -v cargo)
  ok "rust $($CARGO --version) already installed"
else
  info "Installing Rust (stable, minimal profile)..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- -y --default-toolchain stable --profile minimal
  ok "rust $($HOME/.cargo/bin/cargo --version) installed"
  warn "Note: ~/.cargo/env is sourced via ~/.profile and ~/.bashrc on next shell"
fi

# A5. Claude Code CLI (npm global → ~/.local, user-level)
info "Checking Claude Code CLI..."
if have claude; then
  ok "claude CLI already installed"
elif have npm; then
  info "Installing Claude Code CLI via npm..."
  npm install -g @anthropic-ai/claude-code \
    && ok "claude CLI installed" \
    || warn "claude install failed — install manually: npm install -g @anthropic-ai/claude-code"
else
  warn "npm not on PATH yet — open a new shell (source ~/.profile) then re-run to install claude"
fi

# ─── Part B: System-level installs (sudo prompt) ─────────────

info ""
info "── Part B — System-level packages (sudo required) ──"

# B0. GitHub CLI (official apt repo) — needed for gh auth + the private
# domi-claude-plugins marketplace. Not in Ubuntu's default repos, so add
# GitHub's keyring + source first. Idempotent: skipped once gh is present.
if have gh; then
  ok "gh $(gh --version | head -1 | awk '{print $3}') already installed"
else
  info "Installing GitHub CLI (official apt repo)..."
  if sudo mkdir -p -m 755 /etc/apt/keyrings \
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null \
    && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null \
    && sudo apt update -y && sudo apt install -y gh; then
    ok "gh installed"
  else
    warn "gh install failed — see https://github.com/cli/cli/blob/trunk/docs/install_linux.md"
  fi
fi

NEED_APT=()
for pkg in build-essential shellcheck sshpass postgresql-client tmux; do
  if dpkg -s "$pkg" &>/dev/null; then
    ok "$pkg already installed"
  else
    NEED_APT+=("$pkg")
  fi
done

if [[ ${#NEED_APT[@]} -eq 0 ]]; then
  ok "All apt packages already installed"
else
  info "Need to install via apt: ${NEED_APT[*]}"
  info "Running: sudo apt update + apt install (will prompt for password)"
  if sudo apt update -y && sudo apt install -y "${NEED_APT[@]}"; then
    ok "apt packages installed"
  else
    warn "apt install failed or skipped. Re-run manually:"
    warn "  sudo apt install ${NEED_APT[*]}"
  fi
fi

# ─── Part B2: Governance plugins (hub-side enforcement) ──────
# The hub is where every project repo lives, so the governance GUARDS run here
# — authoritatively, server-side. The hub does NOT install hub-relay (it never
# connects to itself) or individual-agent (no personal repos live on the hub).
# Personal machines install the mirror set (individual-agent + hub-relay +
# domi-guide). See domi-claude-plugins README install matrix.
info ""
info "── Part B2 — Governance plugins (hub-side) ──"
if command -v claude &>/dev/null; then
  # The private DOMI marketplace needs gh auth with domiearth org access —
  # without it `marketplace add` 404s. Authenticate here before installing.
  if command -v gh &>/dev/null && gh auth status &>/dev/null; then
    ok "GitHub authenticated"
  elif command -v gh &>/dev/null; then
    info "GitHub auth required for the private DOMI marketplace..."
    if [[ -t 0 ]]; then
      gh auth login || warn "gh auth login skipped — marketplace add will 404 until authenticated"
    else
      warn "Non-interactive shell — run 'gh auth login' (or export GH_TOKEN) in an SSH shell, then re-run."
    fi
  else
    warn "gh not installed — cannot reach the private marketplace. Install gh + 'gh auth login' first."
  fi
  if claude plugin marketplace list 2>/dev/null | grep -q "domi-claude-plugins"; then
    ok "DOMI marketplace already registered"
    # Re-run = update: refresh marketplace so newer plugin versions are visible.
    claude plugin marketplace update domi-claude-plugins 2>/dev/null || true
  else
    claude plugin marketplace add https://github.com/domiearth/domi-claude-plugins \
      && ok "DOMI marketplace registered" \
      || warn "marketplace add failed (need domiearth org access) — install plugins manually later"
  fi
  for plugin in stack-guard entity-guard schema-change project-protect domi-init domi-guide; do
    info "  Installing / updating $plugin..."
    # install = no-op if present; update = bump an already-installed plugin to latest.
    claude plugin install "${plugin}@domi-claude-plugins" 2>/dev/null || true
    claude plugin update  "${plugin}@domi-claude-plugins" 2>/dev/null || true
  done
  ok "hub-side governance plugins done"
else
  warn "claude CLI not found on this hub — skipping governance plugins."
  warn "  Install Claude Code first, then re-run, or install manually:"
  warn "  claude plugin marketplace add https://github.com/domiearth/domi-claude-plugins"
  warn "  claude plugin install stack-guard@domi-claude-plugins  # +entity-guard schema-change project-protect domi-init domi-guide"
fi

# ─── Part C: Verification ────────────────────────────────────

info ""
info "── Part C — Verification ──"

echo ""
printf "%-12s %s\n" "Tool" "Version"
printf "%-12s %s\n" "────────────" "─────────────────────────"
for cmd in node npm pnpm python3 uv cargo rustc gh jq git make gcc shellcheck sshpass psql; do
  if have "$cmd"; then
    v=$($cmd --version 2>&1 | head -1)
    printf "✅ %-10s %s\n" "$cmd" "$v"
  else
    printf "❌ %-10s missing\n" "$cmd"
  fi
done

echo ""
ok "AgentHUB onboarding complete."
echo ""
echo "  Next steps:"
echo "    1. Open a new shell (or run \`source ~/.profile\`) to load PATH changes."
echo "    2. Verify in marketing-system: cd ../marketing-system && pnpm typecheck"
echo "    3. Verify in datahouse:        cd ../datahouse && cargo check"
