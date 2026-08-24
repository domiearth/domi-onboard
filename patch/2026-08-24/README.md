# DOMI patch 2026-08-24 — 個人帳號制清理 + 補裝 asset

> **對象:已經跑過舊版 onboarding 的既有機器**(Tammy、Stacey、Lily…)。
> 全新機器不用這支 —— 直接跑完整的 [`onboard-macos.sh`](../../onboard-macos.sh) / [`onboard-windows.ps1`](../../onboard-windows.ps1)(已更新為個人帳號制)。

## 為什麼需要這支 patch

公司 GitHub 2026-08 回到 Free plan、全員**個人帳號**重新加入。共用帳號時代
(省 seat)跑的 onboarding 在每台機器留下四個殘留,**其中第一個 full onboarding
重跑也修不到**(它看到 gh「已登入」就跳過,不會檢查登的是誰):

| # | 殘留 | 後果(Lily 2026-08-24 實際撞到) |
|---|---|---|
| 1 | `gh` 登著共用/別人的帳號 | 所有操作掛錯人 |
| 2 | `~/.domi-hub.json` 的 `github_account` 是錯的人 | hub 上被 project-protect 擋,governed repo 完全不能寫 |
| 3 | `~/.claude/.domi-autoupdate/gh-token` 是已失效的共用 PAT | plugin 自動更新**靜默失敗**(worker 有檔就用檔),工具越來越舊(Lily 的 hub-relay 停在 0.9.17,落後 11 版) |
| 4 | 沒裝 `asset` plugin(舊版 onboarding 清單沒有它) | 不能用 `/asset:knowledge-*`、`/asset:deck-*` 分享成果 |

Patch 四步對應修掉:確認身分(不對就切/登入)→ 重寫 token → 補裝 asset + 全部更新 → 重跑 hub-setup。

## 怎麼跑

### 🍎 macOS(含 Windows 的 Git Bash 也可)

```bash
curl -fsSL https://raw.githubusercontent.com/domiearth/domi-onboard/main/patch/2026-08-24/patch-macos.sh -o ~/domi-patch.sh
bash ~/domi-patch.sh
```

### 🪟 Windows(PowerShell)

```powershell
$f="$env:TEMP\patch-windows.ps1"; irm https://raw.githubusercontent.com/domiearth/domi-onboard/main/patch/2026-08-24/patch-windows.ps1 -OutFile $f; powershell -ExecutionPolicy Bypass -File $f
```

全程互動、idempotent(重跑安全)。會問的問題:

1. **「目前 gh 登入的是 X,這是你自己的帳號嗎?」**——最重要的一題,不是就答 n,
   接著貼自己的帳號名(已登過就直接切換,沒登過會開瀏覽器登入)。
2. 其他還登著的帳號要不要登出(建議 y)。
3. hub-setup 的 host / user / password——**已設定過的直接一路 Enter 沿用**。

## 跑完怎麼確認

script 結尾自動印驗證,四行都要對:

```
gh 身分       <本人帳號>
hub 身分      <本人帳號> ✅
hub-relay     0.9.28 以上
asset         ✅ <版本>
```

或開一個新的 claude session 問它:
「幫我看 ~/.domi-hub.json 的 github_account 是不是我、asset plugin 有沒有裝」。

## Troubleshooting

| 狀況 | 怎麼辦 |
|---|---|
| 第 1 步登入時瀏覽器沒開 / 卡住 | 終端機會顯示一組 code,手動開 https://github.com/login/device 貼上 |
| 說我的帳號看不到 org / 403 | 帳號還沒被加回 `domiearth` org → 找 Corey |
| plugin 更新失敗 | 先確認第 1 步成功(`gh auth status` 的 active 是本人),重跑 patch;還不行截圖找 Corey |
| hub-setup 連不到 hub | 要在辦公室 LAN 或連著 Tailscale;測法看 tcp/22 不是 ping:跑 hub-relay 的 `hub-ping.sh` |
| 跑到一半中斷了 | 直接重跑,做過的會跳過 |

## 這支 patch 和 full onboarding 的關係

- Full onboarding(`onboard-*.sh/ps1`)= 新機器從零到有;**已更新為個人帳號制**,重跑也安全。
- 本 patch = 既有機器的**身分清理**;多做了 full onboarding 不做的「確認登的是誰」,
  並且不重裝 Homebrew/Node/CLI 那些已存在的東西,快很多。
- 之後如果又有一批既有機器要修別的東西,開新的 `patch/<日期>/` 資料夾,不要改這包
  (跑過的人要能對照自己當時跑的是什麼)。

## 背景(給要查根因的人)

- 事故:Lily 的 handoff(2026-08-24)—— `~/.domi-hub.json` 掛著別人的帳號 + good-forest fail-closed。
- 源頭修復:onboarding 個人帳號制(`c61e270`)、hub-setup 0.9.28 身分防呆(`domi-claude-plugins@ac2965d`)。
- 自動更新 worker 的「有檔用檔、無檔退回 gh」邏輯:`domi-claude-plugins/plugins/domi-guide/scripts/domi-autoupdate-worker.sh`。
