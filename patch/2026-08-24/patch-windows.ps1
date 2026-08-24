# --------------------------------------------------------------
# DOMI patch 2026-08-24 - Windows (PowerShell 5.1+)
#
# For machines that ALREADY ran an older onboarding (new machines:
# run the full onboard-windows.ps1 instead). Fixes the shared-account
# era leftovers (the exact set Lily hit on 2026-08-24):
#   1. Confirm the gh identity is YOUR OWN account and switch if not
#      (full onboarding skips auth when gh is "already logged in" -
#      it never checks WHO, so this patch has to ask)
#   2. Rewrite the plugin auto-update token (old file may hold a dead
#      shared PAT; the worker prefers the file, so a dead file means
#      auto-update silently fails forever)
#   3. Install the asset plugin (older onboarding did not) + update all
#   4. Re-run hub-setup so ~/.domi-hub.json github_account is YOU
#      (that field is the key for hub-side permissions)
#
# Usage:
#   Set-ExecutionPolicy Bypass -Scope Process -Force
#   .\patch-windows.ps1 [-HubHost X] [-HubHostTailscale Y] [-HubUser Z] [-HubPass W]
#   (hub params optional - hub-setup reuses existing config / defaults)
#
# Idempotent: safe to re-run.
#
# !! KEEP THIS FILE PURE ASCII !!  (PS 5.1 + BOM-less download = ANSI
# codepage; any non-ASCII char corrupts parsing. Same rule as
# onboard-windows.ps1.)
# --------------------------------------------------------------

param(
    [string]$HubHost = "",
    [string]$HubHostTailscale = "",
    [string]$HubUser = "",
    [string]$HubPass = ""
)

$ErrorActionPreference = "Continue"   # gh/git write progress to stderr; gate on $LASTEXITCODE

function Info  { Write-Host "[INFO]  $args" -ForegroundColor Cyan }
function Ok    { Write-Host "[OK]    $args" -ForegroundColor Green }
function Warn  { Write-Host "[WARN]  $args" -ForegroundColor Yellow }
function Fail  { Write-Host "[FAIL]  $args" -ForegroundColor Red; exit 1 }

# -- 0. Prereqs: gh + claude must exist (absent = never onboarded) --
if (-not (Get-Command gh -ErrorAction SilentlyContinue))     { Fail "gh not found - this machine was never onboarded; run the full onboard-windows.ps1" }
if (-not (Get-Command claude -ErrorAction SilentlyContinue)) { Fail "claude not found - this machine was never onboarded; run the full onboard-windows.ps1" }

# -- 1. GitHub identity: confirm it is YOU, switch if not ----------
Info "Step 1/4 - GitHub identity check"
gh auth status 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Info "gh not logged in - log in with YOUR OWN account (GitHub.com -> HTTPS -> web browser)"
    gh auth login
    if ($LASTEXITCODE -ne 0) { Fail "gh login not completed - re-run this patch" }
}

function Get-Login { return (gh api user --jq ".login" 2>$null) }

$login = Get-Login
if (-not $login) { Fail "Cannot read gh identity - check network and re-run" }
Write-Host "  gh is currently logged in as: $login" -ForegroundColor White
$ans = Read-Host "  Is this YOUR OWN GitHub account (not shared / someone else's)? [Y/n]"
if ($ans -match '^[nN]$') {
    Write-Host ""
    gh auth status
    Write-Host ""
    Info "If YOUR account appears in the list above we switch to it; otherwise we log in."
    $myHandle = Read-Host "  Your own GitHub account name (e.g. stacey-you-dotcom)"
    if (-not $myHandle) { Fail "No account entered - re-run this patch" }
    gh auth switch -u $myHandle 2>$null
    if ($LASTEXITCODE -eq 0) {
        Ok "Switched to $myHandle"
    } else {
        Info "Account not in the list - logging in now (browser opens; use YOUR OWN account)"
        gh auth login
        if ($LASTEXITCODE -ne 0) { Fail "gh login not completed - re-run this patch" }
    }
    $login = Get-Login
    Write-Host "  gh is now logged in as: $login" -ForegroundColor White
    $ans2 = Read-Host "  Correct now? [Y/n]"
    if ($ans2 -match '^[nN]$') { Fail "Identity still wrong - ask Corey to take a look together" }
}
gh auth setup-git 2>$null
Ok "GitHub identity: $login"

# Offer to log out other accounts (prevents accidental switch-back later)
$others = @()
(gh auth status 2>&1) | Select-String -Pattern 'account ([A-Za-z0-9-]+)' -AllMatches | ForEach-Object {
    $_.Matches | ForEach-Object { $a = $_.Groups[1].Value; if ($a -ne $login -and $others -notcontains $a) { $others += $a } }
}
foreach ($acct in $others) {
    $ans = Read-Host "  Also logged in: $acct - log it out (recommended)? [y/N]"
    if ($ans -match '^[yY]$') {
        gh auth logout -u $acct 2>$null
        if ($LASTEXITCODE -eq 0) { Ok "Logged out $acct" } else { Warn "Could not log out $acct - do it later: gh auth logout -u $acct" }
    }
}

# -- 2. Rewrite the auto-update token with YOUR token --------------
Info "Step 2/4 - refresh plugin auto-update token"
$auDir = Join-Path $env:USERPROFILE ".claude\.domi-autoupdate"
New-Item -ItemType Directory -Force -Path $auDir | Out-Null
$tokFile = Join-Path $auDir "gh-token"
# Old file may hold a dead shared PAT; the worker prefers the file, so clear first.
Remove-Item -Force -ErrorAction SilentlyContinue $tokFile
$auToken = (gh auth token 2>$null)
if ($auToken) {
    [IO.File]::WriteAllText($tokFile, $auToken)
    icacls $tokFile /inheritance:r /grant:r "$($env:USERNAME):F" 2>$null | Out-Null
    Ok "Rewrote ~\.claude\.domi-autoupdate\gh-token with your own token"
} else {
    Warn "Could not read gh token - old file removed; auto-update falls back to gh credentials (still works)."
}

# -- 3. Plugins: install asset + update everything -----------------
Info "Step 3/4 - update DOMI plugins (install asset)"
$marketplaceList = claude plugin marketplace list 2>&1
if ($marketplaceList -match "domi-claude-plugins") {
    try { claude plugin marketplace update domi-claude-plugins 2>$null } catch {}
} else {
    claude plugin marketplace add https://github.com/domiearth/domi-claude-plugins
}
foreach ($plugin in @("individual-agent", "hub-relay", "domi-guide", "asset")) {
    Info "  Installing / updating $plugin..."
    try { claude plugin install "${plugin}@domi-claude-plugins" 2>$null } catch {}
    try { claude plugin update  "${plugin}@domi-claude-plugins" 2>$null } catch {}
}
Ok "plugins done (individual-agent / hub-relay / domi-guide / asset)"

# -- 4. Hub identity: re-run hub-setup with the right account ------
# After the plugin update, so the NEW hub-setup (0.9.28+ identity guard) runs.
Info "Step 4/4 - fix AgentHUB identity (hub-setup)"
$hubSetup = Get-ChildItem "$env:USERPROFILE\.claude\plugins\cache\domi-claude-plugins\hub-relay\*\scripts\hub-setup.ps1" -ErrorAction SilentlyContinue | Sort-Object FullName | Select-Object -Last 1
if ($hubSetup) {
    Write-Host "  It asks host / user / password - press Enter to keep existing values."
    $hubArgs = @{ GithubAccount = $login }
    if ($HubHost)          { $hubArgs["HubHost"]          = $HubHost }
    if ($HubHostTailscale) { $hubArgs["HubHostTailscale"] = $HubHostTailscale }
    if ($HubUser)          { $hubArgs["HubUser"]          = $HubUser }
    if ($HubPass)          { $hubArgs["HubPass"]          = $HubPass }
    try { & $hubSetup.FullName @hubArgs } catch { Warn "hub-setup did not finish - run later: $($hubSetup.FullName) -GithubAccount $login" }
} else {
    Warn "hub-setup.ps1 not found (hub-relay install failed?) - run /hub setup from a claude session later"
}

# -- Verify + summary ----------------------------------------------
Write-Host ""
Write-Host "------------------------------------------------------" -ForegroundColor White
Ok "DOMI patch 2026-08-24 complete! Verify:"
Write-Host "    gh identity     $(Get-Login)"
$hubAcct = ""
$cfgFile = "$env:USERPROFILE\.domi-hub.json"
if (Test-Path $cfgFile) {
    try { $hubAcct = (Get-Content $cfgFile -Raw | ConvertFrom-Json).github_account } catch {}
}
if ($hubAcct -eq $login) {
    Write-Host "    hub identity    $hubAcct [OK]"
} else {
    Write-Host "    hub identity    '$hubAcct' [X] should be $login - re-run step 4 hub-setup" -ForegroundColor Yellow
}
$hrVer = (Get-ChildItem "$env:USERPROFILE\.claude\plugins\cache\domi-claude-plugins\hub-relay" -ErrorAction SilentlyContinue | Sort-Object Name | Select-Object -Last 1).Name
Write-Host "    hub-relay       $hrVer (want >= 0.9.28)"
$asVer = (Get-ChildItem "$env:USERPROFILE\.claude\plugins\cache\domi-claude-plugins\asset" -ErrorAction SilentlyContinue | Sort-Object Name | Select-Object -Last 1).Name
if ($asVer) { Write-Host "    asset           [OK] $asVer" } else { Write-Host "    asset           [X] install failed - ask Corey" -ForegroundColor Yellow }
Write-Host ""
Write-Host "  Open a NEW claude session for everything to take effect."
Write-Host "  Share results with /asset:knowledge-add, slides with /asset:deck-add."
Write-Host "------------------------------------------------------" -ForegroundColor White
