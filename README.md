# DOMI Onboarding

> 新同仁一鍵設定 DOMI Claude agent 開發環境。

## 👉 選你的平台,點進去照做(各檔自成一條龍:安裝 → 裝完下一步 → 該平台 troubleshooting)

| 你的機器 | 看這份 |
|---|---|
| 🍎 **Mac(macOS 13+)** | **[ONBOARDING_MACOS.md](./ONBOARDING_MACOS.md)** |
| 🍎 **Mac(macOS 12 Monterey)** | **[ONBOARDING_MACOS_12.md](./ONBOARDING_MACOS_12.md)** |
| 🪟 **Windows** | **[ONBOARDING_WINDOWS.md](./ONBOARDING_WINDOWS.md)** |
| 🖥️ **AgentHUB**(共用主機,通常有人帶) | **[ONBOARDING_AGENTHUB.md](./ONBOARDING_AGENTHUB.md)** |

> 🚀 **上線當天**:跑 [`GO_LIVE_CHECKLIST.md`](./GO_LIVE_CHECKLIST.md) 自檢(10 分鐘)。

---

## 對照:script 與平台

| Script | 平台 | 對象 |
|---|---|---|
| [`onboard-macos.sh`](./onboard-macos.sh) | macOS **13+**(Intel / Apple Silicon) | 個人 dev 機 |
| [`onboard-macos-12.sh`](./onboard-macos-12.sh) | macOS **12 (Monterey)** — 不用 Homebrew,避開慢編譯 | 個人 dev 機(舊系統) |
| [`onboard-windows.ps1`](./onboard-windows.ps1) | Windows 10/11(PowerShell 5.1+) | 個人 dev 機 |
| [`onboard-agenthub.sh`](./onboard-agenthub.sh) | Ubuntu 22.04+ / 24.04 LTS | AgentHUB server |

跑完會裝好:git、gh CLI、Node.js 22、Claude Code CLI、Claude Desktop、DOMI marketplace + plugin,並設定好 AgentHUB 連線。整個流程 **idempotent**(已裝的跳過,重跑安全)。

## Plugin 安裝矩陣

2026-06-08 起 **不再每台全裝** —— 治理 guard 集中在 hub 端權威執行:

| 機器 | 裝哪些 plugin | 為什麼 |
|---|---|---|
| **個人電腦**(macos / windows) | `individual-agent` · `hub-relay` · `domi-guide` | 個人 repo 行為 + 跨 hub 通道 + 教學 |
| **AgentHUB**(agenthub) | `stack-guard` · `entity-guard` · `schema-change` · `project-protect` · `domi-init` · `domi-guide` | 治理 guard 在 hub 把關(所有 project repo live 在 hub) |

> 個人電腦**不裝**治理 guard:跨 repo 操作經 `hub-relay` 送到 hub,**hub 端的 guard 才是權威把關**。
> 個人機保持極簡 = 更少出錯面。完整說明見 `domi-claude-plugins` README 安裝矩陣。

## 新人導覽 = `/guide`(domi-guide plugin)

onboarding script 最後一步自動開 `claude "/guide all"` 跑完整教學(主題 0–7);之後**忘了任何一章,
任一 Claude Code session 打 `/guide` 從上次進度繼續、`/guide <章名或編號>` 跳章** —— 不用重跑 script。
要改教學內容請改 plugin(`domi-claude-plugins/plugins/domi-guide/commands/guide.md`);
本 repo 的 [`TUTOR_PLAYBOOK.md`](./TUTOR_PLAYBOOK.md) 降為離線 fallback(plugin 沒裝成功時才用)。

## 重新設定 AgentHUB 連線(換 host / 改密碼)

不用重跑整個 onboarding,重跑 `hub-setup` script 或編輯 `~/.domi-hub.json` 即可:

```bash
# macOS / Linux / Git Bash
bash ~/.claude/plugins/cache/domi-claude-plugins/hub-relay/*/scripts/hub-setup.sh
# Windows PowerShell:對應的 hub-setup.ps1
```

或環境變數一次性 override(不寫檔):

```bash
export DOMI_HUB_HOST=<hub-host>
export DOMI_HUB_USER=<hub-user>
export DOMI_HUB_PASS=<password>
```
