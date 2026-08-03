# Stores the keystore password encrypted with Windows DPAPI so tools/sign-aab.ps1 can
# sign without an interactive prompt.
#
# The ciphertext is bound to the current Windows user account on this machine: copied
# anywhere else it is useless. Keep the file outside the repository, next to the keystore.
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$PasswordFile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path $PSScriptRoot -Parent
$resolvedRepoRoot = [System.IO.Path]::GetFullPath($repoRoot).TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar
)
$resolvedTarget = [System.IO.Path]::GetFullPath($PasswordFile)
if ($resolvedTarget.StartsWith(
    "$resolvedRepoRoot$([System.IO.Path]::DirectorySeparatorChar)",
    [System.StringComparison]::OrdinalIgnoreCase
)) {
    throw "Refusing to write the password inside the repository ($resolvedTarget). Keep it next to the keystore instead."
}

$targetDirectory = Split-Path $resolvedTarget -Parent
if (-not (Test-Path -LiteralPath $targetDirectory -PathType Container)) {
    throw "Directory does not exist: $targetDirectory"
}
if (Test-Path -LiteralPath $resolvedTarget) {
    Write-Warning "Overwriting the existing password file $resolvedTarget."
}

$secure = Read-Host "Keystore password" -AsSecureString
if ($secure.Length -eq 0) {
    throw "No password entered; nothing was written."
}

# ConvertFrom-SecureString without a key uses DPAPI under the current user account.
Set-Content -LiteralPath $resolvedTarget -Value (ConvertFrom-SecureString $secure) -Encoding utf8
$secure.Dispose()

Write-Host "Wrote DPAPI-encrypted password to $resolvedTarget"
Write-Host "Only your Windows account on this machine can decrypt it."
Write-Host "Back up the password itself somewhere safe: this file does not survive a reinstall."
