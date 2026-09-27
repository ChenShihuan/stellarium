<#
.SYNOPSIS
    Windows port of scripts/sync-ohos-resources.sh.

.DESCRIPTION
    Populates the generated hvigor project's rawfile tree with the Stellarium
    data files the C++ core needs at runtime.

    The bash version relies on rsync and ffmpeg. Neither ships with Git for
    Windows, so this port uses robocopy for the directory mirroring and
    System.Drawing for the two image compatibility passes:

      * 16-bit PNG textures are re-encoded to 8-bit RGBA
      * grayscale / indexed sky-culture illustrations are re-encoded to RGBA

    ArkUI ImageKit on HarmonyOS 7.0 rejects the encodings those files use
    upstream, so the normalisation is mandatory and not merely cosmetic.

    It also writes data/ohos/skyculture_art_rgba_v1.txt, the evidence file
    StellariumResourceBootstrap.ets requires before it hands off to Qt.

    Whatever is missing from rawfile/stellarium is simply never available on
    the device: the ArkTS bootstrap copies that tree into the app sandbox and
    points STELLARIUM_DATA_ROOT at it.

.PARAMETER RepoRoot
    Repository root. Defaults to the parent directory of this script.

.PARAMETER Out
    Destination rawfile directory. Defaults to
    build/libstellarium-harmonyos/entry/src/main/resources/rawfile/stellarium.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts/sync-ohos-resources-windows.ps1
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$Out
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot 'data'))) {
    throw "cannot find Stellarium source data at $RepoRoot\data"
}

if (-not $Out -or $Out -eq '') {
    $Out = Join-Path $RepoRoot 'build\libstellarium-harmonyos\entry\src\main\resources\rawfile\stellarium'
}
New-Item -ItemType Directory -Path $Out -Force | Out-Null

# Compile the upstream cross-language sky alias index first; it lives in data/
# and therefore must exist before data/ is mirrored.
$node = (Get-Command node -ErrorAction SilentlyContinue).Source
if ($node) {
    Push-Location $RepoRoot
    try { & node (Join-Path $RepoRoot 'scripts\build-ohos-multilingual-search-index.mjs') }
    finally { Pop-Location }
} else {
    Write-Warning 'node not found; reusing the committed data/search/multilingual-sky-aliases.tsv'
}

function Invoke-Mirror {
    param([string]$Source, [string]$Destination, [string[]]$Extra = @())
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    $rcArgs = @($Source, $Destination, '/MIR', '/NFL', '/NDL', '/NJH', '/NJS', '/NP', '/R:1', '/W:1') + $Extra
    & robocopy @rcArgs | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy failed (exit $LASTEXITCODE) for $Source" }
}

Write-Host '==> mirroring full data directories'
foreach ($dir in @('data', 'textures', 'landscapes', 'stars', 'translations', 'scenery3d')) {
    $source = Join-Path $RepoRoot $dir
    if (-not (Test-Path -LiteralPath $source)) { Write-Host "    SKIP (missing): $dir"; continue }
    Invoke-Mirror $source (Join-Path $Out $dir)
    Write-Host "    $dir"
}

Write-Host '==> mirroring nebulae (catalogue indexes and images only)'
Invoke-Mirror (Join-Path $RepoRoot 'nebulae') (Join-Path $Out 'nebulae') @('/IF', '*.dat', '*.json', '*.png')

Write-Host '==> mirroring skycultures (excluding CMake scaffolding)'
Invoke-Mirror (Join-Path $RepoRoot 'skycultures') (Join-Path $Out 'skycultures') `
    @('/XF', 'CMakeLists.txt', 'CMakeLists.txt.template', 'TODO.txt', '*.py')

# scripts/ holds Stellarium's .ssc sky tours together with this repository's own
# build helpers. Only the Stellarium assets may enter rawfile, otherwise hvigor
# flags stray sources and StelScriptMgr lists build scripts as sky tours.
Write-Host '==> mirroring scripts (*.ssc / *.inc only)'
$scriptsSource = Join-Path $RepoRoot 'scripts'
$scriptsDestination = Join-Path $Out 'scripts'
if (Test-Path -LiteralPath $scriptsDestination) { Remove-Item -LiteralPath $scriptsDestination -Recurse -Force }
New-Item -ItemType Directory -Path $scriptsDestination -Force | Out-Null
$scriptCount = 0
foreach ($file in (Get-ChildItem -LiteralPath $scriptsSource -Recurse -File -Force)) {
    if ($file.Extension -ne '.ssc' -and $file.Extension -ne '.inc') { continue }
    $relative = $file.FullName.Substring($scriptsSource.Length).TrimStart('\')
    $target = Join-Path $scriptsDestination $relative
    $parent = Split-Path -Parent $target
    if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    Copy-Item -LiteralPath $file.FullName -Destination $target -Force
    $scriptCount++
}
Write-Host "    $scriptCount script file(s)"

function Get-PngFormat {
    param([string]$Path)
    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $header = New-Object byte[] 26
        [void]$stream.Read($header, 0, 26)
    } finally { $stream.Close() }
    $isIhdr = $header[12] -eq 0x49 -and $header[13] -eq 0x48 -and $header[14] -eq 0x44 -and $header[15] -eq 0x52
    if (-not $isIhdr) { return @{ BitDepth = -1; ColorType = -1 } }
    return @{ BitDepth = [int]$header[24]; ColorType = [int]$header[25] }
}

function Convert-PngToRgba {
    param([string]$Path)
    $image = [System.Drawing.Image]::FromFile($Path)
    try {
        $bitmap = New-Object System.Drawing.Bitmap($image.Width, $image.Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.Clear([System.Drawing.Color]::Transparent)
            $graphics.DrawImage($image, 0, 0, $image.Width, $image.Height)
        } finally { $graphics.Dispose() }
        $temporary = "$Path.rgba.png"
        $bitmap.Save($temporary, [System.Drawing.Imaging.ImageFormat]::Png)
        $bitmap.Dispose()
    } finally { $image.Dispose() }
    Move-Item -LiteralPath $temporary -Destination $Path -Force
}

Write-Host '==> normalising 16-bit textures'
$textureCount = 0
foreach ($png in (Get-ChildItem -LiteralPath (Join-Path $Out 'textures') -Recurse -File -Filter '*.png')) {
    if ((Get-PngFormat $png.FullName).BitDepth -eq 16) { Convert-PngToRgba $png.FullName; $textureCount++ }
}
Write-Host "    converted $textureCount 16-bit PNG(s)"

Write-Host '==> normalising grayscale / indexed sky-culture illustrations'
$artCount = 0
foreach ($png in (Get-ChildItem -LiteralPath (Join-Path $Out 'skycultures') -Recurse -File -Filter '*.png')) {
    if ($png.DirectoryName -notmatch '\\illustrations$') { continue }
    $colorType = (Get-PngFormat $png.FullName).ColorType
    if ($colorType -eq 0 -or $colorType -eq 3 -or $colorType -eq 4) { Convert-PngToRgba $png.FullName; $artCount++ }
}
Write-Host "    converted $artCount grayscale/indexed PNG(s)"

$markerDirectory = Join-Path $Out 'data\ohos'
New-Item -ItemType Directory -Path $markerDirectory -Force | Out-Null
[System.IO.File]::WriteAllText((Join-Path $markerDirectory 'skyculture_art_rgba_v1.txt'), "sky-culture-art-rgba-v1`n")

$total = (Get-ChildItem -LiteralPath $Out -Recurse -File -Force | Measure-Object Length -Sum).Sum
Write-Host ''
Write-Host ('rawfile/stellarium size : {0:N0} MB' -f ($total / 1MB))
Write-Host ('skyculture count        : {0}' -f (Get-ChildItem -LiteralPath (Join-Path $Out 'skycultures') -Directory -ErrorAction SilentlyContinue).Count)
Write-Host ('script count            : {0}' -f (Get-ChildItem -LiteralPath (Join-Path $Out 'scripts') -Recurse -File -Filter '*.ssc' -ErrorAction SilentlyContinue).Count)

# These are the exact paths StellariumResourceBootstrap.hasStartupResourceFiles()
# requires before Qt is allowed to start.
$required = @(
    'stars/hip_gaia3/defaultStarsConfig.json',
    'data/ohos/skyculture_art_rgba_v1.txt',
    'translations/stellarium/zh_CN.qm',
    'translations/stellarium-sky/zh_CN.qm',
    'translations/stellarium-skycultures/zh_CN.qm',
    'translations/stellarium-scripts/zh_CN.qm',
    'skycultures/modern/index.json',
    'skycultures/modern/illustrations/andromeda.png',
    'scripts/constellations_tour.ssc',
    'data/default_cfg.ini'
)
$missing = 0
foreach ($relative in $required) {
    $candidate = Join-Path $Out ($relative -replace '/', '\')
    if (Test-Path -LiteralPath $candidate) {
        Write-Host "    OK   $relative"
    } else {
        Write-Host "    MISS $relative"
        $missing++
    }
}
if ($missing -gt 0) { throw "$missing required startup resource(s) are missing; Qt will refuse to start" }
