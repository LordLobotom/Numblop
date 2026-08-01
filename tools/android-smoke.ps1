[CmdletBinding()]
param(
    [string]$GodotPath = "",
    [string]$ApkPath = "",
    [string]$DeviceSerial = "",
    [switch]$SkipExport,
    [ValidateRange(2, 60)]
    [int]$LaunchWaitSeconds = 5
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path $PSScriptRoot -Parent
$packageId = "cz.gutcloud.numblop"
$androidRoot = [Environment]::GetEnvironmentVariable("ANDROID_HOME", "User")
if ([string]::IsNullOrWhiteSpace($androidRoot)) {
    throw "ANDROID_HOME is not configured as a user environment variable."
}
$adb = Join-Path $androidRoot "platform-tools\adb.exe"
if (-not (Test-Path -LiteralPath $adb -PathType Leaf)) {
    throw "ADB was not found: $adb"
}

if ([string]::IsNullOrWhiteSpace($ApkPath)) {
    $ApkPath = Join-Path $repoRoot "build\Numblop-debug.apk"
}
elseif (-not [IO.Path]::IsPathRooted($ApkPath)) {
    $ApkPath = Join-Path $repoRoot $ApkPath
}
$ApkPath = [IO.Path]::GetFullPath($ApkPath)

if (-not $SkipExport) {
    & (Join-Path $PSScriptRoot "export.ps1") -Target android-debug -GodotPath $GodotPath
    if (-not $?) {
        throw "Android debug export failed."
    }
}
if (-not (Test-Path -LiteralPath $ApkPath -PathType Leaf)) {
    throw "Debug APK was not found: $ApkPath"
}

$deviceLines = @(& $adb devices -l)
$connected = @(
    $deviceLines |
        Where-Object { $_ -match '^\S+\s+device(?:\s|$)' } |
        ForEach-Object { ($_ -split '\s+')[0] }
)
if ([string]::IsNullOrWhiteSpace($DeviceSerial)) {
    if ($connected.Count -eq 0) {
        throw "No authorized Android device is connected. Unlock a phone, enable USB debugging, and retry."
    }
    if ($connected.Count -gt 1) {
        throw "More than one Android device is connected; pass -DeviceSerial."
    }
    $DeviceSerial = $connected[0]
}
elseif ($connected -notcontains $DeviceSerial) {
    throw "The requested authorized device is not connected: $DeviceSerial"
}

function Invoke-DeviceAdb {
    param([Parameter(ValueFromRemainingArguments)] [string[]]$Arguments)

    $output = @(& $adb -s $DeviceSerial @Arguments 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "ADB failed: adb -s $DeviceSerial $($Arguments -join ' ')`n$($output -join "`n")"
    }
    return $output
}

Write-Host "Device: $DeviceSerial"
Write-Host "APK: $ApkPath"
Invoke-DeviceAdb -Arguments @("install", "-r", "-t", $ApkPath) |
    ForEach-Object { Write-Host $_ }
Invoke-DeviceAdb -Arguments @("shell", "am", "force-stop", $packageId) | Out-Null
$launchOutput = Invoke-DeviceAdb -Arguments @(
    "shell", "monkey", "-p", $packageId, "-c", "android.intent.category.LAUNCHER", "1"
)
if (($launchOutput -join "`n") -notmatch 'Events injected:\s*1') {
    throw "The installed Numblop launcher activity did not start.`n$($launchOutput -join "`n")"
}

Start-Sleep -Seconds $LaunchWaitSeconds
$pidText = (
    Invoke-DeviceAdb -Arguments @("shell", "pidof", $packageId) |
        Select-Object -First 1
).Trim()
if ($pidText -notmatch '^\d+$') {
    throw "Numblop is not running after launch."
}
$activityState = Invoke-DeviceAdb -Arguments @("shell", "dumpsys", "activity", "activities")
if (($activityState -join "`n") -notmatch [regex]::Escape($packageId)) {
    throw "Numblop is not present in the Android activity state. Unlock the device and retry."
}

$logs = Invoke-DeviceAdb -Arguments @("logcat", "-d", "--pid=$pidText", "-v", "threadtime")
$artifactRoot = Join-Path $repoRoot "artifacts\android-smoke"
New-Item -ItemType Directory -Path $artifactRoot -Force | Out-Null
$safeSerial = $DeviceSerial -replace '[^A-Za-z0-9._-]', '_'
$logPath = Join-Path $artifactRoot "device-$safeSerial.log"
[IO.File]::WriteAllLines($logPath, [string[]]$logs)
$fatalPattern = 'FATAL EXCEPTION|AndroidRuntime.*FATAL|SCRIPT ERROR:|Parse Error:'
if (($logs -join "`n") -match $fatalPattern) {
    throw "Fatal runtime output was found. Inspect $logPath"
}

Write-Host "Log: $logPath"
Write-Host "NUMBLOP_ANDROID_DEVICE_SMOKE_OK"
