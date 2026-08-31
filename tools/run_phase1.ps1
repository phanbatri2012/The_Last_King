param(
    [string]$GodotPath = ".tools/godot/Godot_v4.7.2-stable_win64_console.exe"
)

$ErrorActionPreference = "Stop"
$verificationScript = Join-Path $PSScriptRoot "run_phase0.ps1"

& $verificationScript -GodotPath $GodotPath
if ($LASTEXITCODE -ne 0) {
    throw "Phase 1 verification failed."
}

Write-Host "Phase 1 acceptance pipeline passed."
