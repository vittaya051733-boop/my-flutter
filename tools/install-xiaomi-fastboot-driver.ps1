# Run as Administrator (right-click -> Run with PowerShell as Admin)
# Fixes Xiaomi fastboot USB\VID_18D1&PID_D00D driver on Windows

$ErrorActionPreference = 'Stop'
$src = "$env:LOCALAPPDATA\Android\Sdk\extras\google\usb_driver"
$dest = "$env:TEMP\xiaomi-fastboot-driver"

if (-not (Test-Path "$src\android_winusb.inf")) {
    Write-Host "Google USB driver not found. Install via Android SDK Manager first." -ForegroundColor Red
    exit 1
}

New-Item -ItemType Directory -Force -Path $dest | Out-Null
Copy-Item "$src\*" $dest -Recurse -Force

$inf = Join-Path $dest 'android_winusb.inf'
$content = Get-Content $inf -Raw
if ($content -notmatch 'PID_D00D') {
    $content = $content -replace '(?m)^(%CompositeAdbInterface%\s+= USB_Install, USB\\VID_18D1&PID_D001)', "`$1`r`n%SingleBootLoaderInterface% = USB_Install, USB\VID_18D1&PID_D00D"
    Set-Content $inf $content -Encoding ASCII
}

Write-Host "Installing driver from $inf ..."
pnputil /add-driver $inf /install | Out-Host
pnputil /scan-devices | Out-Host

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class DriverHelper {
    [DllImport("newdev.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern bool UpdateDriverForPlugAndPlayDevices(
        IntPtr hwndParent,
        string HardwareId,
        string FullInfPath,
        uint InstallFlags,
        out bool bRebootRequired);
}
"@

$reboot = $false
$ok = [DriverHelper]::UpdateDriverForPlugAndPlayDevices(
    [IntPtr]::Zero,
    'USB\VID_18D1&PID_D00D',
    $inf,
    2,
    [ref]$reboot
)

if ($ok) {
    Write-Host "Driver installed successfully." -ForegroundColor Green
} else {
    Write-Host "Auto-bind failed. Open Device Manager -> Android (warning) -> Update driver -> Browse -> $dest" -ForegroundColor Yellow
}

$fastboot = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\fastboot.exe"
if (Test-Path $fastboot) {
    Write-Host "`nFastboot devices:"
    & $fastboot devices
}
