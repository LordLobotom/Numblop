[CmdletBinding()]
param([string]$GodotPath = "")

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "GodotTools.psm1") -Force
$repoRoot = Split-Path $PSScriptRoot -Parent
$artifactRoot = Join-Path $repoRoot "artifacts\responsive"
$godot = Resolve-NumblopGodot -GodotPath $GodotPath

Initialize-NumblopProject -Godot $godot -RepoRoot $repoRoot
New-Item -ItemType Directory -Path $artifactRoot -Force | Out-Null

Invoke-NumblopGodot -Godot $godot -Arguments @(
    "--path", $repoRoot,
    "res://tests/smoke/CaptureResponsive.tscn"
) -ExpectedMarker "NUMBLOP_RESPONSIVE_CAPTURES_OK" -TimeoutSeconds 180

Add-Type -AssemblyName System.Drawing
$expectedScreens = @(
    "home",
    "home_accessories",
    "home_duck",
    "cosmetics",
    "cosmetics_color",
    "cosmetics_buy",
    "trophy",
    "map",
    "map_detail",
    "map_unlock",
    "settings",
    "settings_exit",
    "choice",
    "keypad",
    "reward"
)
$expectedLocales = @("en", "cs")
$expectedSizes = @(
    @{ Width = 390; Height = 844 },
    @{ Width = 450; Height = 900 }
)

foreach ($locale in $expectedLocales) {
    foreach ($size in $expectedSizes) {
        foreach ($screen in $expectedScreens) {
            $name = "{0}_{1}x{2}_{3}.png" -f $locale, $size.Width, $size.Height, $screen
            $path = Join-Path $artifactRoot $name
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
                throw "Responsive capture is missing: $path"
            }
            $image = [System.Drawing.Image]::FromFile($path)
            try {
                if ($image.Width -ne $size.Width -or $image.Height -ne $size.Height) {
                    throw "Responsive capture has the wrong dimensions: $path"
                }
            }
            finally {
                $image.Dispose()
            }
            Write-Host "OK $path"
        }
    }
}

Write-Host "NUMBLOP_RESPONSIVE_ARTIFACTS_OK"
