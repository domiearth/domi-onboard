# Go-Live Smoke Checklist — 同仁個人電腦自檢

> **給誰**:所有要用 DOMI Claude agent 開發的同仁。**上線當天**照這份從上到下跑一遍,
> 每步都有「✅ 應該看到什麼」與「❌ 不對的話怎麼辦」。全部 ✅ = 你的環境就緒。
> **平台**:macOS / Windows(Git-bash)/ Linux 通用;指令差異會標出來。
> **預計時間**:10 分鐘。卡關直接到 #回報窗口,不要自己硬幹。

---

## 0. 前提

- [ ] 已跑過 onboarding script(`onboard-macos.sh` / `onboard-windows.ps1`)。沒跑過 → 先回 [README](./README.md) 跑完再來。
- [ ] 有自己的 GitHub 帳號,且已加入 `domiearth` org(沒有 → 找 Corey)。

---

## 1. Plugin 安裝矩陣(個人電腦)

個人電腦**只需要**這幾個 plugin。跑:

```bash
claude plugin list
```

- [ ] **✅ 應看到**(enabled):`individual-agent`、`hub-relay`、`domi-guide`
- [ ] 版本至少:`hub-relay 0.5.0` 以上、`individual-agent 0.1.0` 以上
- ❌ **缺了 / 版本太舊** →
  ```bash
  claude plugin marketplace update domi-claude-plugins
  claude plugin install individual-agent@domi-claude-plugins
  claude plugin install hub-relay@domi-claude-plugins
  claude plugin install domi-guide@domi-claude-plugins
  ```

> 註:`project-protect` / `stack-guard` / `entity-guard` / `schema-change` **個人電腦不用裝** ——
> 那些是 hub 端的治理把關,你跨過去操作時 hub 會自動執行。

---

## 2. Hub 連線設定

```bash
# macOS / Linux / Git-bash
bash "$(claude plugin marketplace dir 2>/dev/null)/domi-claude-plugins/plugins/hub-relay/scripts/hub-setup.sh"
```
> 找不到上面的路徑就用:`~/.claude/plugins/cache/domi-claude-plugins/hub-relay/*/scripts/hub-setup.sh`
> Windows PowerShell:對應的 `hub-setup.ps1`。

填三樣(不確定問 Corey):
- [ ] **Hub host(LAN)**:按 Enter 用預設(`192.168.0.141`)
- [ ] **Hub host(Tailscale)**:按 Enter 用預設(`100.72.24.53`)—— 出差 / 遠端會自動切到這個
- [ ] **帳號 / 密碼**:Corey 給的 hub 帳密
- [ ] **你的 GitHub 帳號**(如 `kirinchen`)—— ⚠️ **一定要填**,這是你的工作身分;填錯 = 到處被擋
- [ ] **✅ 應看到**:`[OK] Connection successful` 與 `[OK] Config saved`

❌ **連不上** —
- 在公司 → 確認連著公司 Wi-Fi;在外面 → 確認 Tailscale 開著(`tailscale status`)
- 帳密錯 → 重跑 hub-setup
- 仍不行 → 截圖到 #回報窗口

---

## 3. 連線健康檢查

開一個 Claude session(任意目錄),輸入:

```
/hub status
```

- [ ] **✅ 應看到**:`🔗 AgentHUB (...) — ✅ connected` + repo 數 / session 數
- [ ] 在外面時括號內會顯示 `via Tailscale` —— 代表自動切換正常
- ❌ **unreachable** → 回 #2 重設;兩個 host 都試過仍不行 → 回報

---

## 4. 跨 repo 執行(核心功能)

```
/hub run foreman "用一句話說明你是什麼"
```

- [ ] **✅ 應看到**:foreman agent 回一句話(它讀自己的 CLAUDE.md 後回答)
- ❌ **`claude: command not found` / exit 127** → 你的 hub-relay 太舊(這是 0.4.1 修掉的);回 #1 更新到最新
- ❌ **`no github_account configured` 警告** → 回 #2 補填 GitHub 帳號
- ❌ **`unknown repo`** → 正常的防呆;打 `/hub repos` 看正確 repo 名

---

## 5. 個人 agent repo(你的抽屜)

```bash
# macOS / Linux
cd ~/project && gh repo clone domiearth/agent-<你的GitHub帳號> && cd agent-<你的GitHub帳號> && claude
```
> Windows:`cd ~\project; gh repo clone ...; cd agent-<...>; claude`

- [ ] **✅ session 一開**,應看到 `individual-agent` 的守則提示(🗂️ 開頭,說明這是你的個人工作區)
- [ ] 試 `/note 測試筆記` → 應在 `notes/` 建出一份檔
- ❌ **沒看到守則** → 確認 `individual-agent` 已裝(回 #1);確認 repo 名是 `agent-<帳號>`

> 規則:**筆記 / 報表 / 草稿寫這裡,不要丟進別人的 project repo。** 屬於某 project 的決策 → 走 `/hub run <repo>`。

---

## 6. 治理體感(被擋 = 系統正常,不是壞掉)

跨 repo 操作時若遇到:

- [ ] 改別人 repo 的程式被擋 → 看訊息確認你的權限等級,對的話找該 repo owner;不是繞過
- [ ] 改欄位 / migration 被擋 → 走 schema 諮詢(`/propose` 或諮詢 datahouse),**不要開 Issue、不要硬改**
- [ ] 想動 `mt-dao` / `mt-prototype-system` / `good-forest` 被擋 → 正常,那三個禁碰

> 不確定怎麼用 → 任何 session 打 **`/guide`** 重看教學(`/guide 6` 看 hub、`/guide 7` 看治理規則)。

---

## ✅ 全部勾完 = 你就緒了

## 回報窗口

卡在任何一步:**截圖該步的指令 + 輸出**,貼到 [onboarding 窗口 / Corey]。
不要自己改 plugin 或 hub 設定硬幹 —— 多半是已知問題,回報最快。

> **平台註記**:此清單在 **Windows(Git-bash)** 已實測。**macOS 首位完成的同仁**請在 #回報窗口
> 回報跑起來順不順(目前尚無 Mac 實機驗證),有問題會即時修。
