# 📱 iPad 設定(看狀態 / 派工)

> **iPad 是 thin client,不是 dev 機。**
> iPadOS 跑不了 `onboard-macos.sh`(原因見文末 [§ 為什麼不能跑 script](#-為什麼-onboard-macossh-在-ipad-上不可行分析)),
> 也**不需要**跑 —— DOMI 的重活本來就在 AgentHUB 上,iPad 只要能連進去看與派工就夠了。
> 要在 iPad 上實際 coding,請用 Mac / Windows(見 [`ONBOARDING_MACOS.md`](./ONBOARDING_MACOS.md) /
> [`ONBOARDING_WINDOWS.md`](./ONBOARDING_WINDOWS.md))。

**適用對象**:主要用途是「看專案狀態、丟需求派工、回一句話」的人。
**不用安裝任何 script、不用 shell、不用 Node。** 全程 Safari。

---

## 30 秒版

1. iPad 裝 **Tailscale** app,用公司帳號登入(和你 Mac 上同一個)。
2. Safari 開 `http://100.72.24.53:3030` → 加到主畫面。
3. 完成。其他儀表板同法加書籤。

---

## Step 1 — Tailscale(唯一要裝的 app)

hub 沒有對外公開 IP,所有儀表板都只在 **tailnet** 內可達。

1. App Store 裝 **Tailscale**(官方)。
2. 登入 —— DOMI tailnet 目前是**單帳號制**(`service@domiearth.com`),
   和你 Mac 上用的是同一組;iPad 登入後會多一台裝置,**不需要另外找人開權限**。
3. 開關打開,確認狀態顯示 Connected。

驗證:Safari 開 `http://100.72.24.53:4800`,看到「DOMI 許願牆」就通了。

> 在辦公室 Wi-Fi 內也可以走 LAN `192.168.0.141`(同樣的 port)。
> **但建議一律記 Tailscale 的 `100.72.24.53`** —— 在家、在外、換網路都不用改網址。

---

## Step 2 — 你的儀表板(建議全部加到主畫面)

| 開這個 | 網址 | 用途 | 要登入嗎 |
|---|---|---|---|
| 🗂️ **ops-portal** | `http://100.72.24.53:4700` | **全公司系統統一入口** —— 不確定要開哪個就從這裡進 | ✅ HTTP Basic(帳密問 Corey) |
| 📊 **project-cockpit** | `http://100.72.24.53:3030` | 所有 repo 的狀態、branch、完成度、進行中的 agent session | ❌ 免登入 |
| 🙏 **許願牆 wishboard** | `http://100.72.24.53:4800` | **派工主戰場** —— 丟需求、看誰接了、看回覆 | ❌ 免登入 |
| 📈 **MS Rebuild Tracker** | `http://100.72.24.53:4600` | marketing-system rebuild 的進度儀表板 | ❌ 免登入 |
| 🪟 **porthole 舷窗** | `http://100.72.24.53:4321` | 瀏覽器內的 agent session / console(要看 agent 正在做什麼時) | ❌ 免登入 |

**加到主畫面**:Safari 開網址 → 分享鈕 → 「加入主畫面」。之後像 app 一樣點開,而且是全螢幕沒有網址列。

> cockpit 的專案卡片可以直接 deep-link 進 porthole 看那個 repo 的 session —— 兩者是串起來的,
> 從 cockpit 進去比自己記 porthole 網址順。

---

## Step 3 — 怎麼派工

三種方式,由輕到重:

### A. 許願牆丟卡(推薦,最適合 iPad)
`:4800` → 新增一張卡,寫清楚**要什麼**跟**為什麼**。
agent 會被指派到這張卡上工作,做完直接回寫在卡片上,你回來看 status 跟 response 就好。
這條路徑是設計給「需求進來 → 自動派給對的 agent」的,**不需要你指定誰做**。

### B. 儀表板上的 💬 直接對話
cockpit(`:3030`)和 MS Tracker(`:4600`)右下角有 💬 浮動按鈕,點下去就是跟 **foreman**(SA/PM agent)講話。
適合「這個狀態是什麼意思?」「幫我看一下 X」這種即問即答,不用開卡。

### C. porthole 看/接手 session
`:4321` 可以看到正在跑的 agent session,必要時直接在瀏覽器裡打字介入。
iPad 沒鍵盤時打字會痛苦,**建議只用來看,不用來操作**。

---

## 選配 — 真的想用終端機

如果哪天需要在 iPad 上直接下指令(不是預期用途,但可行):

1. 裝 **Blink Shell**(付費,體驗最好)或 **Termius**(免費版夠用)。
2. `ssh <你的帳號>@100.72.24.53`
3. `tmux attach` → `claude`

斷線 = tmux detach **不是** kill,回來 `tmux attach` 接續同一個 session。
原理見 `foreman/doc/ws-tmux-claude-resumable-session.md`。

⚠️ **請用你自己的 hub 帳號,不要共用 `domi` 帳號登入。**
DOMI 的治理模型是 **一人 ↔ 一 repo ↔ 一個人 agent**(`foreman/AGENT_REPO_POLICY.md`);
共用帳號會讓個人身分、`agent-self-<handle>` 個人 repo、per-user worktree、github handshake 全部失效。
沒有自己的 hub 帳號就先開一個,不要借用。

> **強烈建議接外接鍵盤。** 螢幕鍵盤打不了 Ctrl / Esc,tmux 跟 Claude Code 都會很難用。

---

## ❌ 為什麼 `onboard-macos.sh` 在 iPad 上不可行(分析)

留檔備查,免得下次有人再問一次。

### 逐段對照

| script 步驟 | iPadOS 現實 |
|---|---|
| §0 Homebrew | ❌ 不存在,iPadOS 沒有系統級 package manager |
| §1–3 `brew install git / gh / node@22` | ❌ 同上 |
| §4 `npm install -g @anthropic-ai/claude-code` | ❌ 沒有原生 Node runtime,也沒有 global bin PATH |
| §5 Claude Desktop(`/Applications/Claude.app`) | ❌ macOS-only。iPad 的 Claude app 是聊天 app,**不是 Claude Code** |
| §7b `gh repo create agent-self-<handle>` | ⚠️ 需要 gh CLI 才能跑 |
| §9b hub-setup(ssh 到 hub、寫 `~/.domi-hub.json`) | ⚠️ 需要 ssh client + 可寫的 home 目錄 |

**根因**是 iPadOS 的 app sandbox:沒有跨 app 共用的 filesystem,也沒有執行任意二進位的權限。
這不是「找對工具就能解」的問題,是平台設計。

### 那些「iPad 上的 shell」呢?

- **a-Shell** —— 有 Python / Lua,**沒有 Node.js** → Claude Code CLI 裝不了。
- **iSH** —— x86 模擬跑 Alpine,理論上 `apk add nodejs git github-cli` 裝得起來。
  但 32-bit 模擬效能極差、App 進背景會被 iPadOS 掛起,跑 Claude Code 這種長時互動 session
  實務上不堪用。**不建議,也不支援。**

### 那 claude.ai/code 呢?

Safari 可以直接用 Claude Code 的 web 版,但它跑在**雲端 sandbox**:

- 碰不到 hub 上的 canonical clone(所有 DOMI repo 的真值都在 hub)
- 治理 guard(stack-guard / entity-guard / project-protect / schema-change)不在那一側

→ 可以當臨時輔助,**不能當 DOMI 的正式工作路徑**。

### 結論

iPad 走 thin client 是**正確解**而不是妥協 —— AgentHUB 架構本來就是「重活在 hub、個人機只是終端」。
iPad 只是把這個前提推到極致:連終端都省了,用瀏覽器。

---

## Troubleshooting

**開網址轉圈圈 / 連不上**
→ 先確認 Tailscale 是 Connected。iPadOS 會在低電量模式或長時間背景後斷開 VPN,打開 Tailscale app 看一眼。

**「Safari 無法開啟網頁,因為伺服器已停止回應」**
→ hub 上該服務可能沒在跑。從別的儀表板(例如 `:4800`)確認 hub 本身活著;
只有單一 port 掛掉的話,跟 Corey 說哪個 port。

**`:4700` 一直跳帳密框**
→ ops-portal 走 HTTP Basic,帳密問 Corey。其他四個是免登入的,可以先用那些。

**加到主畫面後打不開**
→ 主畫面 icon 記住的是當下網址。如果是用 LAN `192.168.0.141` 存的,離開辦公室就會失效 ——
刪掉重新用 `100.72.24.53` 加一次。

**想看 agent 到底在做什麼**
→ cockpit(`:3030`)找到那個 repo 的卡片 → 展開 → console / session,或直接開 porthole(`:4321`)。

---

## 已知限制

- 本文件的流程**尚未在 iPad 實機驗證過**(與 macOS 12 路徑同等狀態)。跑過有問題請回報,直接改這份。
- iPad 上**沒有** `/hub`、`/guide` 這些 slash command —— 那些活在 Claude Code CLI 裡。
  iPad 的對等物是儀表板上的 💬(直接跟 foreman 講話)。
- 免登入的儀表板(`:3030` `:4321` `:4600` `:4800`)目前**綁在 `0.0.0.0`**,
  代表辦公室 LAN 上的任何人都開得到,不只 tailnet。這是既有狀態,不是 iPad 帶來的;
  收斂與否是另一條議題。
