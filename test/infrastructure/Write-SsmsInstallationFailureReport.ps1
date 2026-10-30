[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('18', '19', '20', '21', '22')]
    [string]$SsmsMajor,

    [Parameter(Mandatory = $true)]
    [string]$InstallationFailurePath,

    [Parameter(Mandatory = $true)]
    [string]$DiagnosticsPath,

    [Parameter(Mandatory = $true)]
    [string]$ReportPath
)

$ErrorActionPreference = 'Stop'
$installationFailure = Get-Content -LiteralPath $InstallationFailurePath -Raw | ConvertFrom-Json
$diagnostics = Get-Content -LiteralPath $DiagnosticsPath -Raw | ConvertFrom-Json
$report = @{
    SchemaVersion = 1
    TestSurface = 'SSMS deployment utility compatibility'
    Target = "SSMS $SsmsMajor"
    SsmsMajor = $SsmsMajor
    Outcome = 'Failed'
    TestedAtUtc = [DateTime]::UtcNow.ToString('o')
    InstallationDurationSeconds = $installationFailure.InstallationDurationSeconds
    UnsupportedDeploymentUtilityProductMajors = @()
    UnsupportedReason = $null
    Runner = @{
        OperatingSystem = $diagnostics.OperatingSystem
        PowerShellVersion = $diagnostics.PowerShellVersion
        ComputerName = $diagnostics.ComputerName
        TotalPhysicalMemoryBytes = $diagnostics.TotalPhysicalMemoryBytes
        FreePhysicalMemoryBytes = $diagnostics.FreePhysicalMemoryBytes
        Drives = $diagnostics.Drives
    }
    DeploymentUtilities = @()
    InstallationMessage = $installationFailure.Error
    TestMessage = 'Discovery and Pester tests were not run because installation failed.'
    TestResults = $null
    Limitations = @('No successful SSMS installation is claimed.')
}

& (Join-Path $PSScriptRoot 'Write-CompatibilityReport.ps1') `
    -Report $report `
    -ReportPath $ReportPath `
    -SummaryPath $env:GITHUB_STEP_SUMMARY
