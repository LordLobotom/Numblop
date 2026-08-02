[CmdletBinding()]
param([string]$GodotPath = "")

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "GodotTools.psm1") -Force
$godot = Resolve-NumblopGodot -GodotPath $GodotPath
$javaRoot = [Environment]::GetEnvironmentVariable("JAVA_HOME", "User")
$androidRoot = [Environment]::GetEnvironmentVariable("ANDROID_HOME", "User")
$templateRoot = Join-Path $env:APPDATA "Godot\export_templates\4.6.2.stable"

if ([string]::IsNullOrWhiteSpace($javaRoot)) {
    throw "JAVA_HOME is not configured as a user environment variable."
}
if ([string]::IsNullOrWhiteSpace($androidRoot)) {
    throw "ANDROID_HOME is not configured as a user environment variable."
}

$required = @(
    $godot,
    (Join-Path $javaRoot "bin\java.exe"),
    (Join-Path $androidRoot "platform-tools\adb.exe"),
    (Join-Path $androidRoot "build-tools\35.0.1\apksigner.bat"),
    (Join-Path $androidRoot "platforms\android-35\android.jar"),
    (Join-Path $androidRoot "ndk\28.1.13356709"),
    (Join-Path $androidRoot "cmake\3.10.2.4988404"),
    (Join-Path $templateRoot "android_debug.apk"),
    (Join-Path $templateRoot "android_release.apk"),
    (Join-Path $templateRoot "android_source.zip"),
    (Join-Path $templateRoot "web_nothreads_debug.zip"),
    (Join-Path $templateRoot "web_nothreads_release.zip")
)

foreach ($path in $required) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required Android export dependency is missing: $path"
    }
    Write-Host "OK $path"
}

Write-Host "NUMBLOP_WEB_ENV_OK"
Write-Host "NUMBLOP_ANDROID_ENV_OK"
