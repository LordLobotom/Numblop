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

# Play Console accepts a 512x512 JPEG or a 32-bit PNG, and 32-bit means RGBA8. The current art is
# opaque `rgb24`, so ffmpeg would emit 24-bit and the Console would reject it: the store set forces
# the alpha channel on.
#
# The shipped set does the opposite and passes no format at all, which makes ffmpeg keep whatever
# the source has. Painting an all-opaque alpha channel into a game texture is a quarter more bytes
# in the build and in VRAM for nothing, and art that really is cut out still keeps its alpha.
$storeSize = 512
$uiSize = 192

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
    foreach ($target in @(
            @{ Root = $storeRoot; Size = $storeSize; Format = @("-pix_fmt", "rgba") },
            @{ Root = $uiRoot; Size = $uiSize; Format = @() }
        )) {
        $size = $target.Size
        $destination = Join-Path $target.Root $source.Name
        & $ffmpeg -y -loglevel error -i $source.FullName `
            -vf "scale=$($size):$($size):flags=lanczos" @($target.Format) $destination
        if ($LASTEXITCODE -ne 0) { throw "ffmpeg failed on $($source.Name) at $size px" }
    }
    Write-Host "  $($source.BaseName)"
}

Write-Host "$($sources.Count) icons written to store\achievements ($storeSize px) and ui\achievements ($uiSize px)."
