$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$canonicalScript = Join-Path $scriptRoot '..\..\..\van2\scripts\deploy-firestore-isolated.ps1'
$canonicalScript = [System.IO.Path]::GetFullPath($canonicalScript)

if (-not (Test-Path $canonicalScript)) {
  Write-Error "Missing canonical Firestore deploy script: $canonicalScript"
  exit 1
}

Write-Host 'Firestore rules are shared by van1/van2/van3 on the default database.' -ForegroundColor DarkYellow
Write-Host 'Delegating to the canonical van2 Firestore rules deploy script to avoid overwriting rules with an app-specific copy.' -ForegroundColor Cyan
& powershell -ExecutionPolicy Bypass -File $canonicalScript
