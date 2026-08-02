[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet("windows", "android-debug", "android-release", "web")]
    [string]$Target,
    [string]$GodotPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "GodotTools.psm1") -Force
$repoRoot = Split-Path $PSScriptRoot -Parent
$buildRoot = Join-Path $repoRoot "build"
$godot = Resolve-NumblopGodot -GodotPath $GodotPath
New-Item -ItemType Directory -Path $buildRoot -Force | Out-Null
Initialize-NumblopProject -Godot $godot -RepoRoot $repoRoot

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
        foreach ($name in @(
            "GODOT_ANDROID_KEYSTORE_RELEASE_PATH",
            "GODOT_ANDROID_KEYSTORE_RELEASE_USER",
            "GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD"
        )) {
            if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($name))) {
                throw "$name must be set for a release AAB. See docs/RELEASES.md."
            }
        }

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

        $arguments = @(
            "--headless", "--path", $repoRoot,
            "--export-release", "Android Release", (Join-Path $buildRoot "Numblop.aab")
        )
    }
    "web" {
        $webRoot = Join-Path $buildRoot "web"
        New-Item -ItemType Directory -Path $webRoot -Force | Out-Null
        $arguments = @(
            "--headless", "--path", $repoRoot,
            "--export-release", "Web", (Join-Path $webRoot "index.html")
        )
    }
}

$previousGradleOptions = [Environment]::GetEnvironmentVariable("GRADLE_OPTS", "Process")
try {
    if ($Target -eq "android-release" -and $previousGradleOptions -notmatch 'org\.gradle\.daemon=false') {
        $scriptedGradleOptions = (($previousGradleOptions, "-Dorg.gradle.daemon=false") |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join " "
        [Environment]::SetEnvironmentVariable("GRADLE_OPTS", $scriptedGradleOptions, "Process")
    }
    Invoke-NumblopGodot -Godot $godot -Arguments $arguments -TimeoutSeconds 600
}
finally {
    [Environment]::SetEnvironmentVariable("GRADLE_OPTS", $previousGradleOptions, "Process")
}
