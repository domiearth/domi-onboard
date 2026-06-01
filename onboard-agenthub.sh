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

# ─── Part B: System-level installs (sudo prompt) ─────────────

info ""
info "── Part B — System-level packages (sudo required) ──"

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
