# DOMI patch 2026-10-21 — 補裝 jq(+ Windows 補裝 python3)

> **對象:已經跑過 onboarding 的機器**。全新機器不用這支 —— 完整的
> [`onboard-macos.sh`](../../onboard-macos.sh) / [`onboard-macos-12.sh`](../../onboard-macos-12.sh) /
> [`onboard-windows.ps1`](../../onboard-windows.ps1) 已經會裝 jq。

## 為什麼需要這支 patch

`asset` plugin(onboarding 必裝四顆之一,2026-08-13 加入)的分享知識、簡報、待辦、
artifact 登記、log、drive 查詢都要 `jq`,**沒有就直接停在「需要 jq」**。但 onboarding
從來沒裝 jq。`hub-relay` 沒 jq 還能跑,但會跳過送出前的權限預檢(hub 端仍會擋)。

| 系統 | 現況 |
|---|---|
| macOS 15 | 系統內建 `/usr/bin/jq`,沒事(patch 會直接說「已經有了」) |
| macOS 12 / 13 / 14 | **沒有 jq → asset 壞** |
| Windows | **沒有 jq → asset 壞** |

### Windows 另外補 `python3`(同日追加)

個人機 plugin 有 6 個 hook 用 `python3` 跑 —— 包括 `individual-agent` 擋「個人帳號開 repo / 對外部署」
的那道 guard、domi-guide 的自動更新、asset 的 artifact hook。Windows 沒有 `python3`:這個名字會落到
Microsoft Store 的佔位程式,只印「Python was not found」→ **這些 hook 不報錯、只是什麼都沒做**。
winget / python.org 的 Python 也只給 `python` / `py`,沒有 `python3`。

所以 Windows patch 用 **uv** 裝 Python 3.12(`uv python install --default` 會同時放 `python.exe` 和
`python3.exe` 到 `%USERPROFILE%\.local\bin`),再把那個資料夾排到使用者 PATH 最前面,蓋過 Store 佔位。
已經有可用 `python3` 的機器會直接跳過。

## 怎麼跑

### 🍎 macOS

```bash
curl -fsSL https://raw.githubusercontent.com/domiearth/domi-onboard/main/patch/2026-10-21/patch-macos.sh -o ~/domi-patch.sh
bash ~/domi-patch.sh
```

有 Homebrew 就 `brew install jq`;沒有(用 macOS 12 那支 onboarding 裝的機器)就從原始碼編,
約 1–2 分鐘,最後會問一次 sudo 密碼(= 開機密碼)。

### 🪟 Windows(PowerShell)

```powershell
$f="$env:TEMP\patch-windows.ps1"; irm https://raw.githubusercontent.com/domiearth/domi-onboard/main/patch/2026-10-21/patch-windows.ps1 -OutFile $f; powershell -ExecutionPolicy Bypass -File $f
```

## 跑完怎麼確認

終端機打 `jq --version`,印出 `jq-1.x` 就好了;Windows 再打 `python3 --version`,要印出 `Python 3.x`。然後**開新的** Claude Code session。

## 為什麼 macOS 12 要用編的

jq 官方的 macOS 執行檔有最低系統版本(讀 Mach-O `LC_BUILD_VERSION` 實測):
**1.8.x 要 macOS 14、1.7.1 要 macOS 13** → macOS 12 沒有能用的官方檔。
所以用 Command Line Tools 編官方 release 原始碼(版本 `1.8.2`、sha256 釘死、
`--disable-shared` 編成單一執行檔)。

## Troubleshooting

| 狀況 | 怎麼辦 |
|---|---|
| 「沒有 Homebrew 也沒有 Command Line Tools」 | 先跑 `xcode-select --install`,裝完再重跑 |
| 「sha256 對不上」 | 不會安裝。截圖找 Kirin |
| 裝完 `jq --version` 找不到 | 關掉終端機重開 |
| Windows:裝完 `python3` 還是跳出 Microsoft Store / 「not found」 | 設定 → 應用程式 → 進階應用程式設定 → **應用程式執行別名**,把 `python.exe` / `python3.exe` 關掉,重開終端機 |
| 跑到一半中斷 | 直接重跑,已裝好會跳過 |
