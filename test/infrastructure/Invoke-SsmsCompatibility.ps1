[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('18', '19', '20', '21', '22')]
    [string]$SsmsMajor,

    [Parameter(Mandatory = $true)]
    [string]$ReportPath,

    [Parameter(Mandatory = $true)]
    [string]$TestResultPath,

    [Parameter(Mandatory = $true)]
    [string]$DiagnosticsPath,

    [Parameter(Mandatory = $true)]
    [string]$InstallationReportPath
)

$ErrorActionPreference = 'Stop'
$diagnostics = Get-Content -LiteralPath $DiagnosticsPath -Raw | ConvertFrom-Json
$installation = Get-Content -LiteralPath $InstallationReportPath -Raw | ConvertFrom-Json
$inventory = @(& (Join-Path $PSScriptRoot 'Get-DeploymentToolInventory.ps1'))
$installationMessage = "SSMS $SsmsMajor installer completed."
$testMessage = $null
$testResult = $null

try {
    if (-not (Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version.Major -ge 5 })) {
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
        Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -Scope CurrentUser -ErrorAction Stop
    }
    Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop

    $env:COMPAT_SSMS_MAJOR = $SsmsMajor
    $configuration = New-PesterConfiguration
    $configuration.Run.Path = Join-Path $PSScriptRoot 'Test-DeploymentToolDiscovery.ps1'
    $configuration.Run.Exit = $false
    $configuration.TestResult.Enabled = $true
    $configuration.TestResult.OutputPath = $TestResultPath
    $configuration.TestResult.OutputFormat = 'NUnitXml'
    $testResult = Invoke-Pester -Configuration $configuration -PassThru
    $testMessage = "Passed $($testResult.PassedCount), failed $($testResult.FailedCount), skipped $($testResult.SkippedCount)."
}
catch {
    $testMessage = @(
        $_.Exception.ToString()
        $_.ScriptStackTrace
    ) -join [Environment]::NewLine
}

$outcome = 'Passed'
if ($inventory.Count -eq 0) {
    $outcome = 'Failed'
    $installationMessage = "SSMS $SsmsMajor installed, but no deployment utility was found."
}
if ($null -eq $testResult -or $testResult.FailedCount -gt 0) {
    $outcome = 'Failed'
}

$report = @{
    SchemaVersion = 1
    TestSurface = 'SSMS deployment utility compatibility'
    Target = "SSMS $SsmsMajor"
    SsmsMajor = $SsmsMajor
    Outcome = $outcome
    TestedAtUtc = [DateTime]::UtcNow.ToString('o')
    InstallationDurationSeconds = $installation.InstallationDurationSeconds
    Runner = @{
        OperatingSystem = $diagnostics.OperatingSystem
        PowerShellVersion = $diagnostics.PowerShellVersion
        ComputerName = $diagnostics.ComputerName
        TotalPhysicalMemoryBytes = $diagnostics.TotalPhysicalMemoryBytes
        FreePhysicalMemoryBytes = $diagnostics.FreePhysicalMemoryBytes
        Drives = $diagnostics.Drives
    }
    DeploymentUtilities = @($inventory)
    InstallationMessage = $installationMessage
    TestMessage = $testMessage
    TestResults = if ($testResult) {
        @{
            Passed = $testResult.PassedCount
            Failed = $testResult.FailedCount
            Skipped = $testResult.SkippedCount
            Total = $testResult.TotalCount
        }
    } else { $null }
    Limitations = @()
}

& (Join-Path $PSScriptRoot 'Write-CompatibilityReport.ps1') `
    -Report $report `
    -ReportPath $ReportPath `
    -SummaryPath $env:GITHUB_STEP_SUMMARY

if ($outcome -ne 'Passed') {
    throw "SSMS $SsmsMajor compatibility check failed. See the JSON report and NUnit test artifact."
}
