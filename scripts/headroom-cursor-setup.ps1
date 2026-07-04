# Ensures Headroom proxy is running and prepares Cursor override URLs.
# Run from my-flutter so project prefix /p/my-flutter is correct.

$ErrorActionPreference = "Stop"

$pythonScripts = Join-Path $env:LOCALAPPDATA "Programs\Python\Python313\Scripts"
$pythonRoot = Join-Path $env:LOCALAPPDATA "Programs\Python\Python313"
$env:Path = "$pythonScripts;$pythonRoot;" + $env:Path

$port = 8787
$projectName = Split-Path -Leaf (Get-Location)
$openAiBase = "http://127.0.0.1:$port/p/$projectName/v1"
$anthropicBase = "http://127.0.0.1:$port/p/$projectName"

function Test-HeadroomProxy {
    try {
        $r = Invoke-WebRequest -Uri "http://127.0.0.1:$port/health" -UseBasicParsing -TimeoutSec 3
        return $r.StatusCode -eq 200
    } catch {
        return $false
    }
}

function Start-HeadroomProxy {
    $headroom = Join-Path $pythonScripts "headroom.exe"
    if (-not (Test-Path $headroom)) {
        throw "headroom.exe not found. Run: pip install 'headroom-ai[proxy,mcp]'"
    }
    Start-Process -FilePath $headroom -ArgumentList @("proxy", "--port", "$port") -WindowStyle Hidden
    for ($i = 0; $i -lt 30; $i++) {
        Start-Sleep -Seconds 1
        if (Test-HeadroomProxy) { return }
    }
    throw "Headroom proxy did not become ready on port $port"
}

if (-not (Test-HeadroomProxy)) {
    Write-Host "Starting Headroom proxy on port $port ..."
    Start-HeadroomProxy
    Write-Host "Proxy ready."
} else {
    Write-Host "Headroom proxy already running on port $port."
}

$clip = @"
OpenAI Base URL:    $openAiBase
Anthropic Base URL: $anthropicBase
"@
Set-Clipboard -Value $clip

Write-Host ""
Write-Host "=== Cursor Settings > Models ==="
Write-Host "OpenAI Override Base URL:    $openAiBase"
Write-Host "Anthropic Override Base URL: $anthropicBase"
Write-Host ""
Write-Host "URLs copied to clipboard."

Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.MessageBox]::Show(
    @"
Headroom proxy พร้อมแล้ว

ใน Cursor IDE (ไม่ใช่เว็บ dashboard):
1. กด Ctrl+, แล้วไปที่ Cursor Settings > Models
2. เปิด Override OpenAI Base URL แล้ววาง:
   $openAiBase
3. เปิด Override Anthropic Base URL แล้ววาง:
   $anthropicBase
4. ใส่ API Key ของคุณ (OpenAI / Anthropic)
5. Restart Cursor ถ้าเพิ่งเพิ่ม MCP

URL อยู่ใน clipboard แล้ว
"@,
    "Headroom + Cursor",
    [System.Windows.Forms.MessageBoxButtons]::OK,
    [System.Windows.Forms.MessageBoxIcon]::Information
) | Out-Null
