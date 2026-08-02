[CmdletBinding()]
param(
    [int]$Port = 8060,
    [switch]$SkipExport,
    [string]$GodotPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path $PSScriptRoot -Parent
$webRoot = Join-Path $repoRoot "build\web"
if (-not $SkipExport) {
    & (Join-Path $PSScriptRoot "export.ps1") -Target web -GodotPath $GodotPath
}

$serverArguments = @{
    FilePath = "powershell"
    ArgumentList = @(
        "-ExecutionPolicy", "Bypass",
        "-File", (Join-Path $PSScriptRoot "serve-web.ps1"),
        "-Port", $Port,
        "-RootPath", $webRoot
    )
    WindowStyle = "Hidden"
    PassThru = $true
}
$server = Start-Process @serverArguments

try {
    $baseUri = "http://127.0.0.1:$Port"
    $ready = $false
    for ($attempt = 0; $attempt -lt 40; $attempt++) {
        try {
            $null = Invoke-WebRequest -UseBasicParsing -Uri "$baseUri/index.html" -TimeoutSec 2
            $ready = $true
            break
        }
        catch {
            Start-Sleep -Milliseconds 150
        }
    }
    if (-not $ready) {
        throw "Local Numblop Web server did not become ready."
    }

    $expectations = @(
        @{ Path = "index.html"; Type = "text/html" },
        @{ Path = "index.js"; Type = "text/javascript" },
        @{ Path = "index.wasm"; Type = "application/wasm" },
        @{ Path = "index.pck"; Type = "application/octet-stream" }
    )
    foreach ($expectation in $expectations) {
        $requestArguments = @{
            UseBasicParsing = $true
            Uri = "$baseUri/$($expectation.Path)"
            Method = "Head"
            TimeoutSec = 10
        }
        $response = Invoke-WebRequest @requestArguments
        if ($response.StatusCode -ne 200) {
            throw "$($expectation.Path) returned HTTP $($response.StatusCode)."
        }
        if ($response.Headers["Content-Type"] -notlike "$($expectation.Type)*") {
            throw "$($expectation.Path) returned the wrong Content-Type."
        }
        Write-Host "OK $($expectation.Path) $($response.Headers['Content-Type'])"
    }
}
finally {
    if (-not $server.HasExited) {
        Stop-Process -Id $server.Id
        $server.WaitForExit()
    }
    $server.Dispose()
}

Write-Host "NUMBLOP_WEB_HTTP_SMOKE_OK"
