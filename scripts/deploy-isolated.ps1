param(
  [switch]$FunctionsOnly,
  [switch]$HostingOnly,
  [switch]$BuildWeb,
  [string[]]$FunctionName
)

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$appRoot = Split-Path -Parent $scriptRoot
Set-Location $appRoot

$expectedProjectId = 'van-merchant'
$functionsCodebase = 'van1'
$hostingTarget = 'van1'
$firestoreScript = Join-Path $scriptRoot 'deploy-firestore-isolated.ps1'
$storageScript = Join-Path $scriptRoot 'deploy-storage-isolated.ps1'

if (-not (Get-Command firebase -ErrorAction SilentlyContinue)) {
  Write-Error 'Firebase CLI was not found in PATH.'
  exit 1
}

if (-not (Test-Path '.firebaserc') -or -not (Test-Path 'firebase.json')) {
  Write-Error 'Missing .firebaserc or firebase.json.'
  exit 1
}

$rc = Get-Content '.firebaserc' -Raw | ConvertFrom-Json
$projectId = $rc.projects.default
if ($projectId -ne $expectedProjectId) {
  Write-Error "Configured project '$projectId' does not match expected '$expectedProjectId'."
  exit 1
}

$config = Get-Content 'firebase.json' -Raw | ConvertFrom-Json
$targets = @()

if ($FunctionsOnly -and -not $HostingOnly) {
  if (-not $FunctionName -or $FunctionName.Count -eq 0) {
    Write-Error "Functions deploy is locked to explicit function names. Use: scripts/deploy-isolated.ps1 -FunctionsOnly -FunctionName verifyTopUpSlip"
    exit 1
  }

  foreach ($name in $FunctionName) {
    $cleanName = [string]$name
    $cleanName = $cleanName.Trim()
    if (-not $cleanName) {
      continue
    }
    if ($cleanName -notmatch '^[A-Za-z0-9_-]+$') {
      Write-Error "Invalid function name '$cleanName'."
      exit 1
    }
    $targets += "functions:${functionsCodebase}:${cleanName}"
  }

  if ($targets.Count -eq 0) {
    Write-Error 'No valid function names were provided.'
    exit 1
  }

  $env:FUNCTIONS_DISCOVERY_TIMEOUT = '30000'
} elseif ($HostingOnly -and -not $FunctionsOnly) {
  $targets += "hosting:$hostingTarget"
} else {
  $targets += "hosting:$hostingTarget"
}

if (-not $FunctionsOnly -and -not $HostingOnly) {
  if (-not (Test-Path $firestoreScript)) {
    Write-Error "Missing deploy script: $firestoreScript"
    exit 1
  }
  if (-not (Test-Path $storageScript)) {
    Write-Error "Missing deploy script: $storageScript"
    exit 1
  }

  Write-Host 'Deploying isolated Firestore rules first...' -ForegroundColor DarkCyan
  & powershell -ExecutionPolicy Bypass -File $firestoreScript

  Write-Host 'Deploying isolated Storage rules next...' -ForegroundColor DarkCyan
  & powershell -ExecutionPolicy Bypass -File $storageScript

  Write-Host 'Routine isolated deploy excludes functions. Use -FunctionsOnly when you need to deploy the van1 codebase explicitly.' -ForegroundColor DarkYellow
}

if ($targets -contains "hosting:$hostingTarget") {
  $hostingMap = $rc.targets.$expectedProjectId.hosting.$hostingTarget
  if (-not $hostingMap -or $hostingMap.Count -eq 0) {
    Write-Error "Hosting target '$hostingTarget' is not mapped. Run: firebase target:apply hosting $hostingTarget <SITE_ID> --project $expectedProjectId"
    exit 1
  }
  if ($BuildWeb) {
    flutter build web
  }
}

Write-Host "Deploying isolated targets: $($targets -join ', ')" -ForegroundColor Cyan
firebase deploy --project $expectedProjectId --only ($targets -join ',')
