[CmdletBinding()]
param(
    [string]$AabPath = "",
    [string]$ExpectedVersionName = "1.0.0",
    [int]$ExpectedVersionCode = 2
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path $PSScriptRoot -Parent
if ($AabPath -eq "") {
    $AabPath = Join-Path $repoRoot "build\Numblop.aab"
}
if (-not (Test-Path $AabPath)) {
    throw "AAB not found at $AabPath. Run tools/export.ps1 -Target android-release first."
}
$aabItem = Get-Item $AabPath
if ($aabItem.Length -lt 5MB) {
    throw "AAB is suspiciously small ($([math]::Round($aabItem.Length / 1MB, 1)) MB)."
}
Write-Host "AAB $($aabItem.FullName) ($([math]::Round($aabItem.Length / 1MB, 1)) MB)"

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::OpenRead($aabItem.FullName)
try {
    $entryNames = @($archive.Entries | ForEach-Object { $_.FullName })
}
finally {
    $archive.Dispose()
}

$requiredEntries = @(
    "BundleConfig.pb",
    "base/manifest/AndroidManifest.xml",
    "base/dex/classes.dex"
)
foreach ($required in $requiredEntries) {
    if ($entryNames -notcontains $required) {
        throw "AAB is missing required entry $required."
    }
    Write-Host "OK entry $required"
}
foreach ($abi in @("arm64-v8a", "armeabi-v7a")) {
    $libEntries = @($entryNames | Where-Object { $_ -like "base/lib/$abi/*.so" })
    if ($libEntries.Count -eq 0) {
        throw "AAB has no native libraries for $abi."
    }
    Write-Host "OK native libs $abi ($($libEntries.Count))"
}

$jarsigner = $null
if ($env:JAVA_HOME) {
    $candidate = Join-Path $env:JAVA_HOME "bin\jarsigner.exe"
    if (Test-Path $candidate) {
        $jarsigner = $candidate
    }
}
if ($null -eq $jarsigner) {
    $command = Get-Command jarsigner -ErrorAction SilentlyContinue
    if ($null -ne $command) {
        $jarsigner = $command.Source
    }
}
if ($null -eq $jarsigner) {
    throw "jarsigner not found. Set JAVA_HOME to the JDK used for Android exports."
}
$signOutput = & $jarsigner -verify -strict $aabItem.FullName
if ($LASTEXITCODE -ne 0 -or ($signOutput -join "`n") -notmatch "jar verified") {
    Write-Host ($signOutput -join "`n")
    throw "jarsigner did not verify the AAB upload signature."
}
Write-Host "OK upload signature (jarsigner)"

if ($env:NUMBLOP_BUNDLETOOL_JAR -and (Test-Path $env:NUMBLOP_BUNDLETOOL_JAR)) {
    $manifest = (& java -jar $env:NUMBLOP_BUNDLETOOL_JAR dump manifest --bundle $aabItem.FullName) -join "`n"
    if ($LASTEXITCODE -ne 0) {
        throw "bundletool failed to dump the manifest."
    }
    $manifestChecks = @(
        @{ Pattern = 'package="cz\.gutcloud\.numblop"'; Label = "package id" },
        @{ Pattern = "android:versionCode=`"$ExpectedVersionCode`""; Label = "versionCode $ExpectedVersionCode" },
        @{ Pattern = "android:versionName=`"$([regex]::Escape($ExpectedVersionName))`""; Label = "versionName $ExpectedVersionName" },
        @{ Pattern = 'android\.permission\.VIBRATE'; Label = "VIBRATE permission" },
        @{ Pattern = 'android:allowBackup="true"'; Label = "allowBackup enabled" }
    )
    foreach ($manifestCheck in $manifestChecks) {
        if ($manifest -notmatch $manifestCheck.Pattern) {
            throw "Manifest check failed: $($manifestCheck.Label)."
        }
        Write-Host "OK manifest $($manifestCheck.Label)"
    }
    if ($manifest -match 'android\.permission\.INTERNET') {
        throw "Manifest unexpectedly requests INTERNET; Numblop must stay offline."
    }
    Write-Host "OK manifest stays offline (no INTERNET)"
}
else {
    Write-Warning ("NUMBLOP_BUNDLETOOL_JAR is not set; skipping manifest checks. " +
        "Download bundletool-all-<version>.jar from github.com/google/bundletool/releases " +
        "and set the env var to enable them.")
}

Write-Host "NUMBLOP_AAB_VERIFY_OK"
