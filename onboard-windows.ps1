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
# Each person now OWNS their personal agent repo on THEIR OWN GitHub account as
# agent-self-<handle> (was: a shared domiearth/agent-<handle> org repo we cloned).
# Keeps personal drawers off the org (cost + clear ownership). One-time migration:
# if a legacy domiearth/agent-<handle> (or a local clone) exists, copy its data
# into the new repo and commit + push. individual-agent plugin governs it.
Info "Setting up your personal agent repo (on your own GitHub account)..."
$ghHandle   = (gh api user --jq ".login" 2>$null)
$newRepo    = "agent-self-$ghHandle"
$newDir     = "$DOMI_PROJECT_DIR\$newRepo"
$legacyRepo = "agent-$ghHandle"
$legacyDir  = "$DOMI_PROJECT_DIR\$legacyRepo"
if (-not $ghHandle) {
    Warn "Could not read your GitHub handle - skipping. Create later: gh repo create <your-handle>/agent-self-<your-handle> --private"
} elseif (Test-Path "$newDir\.git") {
    Ok "$newRepo already set up"
} else {
    gh repo view "$ghHandle/$newRepo" 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        # Already created on a previous run / another machine - just clone it.
        gh repo clone "$ghHandle/$newRepo" "$newDir"
        if ($LASTEXITCODE -eq 0) { Ok "cloned $newRepo - your personal workspace" }
        else { Warn "clone failed - retry later: gh repo clone $ghHandle/$newRepo" }
    } else {
        # Create fresh under YOUR account, migrating legacy data if any exists.
        New-Item -ItemType Directory -Force -Path $newDir | Out-Null
        Push-Location $newDir; git init -q; Pop-Location
        $migSrc = ""
        if (Test-Path "$legacyDir\.git") {
            $migSrc = $legacyDir
        } else {
            gh repo view "domiearth/$legacyRepo" 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Info "Found legacy domiearth/$legacyRepo - migrating its data..."
                $migSrc = Join-Path ([System.IO.Path]::GetTempPath()) $legacyRepo
                if (Test-Path $migSrc) { Remove-Item -Recurse -Force $migSrc }
                gh repo clone "domiearth/$legacyRepo" "$migSrc" 2>$null | Out-Null
                if ($LASTEXITCODE -ne 0) { $migSrc = "" }
            }
        }
        if ($migSrc -ne "") {
            # robocopy returns 0-7 on success; ignore its exit code. /XD skips the source .git.
            robocopy "$migSrc" "$newDir" /E /XD "$migSrc\.git" | Out-Null
            Info "Migrated data from $legacyRepo."
        }
        Push-Location $newDir
        git add -A
        if (-not (git diff --cached --name-only)) {
            "# $newRepo`r`n`r`nDOMI personal agent drawer - notes / reports / drafts. Owner-only." | Out-File -Encoding utf8 README.md
            git add README.md
        }
        $msg = "init $newRepo"
        if ($migSrc -ne "") { $msg = "init $newRepo (migrated from $legacyRepo)" }
        git commit -q -m $msg
        git branch -M main
        gh repo create "$ghHandle/$newRepo" --private --source=. --remote=origin --push -d "DOMI personal agent drawer ($ghHandle)"
        if ($LASTEXITCODE -eq 0) { Ok "created + pushed $newRepo" }
        else { Warn "create/push failed - finish later: cd $newDir; gh repo create $ghHandle/$newRepo --private --source=. --remote=origin --push" }
        Pop-Location
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
if ($ghHandle -and (Test-Path "$newDir\.git")) {
    Write-Host "    2. Your personal workspace: cd $newDir; claude"
} else {
    Write-Host "    2. Create your personal repo: gh repo create <your-handle>/agent-self-<your-handle> --private"
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
if ($ghHandle -and (Test-Path "$newDir\.git")) {
    $tutorDir = "$newDir"   # start in your personal repo
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
