param(
    [string]$GodotSource = ".tools/godot-src-4.7.2",
    [string]$EmsdkPath = ".tools/emsdk",
    [string]$SConsPath = ".tools/build-venv/Scripts/scons.exe"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$sourcePath = (Resolve-Path -LiteralPath (Join-Path $projectRoot $GodotSource)).Path
$emsdkRoot = (Resolve-Path -LiteralPath (Join-Path $projectRoot $EmsdkPath)).Path
$scons = (Resolve-Path -LiteralPath (Join-Path $projectRoot $SConsPath)).Path
$profile = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "build_profiles/web_playables.py")).Path
$outputDirectory = Join-Path $PSScriptRoot "export_templates"
$outputTemplate = Join-Path $outputDirectory "web_playables_release.zip"

$emsdkEnvironment = Join-Path $emsdkRoot "emsdk_env.ps1"
if (-not (Test-Path -LiteralPath $emsdkEnvironment)) {
    throw "Missing emsdk environment script: $emsdkEnvironment"
}

. $emsdkEnvironment
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null

$jobs = [math]::Max(1, [Environment]::ProcessorCount - 1)
Push-Location $sourcePath
try {
    & $scons platform=web target=template_release threads=no dlink_enabled=no optimize=size_extra production=yes profile=$profile debug_symbols=no progress=no -j $jobs
    if ($LASTEXITCODE -ne 0) {
        throw "Godot Web template compilation failed."
    }

    $candidate = Get-ChildItem -LiteralPath (Join-Path $sourcePath "bin") -Filter "*.zip" |
        Where-Object { $_.Name -match 'web.*template_release.*nothreads|web.*nothreads.*release' } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if ($null -eq $candidate) {
        throw "Compiled Web template ZIP was not found."
    }

    Copy-Item -LiteralPath $candidate.FullName -Destination $outputTemplate -Force
}
finally {
    Pop-Location
}

Get-Item -LiteralPath $outputTemplate | Select-Object FullName, Length
