# Aligns Godot's generated Android Gradle build template with the SDK levels the
# release preset targets. The template lives in the git-ignored `android/` directory
# and is overwritten whenever Godot reinstalls it, so this patch must be re-applied
# before every release export. It is idempotent.
[CmdletBinding()]
param(
    [int]$CompileSdk = 36,
    [int]$TargetSdk = 36,
    [int]$MinSdk = 24
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path $PSScriptRoot -Parent
$configPath = Join-Path $repoRoot "android\build\config.gradle"
$propertiesPath = Join-Path $repoRoot "android\build\gradle.properties"

if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
    throw "Android build template not found at $configPath. Run tools/export.ps1 -Target android-release, which installs it, or install it from the Godot editor."
}

function Set-GradleVersion {
    param(
        [Parameter(Mandatory)] [string]$Text,
        [Parameter(Mandatory)] [string]$Key,
        [Parameter(Mandatory)] [int]$Value
    )

    # Matches e.g. "    compileSdk         : 35," inside ext.versions.
    $pattern = "(?m)^(\s*$Key\s*:\s*)\d+(\s*,)"
    if ($Text -notmatch $pattern) {
        throw "Could not find '$Key' in $configPath. The Godot template layout changed; update tools/patch-android-template.ps1."
    }
    return [regex]::Replace($Text, $pattern, "`${1}$Value`${2}")
}

$configText = [System.IO.File]::ReadAllText($configPath)
$patchedText = $configText
$patchedText = Set-GradleVersion -Text $patchedText -Key "compileSdk" -Value $CompileSdk
$patchedText = Set-GradleVersion -Text $patchedText -Key "targetSdk" -Value $TargetSdk
$patchedText = Set-GradleVersion -Text $patchedText -Key "minSdk" -Value $MinSdk

if ($patchedText -ne $configText) {
    [System.IO.File]::WriteAllText($configPath, $patchedText)
    Write-Host "Patched $configPath (compileSdk $CompileSdk, targetSdk $TargetSdk, minSdk $MinSdk)."
}
else {
    Write-Host "config.gradle already at compileSdk $CompileSdk, targetSdk $TargetSdk, minSdk $MinSdk."
}

# The template ships Android Gradle Plugin 8.6.1, which predates compile SDK 36 and
# fails the build with "not tested with this version of the Android Gradle plugin".
$suppressKey = "android.suppressUnsupportedCompileSdk"
$suppressLine = "$suppressKey=$CompileSdk"
$propertiesText = ""
if (Test-Path -LiteralPath $propertiesPath -PathType Leaf) {
    $propertiesText = [System.IO.File]::ReadAllText($propertiesPath)
}
if ($propertiesText -match "(?m)^\s*$([regex]::Escape($suppressKey))\s*=.*$") {
    $updatedProperties = [regex]::Replace(
        $propertiesText,
        "(?m)^\s*$([regex]::Escape($suppressKey))\s*=.*$",
        $suppressLine
    )
}
else {
    $separator = if ($propertiesText -eq "" -or $propertiesText.EndsWith("`n")) { "" } else { "`n" }
    $updatedProperties = "$propertiesText$separator`n# Numblop: AGP 8.6.1 predates compile SDK $CompileSdk.`n$suppressLine`n"
}
if ($updatedProperties -ne $propertiesText) {
    [System.IO.File]::WriteAllText($propertiesPath, $updatedProperties)
    Write-Host "Set $suppressLine in $propertiesPath."
}
else {
    Write-Host "$suppressLine already set in $propertiesPath."
}

$sdkRoot = Join-Path $env:LOCALAPPDATA "Android\Sdk"
$platformDir = Join-Path $sdkRoot "platforms\android-$CompileSdk"
if (-not (Test-Path -LiteralPath $platformDir -PathType Container)) {
    Write-Warning "Android SDK Platform $CompileSdk is missing at $platformDir. Install it with: sdkmanager `"platforms;android-$CompileSdk`" (see docs/RELEASES.md)."
}

Write-Host "NUMBLOP_ANDROID_TEMPLATE_PATCH_OK"
