# --------------------------------------------------------------
# DOMI patch 2026-10-21 - Windows: install jq + python3
#
# For machines that already ran onboarding (new machines get both from the
# full onboard-windows.ps1).
#  1. jq      - the asset plugin (one of the four required) stops with
#               "jq required" on share / deck / task / artifact / log / drive.
#  2. python3 - individual-agent's guard + context hooks, domi-guide's
#               auto-update and asset's artifact hooks run `python3`. Without a
#               real one they silently do nothing (Store placeholder).
# Git Bash picks both up through the Windows PATH.
#
# Idempotent: safe to re-run.
# --------------------------------------------------------------

$ErrorActionPreference = "Stop"
function Info  { Write-Host "[INFO]  $args" -ForegroundColor Cyan }
function Ok    { Write-Host "[OK]    $args" -ForegroundColor Green }
function Warn  { Write-Host "[WARN]  $args" -ForegroundColor Yellow }
function Fail  { Write-Host "[FAIL]  $args" -ForegroundColor Red; exit 1 }
function Refresh-Path {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path", "User")
}

if (-not (Get-Command "winget" -ErrorAction SilentlyContinue)) {
    Fail "winget not found. Install App Installer from Microsoft Store, then re-run."
}

# -- 1. jq ----------------------------------------------------
if (Get-Command "jq" -ErrorAction SilentlyContinue) {
    Ok "jq $(jq --version) already installed"
} else {
    Info "Installing jq via winget..."
    winget install --id jqlang.jq --accept-source-agreements --accept-package-agreements
    Refresh-Path
    if (Get-Command "jq" -ErrorAction SilentlyContinue) { Ok "jq $(jq --version) installed" }
    else { Warn "jq installed but not on PATH yet - close and reopen the terminal, then run: jq --version" }
}

# -- 2. python3 ----------------------------------------------
# individual-agent's hooks (incl. the org-escape guard), domi-guide's
# auto-update worker, asset's artifact hooks and /individual-agent:version all
# run `python3`. Windows has no python3: the name resolves to the Microsoft
# Store placeholder (WindowsApps\python3.exe), which only prints "Python was
# not found" - so those hooks silently do NOTHING (no error surfaces).
# The python.org / winget Python installers do NOT ship python3.exe either
# (only python.exe + py.exe). uv does: `uv python install --default` puts
# python.exe AND python3.exe in %USERPROFILE%\.local\bin (TECH_STACK: Python
# via uv). We then make sure that dir comes BEFORE WindowsApps on the user PATH,
# or the Store placeholder keeps winning.
function Test-RealPython3 {
    $c = Get-Command "python3" -ErrorAction SilentlyContinue
    if (-not $c -or $c.Source -match "WindowsApps") { return $false }
    $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    $v = (& python3 -c "import sys; print(sys.version_info[0])" 2>$null)
    $ok = ($LASTEXITCODE -eq 0 -and "$v".Trim() -eq "3")
    $ErrorActionPreference = $prev
    return $ok
}
function Add-UserPathFront([string]$Dir) {
    $user  = [System.Environment]::GetEnvironmentVariable("Path", "User")
    $parts = @($user -split ';' | Where-Object { $_ -and ($_.TrimEnd('\') -ne $Dir.TrimEnd('\')) })
    [System.Environment]::SetEnvironmentVariable("Path", (@($Dir) + $parts) -join ';', "User")
}

Info "Checking python3..."
if (Test-RealPython3) {
    Ok "python3 already installed ($((Get-Command python3).Source))"
} else {
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"   # uv writes progress to stderr; PS 5.1 + Stop would abort
    if (-not (Get-Command "uv" -ErrorAction SilentlyContinue)) {
        Info "Installing uv (Python manager)..."
        winget install --id astral-sh.uv --accept-source-agreements --accept-package-agreements
        Refresh-Path
    }
    $uvBin = Join-Path $env:USERPROFILE ".local\bin"
    if (Get-Command "uv" -ErrorAction SilentlyContinue) {
        Info "Installing Python 3.12 via uv (with python3.exe)..."
        uv python install 3.12 --default --preview
        Add-UserPathFront $uvBin
        Refresh-Path
    } else {
        Warn "uv not on PATH yet - restart terminal and re-run this script (idempotent)."
    }
    $ErrorActionPreference = $prevEAP
    if (Test-RealPython3) {
        Ok "python3 $(python3 --version) ($((Get-Command python3).Source))"
    } else {
        Warn "python3 still not usable. Plugin guards / auto-update will NOT run until it is."
        Warn "  Fix: close and reopen PowerShell, re-run this script. Still failing -> screenshot to Kirin."
        Warn "  Also: Settings > Apps > Advanced app settings > App execution aliases -> turn OFF python3.exe / python.exe"
    }
}

Write-Host ""
Ok "Done. Open a NEW Claude Code session so the plugins pick up jq / python3."
