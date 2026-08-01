[CmdletBinding()]
param(
    [string]$GodotPath = "",
    [switch]$SkipImport
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "GodotTools.psm1") -Force
$repoRoot = Split-Path $PSScriptRoot -Parent
$godot = Resolve-NumblopGodot -GodotPath $GodotPath

Write-Host "Godot: $godot"
Write-Host "Project: $repoRoot"

if (-not $SkipImport) {
    Initialize-NumblopProject -Godot $godot -RepoRoot $repoRoot
}

Invoke-NumblopGodot -Godot $godot -Arguments @(
    "--headless", "--path", $repoRoot, "--script", "res://tests/run_tests.gd"
) -ExpectedMarker "NUMBLOP_TESTS_OK"
