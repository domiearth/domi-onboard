# DOMI Onboarding Scripts

> 新同仁一鍵設定 DOMI Claude agent 開發環境

三個 script，依作業系統 / 目標環境選擇：

| Script | 平台 | 對象 |
|---|---|---|
| [`onboard-macos.sh`](./onboard-macos.sh) | macOS（Intel 或 Apple Silicon） | 個人 dev 機 |
| [`onboard-windows.ps1`](./onboard-windows.ps1) | Windows 10/11（PowerShell 5.1+） | 個人 dev 機 |
| [`onboard-agenthub.sh`](./onboard-agenthub.sh) | Ubuntu 22.04+ / 24.04 LTS | **AgentHUB server**（同仁透過 SSH 進來開發） |

跑完會裝好：git、gh CLI、Node.js 22、Claude Code CLI、Claude Desktop、sshpass、DOMI marketplace + 5 個 plugin（含 hub-relay），並設定好 AgentHUB 連線。

---

## macOS

### 前置需求

- macOS 11+ (Big Sur 以上)
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
- **新人導覽 session** — 全部裝完後（Step 11）會問要不要開一個 Claude session，由 Claude **一步一步**帶你熟悉 claude CLI 與 `gh`（含 clone foreman repo）。按 Enter 即開始；輸入 `/exit` 結束。跳過的話之後隨時可 `cd ~/project && claude` 自己開。

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
- **新人導覽 session** — 全部裝完後（Step 11）會問要不要開一個 Claude session，由 Claude **一步一步**帶你熟悉 claude CLI 與 `gh`（含 clone foreman repo）。按 Enter 即開始；輸入 `/exit` 結束。若 `claude` 裝完還沒進 PATH，重開 PowerShell 後 `cd $env:USERPROFILE\project; claude` 自己開。

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
