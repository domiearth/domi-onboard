#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────────────────────
# DOMI patch 2026-10-21 — macOS:補裝 jq
#
# 對象:**已經跑過 onboarding 的 Mac**(新機器跑完整 onboard-macos*.sh 就會裝)。
# 為什麼:asset plugin(必裝四顆之一)分享知識 / 簡報 / 待辦 / artifact / log / drive
#   都要 jq,沒有就直接停在「需要 jq」;舊版 onboarding 沒裝它。
#   macOS 15 內建 /usr/bin/jq → 這支會直接說「已經有了」。
#
# 怎麼裝:有 Homebrew → brew install jq;沒有(macOS 12 那支 onboarding 不用 brew)
#   → 用 Command Line Tools 從官方 release 原始碼編(版本 + sha256 釘死,約 1–2 分鐘)。
#   ⚠️ 不下載官方 macOS binary:1.8.x 要 macOS 14、1.7.1 要 macOS 13,12 跑不動。
#
# Usage:bash patch-macos.sh          Idempotent:重跑安全。
# ──────────────────────────────────────────────────────────────

JQ_VER="1.8.2"
JQ_SHA256="71b8d6e8f5fe81f6c6d0d110e3892251f6ce76ed095abd315e26e6e1193af3af"

info()  { printf '\033[1;34m[INFO]\033[0m  %s\n' "$*"; }
ok()    { printf '\033[1;32m[OK]\033[0m    %s\n' "$*"; }
fail()  { printf '\033[1;31m[FAIL]\033[0m  %s\n' "$*"; exit 1; }

if command -v jq &>/dev/null; then
  ok "jq $(jq --version) 已經有了($(command -v jq))—— 不用做任何事"
  exit 0
fi

if command -v brew &>/dev/null; then
  info "用 Homebrew 裝 jq..."
  brew install jq || fail "brew install jq 失敗 —— 截圖找 Kirin / Corey"
else
  xcode-select -p &>/dev/null || fail "沒有 Homebrew 也沒有 Command Line Tools —— 先跑:xcode-select --install,裝完再重跑這支"
  info "沒有 Homebrew → 從原始碼編 jq $JQ_VER(約 1–2 分鐘;最後裝進 /usr/local/bin 會問 sudo 密碼 = 你的開機密碼)..."
  _d="$(mktemp -d)"; trap 'rm -rf "$_d"' EXIT
  curl -fsSL "https://github.com/jqlang/jq/releases/download/jq-${JQ_VER}/jq-${JQ_VER}.tar.gz" -o "$_d/jq.tar.gz" \
    || fail "下載失敗(網路?)—— 重跑一次"
  [[ "$(shasum -a 256 "$_d/jq.tar.gz" | awk '{print $1}')" == "$JQ_SHA256" ]] || fail "下載檔 sha256 對不上 —— 不安裝,截圖找 Kirin"
  tar -xzf "$_d/jq.tar.gz" -C "$_d"
  ( cd "$_d/jq-${JQ_VER}" \
      && ./configure --quiet --disable-docs --disable-maintainer-mode --disable-shared --with-oniguruma=builtin --prefix=/usr/local >/dev/null \
      && make -s -j"$(sysctl -n hw.ncpu 2>/dev/null || echo 2)" >/dev/null 2>&1 ) \
    || fail "編譯失敗 —— 截圖找 Kirin / Corey"
  sudo mkdir -p /usr/local/bin && sudo install -m 755 "$_d/jq-${JQ_VER}/jq" /usr/local/bin/jq
fi

hash -r
command -v jq &>/dev/null || fail "裝完了但找不到 jq —— 關掉終端機重開再試 jq --version"
ok "jq $(jq --version) 裝好了($(command -v jq))"
echo "   開新的 Claude Code session,asset 的分享功能就能用了。"
