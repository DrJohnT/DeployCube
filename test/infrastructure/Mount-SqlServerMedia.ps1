[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$IsoPath,
    [Parameter(Mandatory = $true)][ValidateSet('2017', '2019', '2022', '2025')][string]$SsasVersion,
    [Parameter(Mandatory = $true)][string]$LogDirectory
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'SqlServerMedia.ps1')
New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
$report = [ordered]@{ Outcome = 'Failed'; IsoPath = $IsoPath; Stage = 'Mount ISO'; Error = $null }
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
try {
    Assert-SqlServerIso -Path $IsoPath
    $image = Mount-DiskImage -ImagePath $IsoPath -PassThru -ErrorAction Stop
    $volume = $image | Get-Volume -ErrorAction Stop
    if (-not $volume.DriveLetter) {
        throw "Mounted ISO '$IsoPath' has no drive letter."
    }
    $mediaRoot = "$($volume.DriveLetter):\"
    $report.Stage = 'Validate mounted media'
    $expectedMajor = @{ '2017' = 14; '2019' = 15; '2022' = 16; '2025' = 17 }[$SsasVersion]
    $report.SetupProductVersion = Assert-SqlServerMediaRoot -MediaRoot $mediaRoot -ExpectedMajor $expectedMajor
    $report.MediaRoot = $mediaRoot
    $report.Outcome = 'Passed'
    Write-Host "Verified signed SQL Server setup $($report.SetupProductVersion) at $mediaRoot."
    if ($env:GITHUB_OUTPUT) {
        Add-Content -LiteralPath $env:GITHUB_OUTPUT -Value "media-root=$mediaRoot" -Encoding UTF8
    }
}
catch {
    $report.Error = $_.Exception.ToString()
    Write-Error -Message $report.Error -ErrorAction Continue
    throw
}
finally {
    $report.DurationSeconds = [math]::Round($stopwatch.Elapsed.TotalSeconds, 2)
    $report | ConvertTo-Json -Depth 5 |
        Set-Content -LiteralPath (Join-Path $LogDirectory 'media-validation.json') -Encoding UTF8
}
