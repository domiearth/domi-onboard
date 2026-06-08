# 🍎 macOS 12 (Monterey) 新人環境設定

> DOMI Claude agent 開發環境 —— **macOS 12 (Monterey) 專用**(升不上去的舊機)。
> 做完直接看 [✅ 裝完之後做什麼](#-裝完之後做什麼) 接著往下。
> **macOS 13+** 請改用 [`ONBOARDING_MACOS.md`](./ONBOARDING_MACOS.md)(更簡單,走 Homebrew)。
> Windows 同仁請看 [`ONBOARDING_WINDOWS.md`](./ONBOARDING_WINDOWS.md)。

> **為什麼 macOS 12 要分開**:macOS 12 被 Homebrew 列為 [Tier 3](https://docs.brew.sh/Support-Tiers#tier-3),
> `brew install` 會把工具(如 `gh` 的 Go 相依)**從原始碼編譯**,動輒數十分鐘。本專用 script
> **不用 Homebrew**:git 走 Xcode 命令列工具、Node 與 gh 用官方 `.pkg` 安裝,避開漫長編譯。
> **能升級就先升到 macOS 13+**(系統設定 → 軟體更新),那邊更省事;升不上去再用這份。

---

## 🚀 快速開始(非技術同仁看這裡,照做就好)

你只要做三件事:**①打開「終端機」→ ②貼一行指令 → ③按 Enter 等它跑完。**

> 💡 跑的過程會洗出很多字,正常的。整個過程約 15～40 分鐘(看網路)。

**第 1 步:打開「終端機」(Terminal)**

1. 按 `⌘ Command` + `空白鍵`,右上角跳出搜尋框(Spotlight)。
2. 輸入 `terminal`,按 `Enter`。
3. 跳出的白色/黑色視窗就是終端機。

**第 2 步:複製下面這一整行**

```bash
curl -fsSL https://raw.githubusercontent.com/domiearth/domi-onboard/main/onboard-macos-12.sh -o ~/onboard-macos-12.sh && bash ~/onboard-macos-12.sh
```

**第 3 步:回終端機貼上(`⌘ Command` + `V`)並按 `Enter`**

- 中途會跳出一個「**安裝命令列開發者工具**」的視窗 → 按「**安裝**」,等它裝完(幾分鐘)再回終端機按 Enter。
- 要你輸入**開機/登入密碼**:直接打你的 Mac 密碼按 Enter(⚠️ 打字時畫面**不會顯示任何字**,正常的)。
- 看到 `[y/N]` 之類問題,不確定就直接按 `Enter`。

> ⚠️ **千萬不要在前面自己加 `sudo`**。直接貼上面那行就好。

---

## 開始前:複製貼上、帳號、三個登入

### 怎麼在「終端機」複製貼上

1. 在這份說明或網頁上,把指令**整段反白 → `⌘ Command` + `C`** 複製。
2. 點一下終端機視窗 → **`⌘ Command` + `V`** 貼上 → 按 `Enter` 執行。
3. 要你**輸入密碼**時(開機密碼 / sudo):**打字不會顯示任何字是正常的**,打完按 Enter 即可。

### 你的 GitHub「帳號名稱」(account name)在哪看

clone 你自己的 agent repo 會用到。三種方式看:
- 到 <https://github.com> 右上角**圓形頭像 → 第一行就是你的帳號名**(例 `kirinchen`)。
- 或頭像 → **Settings**,最上方 username。
- 已登入 `gh` 後,終端機打:`gh api user --jq .login`(會印出你的帳號名)。
> ⚠️ 是**帳號名(username)**,不是你的姓名或 email。沒加入 `domiearth` org → 找 Corey。

### 過程中會遇到「三個登入」,怎麼登

| # | 登入哪裡 | 怎麼登 |
|---|---|---|
| 1 | **GitHub CLI(`gh`)** | script 跑到會問,選 **GitHub.com → HTTPS → Login with a web browser**,瀏覽器跟著授權即可 |
| 2 | **Claude Code CLI** | 第一次開 `claude` 會要登入,跟著畫面用 Anthropic 帳號登入(**帳號 / 授權找 Corey**,不要自己亂註冊) |
| 3 | **Claude Desktop** | 開 app 後登入,**帳號找 Corey** |

---

## 前置需求

- **macOS 12 (Monterey)**。能升到 13+ 就先升(用 `ONBOARDING_MACOS.md`,更省事)。
- 有 admin 權限的帳號(裝 `.pkg` 會用到 sudo 密碼)。
- 已加入 `domiearth` GitHub org(script 會跑 `gh auth login` 引導登入;沒加入找 Corey)。

## 執行方式

```bash
# 推薦:先下載再跑(最清楚,互動提問一定正常)
curl -fsSL https://raw.githubusercontent.com/domiearth/domi-onboard/main/onboard-macos-12.sh -o ~/onboard-macos-12.sh
bash ~/onboard-macos-12.sh

# 也支援 pipe(script 偵測到被 pipe 會自動重新下載 + 接終端機再跑)
curl -fsSL https://raw.githubusercontent.com/domiearth/domi-onboard/main/onboard-macos-12.sh | bash
```

> ⚠️ **不要加 `sudo`**。script 內部要 sudo 的地方(裝 `.pkg`)會自己跳密碼。

## 注意事項(macOS 12 特有)

- **不用 Homebrew** — 刻意避開,免得卡在源碼編譯。
- **git = Xcode 命令列工具** — 沒裝過會跳安裝視窗,按「安裝」等它好,再回終端機按 Enter。
- **Node.js / gh = 官方 `.pkg`** — 會用 sudo 安裝(跳密碼正常)。
- **Claude Desktop** — macOS 12 走手動下載:<https://claude.ai/download>,裝好回終端機按 Enter。
- **裝哪些 plugin** — 個人機只裝 `individual-agent` · `hub-relay` · `domi-guide`(治理 guard 在 hub 端把關)。詳見 [README 安裝矩陣](./README.md#plugin-安裝矩陣)。
- **AgentHUB 連線設定** — 會跑 `hub-setup`,問 host / user / password / **你的 GitHub 帳號**(身分,務必填);沒拿到 hub 資訊可全部按 Enter 跳過,稍後再跑。
- **新人導覽** — 最後一步會問要不要開導覽,**按 Enter 就對了**;session 開啟後**把 `/domi-guide:guide all` 整段複製貼上**開始教學(沒開始就打這行)。跳過也沒關係,見下方。

---

## ✅ 裝完之後做什麼

**1. 開新人導覽** — Claude session 內貼上:
```
/domi-guide:guide all
```
之後任何 session 打 `/guide` 可從上次進度繼續;`/guide 6` 看 hub、`/guide 7` 看治理規則。

**2. 開你自己的個人 agent 工作區**(你的「抽屜」,筆記/草稿放這,不污染別人):
```bash
cd ~/project/agent-<你的GitHub帳號> && claude
```
沒 clone 成功就先:`cd ~/project && gh repo clone domiearth/agent-<你的GitHub帳號>`。

**3. 跨 repo 做事走 hub** — 不要 clone 別人的 project,改用:
```
/hub run <repo> "<你的任務>"     # 不知道找哪個 repo:/hub repos
```

**4. 上線當天** — 跑 [`GO_LIVE_CHECKLIST.md`](./GO_LIVE_CHECKLIST.md)(10 分鐘)確認環境就緒。

> 帳號 / 權限問題一律找 Corey。

---

## Troubleshooting(macOS 12)

### 「安裝命令列開發者工具」視窗沒出現 / git 還是找不到

手動觸發,裝完再重跑 script:
```bash
xcode-select --install
```

### Node / gh 的 `.pkg` 安裝失敗

手動下載安裝後重跑 script:
- Node(官方):<https://nodejs.org/en/download>(選 macOS Installer `.pkg`)
- gh(官方):<https://github.com/cli/cli/releases/latest>(下 `macOS universal.pkg`)

### `claude plugin marketplace add` 顯示 404

`gh` 認證沒拿到 `domiearth` org 存取權:確認已加入 org(找 admin)→ 重跑 `gh auth login`,scope 含 `repo`。

### AgentHUB 連線失敗

- `Connection timed out` → 確認在 DOMI LAN 或已連 Tailscale;`ping <hub-host>` 測試
- `Permission denied` → 帳密錯,重跑 `bash ~/.claude/plugins/cache/domi-claude-plugins/hub-relay/*/scripts/hub-setup.sh`

> 換 host / 改密碼不用重跑整個 onboarding,直接重跑 `hub-setup.sh` 或編輯 `~/.domi-hub.json`。
