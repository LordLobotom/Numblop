[CmdletBinding()]
param(
    [string]$AabPath = "",
    [string]$ExpectedVersionName = "0.2.3",
    [int]$ExpectedVersionCode = 5
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "GodotTools.psm1") -Force
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

$jarsigner = Resolve-NumblopJarsigner
$signOutput = & $jarsigner -verify -strict $aabItem.FullName
$signExitCode = $LASTEXITCODE

# -strict reports its findings as a bit mask. A Play upload key is deliberately a
# self-signed certificate that chains to nothing, so those two bits are the expected
# result rather than a failure. Every other bit still fails the check.
$expectedStrictBits = 4 -bor 64   # chainNotValidated, signerSelfSigned
$unexpectedStrictBits = $signExitCode -band (-bnot $expectedStrictBits)
if ($unexpectedStrictBits -ne 0 -or ($signOutput -join "`n") -notmatch "jar verified") {
    Write-Host ($signOutput -join "`n")
    throw ("jarsigner did not verify the AAB upload signature " +
        "(exit $signExitCode, unexpected bits $unexpectedStrictBits).")
}
Write-Host "OK upload signature (jarsigner, self-signed upload key as expected)"

if ($env:NUMBLOP_BUNDLETOOL_JAR -and (Test-Path $env:NUMBLOP_BUNDLETOOL_JAR)) {
    # The JDK that provides jarsigner also provides java, which is often not on PATH.
    $java = Join-Path (Split-Path $jarsigner -Parent) "java.exe"
    if (-not (Test-Path -LiteralPath $java -PathType Leaf)) {
        $java = "java"
    }
    $manifest = (& $java -jar $env:NUMBLOP_BUNDLETOOL_JAR dump manifest --bundle $aabItem.FullName) -join "`n"
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
