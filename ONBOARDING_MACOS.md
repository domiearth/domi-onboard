# 🍎 macOS 新人環境設定

> DOMI Claude agent 開發環境 —— **Mac 專用**。照這份從上到下做一遍即可,做完直接看
> 最後的 [✅ 裝完之後做什麼](#-裝完之後做什麼) 接著往下。
> Windows 同仁請看 [`ONBOARDING_WINDOWS.md`](./ONBOARDING_WINDOWS.md)。

---

## 🚀 快速開始(非技術同仁看這裡,照做就好)

你只要做三件事:**①打開「終端機」→ ②貼一行指令 → ③按 Enter 等它跑完。**
全程不用懂程式,看到提示(輸入密碼、按 Enter)照做即可。

> 💡 跑的過程會洗出很多字,正常的,代表它在工作。整個過程約 10～30 分鐘(看網路)。

> ⚠️ **先確認 macOS 版本:建議 macOS 13 (Ventura) 以上。**
> 點左上角  → 「關於這台 Mac」看版本。**低於 13(如 macOS 12 Monterey)會卡很久** ——
> Homebrew 不再支援舊系統,工具得從原始碼慢慢編譯(可能拖一小時,看起來像當機其實沒當)。
> 請先到「系統設定 → 軟體更新」升級再跑;機型升不上去請找 onboarding 窗口或 Corey。

**第 1 步:打開「終端機」(Terminal)**

1. 按 `⌘ Command` + `空白鍵`,右上角跳出搜尋框(Spotlight)。
2. 輸入 `terminal`,按 `Enter`。
3. 跳出的白色/黑色視窗就是終端機。

**第 2 步:複製下面這一整行**

```bash
curl -fsSL https://raw.githubusercontent.com/domiearth/domi-onboard/main/onboard-macos.sh -o ~/onboard-macos.sh && bash ~/onboard-macos.sh
```

**第 3 步:回終端機貼上(`⌘ Command` + `V`)並按 `Enter`**

- 中途要你輸入**開機/登入密碼**:直接打你的 Mac 密碼按 Enter(⚠️ 打字時畫面**不會顯示任何字**,正常的)。
- 看到 `[y/N]` 之類問題,不確定就直接按 `Enter`。

> ⚠️ **千萬不要在前面自己加 `sudo`**。直接貼上面那行就好。

---

## 前置需求

- **macOS 13 (Ventura) 以上**(建議最新可用版本)。低於 13 被 Homebrew 列為 [Tier 3](https://docs.brew.sh/Support-Tiers#tier-3),套件從原始碼編譯非常慢,請先升級。
- 有 admin 權限的帳號(裝 Homebrew / Cask 用)
- 已加入 `domiearth` GitHub org(script 會跑 `gh auth login` 引導登入;沒加入找 Corey)

## 執行方式

```bash
# 推薦:先下載再跑(最清楚,互動提問一定正常)
curl -fsSL https://raw.githubusercontent.com/domiearth/domi-onboard/main/onboard-macos.sh -o ~/onboard-macos.sh
bash ~/onboard-macos.sh

# 或先 clone repo 後執行
gh repo clone domiearth/domi-onboard ~/domi-onboard
bash ~/domi-onboard/onboard-macos.sh

# 也支援 pipe(script 偵測到被 pipe 會自動重新下載 + 接終端機再跑)
curl -fsSL https://raw.githubusercontent.com/domiearth/domi-onboard/main/onboard-macos.sh | bash
```

> ⚠️ **不要加 `sudo`**(`sudo curl … | bash` ❌)。root + pipe 會讓 Homebrew 拒裝、sudo 密碼在非 TTY 對不上。script 內部要 sudo 的地方(brew)會自己跳密碼。

## 注意事項

- **Homebrew 自動安裝** — 沒裝過會幫你裝;Apple Silicon 自動 `eval` brew 環境變數。
- **Claude Desktop 安裝失敗** — fallback 到「請手動下載」提示,open <https://claude.ai/download>。
- **gh auth login 是互動式** — 跟著 prompt(建議 HTTPS + browser 認證)。
- **裝哪些 plugin** — 個人機只裝 `individual-agent` · `hub-relay` · `domi-guide`(治理 guard 在 hub 端把關,個人機不裝)。詳見 [README 安裝矩陣](./README.md#plugin-安裝矩陣)。
- **AgentHUB 連線設定** — Step 9b 問 host / user / password / **你的 GitHub 帳號**(身分,務必填);host / user 跟 onboarding 窗口索取。全部留空可跳過,稍後再跑 `hub-setup.sh`。
- **新人導覽** — 最後一步(Step 11)會問要不要開 Claude session,**按 Enter 就對了**;session 開啟後**自己輸入 `/guide`** 開始教學(Claude Code 的 slash 指令只能在 session 內手打,無法自動跑)。Claude 會用中文一步一步帶你跑過工具與流程。跳過也沒關係,見下方。

---

## ✅ 裝完之後做什麼

**1. 跑(或補跑)新人導覽** — 任何時候,任一 Claude session 打:
```
/guide
```
從上次進度繼續;`/guide 6` 看 hub 怎麼用、`/guide 7` 看治理規則。

**2. 開你自己的個人 agent 工作區**(你的「抽屜」,筆記/草稿放這,不污染別人):
```bash
cd ~/project && gh repo clone domiearth/agent-<你的GitHub帳號>
cd agent-<你的GitHub帳號> && claude
```
session 一開會看到 `individual-agent` 的守則提示。

**3. 跨 repo 做事走 hub** — 不要 clone 別人的 project,改用:
```
/hub run <repo> "<你的任務>"     # 不知道找哪個 repo:/hub repos
```

**4. 上線當天** — 跑 [`GO_LIVE_CHECKLIST.md`](./GO_LIVE_CHECKLIST.md)(10 分鐘)確認環境就緒。

> 帳號 / 權限問題一律找 Corey。

---

## Troubleshooting(macOS)

### `./onboard-macos.sh: Permission denied`

瀏覽器下載的 script 預設沒執行權限,三選一:
```bash
curl -fsSL https://raw.githubusercontent.com/domiearth/domi-onboard/main/onboard-macos.sh | bash  # 直接 pipe
bash onboard-macos.sh                                                                              # 用 bash 跑
chmod +x onboard-macos.sh && ./onboard-macos.sh                                                    # 加權限
```

### `brew: command not found`

Apple Silicon 上 brew 在 `/opt/homebrew/bin/brew`,加進 PATH:
```bash
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
source ~/.zprofile
```

### 跑 onboarding「卡住」/ log 噴出 script 原始碼

1. **用了 `sudo curl … | bash`** — root + pipe 跑壞:互動 `read` 讀不到鍵盤,子程序吃掉 pipe 裡未執行的 script。**解法**:拿掉 `sudo`,先下載再跑。
2. **`==> ./make.bash` 停很久不是當機** — 舊 macOS(如 12)被列 Tier 3,`go` 只能從原始碼編譯,十幾分鐘正常。耐心等或升級 macOS。

### `claude plugin marketplace add` 顯示 404

你的 `gh` 認證沒拿到 `domiearth` org 存取權:
1. 確認已被加入 `domiearth` org(找 admin)
2. 重跑 `gh auth login`,scope 含 `repo`

### AgentHUB 連線失敗

- `Connection timed out` → 確認在 DOMI LAN 或已連 Tailscale;`ping <hub-host>` 測試
- `Permission denied` → 帳密錯,重跑 `bash ~/.claude/plugins/cache/domi-claude-plugins/hub-relay/*/scripts/hub-setup.sh`

> 換 host / 改密碼不用重跑整個 onboarding,直接重跑 `hub-setup.sh` 或編輯 `~/.domi-hub.json`。
