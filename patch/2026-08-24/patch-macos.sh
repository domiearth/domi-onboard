#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────────────────────
# DOMI patch 2026-08-24 — macOS / Git Bash
#
# 對象:**已經跑過舊版 onboarding 的既有機器**(新機器請跑完整 onboard-macos.sh)。
# 修什麼(共用帳號時代的殘留,Lily 2026-08-24 實際撞到的那一包):
#   1. GitHub 身分確認 + 切回本人(舊 onboarding 用共用 PAT 登入,gh 的
#      active 帳號可能不是你 —— full onboarding 看到「已登入」就跳過,
#      永遠不會發現登錯人,所以需要這支 patch 主動確認)
#   2. 重寫 plugin 自動更新 token(舊檔裡是共用 PAT,已失效;worker
#      「有檔用檔」,爛檔會讓自動更新永遠靜默失敗)
#   3. 補裝 asset plugin(舊版 onboarding 沒裝)+ 全部 plugin 更新到最新
#   4. 重跑 hub-setup 修 ~/.domi-hub.json 的 github_account(hub 權限判定的 key)
#
# Usage:
#   bash patch-macos.sh [-h HUB_HOST] [--host-tailscale TS] [-u HUB_USER] [-p HUB_PASS]
#   (hub 參數全部可省 —— hub-setup 會用預設值/既有設定問你)
#
# Idempotent:重跑安全,已正確的項目會跳過。
# ──────────────────────────────────────────────────────────────

PATCH_URL="https://raw.githubusercontent.com/domiearth/domi-onboard/main/patch/2026-08-24/patch-macos.sh"

info()  { printf '\033[1;34m[INFO]\033[0m  %s\n' "$*"; }
ok()    { printf '\033[1;32m[OK]\033[0m    %s\n' "$*"; }
warn()  { printf '\033[1;33m[WARN]\033[0m  %s\n' "$*"; }
fail()  { printf '\033[1;31m[FAIL]\033[0m  %s\n' "$*"; exit 1; }

# ── stdin / TTY guard(同 onboard-macos.sh:curl|bash 時 stdin 是 pipe)──
if [[ ! -t 0 && -z "${DOMI_PATCH_REEXEC:-}" ]]; then
  if [[ -r /dev/tty ]]; then
    _self="$(mktemp "${TMPDIR:-/tmp}/domi-patch.XXXXXX.sh")"
    if curl -fsSL "$PATCH_URL" -o "$_self"; then
      exec env DOMI_PATCH_REEXEC=1 bash "$_self" "$@" </dev/tty
    fi
    rm -f "$_self"
  fi
  fail "這支 patch 需要互動(要跟你確認身分)。請先下載再跑:curl -fsSL $PATCH_URL -o ~/patch.sh && bash ~/patch.sh"
fi

# ── args(hub 參數 passthrough 給 hub-setup)─────────────────
HUB_ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--host)                    HUB_ARGS+=(--host "${2:-}"); shift 2 ;;
    --host-tailscale|--tailscale) HUB_ARGS+=(--host-tailscale "${2:-}"); shift 2 ;;
    -u|--user)                    HUB_ARGS+=(--user "${2:-}"); shift 2 ;;
    -p|--password|--pass)         HUB_ARGS+=(--password "${2:-}"); shift 2 ;;
    --help)                       echo "Usage: bash patch-macos.sh [-h HUB_HOST] [--host-tailscale TS] [-u HUB_USER] [-p HUB_PASS]"; exit 0 ;;
    *)                            warn "Unknown argument: $1"; shift ;;
  esac
done

# ── 0. 前置:這台要已經有 gh + claude(沒有 = 沒跑過 onboarding)────
command -v gh     &>/dev/null || fail "找不到 gh —— 這台還沒 onboard 過,請跑完整 onboard-macos.sh"
command -v claude &>/dev/null || fail "找不到 claude —— 這台還沒 onboard 過,請跑完整 onboard-macos.sh"

# ── 1. GitHub 身分:確認是本人,不是就換 ─────────────────────
info "Step 1/4 — GitHub 身分確認"
if ! gh auth status &>/dev/null; then
  info "gh 尚未登入 — 用你自己的 GitHub 帳號登入(選 GitHub.com → HTTPS → Login with a web browser)"
  gh auth login </dev/tty || fail "gh 登入未完成 — 重跑本 patch 再試一次"
fi

_confirm_identity() {
  LOGIN="$(gh api user --jq '.login' 2>/dev/null || echo '')"
  [[ -n "$LOGIN" ]] || fail "讀不到 gh 登入身分 — 檢查網路後重跑"
  printf '  目前 gh 登入的是:\033[1m%s\033[0m\n' "$LOGIN"
  printf '  這是「你自己的」GitHub 帳號嗎?(不是共用/別人的)[Y/n] '
  read -r _ans </dev/tty
  [[ ! "$_ans" =~ ^[nN]$ ]]
}

if ! _confirm_identity; then
  # 可能你的帳號已登入只是不是 active(Lily 的情況)→ 先讓使用者看清單再處理
  echo ""
  gh auth status 2>&1 | sed 's/^/  /' || true
  echo ""
  info "如果上面清單裡有你自己的帳號 → 我們用 switch;沒有 → 走登入。"
  printf '  你自己的 GitHub 帳號名稱(直接貼,例如 stacey-you-dotcom):'
  read -r MY_HANDLE </dev/tty
  [[ -n "$MY_HANDLE" ]] || fail "沒輸入帳號 — 重跑本 patch 再試"
  if gh auth switch -u "$MY_HANDLE" 2>/dev/null; then
    ok "已切換到 $MY_HANDLE"
  else
    info "帳號不在清單裡 — 現在登入(瀏覽器會開,用你自己的帳號)"
    gh auth login </dev/tty || fail "gh 登入未完成 — 重跑本 patch 再試一次"
  fi
  _confirm_identity || fail "身分仍不對 — 找 Corey 一起看"
fi
gh auth setup-git 2>/dev/null || true
ok "GitHub 身分:$LOGIN"

# 建議登出共用/別人的帳號,免得日後又被切回去(逐一問,按 Enter = 保留)
_others="$(gh auth status 2>&1 | grep -oE 'account [A-Za-z0-9-]+' | awk '{print $2}' | grep -vx "$LOGIN" || true)"
if [[ -n "$_others" ]]; then
  echo ""
  info "這台還登著其他帳號,建議登出(避免之後又切錯人):"
  while IFS= read -r _acct; do
    printf '  登出 %s?[y/N] ' "$_acct"
    read -r _ans </dev/tty
    if [[ "$_ans" =~ ^[yY]$ ]]; then
      if gh auth logout -u "$_acct" 2>/dev/null; then ok "已登出 $_acct"
      else warn "登出 $_acct 失敗 — 稍後手動:gh auth logout -u $_acct"; fi
    else
      info "保留 $_acct"
    fi
  done <<< "$_others"
fi

# ── 2. 重寫 plugin 自動更新 token(換成你自己的)──────────────
info "Step 2/4 — 更新 plugin 自動更新 token"
AU_DIR="$HOME/.claude/.domi-autoupdate"; mkdir -p "$AU_DIR"
rm -f "$AU_DIR/gh-token"   # 舊檔可能是已失效的共用 PAT;worker「有檔用檔」,必須先清
_AU_TOKEN="$(gh auth token 2>/dev/null || true)"
if [[ -n "$_AU_TOKEN" ]]; then
  ( umask 177; printf '%s' "$_AU_TOKEN" > "$AU_DIR/gh-token" )
  ok "已用你自己的 token 重寫 ~/.claude/.domi-autoupdate/gh-token"
else
  warn "拿不到 gh token — 已刪除舊檔,自動更新會 fallback 用 gh 既有憑證,仍可運作。"
fi

# ── 3. plugin:補裝 asset + 全部更新到最新 ────────────────────
info "Step 3/4 — 更新 DOMI plugins(補裝 asset)"
if claude plugin marketplace list 2>/dev/null | grep -q "domi-claude-plugins"; then
  claude plugin marketplace update domi-claude-plugins 2>/dev/null || true
else
  claude plugin marketplace add https://github.com/domiearth/domi-claude-plugins
fi
for plugin in individual-agent hub-relay domi-guide asset; do
  info "  Installing / updating $plugin..."
  claude plugin install "${plugin}@domi-claude-plugins" 2>/dev/null || true
  claude plugin update  "${plugin}@domi-claude-plugins" 2>/dev/null || true
done
ok "plugins done(individual-agent · hub-relay · domi-guide · asset)"

# ── 4. hub 身分:重跑 hub-setup(帶入正確的 github 帳號)───────
# 放在 plugin 更新之後 —— 這樣跑到的是新版 hub-setup(0.9.28+ 有身分防呆)。
info "Step 4/4 — 修 AgentHUB 身分(hub-setup)"
HUB_SETUP=$(ls "$HOME"/.claude/plugins/cache/domi-claude-plugins/hub-relay/*/scripts/hub-setup.sh 2>/dev/null | sort -V | tail -1)
if [[ -n "$HUB_SETUP" ]]; then
  echo "  會問 host / user / password —— 已設定過的直接按 Enter 沿用即可。"
  bash "$HUB_SETUP" --github "$LOGIN" ${HUB_ARGS[@]+"${HUB_ARGS[@]}"} </dev/tty \
    || warn "hub-setup 沒跑完 — 稍後補:bash $HUB_SETUP --github $LOGIN"
else
  warn "找不到 hub-setup.sh(hub-relay 沒裝好?)— 稍後在 claude 裡跑 /hub setup"
fi

# ── 驗證 + 總結 ──────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ok "DOMI patch 2026-08-24 完成!驗證:"
echo "    gh 身分          $(gh api user --jq .login 2>/dev/null || echo '❌')"
_hub_acct="$(sed -n 's/.*"github_account"[^"]*"\([^"]*\)".*/\1/p' "$HOME/.domi-hub.json" 2>/dev/null | head -1)"
if [[ "$_hub_acct" == "$LOGIN" ]]; then
  echo "    hub 身分         $_hub_acct ✅"
else
  echo "    hub 身分         ${_hub_acct:-'(未設定)'} ❌ 應為 $LOGIN — 重跑 step 4 的 hub-setup"
fi
_hr_ver="$(ls "$HOME"/.claude/plugins/cache/domi-claude-plugins/hub-relay/ 2>/dev/null | sort -V | tail -1)"
echo "    hub-relay        ${_hr_ver:-❌}(應 ≥ 0.9.28)"
_as_ver="$(ls "$HOME"/.claude/plugins/cache/domi-claude-plugins/asset/ 2>/dev/null | sort -V | tail -1)"
echo "    asset            ${_as_ver:+✅ $_as_ver}${_as_ver:-❌ 沒裝成功 — 找 Corey}"
echo ""
echo "  之後開新的 claude session 就全部生效。分享成果用 /asset:knowledge-add,"
echo "  投影片用 /asset:deck-add。"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
