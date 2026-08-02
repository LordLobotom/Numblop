[CmdletBinding()]
param([string]$GodotPath = "")

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "GodotTools.psm1") -Force
$repoRoot = Split-Path $PSScriptRoot -Parent
$storeRoot = Join-Path $repoRoot "store\screenshots"
$godot = Resolve-NumblopGodot -GodotPath $GodotPath

Initialize-NumblopProject -Godot $godot -RepoRoot $repoRoot
New-Item -ItemType Directory -Path $storeRoot -Force | Out-Null

Invoke-NumblopGodot -Godot $godot -Arguments @(
    "--path", $repoRoot,
    "res://tests/smoke/CaptureStore.tscn"
) -ExpectedMarker "NUMBLOP_STORE_CAPTURES_OK" -TimeoutSeconds 180

Add-Type -AssemblyName System.Drawing
$expectedScreens = @(
    "home_accessories",
    "map",
    "choice",
    "keypad",
    "reward",
    "cosmetics"
)
$expectedLocales = @("en", "cs")

foreach ($locale in $expectedLocales) {
    foreach ($screen in $expectedScreens) {
        $path = Join-Path $storeRoot "$locale\$screen.png"
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "Store capture is missing: $path"
        }
        $image = [System.Drawing.Image]::FromFile($path)
        try {
            if ($image.Width -ne 1080 -or $image.Height -ne 1920) {
                throw "Store capture must be 1080x1920 (Play allows at most 2:1): $path"
            }
        }
        finally {
            $image.Dispose()
        }
        Write-Host "OK $path"
    }
}

Write-Host "NUMBLOP_STORE_ARTIFACTS_OK"
