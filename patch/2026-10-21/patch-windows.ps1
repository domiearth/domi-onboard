# --------------------------------------------------------------
# DOMI patch 2026-10-21 - Windows: install jq
#
# For machines that already ran onboarding (new machines get jq from the
# full onboard-windows.ps1). The asset plugin (one of the four required)
# stops with "jq required" on share / deck / task / artifact / log / drive
# without it. Git Bash picks up jq.exe through the Windows PATH.
#
# Idempotent: safe to re-run.
# --------------------------------------------------------------

function Info  { Write-Host "[INFO]  $args" -ForegroundColor Cyan }
function Ok    { Write-Host "[OK]    $args" -ForegroundColor Green }
function Fail  { Write-Host "[FAIL]  $args" -ForegroundColor Red; exit 1 }

if (Get-Command "jq" -ErrorAction SilentlyContinue) {
    Ok "jq $(jq --version) already installed - nothing to do"
    exit 0
}
if (-not (Get-Command "winget" -ErrorAction SilentlyContinue)) {
    Fail "winget not found. Install App Installer from Microsoft Store, then re-run."
}

Info "Installing jq via winget..."
winget install --id jqlang.jq --accept-source-agreements --accept-package-agreements
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
            [System.Environment]::GetEnvironmentVariable("Path", "User")

if (Get-Command "jq" -ErrorAction SilentlyContinue) {
    Ok "jq $(jq --version) installed. Open a new Claude Code session to use asset."
} else {
    Fail "jq installed but not on PATH yet - close and reopen the terminal, then run: jq --version"
}
