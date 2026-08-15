# Signs an unsigned release bundle with the Play upload key, then verifies it.
#
# The password is never a parameter, so it cannot reach the shell history or a process
# listing. By default jarsigner prompts for it and does not echo it. With -PasswordFile
# it is decrypted from a DPAPI-encrypted file (see tools/save-keystore-password.ps1),
# handed to jarsigner through a process-scoped environment variable, and cleared again.
[CmdletBinding()]
param(
    [string]$AabPath = "",
    [string]$KeystorePath = "",
    [string]$Alias = "",
    [string]$PasswordFile = "",
    [string]$JarsignerPath = "",
    [switch]$SkipVerify,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "GodotTools.psm1") -Force
$repoRoot = Split-Path $PSScriptRoot -Parent

if ($AabPath -eq "") {
    $AabPath = Join-Path $repoRoot "build\Numblop.aab"
}
if (-not (Test-Path -LiteralPath $AabPath -PathType Leaf)) {
    throw "AAB not found at $AabPath. Run tools/export.ps1 -Target android-release-unsigned first."
}
$aabItem = Get-Item -LiteralPath $AabPath

if ($KeystorePath -eq "") {
    $KeystorePath = $env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH
}
if ([string]::IsNullOrWhiteSpace($KeystorePath)) {
    throw "Pass -KeystorePath, or set GODOT_ANDROID_KEYSTORE_RELEASE_PATH. See docs/RELEASES.md."
}
if (-not (Test-Path -LiteralPath $KeystorePath -PathType Leaf)) {
    throw "Keystore not found: $KeystorePath"
}

# The encrypted password normally lives beside the keystore under the same base name, which is
# what makes a bare `sign-aab.ps1` work. An explicit -PasswordFile still wins, and finding nothing
# is not an error: jarsigner simply prompts, exactly as it always did.
if ($PasswordFile -eq "") {
    $PasswordFile = $env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD_FILE
}
if ([string]::IsNullOrWhiteSpace($PasswordFile)) {
    $adjacentPassword = [System.IO.Path]::ChangeExtension($KeystorePath, ".pwd")
    if (Test-Path -LiteralPath $adjacentPassword -PathType Leaf) {
        $PasswordFile = $adjacentPassword
    }
    else {
        $PasswordFile = ""
    }
}
if ($PasswordFile -ne "" -and -not (Test-Path -LiteralPath $PasswordFile -PathType Leaf)) {
    throw "Password file not found: $PasswordFile"
}

if ($Alias -eq "") {
    $Alias = $env:GODOT_ANDROID_KEYSTORE_RELEASE_USER
}
if ([string]::IsNullOrWhiteSpace($Alias) -and $PasswordFile -ne "") {
    # A keystore knows its own alias, so there is no reason to make anyone remember it. This only
    # works when the password is already available without a prompt.
    $Alias = Get-NumblopKeystoreAlias -KeystorePath $KeystorePath -PasswordFile $PasswordFile
}
if ([string]::IsNullOrWhiteSpace($Alias)) {
    throw "Pass -Alias with the upload key alias, or set GODOT_ANDROID_KEYSTORE_RELEASE_USER."
}

# Re-signing on top of an existing signature leaves both signature blocks in the bundle
# and Play rejects it, so require an explicit override.
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::OpenRead($aabItem.FullName)
try {
    $signatureEntries = @($archive.Entries |
        Where-Object { $_.FullName -match '^META-INF/.*\.(RSA|DSA|EC|SF)$' })
}
finally {
    $archive.Dispose()
}
if ($signatureEntries.Count -gt 0 -and -not $Force) {
    throw ("$($aabItem.Name) already carries a signature " +
        "($($signatureEntries[0].FullName)). Export a fresh unsigned bundle, or pass -Force.")
}

$jarsigner = Resolve-NumblopJarsigner -JarsignerPath $JarsignerPath
Write-Host "jarsigner: $jarsigner"
Write-Host "Bundle:    $($aabItem.FullName) ($([math]::Round($aabItem.Length / 1MB, 1)) MB)"
Write-Host "Keystore:  $KeystorePath"
Write-Host "Alias:     $Alias"
Write-Host ""

# No -sigalg/-digestalg: jarsigner derives both from the key, which keeps this correct
# for an EC upload key as well.
$passwordArguments = @()
$passwordVariable = "NUMBLOP_KEYSTORE_PASSWORD_TRANSIENT"
try {
    if ($PasswordFile -ne "") {
        # -storepass:env keeps the secret out of the command line, so it never shows up
        # in a process listing. The variable is process-scoped and cleared below.
        [Environment]::SetEnvironmentVariable(
            $passwordVariable, (Unprotect-NumblopPassword -PasswordFile $PasswordFile), "Process"
        )
        $passwordArguments = @("-storepass:env", $passwordVariable)
        Write-Host "Using the DPAPI-encrypted password from $PasswordFile." -ForegroundColor Cyan
    }
    else {
        Write-Host "jarsigner will now prompt for the keystore password; it is not echoed." -ForegroundColor Cyan
    }

    & $jarsigner @passwordArguments -keystore $KeystorePath $aabItem.FullName $Alias
    if ($LASTEXITCODE -ne 0) {
        throw "jarsigner failed with exit code $LASTEXITCODE. The bundle may be partially written; re-export before retrying."
    }
}
finally {
    [Environment]::SetEnvironmentVariable($passwordVariable, $null, "Process")
}
Write-Host "Signed $($aabItem.Name)."

if ($SkipVerify) {
    Write-Host "NUMBLOP_AAB_SIGN_OK (verification skipped)"
    return
}

& (Join-Path $PSScriptRoot "verify-aab.ps1") -AabPath $aabItem.FullName
Write-Host "NUMBLOP_AAB_SIGN_OK"
