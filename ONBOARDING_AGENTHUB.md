# 🖥️ AgentHUB 環境設定(共用 Ubuntu 主機)

> **進階用法,通常會有人帶你。** `onboard-agenthub.sh` 在 AgentHUB 上裝完整 dev 工具鏈 +
> hub 端治理 plugin,讓所有 DOMI 同仁透過 SSH 共用一套環境。
> 個人機請看 [`ONBOARDING_MACOS.md`](./ONBOARDING_MACOS.md) / [`ONBOARDING_WINDOWS.md`](./ONBOARDING_WINDOWS.md)。

---

## 用法

SSH 進 AgentHUB 後跑:

```bash
gh repo clone domiearth/domi-onboard ~/domi-onboard
bash ~/domi-onboard/onboard-agenthub.sh
```

Script idempotent — 已裝的會跳過,重複跑安全。

## Script 做什麼

**Part A — User-level**(不需 sudo):
- **Node.js LTS**(binary tarball → `~/.local/`)+ npm
- **pnpm**(via corepack)
- **uv**(Python toolkit manager → `~/.local/bin`)
- **Rust** stable(via rustup → `~/.cargo`)
- **Claude Code CLI**(npm global → `~/.local`)

**Part B — System-level**(需 sudo prompt):
- **GitHub CLI(`gh`)** — 官方 apt repo;**B2 私庫 marketplace 的前提**
- `build-essential`(make / gcc / linker)
- `shellcheck`(per TECH_STACK §6.2 MUST)
- `sshpass`、`postgresql-client`、`tmux`

> Part B 在非互動環境(如直接被 Claude Code Bash tool 呼叫)會 graceful fail,請用 SSH **互動 shell** 跑。

**Part B2 — Governance plugins(hub 端把關)**:
- **先確保 `gh auth`**(私庫 marketplace 需 `domiearth` org 存取)— 沒認證會引導 `gh auth login`(互動 shell)或提示設 `GH_TOKEN`
- 裝 `stack-guard` · `entity-guard` · `schema-change` · `project-protect` · `domi-init` · `domi-guide`
- **不裝** `hub-relay`(hub 自己不連自己)與 `individual-agent`(hub 上無個人 repo)
- 條件式:偵測到 `claude` CLI 才裝;沒裝 claude 會提示手動步驟

> 為什麼 hub 裝治理 guard、個人機不裝:所有 project repo live 在 hub,**治理在 hub 端權威執行**;
> 個人機跨 repo 操作經 `hub-relay` 送進來,hub 的 guard 才是最終把關。完整安裝矩陣見 [README](./README.md#plugin-安裝矩陣)。

## 為什麼有 AgentHUB(策略)

AgentHUB(共用)vs 個人 dev 機:

- **AgentHUB**:環境統一、不會「我的機器才能跑」、新人 SSH 進來就能開發;缺點佔 server 資源
- **個人機**:本地 IDE 體驗好;缺點環境差異

DOMI **雙軌並行**:AgentHUB 是主力(`hub-relay` 把本地 Claude session 轉接進來),個人機保留做小修小補。

---

## 完成後

驗證工具鏈:
```bash
node --version; pnpm --version; uv --version; cargo --version; shellcheck --version
claude plugin list | grep domi-claude-plugins   # 應見 6 個治理 guard
```

之後同仁從**個人機**用 `/hub run <repo> "<task>"` 把任務委派進 hub 上的 project agent。
