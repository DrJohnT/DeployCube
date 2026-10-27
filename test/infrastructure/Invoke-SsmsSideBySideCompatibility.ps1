[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('20-then-22', '22-then-20')]
    [string]$InstallOrder,

    [Parameter(Mandatory = $true)]
    [string]$ReportPath,

    [Parameter(Mandatory = $true)]
    [string]$TestResultPath,

    [Parameter(Mandatory = $true)]
    [string]$DiagnosticsPath
)

$ErrorActionPreference = 'Stop'
$diagnostics = Get-Content -LiteralPath $DiagnosticsPath -Raw | ConvertFrom-Json
$ssmsInstances = @(& (Join-Path $PSScriptRoot 'Get-InstalledSsmsInstances.ps1'))
$inventory = @(& (Join-Path $PSScriptRoot 'Get-DeploymentToolInventory.ps1'))
$installationDirectory = Join-Path (Split-Path -Parent $ReportPath) 'installation'
$installationDurations = @(
    foreach ($major in @(20, 22)) {
        $installationReportPath = Join-Path $installationDirectory "ssms-$major-install.json"
        if (Test-Path -LiteralPath $installationReportPath) {
            $installation = Get-Content -LiteralPath $installationReportPath -Raw | ConvertFrom-Json
            [pscustomobject]@{
                SsmsMajor = $major
                Seconds = $installation.InstallationDurationSeconds
            }
        }
    }
)
$env:COMPAT_OVERLAPPING_PATH_OCCURRENCES = ''
$testResult = $null
$testMessage = $null

try {
    foreach ($major in @(20, 22)) {
        if (-not ($ssmsInstances | Where-Object { $_.MajorVersion -eq $major })) {
            throw "SSMS $major is not present after installation order '$InstallOrder'."
        }
    }

    $env:COMPAT_SSMS_MAJOR = '20+22'
    if (-not (Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version.Major -ge 5 })) {
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
        Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -Scope CurrentUser -ErrorAction Stop
    }
    Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop

    $configuration = New-PesterConfiguration
    $configuration.Run.Path = @(
        (Join-Path $PSScriptRoot 'Test-DeploymentToolDiscovery.ps1'),
        (Join-Path $PSScriptRoot 'Test-SsmsSideBySide.ps1')
    )
    $configuration.Run.Exit = $false
    $configuration.TestResult.Enabled = $true
    $configuration.TestResult.OutputPath = $TestResultPath
    $configuration.TestResult.OutputFormat = 'NUnitXml'
    $testResult = Invoke-Pester -Configuration $configuration -PassThru
    $testMessage = "Passed $($testResult.PassedCount), failed $($testResult.FailedCount), skipped $($testResult.SkippedCount)."
}
catch {
    $testMessage = $_.Exception.Message
}

$outcome = 'Passed'
if ($inventory.Count -eq 0 -or $null -eq $testResult -or $testResult.FailedCount -gt 0) {
    $outcome = 'Failed'
}

$report = @{
    SchemaVersion = 1
    TestSurface = 'SSMS 20 + SSMS 22 side-by-side deployment utility compatibility'
    Target = "SSMS installation order $InstallOrder"
    InstallOrder = $InstallOrder
    Outcome = $outcome
    TestedAtUtc = [DateTime]::UtcNow.ToString('o')
    InstallationDurations = $installationDurations
    Runner = @{
        OperatingSystem = $diagnostics.OperatingSystem
        PowerShellVersion = $diagnostics.PowerShellVersion
        ComputerName = $diagnostics.ComputerName
        TotalPhysicalMemoryBytes = $diagnostics.TotalPhysicalMemoryBytes
        FreePhysicalMemoryBytes = $diagnostics.FreePhysicalMemoryBytes
        Drives = $diagnostics.Drives
    }
    SsmsInstances = @($ssmsInstances | Where-Object { $_.MajorVersion -in @(20, 22) })
    DeploymentUtilities = @($inventory)
    OverlappingPathOccurrences = if ($env:COMPAT_OVERLAPPING_PATH_OCCURRENCES) {
        [int]$env:COMPAT_OVERLAPPING_PATH_OCCURRENCES
    } else { $null }
    TestMessage = $testMessage
    TestResults = if ($testResult) {
        @{
            Passed = $testResult.PassedCount
            Failed = $testResult.FailedCount
            Skipped = $testResult.SkippedCount
            Total = $testResult.TotalCount
        }
    } else { $null }
    Limitations = @(
        'Installation-order independence is observed on this runner only; this does not establish backward compatibility of each deployment utility with every SSAS server release.'
    )
}

& (Join-Path $PSScriptRoot 'Write-CompatibilityReport.ps1') `
    -Report $report `
    -ReportPath $ReportPath `
    -SummaryPath $env:GITHUB_STEP_SUMMARY

if ($outcome -ne 'Passed') {
    throw "SSMS side-by-side compatibility check failed. See the JSON report and NUnit test artifact."
}
