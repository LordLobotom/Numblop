[CmdletBinding()]
param(
    [string]$GodotPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "GodotTools.psm1") -Force
$repoRoot = Split-Path $PSScriptRoot -Parent
$godot = Resolve-NumblopGodot -GodotPath $GodotPath

Write-Host "Godot: $godot"
Write-Host "Project: $repoRoot"

Initialize-NumblopProject -Godot $godot -RepoRoot $repoRoot

Invoke-NumblopGodot -Godot $godot -Arguments @(
    "--headless", "--path", $repoRoot, "--script", "res://tools/generate_app_icons.gd"
) -ExpectedMarker "NUMBLOP_ICONS_OK"

# The icons themselves changed on disk; reimport so the editor and exports pick them up.
Initialize-NumblopProject -Godot $godot -RepoRoot $repoRoot
