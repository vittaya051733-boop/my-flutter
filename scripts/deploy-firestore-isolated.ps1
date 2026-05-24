param(
  [string]$ConfirmDeploy,
  [string]$ConfirmFile,
  [string]$ConfirmImpact,
  [switch]$InteractiveConfirm,
  [string]$FinalAcknowledge,
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$importScript = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..\van2\scripts\deploy-governance-import.ps1'))
$canonicalScript = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..\van2\scripts\deploy-firestore-isolated.ps1'))
. $importScript -CallingScriptRoot $PSScriptRoot

$cfg = Get-VanGovernanceConfig
$expectedFile = "van2/$($cfg.FirestoreCanonicalFile)"

Assert-VanDeployConfirmation -App 'van1' -ConfirmDeploy $ConfirmDeploy
Assert-VanFileConfirmation -ConfirmFile $ConfirmFile -ExpectedFile $expectedFile
Assert-VanImpactConfirmation -ConfirmImpact $ConfirmImpact -ExpectedImpact $cfg.FirestoreSharedImpact
Assert-VanFinalAcknowledge -FinalAcknowledge $FinalAcknowledge
Assert-VanAppCanDeploy -App 'van1' -Target 'firestore'
Assert-VanFirestoreRulesSynced -App 'van1'

Write-Host 'van1 delegates shared Firestore deploy to van2 canonical script.' -ForegroundColor Cyan
& $canonicalScript `
  -ConfirmDeploy (Get-VanDeployConfirmToken -App 'van2') `
  -ConfirmFile $cfg.FirestoreCanonicalFile `
  -ConfirmImpact $cfg.FirestoreSharedImpact `
  -FinalAcknowledge $FinalAcknowledge `
  -DryRun:$DryRun
