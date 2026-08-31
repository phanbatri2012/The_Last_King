param(
    [string]$GodotPath = ".tools/godot/Godot_v4.7.2-stable_win64_console.exe"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$godotCandidate = if ([IO.Path]::IsPathRooted($GodotPath)) {
    $GodotPath
}
else {
    Join-Path $projectRoot $GodotPath
}
$resolvedGodot = Resolve-Path -LiteralPath $godotCandidate -ErrorAction Stop
$webTemplate = Join-Path $projectRoot "tools/export_templates/web_playables_release.zip"

if (-not (Test-Path -LiteralPath $webTemplate)) {
    throw "Missing custom Web template. Follow docs/toolchain-setup.md, then run tools/build_web_template.ps1."
}

& $resolvedGodot --headless --path $projectRoot --editor --quit
if ($LASTEXITCODE -ne 0) { throw "Godot project import failed." }

& $resolvedGodot --headless --path $projectRoot --script res://tests/run_tests.gd
if ($LASTEXITCODE -ne 0) { throw "Phase 0 tests failed." }

& $resolvedGodot --headless --path $projectRoot --quit-after 120
if ($LASTEXITCODE -ne 0) { throw "Bootstrap runtime smoke test failed." }

New-Item -ItemType Directory -Force -Path (Join-Path $projectRoot "build/windows") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $projectRoot "build/web") | Out-Null

& $resolvedGodot --headless --path $projectRoot --export-release "Windows Desktop" (Join-Path $projectRoot "build/windows/the-last-king.exe")
if ($LASTEXITCODE -ne 0) { throw "Windows export failed." }

& $resolvedGodot --headless --path $projectRoot --export-release "Web" (Join-Path $projectRoot "build/web/index.html")
if ($LASTEXITCODE -ne 0) { throw "Web export failed." }

& (Join-Path $PSScriptRoot "check_web_bundle.ps1") -BundlePath (Join-Path $projectRoot "build/web")
if ($LASTEXITCODE -ne 0) { throw "Web bundle validation failed." }

Write-Host "Phase 0 verification passed."
