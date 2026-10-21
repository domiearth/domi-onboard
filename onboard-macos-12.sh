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
#
# Usage:
#   bash onboard-macos-12.sh [-t GH_TOKEN] [-h HUB_HOST]
#   curl -fsSL <raw-url> -o ~/onboard.sh && bash ~/onboard.sh -t <token> -h 192.168.0.141
#
#   -t / --token            (選用,CI/bot 用)GitHub PAT。一般人不用帶 ——
#                           預設走 `gh auth login` 用你自己的 GitHub 帳號登入。
#                           省略則讀環境變數 DOMI_GH_TOKEN,再省略走互動式登入。
#   -h / --host             AgentHUB LAN 位址(預設 192.168.0.141);傳給 hub-setup。
#   --host-tailscale        AgentHUB Tailscale 位址(預設 100.72.24.53);傳給 hub-setup。
#   -u / --user             hub ssh 帳號(預設 domi);傳給 hub-setup。
#   -p / --password         hub ssh 密碼;傳給 hub-setup。省略則 hub-setup 隱藏輸入。
#   注意:token / 密碼寫在指令列會留在 shell history。要乾淨就別帶,讓它隱藏輸入。
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
      exec env DOMI_ONBOARD_REEXEC=1 bash "$_self" "$@" </dev/tty
    fi
    rm -f "$_self"
    warn "Could not re-fetch script for interactive run; continuing non-interactively."
  fi
  export DOMI_NONINTERACTIVE=1
fi

# ── arg parsing(-t token / -h hub host)──────────────────────
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
    --help)                       echo "Usage: bash onboard-macos-12.sh [-t GH_TOKEN] [-h HUB_HOST] [--host-tailscale TS] [-u HUB_USER] [-p HUB_PASS]"; exit 0 ;;
    *)                            warn "Unknown argument: $1"; shift ;;
  esac
done

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

# ── 3b. jq(asset plugin 必需;macOS 12 只能從原始碼編)──────
# asset(必裝四顆之一)沒有 jq 就 die「需要 jq」。
# ⚠️ jq 官方 macOS binary 最低要求:1.8.x = macOS 14、1.7.1 = macOS 13(讀 Mach-O
# LC_BUILD_VERSION 實測)→ macOS 12 **沒有可用的官方 binary**。brew 在 12 又會走源碼編譯。
# 所以直接用 step 1 裝好的 Command Line Tools 編官方 release tarball(C,約 1–2 分鐘),
# 版本 + sha256 釘死。oniguruma 用內建的、--disable-shared(否則 ./jq 是 libtool wrapper,單獨複製會壞)。
JQ_VER="1.8.2"
JQ_SHA256="71b8d6e8f5fe81f6c6d0d110e3892251f6ce76ed095abd315e26e6e1193af3af"
info "Checking jq..."
if have jq; then
  ok "jq $(jq --version) already installed"
else
  info "Building jq $JQ_VER from source(macOS 12 沒有官方 binary;約 1–2 分鐘,裝進 /usr/local/bin 需要 sudo)..."
  _jqdir="$(mktemp -d)"
  if curl -fsSL "https://github.com/jqlang/jq/releases/download/jq-${JQ_VER}/jq-${JQ_VER}.tar.gz" -o "$_jqdir/jq.tar.gz" \
     && [[ "$(shasum -a 256 "$_jqdir/jq.tar.gz" | awk '{print $1}')" == "$JQ_SHA256" ]] \
     && tar -xzf "$_jqdir/jq.tar.gz" -C "$_jqdir" \
     && ( cd "$_jqdir/jq-${JQ_VER}" \
          && ./configure --quiet --disable-docs --disable-maintainer-mode --disable-shared --with-oniguruma=builtin --prefix=/usr/local >/dev/null \
          && make -s -j"$(sysctl -n hw.ncpu 2>/dev/null || echo 2)" >/dev/null 2>&1 \
          && sudo mkdir -p /usr/local/bin \
          && sudo install -m 755 jq /usr/local/bin/jq ); then
    ok "jq $(/usr/local/bin/jq --version) installed"
  else
    warn "jq 編譯/安裝失敗 —— asset plugin 的分享功能會不能用。找 Kirin / Corey 協助手動裝。"
  fi
  rm -rf "$_jqdir"
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
# 個人帳號制(2026-08 起:org 回 Free plan、全員個人帳號重新加入):
# 預設走 `gh auth login` 互動式登入 —— 用「你自己的」GitHub 帳號。這個身分
# 會一路帶進 agent-self-<handle>、~/.domi-hub.json 的 github_account、以及
# hub 端 project-protect 的權限判定,所以絕對不要再登共用帳號。
# -t / DOMI_GH_TOKEN 保留給 CI / bot / 特殊情況(不再預設提示輸入);
# token 登入失敗不再中止整個 onboarding,改 fallback 互動式登入。
info "Checking GitHub auth..."
if gh auth status &>/dev/null; then
  ok "Already authenticated to GitHub ($(gh api user --jq .login 2>/dev/null || echo '?'))"
elif [[ -n "$GH_TOKEN_ARG" ]]; then
  if printf '%s' "$GH_TOKEN_ARG" | gh auth login --with-token; then
    ok "GitHub 已用 token 登入"
  else
    warn "Token 登入失敗 — 改用互動式登入(用你自己的帳號)。"
    GH_TOKEN_ARG=""
    if [[ -z "${DOMI_NONINTERACTIVE:-}" ]]; then
      gh auth login </dev/tty || warn "gh 登入未完成 — 稍後手動:gh auth login,再重跑本 script(idempotent)。"
    fi
  fi
elif [[ -z "${DOMI_NONINTERACTIVE:-}" ]]; then
  info "用你自己的 GitHub 帳號登入(選 GitHub.com → HTTPS → Login with a web browser)..."
  gh auth login </dev/tty || warn "gh 登入未完成 — 稍後手動:gh auth login,再重跑本 script(idempotent)。"
else
  warn "Non-interactive 且未帶 token — 跳過 GitHub 登入(之後手動:gh auth login)。"
fi
if gh auth status &>/dev/null; then
  gh auth setup-git 2>/dev/null || true   # 讓 git clone 私有 repo 走 gh 憑證
  # 持久化 token 給 plugin 自動更新器「自我內含」使用:domi-guide 背景 worker 讀它
  # export GH_TOKEN,即使 gh 被清/不在 PATH 也照樣更新,不再靜默吃 stale cache。
  # 來源:-t 給的 PAT,否則 gh 自己的 oauth token(gh 本來就存在 ~/.config/gh,
  # 複製一份非新增曝險面)。chmod 600、絕不進任何 git。
  AU_DIR="$HOME/.claude/.domi-autoupdate"; mkdir -p "$AU_DIR"
  _AU_TOKEN="${GH_TOKEN_ARG:-$(gh auth token 2>/dev/null || true)}"
  if [[ -n "$_AU_TOKEN" ]]; then
    ( umask 177; printf '%s' "$_AU_TOKEN" > "$AU_DIR/gh-token" )
    ok "已存 token 供 plugin 自動更新(~/.claude/.domi-autoupdate/gh-token,chmod 600)"
  fi
fi

# ── 7. Project dir + 7b. 個人 agent repo ────────────────────
info "Setting up project directory: $DOMI_PROJECT_DIR"
mkdir -p "$DOMI_PROJECT_DIR"

# 個人 agent repo 改為「用你自己的 gh 在你自己帳號建 agent-self-<帳號>」
# (原本是 clone 共用的 domiearth/agent-<帳號>)。一次性搬遷:若有舊的
# domiearth/agent-<帳號>(或本機 clone),把裡面 data 複製進新 repo 並 commit + push。
info "設定你的個人 agent repo(建在你自己的 GitHub 帳號)..."
GH_HANDLE=$(gh api user --jq '.login' 2>/dev/null || echo "")
NEW_REPO="agent-self-$GH_HANDLE"
NEW_DIR="$DOMI_PROJECT_DIR/$NEW_REPO"
LEGACY_REPO="agent-$GH_HANDLE"
LEGACY_DIR="$DOMI_PROJECT_DIR/$LEGACY_REPO"
if [[ -z "$GH_HANDLE" ]]; then
  warn "讀不到你的 GitHub 帳號 — 跳過。之後:gh repo create <你的帳號>/agent-self-<你的帳號> --private"
elif [[ -d "$NEW_DIR/.git" ]]; then
  ok "$NEW_REPO 已就緒"
elif gh repo view "$GH_HANDLE/$NEW_REPO" &>/dev/null; then
  gh repo clone "$GH_HANDLE/$NEW_REPO" "$NEW_DIR" \
    && ok "cloned $NEW_REPO — 你的個人工作區" \
    || warn "clone 失敗 — 之後:gh repo clone $GH_HANDLE/$NEW_REPO"
else
  # 在你自己帳號新建,若有舊資料先搬遷
  mkdir -p "$NEW_DIR" && ( cd "$NEW_DIR" && git init -q )
  MIG_SRC=""
  if [[ -d "$LEGACY_DIR/.git" ]]; then
    MIG_SRC="$LEGACY_DIR"
  elif gh repo view "domiearth/$LEGACY_REPO" &>/dev/null; then
    info "發現舊的 domiearth/$LEGACY_REPO — 搬遷其資料..."
    MIG_SRC="$(mktemp -d)/$LEGACY_REPO"
    gh repo clone "domiearth/$LEGACY_REPO" "$MIG_SRC" &>/dev/null || MIG_SRC=""
  fi
  [[ -n "$MIG_SRC" ]] && rsync -a --exclude='.git' "$MIG_SRC"/ "$NEW_DIR"/ 2>/dev/null \
    && info "已從 $LEGACY_REPO 搬入資料。"
  ( cd "$NEW_DIR" \
      && git add -A \
      && { git diff --cached --quiet && printf '# %s\n\nDOMI 個人 agent 抽屜 — 筆記 / 報表 / 草稿。Owner-only。\n' "$NEW_REPO" > README.md && git add README.md || true; } \
      && git commit -q -m "init $NEW_REPO${MIG_SRC:+ (migrated from $LEGACY_REPO)}" \
      && git branch -M main ) \
    && gh repo create "$GH_HANDLE/$NEW_REPO" --private --source="$NEW_DIR" --remote=origin --push \
         -d "DOMI personal agent drawer ($GH_HANDLE)" \
    && ok "已建立 + push $NEW_REPO${MIG_SRC:+(已從 $LEGACY_REPO 搬遷)}" \
    || warn "建立/push 失敗 — 之後:cd $NEW_DIR && gh repo create $GH_HANDLE/$NEW_REPO --private --source=. --remote=origin --push"
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
for plugin in individual-agent hub-relay domi-guide asset; do
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
HUB_ARGS=()
[[ -n "$HUB_HOST_ARG" ]]    && HUB_ARGS+=(--host "$HUB_HOST_ARG")
[[ -n "$HUB_HOST_TS_ARG" ]] && HUB_ARGS+=(--host-tailscale "$HUB_HOST_TS_ARG")
[[ -n "$HUB_USER_ARG" ]]    && HUB_ARGS+=(--user "$HUB_USER_ARG")
[[ -n "$HUB_PASS_ARG" ]]    && HUB_ARGS+=(--password "$HUB_PASS_ARG")
[[ -n "${GH_HANDLE:-}" ]]   && HUB_ARGS+=(--github "$GH_HANDLE")
if [[ -n "${DOMI_NONINTERACTIVE:-}" ]]; then
  info "Non-interactive — 之後用 /hub setup 設定。"
elif [[ -n "$HUB_SETUP" ]]; then
  info "Launching hub-setup (host / user / password / 你的 GitHub 帳號)..."
  echo "  還沒拿到 hub 資訊?全部按 Enter 跳過,之後再跑。"
  bash "$HUB_SETUP" ${HUB_ARGS[@]+"${HUB_ARGS[@]}"} </dev/tty || warn "hub-setup 跳過/失敗 — 之後:bash $HUB_SETUP"
else
  warn "找不到 hub-setup.sh(plugin 沒裝成功)— 之後 /hub setup 設定。"
fi

# ── 10. Summary ─────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ok "DOMI onboarding (macOS 12) complete!"
echo "    git $(git --version | awk '{print $3}') · gh $(gh --version | head -1 | awk '{print $3}') · node $(node --version) · claude ✅"
echo "  Plugins: individual-agent · hub-relay · domi-guide · asset"
echo ""
echo "  Next: 1) 登入 Claude Desktop(帳號找 Corey)"
if [[ -n "${GH_HANDLE:-}" && -d "$NEW_DIR/.git" ]]; then
  echo "        2) cd $NEW_DIR && claude"
else
  echo "        2) gh repo create <你的帳號>/agent-self-<你的帳號> --private,再 cd 進去 claude"
fi
echo "        3) session 內貼上  /domi-guide:guide all  開始教學"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── 11. Guided first session ────────────────────────────────
# Auto-start: natural-language prompt (first char != /) asks Claude to run the
# tutorial command itself, so the tutor greets proactively. A startup prompt
# starting with / would parse as a command and hang the interactive session.
TUTOR_DIR="$DOMI_PROJECT_DIR"
[[ -n "${GH_HANDLE:-}" && -d "$NEW_DIR/.git" ]] && TUTOR_DIR="$NEW_DIR"
TUTOR_PROMPT="請用 /domi-guide:guide all 指令開始 DOMI 新人互動教學;全程繁體中文,先自我介紹 + 列出全部主題 + 問我準備好了沒,再等我回覆。若找不到該指令,請直接告訴我 domi-guide plugin 沒裝成功、要找 Corey。"
if [[ -z "${DOMI_NONINTERACTIVE:-}" ]] && have claude; then
  echo ""
  printf '  Start the guided tutorial now? [Y/n] '
  read -r START_TUTORIAL </dev/tty
  if [[ ! "$START_TUTORIAL" =~ ^[nN]$ ]]; then
    info "Launching tutorial — 導師會主動開場。/exit 離開;之後打 /guide 可續。"
    echo ""
    cd "$TUTOR_DIR" && exec claude "$TUTOR_PROMPT" </dev/tty
  fi
  info "Skipped. 之後:開 claude session 打 /guide 開始教學。"
fi
