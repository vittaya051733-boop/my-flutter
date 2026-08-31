#Requires -RunAsAdministrator
$ErrorActionPreference = 'Continue'

$src  = "$env:LOCALAPPDATA\Android\Sdk\extras\google\usb_driver"
$dest = "$env:TEMP\xiaomi-fastboot-driver"
$inf  = Join-Path $dest 'android_winusb.inf'
$hwid = 'USB\VID_18D1&PID_D00D'
$instance = 'USB\VID_18D1&PID_D00D\86766A72'
$fastboot = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\fastboot.exe"

Write-Host '=== Xiaomi Fastboot Driver Install ===' -ForegroundColor Cyan

if (-not (Test-Path "$src\android_winusb.inf")) {
    Write-Host 'Missing Google USB driver. Run: sdkmanager "extras;google;usb_driver"' -ForegroundColor Red
    exit 1
}

New-Item -ItemType Directory -Force -Path $dest | Out-Null
Copy-Item "$src\*" $dest -Recurse -Force

$content = Get-Content $inf -Raw
if ($content -notmatch 'PID_D00D') {
    $content = $content -replace '(?m)^(%CompositeAdbInterface%\s+= USB_Install, USB\\VID_18D1&PID_D001)', "`$1`r`n%SingleBootLoaderInterface% = USB_Install, USB\VID_18D1&PID_D00D"
    Set-Content $inf $content -Encoding ASCII
    Write-Host 'Patched inf for PID_D00D' -ForegroundColor Yellow
}

Write-Host 'Step 1: Add driver package...'
pnputil /add-driver $inf /install

Write-Host 'Step 2: Remove stale binding (replug USB after if needed)...'
pnputil /remove-device $instance 2>$null
Start-Sleep -Seconds 2

Write-Host 'Step 3: Bind driver to hardware ID...'
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class DriverHelper {
    [DllImport("newdev.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern bool UpdateDriverForPlugAndPlayDevices(
        IntPtr hwndParent, string HardwareId, string FullInfPath,
        uint InstallFlags, out bool bRebootRequired);
}
"@
$reboot = $false
$ok = [DriverHelper]::UpdateDriverForPlugAndPlayDevices([IntPtr]::Zero, $hwid, $inf, 2, [ref]$reboot)
Write-Host "UpdateDriverForPlugAndPlayDevices: $ok (reboot=$reboot)"

Write-Host 'Step 4: Rescan + enable...'
pnputil /scan-devices
Start-Sleep -Seconds 2
Enable-PnpDevice -InstanceId $instance -Confirm:$false -ErrorAction SilentlyContinue

Write-Host 'Step 5: Device status'
Get-PnpDevice -ErrorAction SilentlyContinue | Where-Object { $_.InstanceId -match '18D1' } |
    Format-Table FriendlyName, Status, Class -AutoSize
pnputil /enum-devices /instanceid $instance 2>$null

if (Test-Path $fastboot) {
    Write-Host 'Step 6: fastboot devices'
    & $fastboot devices
}

Write-Host '=== Done ===' -ForegroundColor Green
Read-Host 'Press Enter to close'
