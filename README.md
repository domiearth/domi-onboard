# DOMI Onboarding Scripts

> 新同仁一鍵設定 DOMI Claude agent 開發環境

三個 script，依作業系統 / 目標環境選擇：

| Script | 平台 | 對象 |
|---|---|---|
| [`onboard-macos.sh`](./onboard-macos.sh) | macOS（Intel 或 Apple Silicon） | 個人 dev 機 |
| [`onboard-windows.ps1`](./onboard-windows.ps1) | Windows 10/11（PowerShell 5.1+） | 個人 dev 機 |
| [`onboard-agenthub.sh`](./onboard-agenthub.sh) | Ubuntu 22.04+ / 24.04 LTS | **AgentHUB server**（同仁透過 SSH 進來開發） |

跑完會裝好：git、gh CLI、Node.js 22、Claude Code CLI、Claude Desktop、sshpass、DOMI marketplace + 5 個 plugin（含 hub-relay），並設定好 AgentHUB 連線。

> 新人導覽 session 的教學腳本獨立放在 [`TUTOR_PLAYBOOK.md`](./TUTOR_PLAYBOOK.md)；三個 onboarding script 在 Step 11 都會自動載入它（本機有副本就讀檔，否則抓 GitHub 上的最新版）。**要改教學內容只改這一個檔即可，不用動 script。**

## 🚀 快速開始（非技術同仁看這裡，照做就好）

你只要做三件事：**①打開一個叫「終端機」的視窗 → ②把一行指令貼進去 → ③按 Enter，然後等它跑完。**
全程不用懂程式，看到問題（例如要你輸入密碼、按 Enter）就照提示做即可。

> 💡 什麼是「指令」？就是下面那一長串文字。你不用自己打，**整段複製、貼上、按 Enter** 就好。
> 💡 跑的過程會洗出很多字，那是正常的，代表它在工作。整個過程大概 10～30 分鐘（看網路）。

---

### 🍎 我用的是 Mac

> ⚠️ **先確認你的 macOS 版本：建議 macOS 13 (Ventura) 以上。**
> 點左上角  → 「關於這台 Mac」看版本。**低於 13（例如 macOS 12 Monterey）會卡很久**——因為 Homebrew 不再支援舊系統，工具得從原始碼慢慢編譯（可能拖到一小時，看起來像當機其實沒當）。
> 請先到「系統設定 → 軟體更新」**升級到最新可用版本再跑**；若你的機型升不上去，請找 onboarding 窗口或 Corey。

**第 1 步：打開「終端機」(Terminal)**

1. 按鍵盤 `⌘ Command` + `空白鍵`，右上角會跳出搜尋框（這叫 Spotlight）。
2. 輸入 `terminal`，按 `Enter`。
3. 會跳出一個白色或黑色的視窗——這就是終端機，等你輸入指令。

**第 2 步：複製下面這一整行**（點右上角的複製鈕，或整行反白後 `⌘ Command` + `C`）

```bash
curl -fsSL https://raw.githubusercontent.com/domiearth/domi-onboard/main/onboard-macos.sh -o ~/onboard-macos.sh && bash ~/onboard-macos.sh
```

**第 3 步：回到終端機視窗，貼上並執行**

1. 在終端機裡按 `⌘ Command` + `V` 貼上（指令會整行出現）。
2. 按 `Enter` 開始跑。
3. 中途如果要你輸入**開機/登入用的密碼**：直接打你的 Mac 密碼按 Enter（⚠️ 打字時畫面**不會顯示任何字**，這是正常的，打完按 Enter 就好）。
4. 看到問你問題時（例如 `[y/N]`、要不要裝某東西），照下方「注意事項」說明回答，不確定就直接按 `Enter`。

> ⚠️ **千萬不要在前面自己加 `sudo`**。直接貼上面那行就好。

---

### 🪟 我用的是 Windows

**第 1 步：用「系統管理員」打開 PowerShell**（這步很重要，少了會裝不起來）

1. 按鍵盤左下角的 `⊞ 視窗鍵`（或點開始功能表）。
2. 輸入 `powershell`。
3. 在搜尋結果的「Windows PowerShell」上**按右鍵 → 選「以系統管理員身分執行」**。
4. 跳出「是否允許變更」就按「**是**」。會開一個藍色（或黑色）視窗——這就是 PowerShell。

**第 2 步：複製下面這一整行**（點右上角複製鈕，或反白後 `Ctrl` + `C`）

```powershell
$f="$env:TEMP\onboard-windows.ps1"; irm https://raw.githubusercontent.com/domiearth/domi-onboard/main/onboard-windows.ps1 -OutFile $f; powershell -ExecutionPolicy Bypass -File $f
```

**第 3 步：回到 PowerShell 視窗，貼上並執行**

1. 在 PowerShell 視窗裡**按滑鼠右鍵**就會自動貼上（或按 `Ctrl` + `V`）。
2. 按 `Enter` 開始跑。
3. 中途若彈出視窗問「是否允許安裝」就按「**是 / 允許**」；問你問題時照下方「注意事項」回答，不確定就按 `Enter`。

> ⚠️ 如果忘了用「系統管理員」開，看到紅字錯誤是正常的——關掉視窗，回第 1 步重開一次。

---

### 🖥️ AgentHUB（公司共用主機）

這台是進階用法，**通常會有人帶你**。先用 SSH 連進主機，再貼這行：

```bash
curl -fsSL https://raw.githubusercontent.com/domiearth/domi-onboard/main/onboard-agenthub.sh -o ~/onboard-agenthub.sh && bash ~/onboard-agenthub.sh
```

---

### ✅ 跑完之後會怎樣？

裝到最後，畫面會問你「**要不要開一個導覽 session？**」——**按 `Enter` 就對了**。
接著 Claude 會用中文**一步一步**教你怎麼用工具、怎麼把專案抓下來。跟著它做就好；想結束就輸入 `/exit`。

> 卡住了？最常見的兩個狀況（Mac 看起來「不動」、Windows 紅字錯誤）在最下面的 [Troubleshooting](#troubleshooting) 有解法；真的不行就找你的 onboarding 窗口或 Corey。
> 各平台的詳細前置需求、進階執行方式見下方對應章節。

---

## macOS

### 前置需求

- **macOS 13 (Ventura) 以上**（建議跑最新可用版本）。低於 13（如 macOS 12 Monterey）被 Homebrew 列為 [Tier 3](https://docs.brew.sh/Support-Tiers#tier-3) 不支援，多數套件會**從原始碼編譯、非常慢**，請先升級再跑；機型升不上去的個案請找 onboarding 窗口。
- 有 admin 權限的帳號（裝 Homebrew / Cask 會用到）
- 已加入 `domiearth` GitHub org（script 中會跑 `gh auth login` 引導登入）

### 執行方式

```bash
# 推薦：先下載再跑（最清楚，互動提問一定正常）
curl -fsSL https://raw.githubusercontent.com/domiearth/domi-onboard/main/onboard-macos.sh -o ~/onboard-macos.sh
bash ~/onboard-macos.sh

# 或先 clone domi-onboard repo 後執行
gh repo clone domiearth/domi-onboard ~/domi-onboard
bash ~/domi-onboard/onboard-macos.sh

# 也支援 pipe（script 偵測到被 pipe 會自動重新下載 + 接上終端機再跑）
curl -fsSL https://raw.githubusercontent.com/domiearth/domi-onboard/main/onboard-macos.sh | bash
```

> ⚠️ **不要在前面加 `sudo`**（`sudo curl … | bash` ❌）。整條 pipeline 用 root 跑會讓 Homebrew 拒裝、sudo 密碼在非 TTY 下對不上。script 內部需要 sudo 的地方（brew）會自己跳密碼。

### 注意事項

- **Homebrew 自動安裝** — 若沒裝過 Homebrew，script 會幫你裝；Apple Silicon 上會自動 `eval` brew 環境變數。
- **Claude Desktop 安裝失敗時** — 會 fallback 到「請手動下載」提示，open <https://claude.ai/download>。
- **gh auth login 是互動式的** — 跟著 prompt 走（建議選 HTTPS + browser 認證）。
- **AgentHUB 連線設定** — Step 9b 會詢問 host / user / password；host / user 跟你的 DOMI onboarding 窗口索取（LAN 或 Tailscale IP 視你的接入方式而定）。留空可跳過,稍後再跑 hub-setup.sh。
- **新人導覽 session** — 全部裝完後（Step 11）會問要不要開一個 Claude session，由 Claude 照 playbook **一步一步**帶你跑過 5 個主題:① Claude Desktop vs Claude Code CLI 介紹 ② 設定 Claude Desktop（**登入資訊找 Corey**）③ 怎麼 clone GitHub 專案（gh CLI 或請 Claude 代勞）④ 在 Claude Code 開啟專案並開始互動 ⑤ git repo / agent / agent workspace 的關係。按 Enter 即開始；輸入 `/exit` 結束。跳過的話之後隨時可 `cd ~/project && claude` 自己開。

---

## Windows

### 前置需求

- Windows 10 (1709+) 或 Windows 11
- PowerShell 5.1+（Windows 10+ 內建）
- App Installer / winget 可用（Microsoft Store 可裝）
- 有 admin 權限的帳號
- 已加入 `domiearth` GitHub org

### ⚠️ PowerShell 執行原則錯誤的解法

預設 Windows 禁止跑沒簽章的 PowerShell script，會看到：

```
無法載入 .\onboard-windows.ps1 檔案。
因為這個系統上已停用指令碼執行。
+ FullyQualifiedErrorId : UnauthorizedAccess
```

**推薦解法（本次 session 暫時放寬，最安全）**：

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\onboard-windows.ps1
```

`-Scope Process` 只影響當前 PowerShell 視窗，關掉就恢復。

**其他選擇**：

```powershell
# 一次性 bypass，不改設定
powershell -ExecutionPolicy Bypass -File .\onboard-windows.ps1

# 永久放寬到 user-level（之後不用每次設）
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### 執行方式

**強烈建議以系統管理員身份開 PowerShell**（右鍵 PowerShell → 「以系統管理員身份執行」），因為 winget 安裝某些套件需要 admin。

**推薦：一行下載 + 執行（console 全程搞定，免手動下載、免改執行原則）**

```powershell
$f="$env:TEMP\onboard-windows.ps1"; irm https://raw.githubusercontent.com/domiearth/domi-onboard/main/onboard-windows.ps1 -OutFile $f; powershell -ExecutionPolicy Bypass -File $f
```

`irm`（=`Invoke-RestMethod`）先把 script 抓到暫存檔，再用 `-ExecutionPolicy Bypass` 開一個子 PowerShell 跑它 —— 等於 macOS 的 `curl -o … && bash …`，不用先 `Set-ExecutionPolicy`、不用瀏覽器下載。互動提問（workbench / Hub / 導覽 session）照常運作。

**或手動下載後執行：**

```powershell
# 1. 開啟 admin PowerShell
# 2. cd 到 script 所在目錄
cd C:\Users\<你>\Downloads   # 或 cd 到你下載的位置

# 3. 放寬執行原則 + 跑 script
Set-ExecutionPolicy Bypass -Scope Process -Force
.\onboard-windows.ps1
```

或先 clone repo：

```powershell
gh repo clone domiearth/domi-onboard $env:USERPROFILE\domi-onboard
Set-ExecutionPolicy Bypass -Scope Process -Force
.\domi-onboard\onboard-windows.ps1
```

### 注意事項

- **Scoop 會被自動安裝** — sshpass 需要 Scoop，script 沒裝過會用 user-level 安裝（不需 admin）。
- **某些工具裝完需要重開 terminal** — script 會用 `Refresh-Path` 嘗試刷新；若仍出現 "not in PATH yet"，照提示重開 PowerShell 後再驗證：
  ```powershell
  git --version; gh --version; node --version; claude --version; sshpass -V
  ```
- **gh auth login 走瀏覽器** — 跟著 prompt 走。
- **AgentHUB 連線設定** — Step 9b 互動式提問 host / user / password；host / user 跟你的 DOMI onboarding 窗口索取。留空可跳過,稍後再跑 hub-setup.ps1。
- **新人導覽 session** — 全部裝完後（Step 11）會問要不要開一個 Claude session，由 Claude 照 playbook **一步一步**帶你跑過 5 個主題:① Claude Desktop vs Claude Code CLI 介紹 ② 設定 Claude Desktop（**登入資訊找 Corey**）③ 怎麼 clone GitHub 專案（gh CLI 或請 Claude 代勞）④ 在 Claude Code 開啟專案並開始互動 ⑤ git repo / agent / agent workspace 的關係。按 Enter 即開始；輸入 `/exit` 結束。若 `claude` 裝完還沒進 PATH，重開 PowerShell 後 `cd $env:USERPROFILE\project; claude` 自己開。

---

## AgentHUB（centralized Ubuntu server）

`onboard-agenthub.sh` 在 AgentHUB 上裝**完整 dev 工具鏈**，讓所有 DOMI 同仁透過 SSH 共用一套環境。

### 用法

直接 SSH 進 AgentHUB 後跑：

```bash
gh repo clone domiearth/domi-onboard ~/domi-onboard
bash ~/domi-onboard/onboard-agenthub.sh
```

Script 兩段：

**Part A — User-level**（不需 sudo）：
- **Node.js LTS**（binary tarball → `~/.local/`）+ npm
- **pnpm**（via corepack）
- **uv**（Python toolkit manager，official installer → `~/.local/bin`）
- **Rust** stable（via rustup → `~/.cargo`）

**Part B — System-level**（需要 sudo prompt）：
- `build-essential`（make / gcc / linker — Rust 編譯與多數 native deps 需要）
- `shellcheck`（per TECH_STACK §6.2 MUST）
- `sshpass`（hub-relay 連回 LAN 用）
- `postgresql-client`（datahouse / marketing-system 操作）
- `tmux`（hub-relay session 用）

Script idempotent — 已裝的會跳過。Part B 在非互動環境（如直接被 Claude Code Bash tool 呼叫）會 graceful fail，請用 SSH 互動 shell 跑。

### 策略

裝在 AgentHUB（共用）vs 個人 dev 機（`onboard-macos` / `onboard-windows`）：

- **AgentHUB**：環境統一、不會「我的機器可以跑」、新人 SSH 進來就能開發；缺點是佔 server 資源
- **個人機**：本地 IDE 體驗好；缺點是環境差異

DOMI 目前**雙軌並行**。AgentHUB 是主力（hub-relay 把本地 Claude session 轉接到這），個人機保留做小修小補。

---

## 個人 dev 機（macOS / Windows）共同會做的事

1. 安裝基礎工具（git、gh、node 22、claude CLI、Claude Desktop、sshpass）
2. `gh auth login` 確保 GitHub 認證
3. 建立專案目錄（`~/project`）
4. **註冊 DOMI marketplace**：
   ```bash
   claude plugin marketplace add https://github.com/domiearth/domi-claude-plugins
   ```
5. **安裝 5 個 DOMI plugin**（stack-guard / entity-guard / domi-init / schema-change / hub-relay）
6. 互動式設定 AgentHUB 連線，credentials 存到 `~/.domi-hub.json`（chmod 600 / current-user ACL）
7. 印出安裝摘要與 next steps

整個流程是 **idempotent** — 已裝的會自動跳過，重複跑安全。

---

## Onboarding 完成後

```bash
# 進入 foreman repo 開始第一個 session
cd ~/project/foreman   # Windows: cd $env:USERPROFILE\project\foreman
gh repo clone domiearth/foreman .   # 若還沒 clone
claude                  # 開啟 Claude session（foreman 的 CLAUDE.md 自動載入）
```

開 Claude session 後，會看到 hub-relay 的 SessionStart banner：

```
🔗 AgentHUB (<your-hub-host>) — ✅ connected
   12 repos with CLAUDE.md | 0 tmux sessions
```

之後可以用 `/hub run <repo> "<task>"` 委派任務給 AgentHUB 上的 project agent。

---

## Troubleshooting

### macOS：`./onboard-macos.sh: Permission denied`

從瀏覽器下載的 script 預設沒有執行權限。三種解法擇一：

```bash
# 方法 1：直接 pipe 給 bash（最省事，不用存檔）
curl -fsSL https://raw.githubusercontent.com/domiearth/domi-onboard/main/onboard-macos.sh | bash

# 方法 2：用 bash 跑（不用改權限）
bash onboard-macos.sh

# 方法 3：加執行權限後再跑
chmod +x onboard-macos.sh
./onboard-macos.sh
```

### macOS：`brew: command not found`

Apple Silicon 上 brew 裝在 `/opt/homebrew/bin/brew`，需要把它加進 PATH：

```bash
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
source ~/.zprofile
```

### macOS：跑 onboarding「卡住」/ log 噴出 script 原始碼

兩個常見原因，通常一起出現：

1. **用了 `sudo curl … | bash`** — 整條 pipeline 被 root + pipe 跑壞：互動 `read` 讀不到鍵盤，且 Homebrew / go build 等子程序會把 pipe 裡「還沒執行的 script 內容」吃掉，於是 log 突然冒出 script 原始碼然後卡死。
   **解法**：拿掉 `sudo`，改成先下載再跑（見上方「執行方式」）。最新版 script 已能偵測 pipe 並自動重新下載 + 接終端機，但 `sudo` 仍請避免。

2. **`==> ./make.bash` 停很久不是當機** — 舊版 macOS（如 **macOS 12**）被 Homebrew 列為 [Tier 3](https://docs.brew.sh/Support-Tiers#tier-3)，沒有預編好的 bottle，`gh` 的相依套件 `go` 只能**從原始碼編譯**，會跑十幾分鐘。耐心等它跑完即可；想避開可考慮升級 macOS。

### Windows：Scoop 安裝時 `Set-ExecutionPolicy ... ExecutionPolicyOverride`

當你已經跑過 `Set-ExecutionPolicy Bypass -Scope Process -Force`，script 內部再嘗試設定 `Scope CurrentUser` 時會印出「設定已被覆寫」警告，加上 `$ErrorActionPreference = "Stop"` 會中止 script。已在 `onboard-windows.ps1` v2 修掉（用 try/catch 包住）。如果你拿到的是舊版，**重新從 GitHub 下載最新**：

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/domiearth/domi-onboard/main/onboard-windows.ps1" -OutFile onboard-windows.ps1
```

### Windows：一執行就紅字 `未預期的 'Start' 語彙基元` / `字串遺漏結尾字元`

代表你拿到的是**含中文字元的舊版** `.ps1`。Windows PowerShell 5.1 會把沒有 BOM 的下載檔當成系統 ANSI 編碼(繁中機是 Big5/cp950)讀，於是中文被讀壞、script 根本載不進去。最新版的 `.ps1` 已改成**純 ASCII**(中文教學移到 `TUTOR_PLAYBOOK.md`，執行時才抓)，重新用上方「一行下載 + 執行」跑一次即可。確認自己是不是舊版:

```powershell
# 重新抓最新版再跑
$f="$env:TEMP\onboard-windows.ps1"; irm https://raw.githubusercontent.com/domiearth/domi-onboard/main/onboard-windows.ps1 -OutFile $f; powershell -ExecutionPolicy Bypass -File $f
```

### Windows：`scoop : 無法辨識……名稱`

Scoop 裝完後 PATH 未刷新。**重開 PowerShell** 再跑一次 script，或手動：

```powershell
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","User") + ";" + $env:Path
```

### `claude plugin marketplace add` 失敗 — 顯示 404

代表你的 `gh` 認證沒拿到 `domiearth` org 的存取權。請：

1. 確認你已被加入 `domiearth` org（找 admin 確認）
2. 重新跑 `gh auth login`，**reset 認證 scope 包含 `repo`**

### AgentHUB 連線失敗 — `Connection timed out`

- 確認本機在 DOMI LAN 上，或已連 Tailscale
- 用你拿到的 hub host 測試：`ping <your-hub-host>`（LAN 或 Tailscale IP，視接入方式）
- 若用 Tailscale，重跑 hub-setup script 並輸入 Tailscale IP

### AgentHUB 連線失敗 — `Permission denied`

帳號或密碼錯。手動重設：

```bash
# macOS / Linux / Git Bash
bash ~/.claude/plugins/.../hub-relay/scripts/hub-setup.sh

# Windows PowerShell
.\hub-setup.ps1
```

---

## 重新設定 AgentHUB 連線（換 host / 改密碼）

不需要重跑整個 onboarding，直接編輯 `~/.domi-hub.json` 或重跑 `hub-setup` script 即可：

```bash
# macOS / Linux / Git Bash
bash <plugin-dir>/hub-relay/scripts/hub-setup.sh

# Windows PowerShell
.\<plugin-dir>\hub-relay\scripts\hub-setup.ps1
```

或用環境變數一次性 override（不寫入檔案）：

```bash
export DOMI_HUB_HOST=<your-hub-host>
export DOMI_HUB_USER=<your-hub-user>
export DOMI_HUB_PASS=your-password
```
