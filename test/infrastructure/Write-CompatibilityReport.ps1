[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [hashtable]$Report,

    [Parameter(Mandatory = $true)]
    [string]$ReportPath,

    [Parameter(Mandatory = $true)]
    [string]$SummaryPath
)

$reportDirectory = Split-Path -Parent $ReportPath
if (-not (Test-Path -LiteralPath $reportDirectory)) {
    New-Item -ItemType Directory -Path $reportDirectory -Force | Out-Null
}

$Report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $ReportPath -Encoding UTF8

$lines = @(
    "## Compatibility test: $($Report.TestSurface)",
    '',
    "- **Outcome:** $($Report.Outcome)",
    "- **Target:** $($Report.Target)",
    "- **Runner:** $($Report.Runner.OperatingSystem), PowerShell $($Report.Runner.PowerShellVersion)",
    "- **Tested (UTC):** $($Report.TestedAtUtc)",
    ''
)

if ($Report.DeploymentUtilityVersion) {
    $lines += "- **Selected deployment utility product major:** $($Report.DeploymentUtilityVersion)"
}
if ($null -ne $Report.ModelCompatibilityLevel) {
    $lines += "- **Model compatibility level:** expected $($Report.ModelCompatibilityLevel), observed $($Report.ActualModelCompatibilityLevel)"
}
if ($Report.ActualServerMode) {
    $lines += "- **Observed SSAS mode:** $($Report.ActualServerMode)"
}
if ($Report.SqlServerEdition) {
    $lines += "- **SQL Server edition:** $($Report.SqlServerEdition)"
}
if ($Report.InstallOrder) {
    $lines += "- **SSMS install order:** $($Report.InstallOrder)"
}
if ($null -ne $Report.InstallationDurationSeconds) {
    $lines += "- **SSMS installation duration:** $($Report.InstallationDurationSeconds) seconds"
}
if ($Report.InstallationDurations) {
    foreach ($installation in $Report.InstallationDurations) {
        $lines += "- **SSMS $($installation.SsmsMajor) installation duration:** $($installation.Seconds) seconds"
    }
}
if ($null -ne $Report.OverlappingPathOccurrences) {
    $lines += "- **Occurrences for the overlapping utility path:** $($Report.OverlappingPathOccurrences)"
}
if ($Report.DeploymentUtilityVersion -or $null -ne $Report.ModelCompatibilityLevel -or $Report.ActualServerMode -or $Report.SqlServerEdition -or $Report.InstallOrder -or $Report.InstallationDurations -or $null -ne $Report.InstallationDurationSeconds -or $null -ne $Report.OverlappingPathOccurrences) {
    $lines += ''
}

if ($Report.DeploymentUtilities.Count -gt 0) {
    $lines += @(
        '| Path | File version | Product version |',
        '|------|--------------|-----------------|'
    )
    foreach ($utility in $Report.DeploymentUtilities) {
        $escapedPath = ([string]$utility.Path).Replace('|', '\|')
        $lines += "| ``$escapedPath`` | $($utility.FileVersion) | $($utility.ProductVersion) |"
    }
}
else {
    $lines += 'No Microsoft.AnalysisServices.Deployment.exe was found. This is recorded as an installation/coverage failure, not a successful compatibility result.'
}

if ($Report.InstallationMessage) {
    $lines += @('', "**Installation:** $($Report.InstallationMessage)")
}
if ($Report.TestMessage) {
    $lines += @('', "**Tests:** $($Report.TestMessage)")
}
if ($Report.UnsupportedReason) {
    $lines += @('', "**Unsupported:** $($Report.UnsupportedReason)")
}
if ($Report.Limitations) {
    $lines += @('', '### Limitations')
    foreach ($limitation in $Report.Limitations) {
        $lines += "- $limitation"
    }
}

Add-Content -LiteralPath $SummaryPath -Value ($lines -join [Environment]::NewLine) -Encoding UTF8
