[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet("windows", "android-debug", "android-release", "android-release-unsigned", "web")]
    [string]$Target,
    [string]$GodotPath = "",
    # android-release only: fills the keystore environment variables Godot reads, so a
    # signed bundle needs no secret in the shell. See tools/save-keystore-password.ps1.
    [string]$PasswordFile = "",
    [string]$KeystorePath = "",
    [string]$Alias = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "GodotTools.psm1") -Force

if (($PasswordFile -ne "" -or $KeystorePath -ne "" -or $Alias -ne "") -and $Target -ne "android-release") {
    throw "-PasswordFile, -KeystorePath and -Alias only apply to -Target android-release."
}

$repoRoot = Split-Path $PSScriptRoot -Parent
$buildRoot = Join-Path $repoRoot "build"
$godot = Resolve-NumblopGodot -GodotPath $GodotPath
New-Item -ItemType Directory -Path $buildRoot -Force | Out-Null
$buildIgnorePath = Join-Path $buildRoot ".gdignore"
if (-not (Test-Path -LiteralPath $buildIgnorePath -PathType Leaf)) {
    [System.IO.File]::WriteAllText($buildIgnorePath, "")
}
Initialize-NumblopProject -Godot $godot -RepoRoot $repoRoot

$presetsPath = Join-Path $repoRoot "export_presets.cfg"

function Initialize-NumblopAndroidGradle {
    $androidBuildScript = Join-Path $repoRoot "android\build\build.gradle"
    if (-not (Test-Path -LiteralPath $androidBuildScript -PathType Leaf)) {
        Invoke-NumblopGodot -Godot $godot -Arguments @(
            "--headless", "--editor", "--path", $repoRoot,
            "--install-android-build-template", "--quit-after", "30"
        ) -TimeoutSeconds 300
        if (-not (Test-Path -LiteralPath $androidBuildScript -PathType Leaf)) {
            throw "Godot did not install the Android Gradle build template."
        }
    }

    # Re-applied on every export: the template is git-ignored and Godot may
    # overwrite it with its stock compile SDK, which is lower than our target.
    & (Join-Path $PSScriptRoot "patch-android-template.ps1")
}

# Godot has no per-option command line override, so an unsigned export needs
# package/signed=false written into the preset for the duration of the build. The
# edit is scoped to the Android Release options block and the original file is
# restored verbatim afterwards, so the committed preset never drifts.
function Disable-NumblopReleaseSigning {
    param([Parameter(Mandatory)] [string]$Text)

    # Header line, then any number of non-section lines, then this preset's name.
    if ($Text -notmatch '(?m)^\[preset\.(\d+)\]\r?\n(?:[^\[\r\n]*\r?\n)*?name="Android Release"\r?$') {
        throw "Could not locate the Android Release preset in $presetsPath."
    }
    $optionsHeader = "[preset.$($Matches[1]).options]"
    $start = $Text.IndexOf($optionsHeader)
    if ($start -lt 0) {
        throw "Could not locate $optionsHeader in $presetsPath."
    }
    $next = $Text.IndexOf("`n[", $start + $optionsHeader.Length)
    $end = if ($next -lt 0) { $Text.Length } else { $next }

    $section = $Text.Substring($start, $end - $start)
    if ($section -notmatch '(?m)^package/signed=true\s*$') {
        throw "Android Release preset does not have package/signed=true; refusing to guess."
    }
    $patchedSection = [regex]::Replace(
        $section, '(?m)^package/signed=true\s*$', 'package/signed=false'
    )
    return $Text.Substring(0, $start) + $patchedSection + $Text.Substring($end)
}

$unsignReleasePreset = $false
$clearKeystoreEnvironment = $false

switch ($Target) {
    "windows" {
        $arguments = @(
            "--headless", "--path", $repoRoot,
            "--export-release", "Windows Desktop", (Join-Path $buildRoot "Numblop.exe")
        )
    }
    "android-debug" {
        $arguments = @(
            "--headless", "--path", $repoRoot,
            "--export-debug", "Android Debug", (Join-Path $buildRoot "Numblop-debug.apk")
        )
    }
    "android-release" {
        # The parameters only ever populate process-scoped variables, which are cleared
        # in the finally block below; nothing leaks into the caller's shell.
        if ($KeystorePath -ne "") {
            [Environment]::SetEnvironmentVariable(
                "GODOT_ANDROID_KEYSTORE_RELEASE_PATH", $KeystorePath, "Process"
            )
        }
        if ($Alias -ne "") {
            [Environment]::SetEnvironmentVariable(
                "GODOT_ANDROID_KEYSTORE_RELEASE_USER", $Alias, "Process"
            )
        }
        if ($PasswordFile -ne "") {
            [Environment]::SetEnvironmentVariable(
                "GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD",
                (Unprotect-NumblopPassword -PasswordFile $PasswordFile),
                "Process"
            )
            $clearKeystoreEnvironment = $true
        }

        foreach ($name in @(
            "GODOT_ANDROID_KEYSTORE_RELEASE_PATH",
            "GODOT_ANDROID_KEYSTORE_RELEASE_USER",
            "GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD"
        )) {
            if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($name))) {
                throw "$name must be set for a release AAB, or pass -KeystorePath/-Alias/-PasswordFile. See docs/RELEASES.md."
            }
        }

        Initialize-NumblopAndroidGradle

        $arguments = @(
            "--headless", "--path", $repoRoot,
            "--export-release", "Android Release", (Join-Path $buildRoot "Numblop.aab")
        )
    }
    "android-release-unsigned" {
        # Deliberately no keystore environment variables: this target exists so the
        # bundle can be built without any credential, then signed interactively with
        # tools/sign-aab.ps1.
        Initialize-NumblopAndroidGradle
        $unsignReleasePreset = $true

        $arguments = @(
            "--headless", "--path", $repoRoot,
            "--export-release", "Android Release", (Join-Path $buildRoot "Numblop.aab")
        )
    }
    "web" {
        $webRoot = Join-Path $buildRoot "web"
        $resolvedBuildRoot = [System.IO.Path]::GetFullPath($buildRoot).TrimEnd(
            [System.IO.Path]::DirectorySeparatorChar
        )
        $resolvedWebRoot = [System.IO.Path]::GetFullPath($webRoot)
        if (-not $resolvedWebRoot.StartsWith(
            "$resolvedBuildRoot$([System.IO.Path]::DirectorySeparatorChar)",
            [System.StringComparison]::OrdinalIgnoreCase
        )) {
            throw "Refusing to clean Web output outside the build directory: $resolvedWebRoot"
        }
        if (Test-Path -LiteralPath $resolvedWebRoot) {
            Remove-Item -LiteralPath $resolvedWebRoot -Recurse -Force
        }
        New-Item -ItemType Directory -Path $webRoot -Force | Out-Null
        $arguments = @(
            "--headless", "--path", $repoRoot,
            "--export-release", "Web", (Join-Path $webRoot "index.html")
        )
    }
}

$previousGradleOptions = [Environment]::GetEnvironmentVariable("GRADLE_OPTS", "Process")
$originalPresets = $null
try {
    if ($Target -like "android-release*" -and $previousGradleOptions -notmatch 'org\.gradle\.daemon=false') {
        $scriptedGradleOptions = (($previousGradleOptions, "-Dorg.gradle.daemon=false") |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join " "
        [Environment]::SetEnvironmentVariable("GRADLE_OPTS", $scriptedGradleOptions, "Process")
    }
    if ($unsignReleasePreset) {
        $originalPresets = [System.IO.File]::ReadAllText($presetsPath)
        [System.IO.File]::WriteAllText($presetsPath, (Disable-NumblopReleaseSigning -Text $originalPresets))
        Write-Host "Android Release preset temporarily set to package/signed=false."
    }
    # A first Gradle run downloads the plugin and dependencies and outlasts the
    # timeout that is generous for every other target.
    $exportTimeoutSeconds = if ($Target -like "android-release*") { 1800 } else { 600 }
    Invoke-NumblopGodot -Godot $godot -Arguments $arguments -TimeoutSeconds $exportTimeoutSeconds
}
finally {
    [Environment]::SetEnvironmentVariable("GRADLE_OPTS", $previousGradleOptions, "Process")
    if ($clearKeystoreEnvironment) {
        [Environment]::SetEnvironmentVariable(
            "GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD", $null, "Process"
        )
    }
    if ($null -ne $originalPresets) {
        [System.IO.File]::WriteAllText($presetsPath, $originalPresets)
        Write-Host "Restored $presetsPath."
    }
}

if ($Target -eq "android-release-unsigned") {
    Write-Host ""
    Write-Host "Unsigned bundle ready. Sign it with:" -ForegroundColor Cyan
    Write-Host "  tools/sign-aab.ps1 -KeystorePath <keystore.jks> -Alias <alias>"
}
