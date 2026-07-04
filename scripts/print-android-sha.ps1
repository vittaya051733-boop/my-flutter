# แสดง SHA-1 / SHA-256 สำหรับลงทะเบียน Firebase (van.merchant)
# ใช้เมื่อ Phone Auth แจ้ง app-not-authorized

$keystore = Join-Path $env:USERPROFILE '.android\debug.keystore'
if (-not (Test-Path $keystore)) {
  Write-Error "ไม่พบ debug.keystore ที่ $keystore"
  exit 1
}

Write-Host "=== Debug keystore (flutter run / debug build) ===" -ForegroundColor Cyan
keytool -list -v -keystore $keystore -alias androiddebugkey -storepass android -keypass android |
  Select-String -Pattern 'SHA1:|SHA256:'

Write-Host ""
Write-Host "Firebase Console -> Project settings -> van.merchant (Android)" -ForegroundColor Yellow
Write-Host "เพิ่ม SHA-1 และ SHA-256 ด้านบน แล้ว rebuild แอป" -ForegroundColor Yellow
Write-Host ""
Write-Host "หากติดตั้งจาก OTA APK ที่ build บนเครื่องอื่น ต้องเพิ่ม SHA ของ keystore นั้นด้วย" -ForegroundColor Yellow
