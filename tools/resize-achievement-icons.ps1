[CmdletBinding()]
param([string]$FfmpegPath = "")

# Generates both shipped sizes of the achievement icons from the full-size originals.
#
# The originals are 1254 px squares of roughly 2 MB each. Nothing that large may reach a build:
# the trophy tile is 64 px, and Play Console wants 512 px. So the originals stay in `input/`,
# which is both git-ignored and excluded from every export preset, and this script writes the two
# derived sets that are actually committed. Re-run it whenever the art is redrawn.

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path $PSScriptRoot -Parent
$sourceRoot = Join-Path $repoRoot "input\achievements"
$storeRoot = Join-Path $repoRoot "store\achievements"
$uiRoot = Join-Path $repoRoot "ui\achievements"

# Play Console accepts a 512x512 JPEG or a 32-bit PNG, and 32-bit means RGBA8, so the format is
# forced rather than inferred: the originals are opaque `rgb24` and a 24-bit PNG is rejected.
$storeSize = 512
$uiSize = 192

# Every icon is a round gold medallion inscribed in a square, and the source bakes a black
# backdrop into the corners. Left alone that reads as a black square sitting on top of the cream
# trophy tile, with hard corners in an otherwise rounded screen. The mask cuts the circle out
# instead, so the art sits directly on whatever is behind it.
#
# Applied at full resolution and only then scaled down, which is what antialiases the rim: masking
# after the downscale would leave a stair-stepped edge. `W` and `H` keep it independent of the
# source size.
$circleMask = "format=rgba,geq=r='r(X,Y)':g='g(X,Y)':b='b(X,Y)':" +
    "a='clip(255*(W/2-hypot(X-(W-1)/2,Y-(H-1)/2)),0,255)'"

function Resolve-Ffmpeg {
    param([string]$Requested)
    if ($Requested) {
        if (-not (Test-Path $Requested)) { throw "ffmpeg not found at $Requested" }
        return $Requested
    }
    $found = Get-Command ffmpeg -ErrorAction SilentlyContinue
    if ($null -eq $found) {
        throw "ffmpeg is not on PATH. Pass -FfmpegPath with its full location."
    }
    return $found.Source
}

$ffmpeg = Resolve-Ffmpeg -Requested $FfmpegPath
if (-not (Test-Path $sourceRoot)) { throw "No originals in $sourceRoot" }
$sources = @(Get-ChildItem (Join-Path $sourceRoot "*.png") | Sort-Object Name)
if ($sources.Count -eq 0) { throw "No PNG originals in $sourceRoot" }

New-Item -ItemType Directory -Force -Path $storeRoot | Out-Null
New-Item -ItemType Directory -Force -Path $uiRoot | Out-Null

foreach ($source in $sources) {
    foreach ($size in @($storeSize, $uiSize)) {
        $root = if ($size -eq $storeSize) { $storeRoot } else { $uiRoot }
        $destination = Join-Path $root $source.Name
        & $ffmpeg -y -loglevel error -i $source.FullName `
            -vf "$circleMask,scale=$($size):$($size):flags=lanczos" -pix_fmt rgba $destination
        if ($LASTEXITCODE -ne 0) { throw "ffmpeg failed on $($source.Name) at $size px" }
    }
    Write-Host "  $($source.BaseName)"
}

Write-Host "$($sources.Count) icons written to store\achievements ($storeSize px) and ui\achievements ($uiSize px)."
