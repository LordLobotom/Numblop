[CmdletBinding()]
param([string]$GodotVersion = "4.6.2.stable")

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Net.Http

$releaseTag = $GodotVersion.Replace(".stable", "-stable")
$archiveName = "Godot_v$releaseTag`_export_templates.tpz"
$archiveUri = "https://github.com/godotengine/godot-builds/releases/download/$releaseTag/$archiveName"
$templateRoot = Join-Path $env:APPDATA "Godot\export_templates\$GodotVersion"
$entriesToInstall = @(
    "templates/web_nothreads_debug.zip",
    "templates/web_nothreads_release.zip"
)

function Get-RemoteRange {
    param(
        [Parameter(Mandatory)] [Net.Http.HttpClient]$Client,
        [Parameter(Mandatory)] [Uri]$Uri,
        [Parameter(Mandatory)] [long]$Start,
        [Parameter(Mandatory)] [long]$End
    )

    $request = [Net.Http.HttpRequestMessage]::new([Net.Http.HttpMethod]::Get, $Uri)
    $request.Headers.Range = [Net.Http.Headers.RangeHeaderValue]::new($Start, $End)
    try {
        $response = $Client.SendAsync($request).GetAwaiter().GetResult()
        try {
            $response.EnsureSuccessStatusCode() | Out-Null
            $bytes = $response.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult()
            Write-Output -NoEnumerate $bytes
        }
        finally {
            $response.Dispose()
        }
    }
    finally {
        $request.Dispose()
    }
}

function Write-ZipPayload {
    param(
        [Parameter(Mandatory)] [byte[]]$CompressedBytes,
        [Parameter(Mandatory)] [int]$CompressionMethod,
        [Parameter(Mandatory)] [long]$ExpectedLength,
        [Parameter(Mandatory)] [string]$Destination
    )

    if ($CompressionMethod -eq 0) {
        [IO.File]::WriteAllBytes($Destination, $CompressedBytes)
    }
    elseif ($CompressionMethod -eq 8) {
        $inputStream = [IO.MemoryStream]::new($CompressedBytes, $false)
        $deflateStream = [IO.Compression.DeflateStream]::new(
            $inputStream,
            [IO.Compression.CompressionMode]::Decompress
        )
        $outputStream = [IO.File]::Open(
            $Destination,
            [IO.FileMode]::Create,
            [IO.FileAccess]::Write,
            [IO.FileShare]::None
        )
        try {
            $deflateStream.CopyTo($outputStream)
        }
        finally {
            $outputStream.Dispose()
            $deflateStream.Dispose()
            $inputStream.Dispose()
        }
    }
    else {
        throw "Unsupported template archive compression method: $CompressionMethod"
    }

    $actualLength = (Get-Item -LiteralPath $Destination).Length
    if ($actualLength -ne $ExpectedLength) {
        throw "Template length mismatch for $Destination ($actualLength instead of $ExpectedLength)."
    }
}

$handler = [Net.Http.HttpClientHandler]::new()
$handler.AllowAutoRedirect = $true
$client = [Net.Http.HttpClient]::new($handler)
$client.DefaultRequestHeaders.UserAgent.ParseAdd("Numblop-Web-Template-Installer/1.0")
$archive = [Uri]$archiveUri

try {
    $probeRequest = [Net.Http.HttpRequestMessage]::new([Net.Http.HttpMethod]::Get, $archive)
    $probeRequest.Headers.Range = [Net.Http.Headers.RangeHeaderValue]::new(0, 0)
    try {
        $probeResponse = $client.SendAsync($probeRequest).GetAwaiter().GetResult()
        try {
            $probeResponse.EnsureSuccessStatusCode() | Out-Null
            $archiveLength = $probeResponse.Content.Headers.ContentRange.Length
        }
        finally {
            $probeResponse.Dispose()
        }
    }
    finally {
        $probeRequest.Dispose()
    }
    if ($null -eq $archiveLength -or $archiveLength -lt 22) {
        throw "The official template archive did not report a usable length."
    }

    $tailLength = [Math]::Min(131072, [long]$archiveLength)
    $tailStart = [long]$archiveLength - $tailLength
    [byte[]]$tail = Get-RemoteRange -Client $client -Uri $archive -Start $tailStart -End ([long]$archiveLength - 1)
    $eocdOffset = -1
    for ($index = $tail.Length - 22; $index -ge 0; $index--) {
        if (
            $tail[$index] -eq 0x50 -and $tail[$index + 1] -eq 0x4b -and
            $tail[$index + 2] -eq 0x05 -and $tail[$index + 3] -eq 0x06
        ) {
            $eocdOffset = $index
            break
        }
    }
    if ($eocdOffset -lt 0) {
        throw "Could not find the ZIP directory in the official template archive."
    }

    $centralSize = [BitConverter]::ToUInt32($tail, $eocdOffset + 12)
    $centralOffset = [BitConverter]::ToUInt32($tail, $eocdOffset + 16)
    if ($centralSize -eq [uint32]::MaxValue -or $centralOffset -eq [uint32]::MaxValue) {
        throw "ZIP64 template archives are not supported by this installer."
    }
    $centralRange = @{
        Client = $client
        Uri = $archive
        Start = $centralOffset
        End = [long]$centralOffset + $centralSize - 1
    }
    [byte[]]$central = Get-RemoteRange @centralRange

    $wanted = @{}
    foreach ($entryName in $entriesToInstall) {
        $wanted[$entryName] = $null
    }
    $cursor = 0
    while ($cursor -lt $central.Length) {
        if ([BitConverter]::ToUInt32($central, $cursor) -ne 0x02014b50) {
            throw "Invalid ZIP central-directory entry at offset $cursor."
        }
        $method = [BitConverter]::ToUInt16($central, $cursor + 10)
        $compressedLength = [BitConverter]::ToUInt32($central, $cursor + 20)
        $uncompressedLength = [BitConverter]::ToUInt32($central, $cursor + 24)
        $nameLength = [BitConverter]::ToUInt16($central, $cursor + 28)
        $extraLength = [BitConverter]::ToUInt16($central, $cursor + 30)
        $commentLength = [BitConverter]::ToUInt16($central, $cursor + 32)
        $localOffset = [BitConverter]::ToUInt32($central, $cursor + 42)
        $entryName = [Text.Encoding]::UTF8.GetString($central, $cursor + 46, $nameLength)
        if ($wanted.ContainsKey($entryName)) {
            $wanted[$entryName] = @{
                Method = $method
                CompressedLength = $compressedLength
                UncompressedLength = $uncompressedLength
                LocalOffset = $localOffset
            }
        }
        $cursor += 46 + $nameLength + $extraLength + $commentLength
    }

    New-Item -ItemType Directory -Path $templateRoot -Force | Out-Null
    foreach ($entryName in $entriesToInstall) {
        $entry = $wanted[$entryName]
        if ($null -eq $entry) {
            throw "The official archive is missing $entryName."
        }
        $localHeaderRange = @{
            Client = $client
            Uri = $archive
            Start = $entry.LocalOffset
            End = [long]$entry.LocalOffset + 29
        }
        [byte[]]$localHeader = Get-RemoteRange @localHeaderRange
        if ([BitConverter]::ToUInt32($localHeader, 0) -ne 0x04034b50) {
            throw "Invalid local ZIP header for $entryName."
        }
        $localNameLength = [BitConverter]::ToUInt16($localHeader, 26)
        $localExtraLength = [BitConverter]::ToUInt16($localHeader, 28)
        $payloadStart = [long]$entry.LocalOffset + 30 + $localNameLength + $localExtraLength
        $payloadRange = @{
            Client = $client
            Uri = $archive
            Start = $payloadStart
            End = $payloadStart + [long]$entry.CompressedLength - 1
        }
        [byte[]]$payload = Get-RemoteRange @payloadRange
        $destination = Join-Path $templateRoot ([IO.Path]::GetFileName($entryName))
        $writePayload = @{
            CompressedBytes = $payload
            CompressionMethod = $entry.Method
            ExpectedLength = $entry.UncompressedLength
            Destination = $destination
        }
        Write-ZipPayload @writePayload
        Write-Host "OK $destination"
    }
}
finally {
    $client.Dispose()
    $handler.Dispose()
}

Write-Host "NUMBLOP_WEB_TEMPLATES_OK"
