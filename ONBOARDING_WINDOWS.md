# 🪟 Windows 新人環境設定

> DOMI Claude agent 開發環境 —— **Windows 專用**(Windows 10/11,PowerShell 5.1+)。
> 照這份從上到下做一遍,做完直接看 [✅ 裝完之後做什麼](#-裝完之後做什麼) 接著往下。
> Mac 同仁請看 [`ONBOARDING_MACOS.md`](./ONBOARDING_MACOS.md)。

---

## 🚀 快速開始(非技術同仁看這裡,照做就好)

你只要做三件事:**①用「系統管理員」打開 PowerShell → ②貼一行指令 → ③按 Enter 等它跑完。**

> 💡 跑的過程會洗出很多字,正常的。整個過程約 10～30 分鐘(看網路)。

**第 1 步:用「系統管理員」打開 PowerShell**(這步很重要,少了會裝不起來)

1. 按左下角 `⊞ 視窗鍵`(或點開始功能表)。
2. 輸入 `powershell`。
3. 在「Windows PowerShell」上**按右鍵 → 以系統管理員身分執行**。
4. 跳出「是否允許變更」按「**是**」。開出來的藍色/黑色視窗就是 PowerShell。

**第 2 步:複製下面這一整行**

```powershell
$f="$env:TEMP\onboard-windows.ps1"; irm https://raw.githubusercontent.com/domiearth/domi-onboard/main/onboard-windows.ps1 -OutFile $f; powershell -ExecutionPolicy Bypass -File $f
```

**第 3 步:回 PowerShell 視窗,按滑鼠右鍵貼上(或 `Ctrl` + `V`),按 `Enter`**

- 中途彈窗問「是否允許安裝」按「**是 / 允許**」;問你問題不確定就按 `Enter`。

> ⚠️ 忘了用「系統管理員」開 → 看到紅字錯誤正常,關掉視窗回第 1 步重開。

---

## 前置需求

- Windows 10 (1709+) 或 Windows 11
- PowerShell 5.1+(Windows 10+ 內建)
- App Installer / winget 可用(Microsoft Store 可裝)
- 有 admin 權限的帳號
- 已加入 `domiearth` GitHub org(沒加入找 Corey)

## ⚠️ PowerShell 執行原則錯誤的解法

預設 Windows 禁止跑沒簽章的 script,會看到:
```
無法載入 .\onboard-windows.ps1 檔案。因為這個系統上已停用指令碼執行。
+ FullyQualifiedErrorId : UnauthorizedAccess
```

**推薦解法(本次 session 暫時放寬,最安全)**:
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\onboard-windows.ps1
```
`-Scope Process` 只影響當前視窗,關掉就恢復。

## 執行方式

**強烈建議以系統管理員開 PowerShell**(winget 裝某些套件需要 admin)。

**推薦:一行下載 + 執行(console 全程搞定,免手動下載、免改執行原則)**

```powershell
$f="$env:TEMP\onboard-windows.ps1"; irm https://raw.githubusercontent.com/domiearth/domi-onboard/main/onboard-windows.ps1 -OutFile $f; powershell -ExecutionPolicy Bypass -File $f
```

`irm`(=`Invoke-RestMethod`)先抓 script 到暫存檔,再用 `-ExecutionPolicy Bypass` 開子 PowerShell 跑 —— 等於 macOS 的 `curl -o … && bash …`。互動提問照常。

**或手動下載後執行:**
```powershell
cd C:\Users\<你>\Downloads     # cd 到下載位置
Set-ExecutionPolicy Bypass -Scope Process -Force
.\onboard-windows.ps1
```

## 注意事項

- **某些工具裝完需重開 terminal** — script 會 `Refresh-Path` 嘗試刷新;仍 "not in PATH" 就重開 PowerShell 再驗證:
  ```powershell
  git --version; gh --version; node --version; claude --version
  ```
- **gh auth login 走瀏覽器** — 跟著 prompt。
- **裝哪些 plugin** — 個人機只裝 `individual-agent` · `hub-relay` · `domi-guide`(治理 guard 在 hub 端把關)。詳見 [README 安裝矩陣](./README.md#plugin-安裝矩陣)。
- **AgentHUB 連線設定** — Step 9b 問 host / user / password / **你的 GitHub 帳號**(身分,務必填);host / user 跟 onboarding 窗口索取。留空可跳過,稍後再跑 `hub-setup.ps1`。
- **新人導覽** — 最後一步會問要不要開導覽,**按 Enter 就對了**,教學會自動開始(沒開始就在 session 內打 `/guide`)。跳過也沒關係,見下方。

---

## ✅ 裝完之後做什麼

**1. 跑(或補跑)新人導覽** — 任何時候,任一 Claude session 打:
```
/guide
```
從上次進度繼續;`/guide 6` 看 hub 怎麼用、`/guide 7` 看治理規則。

**2. 開你自己的個人 agent 工作區**(你的「抽屜」,筆記/草稿放這,不污染別人):
```powershell
cd $env:USERPROFILE\project; gh repo clone domiearth/agent-<你的GitHub帳號>
cd agent-<你的GitHub帳號>; claude
```
session 一開會看到 `individual-agent` 的守則提示。

**3. 跨 repo 做事走 hub** — 不要 clone 別人的 project,改用:
```
/hub run <repo> "<你的任務>"     # 不知道找哪個 repo:/hub repos
```

**4. 上線當天** — 跑 [`GO_LIVE_CHECKLIST.md`](./GO_LIVE_CHECKLIST.md)(10 分鐘)確認環境就緒。

> 帳號 / 權限問題一律找 Corey。

---

## Troubleshooting(Windows)

### 一執行就紅字 `未預期的 'Start' 語彙基元` / `字串遺漏結尾字元`

你拿到的是**含中文字元的舊版** `.ps1`。PowerShell 5.1 把無 BOM 的下載檔當系統 ANSI(繁中機 Big5/cp950)讀,中文被讀壞、script 載不進去。最新版已改**純 ASCII**(中文移到 `TUTOR_PLAYBOOK.md`),重抓最新再跑:
```powershell
$f="$env:TEMP\onboard-windows.ps1"; irm https://raw.githubusercontent.com/domiearth/domi-onboard/main/onboard-windows.ps1 -OutFile $f; powershell -ExecutionPolicy Bypass -File $f
```

### `claude plugin marketplace add` 顯示 404

`gh` 認證沒拿到 `domiearth` org 存取權:確認已加入 org(找 admin)→ 重跑 `gh auth login`,scope 含 `repo`。

### AgentHUB 連線失敗

- `Connection timed out` → 確認在 DOMI LAN 或已連 Tailscale;`ping <hub-host>` 測試
- `Permission denied` → 帳密錯,重跑 `.\hub-setup.ps1`

> 換 host / 改密碼不用重跑整個 onboarding,直接重跑 `hub-setup.ps1` 或編輯 `~/.domi-hub.json`。
