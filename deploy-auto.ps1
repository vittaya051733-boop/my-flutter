param(
  [switch]$IncludeApp,
  [switch]$ForceLegacy
)

$ErrorActionPreference = 'Stop'

Write-Host ''
Write-Host 'BLOCKED: deploy-auto.ps1 — combined deploy breaks van3 rider connections.' -ForegroundColor Red
Write-Host ''
Write-Host 'Use: ..\..\..\van2\scripts\deploy-self.ps1 -App van1 -Target storage ...' -ForegroundColor Yellow
Write-Host 'Read: Desktop\van2\scripts\DEPLOY_GOVERNANCE.md + DEPLOY_RISK_MATRIX.md' -ForegroundColor Cyan
Write-Host ''

if (-not $ForceLegacy) { exit 1 }

Write-Warning 'ForceLegacy — deprecated combined deploy.'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root
powershell -ExecutionPolicy Bypass -File 'scripts/deploy-firestore-isolated.ps1'
powershell -ExecutionPolicy Bypass -File 'scripts/deploy-storage-isolated.ps1'
if ($IncludeApp) { powershell -ExecutionPolicy Bypass -File 'scripts/deploy-isolated.ps1' }
