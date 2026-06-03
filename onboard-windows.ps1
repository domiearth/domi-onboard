# ──────────────────────────────────────────────────────────────
# DOMI onboarding — Windows (PowerShell 5.1+)
# Usage: Run as Administrator
#   Set-ExecutionPolicy Bypass -Scope Process -Force
#   .\onboard-windows.ps1
# ──────────────────────────────────────────────────────────────

$ErrorActionPreference = "Stop"

$DOMI_PROJECT_DIR = "$env:USERPROFILE\project"

# ── helpers ──────────────────────────────────────────────────

function Info  { Write-Host "[INFO]  $args" -ForegroundColor Cyan }
function Ok    { Write-Host "[OK]    $args" -ForegroundColor Green }
function Warn  { Write-Host "[WARN]  $args" -ForegroundColor Yellow }
function Fail  { Write-Host "[FAIL]  $args" -ForegroundColor Red; exit 1 }

function Test-Command {
    param([string]$Name)
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) {
        Ok "$Name already installed ($($cmd.Source))"
        return $true
    }
    return $false
}

function Refresh-Path {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path", "User")
}

# ── 0. Check winget ──────────────────────────────────────────

Info "Checking winget..."
if (-not (Test-Command "winget")) {
    Fail "winget not found. Please install App Installer from Microsoft Store first."
}

# ── 1. Git ───────────────────────────────────────────────────

Info "Checking git..."
if (-not (Test-Command "git")) {
    Info "Installing git..."
    winget install --id Git.Git --accept-source-agreements --accept-package-agreements
    Refresh-Path
}
if (Test-Command "git") {
    Ok "git $(git --version)"
} else {
    Warn "git installed but not in PATH yet. Restart terminal after script completes."
}

# ── 2. GitHub CLI ────────────────────────────────────────────

Info "Checking GitHub CLI..."
if (-not (Test-Command "gh")) {
    Info "Installing GitHub CLI..."
    winget install --id GitHub.cli --accept-source-agreements --accept-package-agreements
    Refresh-Path
}
if (Test-Command "gh") {
    Ok "gh $(gh --version | Select-Object -First 1)"
}

# ── 3. Node.js ───────────────────────────────────────────────

Info "Checking Node.js..."
if (-not (Test-Command "node")) {
    Info "Installing Node.js LTS..."
    winget install --id OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements
    Refresh-Path
}
if (Test-Command "node") {
    $nodeVer = node --version
    $nodeMajor = [int]($nodeVer -replace '^v(\d+)\..*', '$1')
    if ($nodeMajor -lt 18) {
        Fail "Node.js >= 18 required (found $nodeVer). Please update via winget."
    }
    Ok "node $nodeVer"
} else {
    Warn "Node.js installed but not in PATH yet. Restart terminal after script completes."
}

# ── 4. Claude Code CLI ──────────────────────────────────────

Info "Checking Claude Code CLI..."
if (-not (Test-Command "claude")) {
    Info "Installing Claude Code CLI via npm..."
    npm install -g @anthropic-ai/claude-code
    Refresh-Path
}
if (Test-Command "claude") {
    Ok "claude CLI installed"
} else {
    Warn "Claude CLI installed but not in PATH yet. Restart terminal after script completes."
}

# ── 4b. Scoop + sshpass (required by hub-relay) ─────────────

Info "Checking Scoop..."
if (-not (Test-Command "scoop")) {
    Info "Installing Scoop (user-level, no admin needed)..."
    # Try to set CurrentUser policy for future sessions; harmless if a more
    # specific scope (e.g. Process Bypass) already provides sufficient permissions
    try {
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction Stop
    } catch {
        # Already covered by Process scope; install will still work
    }
    Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
    Refresh-Path
}

Info "Checking sshpass..."
if (-not (Test-Command "sshpass")) {
    Info "Installing sshpass via Scoop..."
    scoop install sshpass
    Refresh-Path
}
if (Test-Command "sshpass") {
    Ok "sshpass installed"
} else {
    Warn "sshpass install may need a terminal restart"
}

# ── 5. Claude Desktop ───────────────────────────────────────

Info "Checking Claude Desktop..."
$claudeDesktop = Get-Command "Claude" -ErrorAction SilentlyContinue
$claudeDesktopPath = "$env:LOCALAPPDATA\Programs\claude-desktop"
if ($claudeDesktop -or (Test-Path $claudeDesktopPath)) {
    Ok "Claude Desktop already installed"
} else {
    Info "Installing Claude Desktop..."
    $installed = $false
    try {
        winget install --id Anthropic.Claude --accept-source-agreements --accept-package-agreements
        $installed = $true
    } catch {}

    if (-not $installed) {
        Warn "Auto-install failed. Please download manually:"
        Warn "  https://claude.ai/download"
        Read-Host "Press Enter after installing, or close to skip"
    } else {
        Ok "Claude Desktop installed"
    }
}

# ── 6. GitHub authentication ────────────────────────────────

Info "Checking GitHub auth..."
$authStatus = gh auth status 2>&1
if ($LASTEXITCODE -eq 0) {
    Ok "Already authenticated to GitHub"
} else {
    Info "Please authenticate with GitHub..."
    gh auth login
}

# ── 7. Project directory ────────────────────────────────────

Info "Setting up project directory: $DOMI_PROJECT_DIR"
New-Item -ItemType Directory -Force -Path $DOMI_PROJECT_DIR | Out-Null

# ── 8. claude-workbench (optional) ──────────────────────────

Write-Host ""
Info "claude-workbench - Kirin's productivity plugins (mentor, kanban, chat)"
$installWB = Read-Host "  Install claude-workbench? [y/N]"

if ($installWB -match '^[yY]$') {
    Info "Registering claude-workbench marketplace..."
    $wbMarketList = claude plugin marketplace list 2>&1
    if ($wbMarketList -match "claude-workbench") {
        Ok "claude-workbench marketplace already registered"
    } else {
        claude plugin marketplace add https://github.com/kirinchen/claude-workbench
        Ok "claude-workbench marketplace registered"
    }

    Info "Installing workbench plugins (mentor, kanban, chat)..."
    foreach ($plugin in @("mentor", "kanban", "chat")) {
        Info "  Installing $plugin..."
        try { claude plugin install "${plugin}@claude-workbench" 2>$null } catch { Warn "  $plugin skipped (may already be installed)" }
    }
    Ok "claude-workbench done"
} else {
    Info "Skipping claude-workbench"
}

# ── 9. domi-claude-plugins (required, via marketplace) ─────

Write-Host ""
Info "domi-claude-plugins - DOMI governance plugins (REQUIRED)"
Info "Registering DOMI marketplace (private - requires domiearth org access)..."

$marketplaceList = claude plugin marketplace list 2>&1
if ($marketplaceList -match "domi-claude-plugins") {
    Ok "DOMI marketplace already registered"
} else {
    claude plugin marketplace add https://github.com/domiearth/domi-claude-plugins
    Ok "DOMI marketplace registered"
}

Info "Installing DOMI plugins from marketplace..."
foreach ($plugin in @("stack-guard", "entity-guard", "domi-init", "schema-change", "hub-relay")) {
    Info "  Installing $plugin..."
    try { claude plugin install "${plugin}@domi-claude-plugins" 2>$null } catch { Warn "  $plugin skipped (may already be installed)" }
}
Ok "domi-claude-plugins done"

# ── 9b. AgentHUB connection setup ───────────────────────────

Write-Host ""
Info "AgentHUB connection setup - host/user/password"
Write-Host "  (Ask your DOMI onboarding contact for the hub host/user.)"
Write-Host "  (Leave host or password blank to skip - run hub-setup.ps1 later.)"
Write-Host ""

$hubHost = Read-Host "  Hub host"
$hubUser = Read-Host "  Hub user"

$hubPassSecure = Read-Host "  Hub password" -AsSecureString
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($hubPassSecure)
$hubPass = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)

$configFile = "$env:USERPROFILE\.domi-hub.json"

if ((-not $hubHost) -or (-not $hubUser) -or (-not $hubPass)) {
    Warn "Host/user/password incomplete - skipping AgentHUB config. Run hub-setup.ps1 later."
} else {
    Info "Testing connection to ${hubUser}@${hubHost}..."
    & sshpass -p "$hubPass" ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new -o LogLevel=ERROR "${hubUser}@${hubHost}" "echo ok" 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        $cfg = [ordered]@{
            host = $hubHost
            user = $hubUser
            password = $hubPass
        } | ConvertTo-Json
        Set-Content -Path $configFile -Value $cfg -Encoding UTF8
        try {
            $acl = Get-Acl $configFile
            $acl.SetAccessRuleProtection($true, $false)
            $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($env:USERNAME, "FullControl", "Allow")
            $acl.AddAccessRule($rule)
            Set-Acl -Path $configFile -AclObject $acl
        } catch {}
        Ok "AgentHUB credentials saved to $configFile"
    } else {
        Warn "Connection test failed - credentials NOT saved. Run hub-setup.ps1 after fixing network."
    }
}

# ── 10. Summary ─────────────────────────────────────────────

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor White
Ok "DOMI onboarding complete!"
Write-Host ""
Write-Host "  Installed:"
try { Write-Host "    git          $(git --version)" } catch { Write-Host "    git          (restart terminal)" }
try { Write-Host "    gh           $(gh --version | Select-Object -First 1)" } catch { Write-Host "    gh           (restart terminal)" }
try { Write-Host "    node         $(node --version)" } catch { Write-Host "    node         (restart terminal)" }
try { Write-Host "    claude CLI   installed" } catch { Write-Host "    claude CLI   (restart terminal)" }
Write-Host ""
Write-Host "  Plugins (via domi-claude-plugins marketplace):"
Write-Host "    stack-guard    ✅  TECH_STACK.md enforcement"
Write-Host "    entity-guard   ✅  Local vs Global/MT-DAO boundary"
Write-Host "    domi-init      ✅  repo bootstrap with CLAUDE.md templates"
Write-Host "    schema-change  ✅  datahouse cross-repo coordination"
Write-Host "    hub-relay      ✅  SSH bridge to AgentHUB"
if ($installWB -match '^[yY]$') {
    Write-Host "    claude-workbench     ✅ (mentor, kanban, chat)"
}
Write-Host ""
Write-Host "  Next steps:"
Write-Host "    1. Open Claude Desktop and sign in"
Write-Host "    2. Run: cd $DOMI_PROJECT_DIR; gh repo clone domiearth/foreman"
Write-Host "    3. Run: cd foreman; claude   # start your first session"
Write-Host "    4. (If skipped above) run hub-setup.ps1 to configure AgentHUB later"
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor White

Write-Host ""
Warn "If any tools show 'restart terminal', close and reopen PowerShell, then verify with:"
Write-Host "    git --version && gh --version && node --version && claude --version"

# ── 11. Guided first session (optional) ─────────────────────
# Hand off into a live Claude Code session that tutors the new hire through
# the claude CLI and gh (clone a project), one step at a time. Skipped if the
# claude CLI isn't on PATH yet (needs a terminal restart after install).

$TUTOR_PROMPT = @'
你是 DOMI 的新人 onboarding 導師。請全程用繁體中文,照下面的 playbook 一步一步帶我 —— 一次只教一個主題裡的一個小步驟,給我可以直接複製貼上的指令或操作,然後等我回報結果(或貼上輸出/描述畫面)後再進行下一步。不要一次把全部內容倒出來。每個大主題開始前,先用一兩句說明「接下來要學什麼、為什麼」。

═══ 教學 playbook(請依序進行)═══

【主題 0 — 開場】
簡短自我介紹你是新人導覽助手,說明今天會帶我認識 DOMI 的開發工具與流程(共 4 個主題,約 10 分鐘),問我準備好了沒再開始。

【主題 1 — 介紹 Claude Desktop 與 Claude Code CLI】
用淺白的話解釋這兩個工具是什麼、差在哪、各自適合做什麼:
- Claude Desktop:圖形介面 app,適合對話、貼檔案、輕量操作,新手友善。
- Claude Code CLI(就是現在這個 `claude` 終端機工具):跑在 PowerShell 裡,能直接讀寫專案檔案、執行指令、跑 git,是真正「動手做事」的 agent。
說明 DOMI 日常兩個都會用到。問我有沒有問題再往下。

【主題 2 — 一步一步設定 Claude Desktop】
帶我完成:
1. 確認 Claude Desktop 是否已安裝(onboarding script 通常已裝好;若沒有,引導我到 https://claude.ai/download 下載)。
2. 開啟 app。
3. 登入 —— ⚠️ 重要:登入帳號 / 授權資訊「請聯絡 Corey」索取。不要自己編造帳號、也不要叫我隨便註冊;若我登入卡關或拿不到權限,明確告訴我「找 Corey」。
4. 登入後帶我看主畫面、怎麼開一個新對話。
每一步等我回報「完成」再繼續。

【主題 3 — 如何 clone 一個 GitHub 專案】
先說明 clone =「把遠端 repo 抓一份完整副本到本機」。教我兩種方式:
A. 用 gh CLI(PowerShell):先 `gh auth status` 確認已登入(沒登入就帶我 `gh auth login`),再:
     cd ~\project; gh repo clone domiearth/foreman
B. 也可以「請 Claude 代勞」:示範我可以直接在 Claude Desktop 或這個 CLI session 裡用自然語言說「幫我把 domiearth/foreman clone 到 ~\project」,讓 agent 自己跑 git。
讓我實際把 foreman clone 成功後再往下。

【主題 4 — git repo / agent / agent workspace 的關係】
用簡單比喻幫我建立心智模型,講清楚三者與彼此的關係:
- git repo:程式碼與歷史的「真實來源」。remote 在 GitHub,clone 下來是 local 副本。
- agent:Claude(Desktop 或 CLI),負責「讀懂 repo、改 code、跑指令」的執行者。
- agent workspace:agent 實際幹活的那個資料夾 / 環境 —— 通常就是你 clone 下來、開 session 的那個 repo 目錄(可能在本機,也可能在 AgentHUB 上)。
重點說明:同一個 repo 可被不同 agent、在不同 workspace 打開;agent 在 workspace 裡的改動,要透過 git commit / push 才會回到 repo 的 remote。並順帶提一句 DOMI 用 hub-relay 把本地 session 接到 AgentHUB 上的 workspace。

【收尾】
總結今天學到的 4 件事,告訴我接下來可做什麼(例如 cd ~\project\foreman; claude 開始第一個真正的 session),並提醒我帳號 / 權限問題一律找 Corey。

═══ 現在從【主題 0】開始。═══
'@

if (Get-Command claude -ErrorAction SilentlyContinue) {
    Write-Host ""
    $startTutorial = Read-Host "  Start a guided Claude session to learn the claude CLI + gh? [Y/n]"
    if ($startTutorial -notmatch '^[nN]$') {
        Info "Launching guided session - follow along, type /exit when done."
        Write-Host ""
        claude $TUTOR_PROMPT
    } else {
        Info "Skipped guided session. Start one anytime with:  cd $DOMI_PROJECT_DIR; claude"
    }
} else {
    Info "claude CLI not on PATH yet - restart PowerShell, then start a session with:"
    Write-Host "    cd $DOMI_PROJECT_DIR; claude"
}
