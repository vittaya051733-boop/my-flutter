param(
  [string]$ConfirmDeploy,
  [string]$ConfirmFile,
  [string]$ConfirmImpact,
  [switch]$InteractiveConfirm,
  [string]$FinalAcknowledge,
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'deploy-governance-import.ps1') -CallingScriptRoot $PSScriptRoot
Invoke-VanStorageRulesDeploy -App 'van1' -ConfirmDeploy $ConfirmDeploy -ConfirmFile $ConfirmFile -ConfirmImpact $ConfirmImpact -FinalAcknowledge $FinalAcknowledge -InteractiveConfirm:$InteractiveConfirm -DryRun:$DryRun
