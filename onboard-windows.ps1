# --------------------------------------------------------------
# DOMI onboarding - Windows (PowerShell 5.1+)
# Usage: Run as Administrator
#   Set-ExecutionPolicy Bypass -Scope Process -Force
#   .\onboard-windows.ps1
#
# !! KEEP THIS FILE PURE ASCII !!  Windows PowerShell 5.1 reads a BOM-less
# download (what `irm -OutFile` produces) as the system ANSI codepage, so any
# non-ASCII char (Chinese, emoji, box-drawing) corrupts string parsing and the
# script won't even load. All localized text lives in TUTOR_PLAYBOOK.md and is
# fetched at runtime, never parsed by PowerShell.
# --------------------------------------------------------------

$ErrorActionPreference = "Stop"

$DOMI_PROJECT_DIR = "$env:USERPROFILE\project"

# -- helpers --------------------------------------------------

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

# -- 0. Check winget ------------------------------------------

Info "Checking winget..."
if (-not (Test-Command "winget")) {
    Fail "winget not found. Please install App Installer from Microsoft Store first."
}

# -- 1. Git ---------------------------------------------------

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

# -- 2. GitHub CLI --------------------------------------------

Info "Checking GitHub CLI..."
if (-not (Test-Command "gh")) {
    Info "Installing GitHub CLI..."
    winget install --id GitHub.cli --accept-source-agreements --accept-package-agreements
    Refresh-Path
}
if (Test-Command "gh") {
    Ok "gh $(gh --version | Select-Object -First 1)"
}

# -- 3. Node.js -----------------------------------------------

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

# -- 4. Claude Code CLI --------------------------------------

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

# -- 4b. Scoop + sshpass (required by hub-relay) -------------

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

# -- 5. Claude Desktop ---------------------------------------

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

# -- 6. GitHub authentication --------------------------------

Info "Checking GitHub auth..."
$authStatus = gh auth status 2>&1
if ($LASTEXITCODE -eq 0) {
    Ok "Already authenticated to GitHub"
} else {
    Info "Please authenticate with GitHub..."
    gh auth login
}

# -- 7. Project directory ------------------------------------

Info "Setting up project directory: $DOMI_PROJECT_DIR"
New-Item -ItemType Directory -Force -Path $DOMI_PROJECT_DIR | Out-Null

# -- 8. claude-workbench (optional) --------------------------

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

# -- 9. domi-claude-plugins (required, via marketplace) -----

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

# -- 9b. AgentHUB connection setup ---------------------------

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

# -- 10. Summary ---------------------------------------------

Write-Host ""
Write-Host "------------------------------------------------------" -ForegroundColor White
Ok "DOMI onboarding complete!"
Write-Host ""
Write-Host "  Installed:"
try { Write-Host "    git          $(git --version)" } catch { Write-Host "    git          (restart terminal)" }
try { Write-Host "    gh           $(gh --version | Select-Object -First 1)" } catch { Write-Host "    gh           (restart terminal)" }
try { Write-Host "    node         $(node --version)" } catch { Write-Host "    node         (restart terminal)" }
try { Write-Host "    claude CLI   installed" } catch { Write-Host "    claude CLI   (restart terminal)" }
Write-Host ""
Write-Host "  Plugins (via domi-claude-plugins marketplace):"
Write-Host "    stack-guard    [OK]  TECH_STACK.md enforcement"
Write-Host "    entity-guard   [OK]  Local vs Global/MT-DAO boundary"
Write-Host "    domi-init      [OK]  repo bootstrap with CLAUDE.md templates"
Write-Host "    schema-change  [OK]  datahouse cross-repo coordination"
Write-Host "    hub-relay      [OK]  SSH bridge to AgentHUB"
if ($installWB -match '^[yY]$') {
    Write-Host "    claude-workbench     [OK] (mentor, kanban, chat)"
}
Write-Host ""
Write-Host "  Next steps:"
Write-Host "    1. Open Claude Desktop and sign in"
Write-Host "    2. Run: cd $DOMI_PROJECT_DIR; gh repo clone domiearth/foreman"
Write-Host "    3. Run: cd foreman; claude   # start your first session"
Write-Host "    4. (If skipped above) run hub-setup.ps1 to configure AgentHUB later"
Write-Host "------------------------------------------------------" -ForegroundColor White

Write-Host ""
Warn "If any tools show 'restart terminal', close and reopen PowerShell, then verify with:"
Write-Host "    git --version && gh --version && node --version && claude --version"

# -- 11. Guided first session (optional) ---------------------
# Hand off into a live Claude Code session that tutors the new hire through
# the claude CLI and gh (clone a project), one step at a time. Skipped if the
# claude CLI isn't on PATH yet (needs a terminal restart after install).

# Load the tutor playbook: prefer a copy next to this script (clone / offline),
# else fetch the published copy, else fall back to a short inline prompt.
$DOMI_PLAYBOOK_URL = "https://raw.githubusercontent.com/domiearth/domi-onboard/main/TUTOR_PLAYBOOK.md"
$TUTOR_PROMPT = $null
if ($PSScriptRoot) {
    $localPlaybook = Join-Path $PSScriptRoot "TUTOR_PLAYBOOK.md"
    if (Test-Path $localPlaybook) { $TUTOR_PROMPT = Get-Content -Raw -Encoding UTF8 $localPlaybook }
}
if (-not $TUTOR_PROMPT) {
    try { $TUTOR_PROMPT = Invoke-RestMethod -Uri $DOMI_PLAYBOOK_URL } catch {}
}
if (-not $TUTOR_PROMPT -or -not $TUTOR_PROMPT.Trim()) {
    # ASCII-only fallback (this file must stay ASCII for Windows PowerShell 5.1,
    # which reads BOM-less downloads as the system ANSI codepage). The real
    # Traditional-Chinese playbook is fetched from TUTOR_PLAYBOOK.md above.
    $TUTOR_PROMPT = "You are the DOMI new-hire onboarding tutor. Teach me in Traditional Chinese, one step at a time (wait for my reply before continuing): (1) Claude Desktop vs the Claude Code CLI; (2) setting up Claude Desktop -- for login credentials tell me to contact Corey; (3) cloning domiearth/foreman with gh into my project folder; (4) the relationship between a git repo, an agent, and an agent workspace."
}

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
