param(
    [string]$BundlePath = "build/web"
)

$ErrorActionPreference = "Stop"
$resolvedBundle = Resolve-Path -LiteralPath $BundlePath -ErrorAction Stop
$files = Get-ChildItem -LiteralPath $resolvedBundle -File -Recurse

if ($files.Count -eq 0) {
    throw "Web bundle contains no files: $resolvedBundle"
}

$totalBytes = ($files | Measure-Object -Property Length -Sum).Sum
$maxTotalBytes = 250MB
$maxIndividualBytes = 30MB
$invalidNames = @($files | Where-Object { $_.Name -notmatch '^[A-Za-z0-9_.-]+$' })
$oversizedFiles = @($files | Where-Object { $_.Length -ge $maxIndividualBytes })

$summary = [pscustomobject]@{
    FileCount = $files.Count
    TotalMiB = [math]::Round($totalBytes / 1MB, 2)
    LargestFileMiB = [math]::Round(($files | Sort-Object Length -Descending | Select-Object -First 1).Length / 1MB, 2)
    UnderTotalLimit = $totalBytes -lt $maxTotalBytes
    UnderIndividualLimit = $oversizedFiles.Count -eq 0
    ValidFileNames = $invalidNames.Count -eq 0
}

$summary | Format-List

if (-not $summary.UnderTotalLimit) {
    throw "Web bundle is at or above the 250 MiB total limit."
}
if (-not $summary.UnderIndividualLimit) {
    $oversizedFiles | Select-Object FullName, Length | Format-Table
    throw "One or more Web bundle files are at or above the 30 MiB individual limit."
}
if (-not $summary.ValidFileNames) {
    $invalidNames | Select-Object FullName | Format-Table
    throw "One or more Web bundle filenames contain unsupported characters."
}
