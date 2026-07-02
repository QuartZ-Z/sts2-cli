[CmdletBinding()]
param(
    [string]$GameDir,
    [string]$ConfigPath = (Join-Path $PSScriptRoot "config.json"),
    [switch]$ValidateOnly
)

$ErrorActionPreference = "Stop"
$Root = $PSScriptRoot
$LibDir = Join-Path $Root "lib"
if (-not $PSBoundParameters.ContainsKey("ConfigPath") -and $env:STS2_CLI_CONFIG) {
    $ConfigPath = $env:STS2_CLI_CONFIG
}

if (-not $GameDir -and $env:STS2_GAME_DIR) {
    $GameDir = $env:STS2_GAME_DIR
}
if (-not $GameDir -and (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
    $Config = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $GameDir = $Config.game_path
}
if (-not $GameDir) {
    $Candidates = foreach ($Drive in "C", "D", "E", "F", "G") {
        "$Drive`:\Program Files (x86)\Steam\steamapps\common\Slay the Spire 2"
        "$Drive`:\Program Files\Steam\steamapps\common\Slay the Spire 2"
        "$Drive`:\SteamLibrary\steamapps\common\Slay the Spire 2"
        "$Drive`:\Games\Steam\steamapps\common\Slay the Spire 2"
    }
    $GameDir = $Candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Container } |
        Select-Object -First 1
}
if (-not $GameDir -or -not (Test-Path -LiteralPath $GameDir -PathType Container)) {
    throw "Slay the Spire 2 directory was not found. Set game_path in config.json or pass -GameDir."
}

$Dotnet = Get-Command dotnet -ErrorAction SilentlyContinue
if (-not $Dotnet) { throw ".NET 9+ SDK was not found on PATH." }
$SdkVersions = @(& $Dotnet.Source --list-sdks)
$HasDotnet9 = $SdkVersions | Where-Object {
    $Version = ($_ -split "\s+")[0]
    $Major = 0
    [int]::TryParse(($Version -split "\.")[0], [ref]$Major) -and $Major -eq 9
}
if (-not $HasDotnet9) { throw ".NET 9 SDK was not found." }

$RequiredDlls = @(
    "sts2.dll", "SmartFormat.dll", "SmartFormat.ZString.dll", "Sentry.dll",
    "Steamworks.NET.dll", "MonoMod.Backports.dll", "MonoMod.ILHelpers.dll",
    "0Harmony.dll", "System.IO.Hashing.dll"
)

function Find-GameDll([string]$Name) {
    $DirectPath = Join-Path $GameDir $Name
    if (Test-Path -LiteralPath $DirectPath -PathType Leaf) {
        return $DirectPath
    }
    return Get-ChildItem -LiteralPath $GameDir -Filter $Name -File -Recurse -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty FullName
}

if ($ValidateOnly) {
    $Missing = @()
    Write-Host "Game directory: $GameDir"
    Write-Host ".NET SDK: $($SdkVersions -join ', ')"
    foreach ($Dll in $RequiredDlls) {
        if (Find-GameDll $Dll) {
            Write-Host "  OK $Dll"
        }
        else {
            Write-Host "  MISSING $Dll"
            $Missing += $Dll
        }
    }
    if ($Missing.Count -gt 0) {
        throw "Validation failed: $($Missing.Count) required DLL(s) are missing."
    }
    Write-Host "Validation passed. No files were changed."
    return
}

New-Item -ItemType Directory -Path $LibDir -Force | Out-Null
Write-Host "Game directory: $GameDir"
Write-Host "Copying game DLLs..."

foreach ($Dll in $RequiredDlls) {
    $Source = Find-GameDll $Dll
    if ($Source) {
        Copy-Item -LiteralPath $Source -Destination (Join-Path $LibDir $Dll) -Force
        Write-Host "  OK $Dll"
    }
    else {
        Write-Warning "$Dll was not found."
    }
}

$Sts2Dll = Join-Path $LibDir "sts2.dll"
if (-not (Test-Path -LiteralPath $Sts2Dll -PathType Leaf)) {
    throw "sts2.dll could not be copied from $GameDir."
}
$Backup = "$Sts2Dll.original"
if (-not (Test-Path -LiteralPath $Backup -PathType Leaf)) {
    Copy-Item -LiteralPath $Sts2Dll -Destination $Backup
}

Write-Host "Applying headless IL patches..."
& $Dotnet.Source run --project (Join-Path $Root "src\Sts2Patcher\Sts2Patcher.csproj") -- $Sts2Dll
if ($LASTEXITCODE -ne 0) { throw "IL patching failed." }

Write-Host "Building sts2-cli..."
& $Dotnet.Source build (Join-Path $Root "src\Sts2Headless\Sts2Headless.csproj")
if ($LASTEXITCODE -ne 0) { throw "Build failed." }

Write-Host ""
Write-Host "Setup complete. Start with: py -3 .\launch.py"
