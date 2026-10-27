[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('2017', '2019', '2022', '2025')]
    [string]$SsasVersion,

    [Parameter(Mandatory = $true)]
    [ValidateSet('Tabular', 'Multidimensional')]
    [string]$Mode,

    [Parameter(Mandatory = $true)]
    [ValidateSet('20', '22')]
    [string]$SsmsMajor,

    [Parameter(Mandatory = $true)]
    [string]$ReportPath,

    [Parameter(Mandatory = $true)]
    [string]$TestResultPath,

    [Parameter(Mandatory = $true)]
    [string]$DiagnosticsPath,

    [Parameter(Mandatory = $true)]
    [string]$LogDirectory
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$diagnostics = Get-Content -LiteralPath $DiagnosticsPath -Raw | ConvertFrom-Json
$ssmsInstances = @(& (Join-Path $PSScriptRoot 'Get-InstalledSsmsInstances.ps1'))
$inventory = @(& (Join-Path $PSScriptRoot 'Get-DeploymentToolInventory.ps1'))
$ssasServer = 'localhost\DCUBE'
$sourceDatabaseCreated = $false
$modelPath = $null
$testResult = $null
$testMessage = $null
$unsupportedReason = $null
$actualMode = $null
$selectedDeploymentUtility = $null
$selectedVersion = $null
$sqlServerEdition = $null
$installationMessage = 'SSAS installation result is unknown; inspect setup logs.'
$modelCompatibilityLevel = if ($SsasVersion -eq '2017') { 1200 } else { 1500 }
$outcome = 'Failed'

try {
    Import-Module (Join-Path $repositoryRoot 'DeployCube\DeployCube.psd1') -Force -ErrorAction Stop
    if (-not (Get-Module -ListAvailable -Name SqlServer)) {
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
        Install-Module -Name SqlServer -Force -Scope CurrentUser -ErrorAction Stop
    }
    Import-Module SqlServer -ErrorAction Stop

    $editionResult = Invoke-Sqlcmd `
        -ServerInstance 'localhost' `
        -Database 'master' `
        -Query "SELECT CONVERT(nvarchar(128), SERVERPROPERTY('Edition')) AS Edition" `
        -ErrorAction Stop
    $sqlServerEdition = [string]$editionResult.Edition
    if ($sqlServerEdition -notmatch 'Developer') {
        throw "The installed SQL Server edition is '$sqlServerEdition', not Developer. This matrix requires Developer Edition and will not treat Evaluation or another edition as equivalent."
    }

    if (-not ($ssmsInstances | Where-Object { $_.MajorVersion -eq [int]$SsmsMajor })) {
        throw "SSMS $SsmsMajor is not installed on this runner."
    }
    if ($inventory.Count -eq 0) {
        throw 'No Microsoft.AnalysisServices.Deployment.exe was found after SSMS installation.'
    }
    if (-not (Ping-SsasServer -Server $ssasServer)) {
        throw "Analysis Services instance '$ssasServer' is not reachable."
    }
    $actualMode = Get-ServerMode -Server $ssasServer
    if ($actualMode -ne $Mode) {
        throw "Expected SSAS mode '$Mode' but '$ssasServer' reports '$actualMode'."
    }
    $installationMessage = "SSAS $SsasVersion $Mode instance '$ssasServer' is running and reports mode '$actualMode'."
    $selectedVersion = Select-AnalysisServicesDeploymentExeVersion -PreferredVersion latest
    if (-not $selectedVersion) {
        throw 'DeployCube could not select an installed deployment utility.'
    }
    $selectedPath = Get-AnalysisServicesDeploymentExePath -Version $selectedVersion
    $selectedDeploymentUtility = $inventory | Where-Object {
        [System.StringComparer]::OrdinalIgnoreCase.Equals($_.Path, $selectedPath)
    } | Select-Object -First 1

    if ($Mode -eq 'Multidimensional') {
        $unsupportedReason = 'The repository currently has no checked-in or buildable Multidimensional .asdatabase fixture. The server installation and mode are verified, but a deployment is not claimed.'
        $outcome = 'Unsupported'
    }
    else {
        $modelPath = & (Join-Path $PSScriptRoot 'Build-CompatibilityModel.ps1') `
            -CompatibilityLevel ([string]$modelCompatibilityLevel) `
            -LogDirectory $LogDirectory

        $env:COMPAT_SSAS_VERSION = $SsasVersion
        $env:COMPAT_SSAS_MODE = $Mode
        $env:COMPAT_SSMS_MAJOR = $SsmsMajor
        $env:COMPAT_MODEL_PATH = $modelPath
        $env:COMPAT_MODEL_COMPATIBILITY = [string]$modelCompatibilityLevel

        $sourceQuery = @'
IF DB_ID(N'DatabaseToPublish') IS NULL
    CREATE DATABASE [DatabaseToPublish];

IF SUSER_ID(N'NT Service\MSOLAP$DCUBE') IS NULL
    CREATE LOGIN [NT Service\MSOLAP$DCUBE] FROM WINDOWS;

USE [DatabaseToPublish];
IF OBJECT_ID(N'dbo.MyOnlyTable', N'U') IS NULL
    CREATE TABLE dbo.MyOnlyTable
    (
        MyOnlyTableId int NOT NULL PRIMARY KEY,
        MyOnlyColumn nvarchar(100) NULL,
        MyOnlyValue decimal(18, 2) NULL,
        InMyCurrency nvarchar(10) NULL
    );

IF NOT EXISTS (SELECT 1 FROM dbo.MyOnlyTable)
    INSERT dbo.MyOnlyTable (MyOnlyTableId, MyOnlyColumn, MyOnlyValue, InMyCurrency)
    VALUES (1, N'Compatibility test', 1.00, N'USD');

IF USER_ID(N'NT Service\MSOLAP$DCUBE') IS NULL
    CREATE USER [NT Service\MSOLAP$DCUBE] FOR LOGIN [NT Service\MSOLAP$DCUBE];
ALTER ROLE db_datareader ADD MEMBER [NT Service\MSOLAP$DCUBE];
'@
        $sourceDatabaseCreated = $true
        Invoke-Sqlcmd -ServerInstance 'localhost' -Database 'master' -Query $sourceQuery -ErrorAction Stop

        if (-not (Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version.Major -ge 5 })) {
            Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
            Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -Scope CurrentUser -ErrorAction Stop
        }
        Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop

        $configuration = New-PesterConfiguration
        $configuration.Run.Path = Join-Path $PSScriptRoot 'Test-SsasDeployment.ps1'
        $configuration.Run.Exit = $false
        $configuration.Run.PassThru = $true
        $configuration.TestResult.Enabled = $true
        $configuration.TestResult.OutputPath = $TestResultPath
        $configuration.TestResult.OutputFormat = 'NUnitXml'
        $testResult = Invoke-Pester -Configuration $configuration
        $testMessage = "Passed $($testResult.PassedCount), failed $($testResult.FailedCount), skipped $($testResult.SkippedCount)."
        $outcome = if ($testResult.FailedCount -eq 0) { 'Passed' } else { 'Failed' }
    }
}
catch {
    $testMessage = $_.Exception.Message
    $outcome = 'Failed'
}
finally {
    if ($sourceDatabaseCreated) {
        try {
            Invoke-Sqlcmd `
                -ServerInstance 'localhost' `
                -Database 'master' `
                -Query "IF DB_ID(N'DatabaseToPublish') IS NOT NULL BEGIN ALTER DATABASE [DatabaseToPublish] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [DatabaseToPublish]; END" `
                -ErrorAction Stop
        }
        catch {
            $outcome = 'Failed'
            $cleanupMessage = "Test source database cleanup failed: $($_.Exception.Message)"
            $testMessage = if ($testMessage) { "$testMessage $cleanupMessage" } else { $cleanupMessage }
        }
    }
}

$report = @{
    SchemaVersion = 1
    TestSurface = 'SSAS deployment integration'
    Target = "SSAS $SsasVersion $Mode, SSMS $SsmsMajor deployment utility"
    Outcome = $outcome
    SsasVersion = $SsasVersion
    SsasMode = $Mode
    SsmsMajor = $SsmsMajor
    DeploymentUtilityVersion = $selectedVersion
    SelectedDeploymentUtility = $selectedDeploymentUtility
    SqlServerEdition = $sqlServerEdition
    ModelCompatibilityLevel = if ($Mode -eq 'Tabular') { $modelCompatibilityLevel } else { $null }
    ActualServerMode = if ($env:COMPAT_ACTUAL_SSAS_MODE) { $env:COMPAT_ACTUAL_SSAS_MODE } else { $actualMode }
    ActualModelCompatibilityLevel = if ($env:COMPAT_ACTUAL_MODEL_COMPATIBILITY) {
        [int]$env:COMPAT_ACTUAL_MODEL_COMPATIBILITY
    } else { $null }
    TestedAtUtc = [DateTime]::UtcNow.ToString('o')
    Runner = @{
        OperatingSystem = $diagnostics.OperatingSystem
        PowerShellVersion = $diagnostics.PowerShellVersion
        ComputerName = $diagnostics.ComputerName
        TotalPhysicalMemoryBytes = $diagnostics.TotalPhysicalMemoryBytes
        FreePhysicalMemoryBytes = $diagnostics.FreePhysicalMemoryBytes
        Drives = $diagnostics.Drives
    }
    SsmsInstances = @($ssmsInstances | Where-Object { $_.MajorVersion -eq [int]$SsmsMajor })
    DeploymentUtilities = @($inventory)
    InstallationMessage = $installationMessage
    TestMessage = $testMessage
    UnsupportedReason = $unsupportedReason
    TestResults = if ($testResult) {
        @{
            Passed = $testResult.PassedCount
            Failed = $testResult.FailedCount
            Skipped = $testResult.SkippedCount
            Total = $testResult.TotalCount
        }
    } else { $null }
    Limitations = @(
        'A passing result applies only to the exact SSAS mode/version and SSMS deployment utility version recorded here.',
        'Tabular processing requires the local DatabaseToPublish source table. Processing errors are reported as failed compatibility, not silently skipped.'
    )
}

& (Join-Path $PSScriptRoot 'Write-CompatibilityReport.ps1') `
    -Report $report `
    -ReportPath $ReportPath `
    -SummaryPath $env:GITHUB_STEP_SUMMARY

if ($outcome -ne 'Passed') {
    throw "SSAS compatibility outcome is '$outcome'. See the JSON report, setup logs, and NUnit results."
}
