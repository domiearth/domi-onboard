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

# -- 7b. Personal agent repo (your "drawer") -----------------
# gh is installed + authenticated by now, so clone the person's own
# agent-<handle> repo first - their home base (notes / reports / drafts;
# individual-agent plugin governs it). Cross-repo work goes via /hub run.
Info "Cloning your personal agent repo..."
$ghHandle = (gh api user --jq ".login" 2>$null)
if (-not $ghHandle) {
    Warn "Could not read your GitHub handle - skipping. Clone later: gh repo clone domiearth/agent-<your-handle>"
} elseif (Test-Path "$DOMI_PROJECT_DIR\agent-$ghHandle\.git") {
    Ok "agent-$ghHandle already cloned"
} else {
    gh repo view "domiearth/agent-$ghHandle" 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        gh repo clone "domiearth/agent-$ghHandle" "$DOMI_PROJECT_DIR\agent-$ghHandle"
        if ($LASTEXITCODE -eq 0) { Ok "cloned agent-$ghHandle - your personal workspace" }
        else { Warn "clone failed - retry later: gh repo clone domiearth/agent-$ghHandle" }
    } else {
        Warn "Personal agent repo domiearth/agent-$ghHandle not found yet. Ask Corey (domi-init); you can still work via /hub run."
    }
}

# -- 8. claude-workbench (optional) --------------------------

Write-Host ""
Info "claude-workbench - Kirin's productivity plugins (mentor, kanban, chat)"
$installWB = Read-Host "  Install claude-workbench? [y/N]"

if ($installWB -match '^[yY]$') {
    Info "Registering claude-workbench marketplace..."
    $wbMarketList = claude plugin marketplace list 2>&1
    if ($wbMarketList -match "claude-workbench") {
        Ok "claude-workbench marketplace already registered"
        # Re-run = update: refresh marketplace so newer plugin versions are visible.
        try { claude plugin marketplace update claude-workbench 2>$null } catch {}
    } else {
        claude plugin marketplace add https://github.com/kirinchen/claude-workbench
        Ok "claude-workbench marketplace registered"
    }

    Info "Installing / updating workbench plugins (mentor, kanban, chat)..."
    foreach ($plugin in @("mentor", "kanban", "chat")) {
        Info "  Installing / updating $plugin..."
        # install = no-op if present; update = bump an already-installed plugin to latest.
        try { claude plugin install "${plugin}@claude-workbench" 2>$null } catch {}
        try { claude plugin update  "${plugin}@claude-workbench" 2>$null } catch {}
    }
    Ok "claude-workbench done"
} else {
    Info "Skipping claude-workbench"
}

# -- 9. domi-claude-plugins (required, via marketplace) -----

Write-Host ""
Info "domi-claude-plugins - personal-machine plugins (REQUIRED)"
Info "Registering DOMI marketplace (private - requires domiearth org access)..."

$marketplaceList = claude plugin marketplace list 2>&1
if ($marketplaceList -match "domi-claude-plugins") {
    Ok "DOMI marketplace already registered"
    # Re-run = update: refresh marketplace so newer plugin versions are visible.
    try { claude plugin marketplace update domi-claude-plugins 2>$null } catch {}
} else {
    claude plugin marketplace add https://github.com/domiearth/domi-claude-plugins
    Ok "DOMI marketplace registered"
}

# Personal machines install ONLY these three. The governance guards
# (stack-guard / entity-guard / schema-change / project-protect / domi-init)
# run on the AgentHUB, not here - cross-repo work goes through hub-relay and the
# hub enforces them server-side. See domi-claude-plugins README (install matrix)
# + GO_LIVE_CHECKLIST.md section 1.
Info "Installing / updating DOMI plugins from marketplace..."
foreach ($plugin in @("individual-agent", "hub-relay", "domi-guide")) {
    Info "  Installing / updating $plugin..."
    # install = no-op if present; update = bump an already-installed plugin to latest.
    try { claude plugin install "${plugin}@domi-claude-plugins" 2>$null } catch {}
    try { claude plugin update  "${plugin}@domi-claude-plugins" 2>$null } catch {}
}
Ok "domi-claude-plugins done"

# -- 9b. AgentHUB connection setup (delegates to hub-relay's hub-setup.ps1) --
# Single source of truth: hub-setup.ps1 handles host/user/password + your GitHub
# account, dual-host (LAN/Tailscale) failover, and SSH_ASKPASS auth - no sshpass
# dependency here.
Write-Host ""
Info "AgentHUB connection setup"
$hubSetup = Get-ChildItem "$env:USERPROFILE\.claude\plugins\cache\domi-claude-plugins\hub-relay\*\scripts\hub-setup.ps1" -ErrorAction SilentlyContinue | Sort-Object FullName | Select-Object -Last 1
if ($hubSetup) {
    Info "Launching hub-setup (host / user / password / your GitHub account)..."
    Write-Host "  Don't have the hub host/creds yet? Press Enter through to skip - run it later."
    try { & $hubSetup.FullName } catch { Warn "hub-setup skipped/failed - run later: $($hubSetup.FullName)" }
} else {
    Warn "hub-relay hub-setup.ps1 not found (plugin install may have failed)."
    Warn "  Configure later from any Claude session with: /hub setup"
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
Write-Host "  Plugins (personal machine, via domi-claude-plugins marketplace):"
Write-Host "    individual-agent [OK]  your personal repo behaviour + /note"
Write-Host "    hub-relay        [OK]  /hub - work on hub-side project agents"
Write-Host "    domi-guide       [OK]  /guide interactive tutorial"
if ($installWB -match '^[yY]$') {
    Write-Host "    claude-workbench     [OK] (mentor, kanban, chat)"
}
Write-Host ""
Write-Host "  Next steps:"
Write-Host "    1. Open Claude Desktop and sign in (account from Corey)"
if ($ghHandle -and (Test-Path "$DOMI_PROJECT_DIR\agent-$ghHandle\.git")) {
    Write-Host "    2. Your personal workspace: cd $DOMI_PROJECT_DIR\agent-$ghHandle; claude"
} else {
    Write-Host "    2. Clone your personal repo: gh repo clone domiearth/agent-<your-handle>"
}
Write-Host "    3. New here? The guided tour starts next - or type /guide anytime."
Write-Host "    4. (If skipped above) run /hub setup to configure AgentHUB later"
Write-Host "------------------------------------------------------" -ForegroundColor White

Write-Host ""
Warn "If any tools show 'restart terminal', close and reopen PowerShell, then verify with:"
Write-Host "    git --version && gh --version && node --version && claude --version"

# -- 11. Guided first session (optional) ---------------------
# Auto-start: seed a NATURAL-LANGUAGE prompt (first char != /) that asks Claude
# to run /domi-guide:guide all itself, so the tutor greets the user proactively.
# A startup prompt starting with / parses as a command (hangs on some setups);
# plain text is a normal message Claude then acts on. Prompt is ASCII (this file
# must stay ASCII) but instructs Claude to reply in Traditional Chinese.
$tutorDir = $DOMI_PROJECT_DIR
if ($ghHandle -and (Test-Path "$DOMI_PROJECT_DIR\agent-$ghHandle\.git")) {
    $tutorDir = "$DOMI_PROJECT_DIR\agent-$ghHandle"   # start in your personal repo
}
$tutorPrompt = "Please run the /domi-guide:guide all command to start the DOMI new-hire tutorial. Reply in Traditional Chinese throughout; first introduce yourself, list all topics, ask if I'm ready, then wait for my reply. If the command is not found, tell me the domi-guide plugin failed to install and to contact Corey."

if (Get-Command claude -ErrorAction SilentlyContinue) {
    Write-Host ""
    $startTutorial = Read-Host "  Start the guided tutorial now? [Y/n]"
    if ($startTutorial -notmatch '^[nN]$') {
        Info "Launching tutorial - the tutor greets you. /exit to leave; later: /guide to resume."
        Write-Host ""
        Set-Location $tutorDir
        claude "$tutorPrompt"
    } else {
        Info "Skipped. Start anytime: open a claude session and type  /guide"
    }
} else {
    Info "claude CLI not on PATH yet - restart PowerShell, then: cd $DOMI_PROJECT_DIR; claude"
}
