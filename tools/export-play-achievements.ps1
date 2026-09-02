[CmdletBinding()]
param([string]$GodotPath = "")

# Builds the ZIP that Play Console imports to create all 25 achievements at once.
#
# The three CSVs are generated from `AchievementCatalog` and `localization/strings.csv`, so the
# names and descriptions in Console are the ones the game shows, in all shipped languages. Re-run this
# whenever an achievement is added or a string is reworded, then re-import.

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "GodotTools.psm1") -Force
$repoRoot = Split-Path $PSScriptRoot -Parent
$stageRoot = Join-Path $repoRoot "artifacts\play-achievements"
$archivePath = Join-Path $repoRoot "artifacts\play-achievements.zip"
$godot = Resolve-NumblopGodot -GodotPath $GodotPath

Initialize-NumblopProject -Godot $godot -RepoRoot $repoRoot

if (Test-Path $stageRoot) { Remove-Item $stageRoot -Recurse -Force }

Invoke-NumblopGodot -Godot $godot -Arguments @(
    "--path", $repoRoot,
    "res://tests/smoke/ExportPlayAchievements.tscn"
) -ExpectedMarker "NUMBLOP_PLAY_ACHIEVEMENTS_OK" -TimeoutSeconds 180

$expected = @(
    "AchievementsMetadata.csv",
    "AchievementsLocalizations.csv",
    "AchievementsIconsMappings.csv"
)
foreach ($name in $expected) {
    $path = Join-Path $stageRoot $name
    if (-not (Test-Path $path)) { throw "Missing $name" }
}
$icons = @(Get-ChildItem (Join-Path $stageRoot "*.png"))
if ($icons.Count -eq 0) { throw "No icons staged" }

if (Test-Path $archivePath) { Remove-Item $archivePath -Force }
Compress-Archive -Path (Join-Path $stageRoot "*") -DestinationPath $archivePath

$sizeMb = [math]::Round((Get-Item $archivePath).Length / 1MB, 2)
# Console rejects an import over 200 MB.
if ($sizeMb -gt 200) { throw "Archive is $sizeMb MB, over the 200 MB Console limit" }
Write-Host "$archivePath : $($icons.Count) icons, $sizeMb MB"
