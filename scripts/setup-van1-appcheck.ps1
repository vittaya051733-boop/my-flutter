# Register van1 App Check debug token + print Play Integrity setup checklist.
# SHA-1/SHA-256 for upload keystore should already be in Firebase project settings.
param(
  [string]$ProjectNumber = '802503541368',
  [string]$Van1AppId = '1:802503541368:android:c8333c4310663e19f6a38d',
  [string]$DebugToken = 'd1a5b8e3-7f2c-4a6d-9e1b-3c4d5e6f7a82'
)

$ErrorActionPreference = 'Stop'

function Get-GcloudAccessToken {
  $token = & gcloud auth print-access-token 2>$null
  if (-not $token) {
    throw 'gcloud auth print-access-token failed — run: gcloud auth login'
  }
  return $token.Trim()
}

Write-Host ''
Write-Host '=== van1 App Check setup (van.merchant) ===' -ForegroundColor Cyan
Write-Host "Project: van-merchant ($ProjectNumber)" -ForegroundColor Gray
Write-Host "App ID:  $Van1AppId" -ForegroundColor Gray
Write-Host ''

# Register debug token for dev/emulator builds.
$token = Get-GcloudAccessToken
$body = @{
  displayName = 'van1-dev-pinned'
  token       = $DebugToken
} | ConvertTo-Json

$uri = "https://firebaseappcheck.googleapis.com/v1/projects/$ProjectNumber/apps/$Van1AppId/debugTokens"
try {
  $response = Invoke-RestMethod -Method Post -Uri $uri -Headers @{
    Authorization = "Bearer $token"
    'Content-Type'  = 'application/json'
  } -Body $body
  Write-Host '[OK] Debug token registered for van.merchant' -ForegroundColor Green
  if ($response.name) {
    Write-Host "     Resource: $($response.name)" -ForegroundColor DarkGray
  }
} catch {
  $status = $_.Exception.Response.StatusCode.value__
  $detail = $_.ErrorDetails.Message
  if ($status -eq 409 -or ($detail -match 'ALREADY_EXISTS|already exists')) {
    Write-Host '[OK] Debug token already registered' -ForegroundColor Green
  } else {
    Write-Host "[WARN] Debug token registration failed ($status)" -ForegroundColor Yellow
    if ($detail) { Write-Host $detail -ForegroundColor DarkYellow }
    Write-Host 'Manual: Firebase Console → App Check → van.merchant → Manage debug tokens' -ForegroundColor Yellow
    Write-Host "Token: $DebugToken" -ForegroundColor Gray
  }
}

Write-Host ''
Write-Host 'Play Integrity (release APK):' -ForegroundColor Cyan
Write-Host '1. Firebase Console → App Check → Apps → van.merchant (Android)' -ForegroundColor White
Write-Host '2. Register provider: Play Integrity (if not already enabled)' -ForegroundColor White
Write-Host '3. Upload keystore SHA-256 should be registered (via firebase_create_android_sha)' -ForegroundColor White
Write-Host '4. Optional: enforce App Check on Functions/Firestore after smoke test' -ForegroundColor White
Write-Host ''
Write-Host 'Console: https://console.firebase.google.com/project/van-merchant/appcheck/apps' -ForegroundColor DarkGray
Write-Host ''
