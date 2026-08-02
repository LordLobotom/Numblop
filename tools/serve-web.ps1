[CmdletBinding()]
param(
    [int]$Port = 8060,
    [string]$RootPath = "",
    [switch]$Open
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path $PSScriptRoot -Parent
if ([string]::IsNullOrWhiteSpace($RootPath)) {
    $RootPath = Join-Path $repoRoot "build\web"
}
$webRoot = [IO.Path]::GetFullPath($RootPath)
if (-not (Test-Path -LiteralPath $webRoot -PathType Container)) {
    throw "Web export directory not found: $webRoot"
}

$mimeTypes = @{
    ".html" = "text/html; charset=utf-8"
    ".js" = "text/javascript; charset=utf-8"
    ".wasm" = "application/wasm"
    ".pck" = "application/octet-stream"
    ".png" = "image/png"
    ".svg" = "image/svg+xml"
    ".json" = "application/json; charset=utf-8"
}

$listener = [Net.HttpListener]::new()
$webUrl = "http://127.0.0.1:$Port/"
$listener.Prefixes.Add($webUrl)
$listener.Start()
Write-Host "NUMBLOP_WEB_SERVER $webUrl"
if ($Open) {
    Start-Process -FilePath $webUrl
    Write-Host "Numblop opened in the default browser. Keep this window open; press Ctrl+C to stop."
}

try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        try {
            $relativePath = [Uri]::UnescapeDataString($context.Request.Url.AbsolutePath).TrimStart("/")
            if ([string]::IsNullOrWhiteSpace($relativePath)) {
                $relativePath = "index.html"
            }
            $candidate = [IO.Path]::GetFullPath((Join-Path $webRoot $relativePath))
            $insideRoot = $candidate.Equals($webRoot, [StringComparison]::OrdinalIgnoreCase) -or
                $candidate.StartsWith($webRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)
            if (-not $insideRoot) {
                $context.Response.StatusCode = 403
                continue
            }
            if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
                $context.Response.StatusCode = 404
                continue
            }

            $extension = [IO.Path]::GetExtension($candidate).ToLowerInvariant()
            $context.Response.ContentType = if ($mimeTypes.ContainsKey($extension)) {
                $mimeTypes[$extension]
            }
            else {
                "application/octet-stream"
            }
            $context.Response.Headers["Cache-Control"] = "no-store"
            $file = [IO.File]::OpenRead($candidate)
            try {
                $context.Response.ContentLength64 = $file.Length
                if ($context.Request.HttpMethod -ne "HEAD") {
                    $file.CopyTo($context.Response.OutputStream)
                }
            }
            finally {
                $file.Dispose()
            }
        }
        catch {
            $context.Response.StatusCode = 500
            Write-Error $_
        }
        finally {
            $context.Response.OutputStream.Close()
        }
    }
}
finally {
    $listener.Stop()
    $listener.Close()
}
