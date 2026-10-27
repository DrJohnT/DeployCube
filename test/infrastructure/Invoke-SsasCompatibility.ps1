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
    [string]$SsmsInstallationReportPath,

    [Parameter(Mandatory = $true)]
    [string]$SsasInstallationReportPath,

    [Parameter(Mandatory = $true)]
    [string]$LogDirectory
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$diagnostics = Get-Content -LiteralPath $DiagnosticsPath -Raw | ConvertFrom-Json
$ssmsInstances = @(& (Join-Path $PSScriptRoot 'Get-InstalledSsmsInstances.ps1'))
$inventory = @(& (Join-Path $PSScriptRoot 'Get-DeploymentToolInventory.ps1'))
$ssasInstallation = Get-Content -LiteralPath $SsasInstallationReportPath -Raw | ConvertFrom-Json
$ssmsInstallation = Get-Content -LiteralPath $SsmsInstallationReportPath -Raw | ConvertFrom-Json
$ssasServer = 'localhost\DCUBE'
$modelPath = $null
$testResult = $null
$testMessage = $null
$unsupportedReason = $null
$actualMode = $null
$actualSsasProductVersion = $null
$selectedDeploymentUtility = $null
$selectedVersion = $null
$analysisServicesEdition = $null
$installationMessage = 'SSAS installation result is unknown; inspect setup logs.'
$modelCompatibilityLevel = 1500
$outcome = 'Failed'
$failureCategory = 'Prerequisites'
$utilityProbe = $null

try {
    Import-Module (Join-Path $repositoryRoot 'DeployCube\DeployCube.psd1') -Force -ErrorAction Stop
    if (-not (Get-Module -ListAvailable -Name SqlServer)) {
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
        Install-Module -Name SqlServer -Force -Scope CurrentUser -ErrorAction Stop
    }
    Import-Module SqlServer -ErrorAction Stop

    if (-not ($ssmsInstances | Where-Object { $_.MajorVersion -eq [int]$SsmsMajor })) {
        throw "SSMS $SsmsMajor is not installed on this runner."
    }
    if ($inventory.Count -eq 0) {
        throw 'No Microsoft.AnalysisServices.Deployment.exe was found after SSMS installation.'
    }
    $failureCategory = 'SSAS connectivity'
    $service = Get-Service -Name 'MSOLAP$DCUBE' -ErrorAction Stop
    if ($service.Status -ne 'Running') {
        throw "Analysis Services service '$($service.Name)' is '$($service.Status)', not Running."
    }
    if (-not (Ping-SsasServer -Server $ssasServer)) {
        throw "Analysis Services instance '$ssasServer' is not reachable."
    }
    $amoServer = New-Object Microsoft.AnalysisServices.Server
    $amoServer.Connect($ssasServer)
    try {
        $actualMode = [string]$amoServer.ServerMode
        $actualSsasProductVersion = $amoServer.Version.ToString()
        $analysisServicesEdition = [string]$amoServer.Edition
    }
    finally {
        if ($amoServer.Connected) {
            $amoServer.Disconnect()
        }
    }
    if ($actualMode -ne $Mode) {
        throw "Expected SSAS mode '$Mode' but '$ssasServer' reports '$actualMode'."
    }
    if ($actualSsasProductVersion -notmatch '^16\.') {
        throw "Expected SQL Server Analysis Services 2022 product version 16.x, but '$ssasServer' reports '$actualSsasProductVersion'."
    }
    if ($analysisServicesEdition -notmatch 'Developer') {
        throw "Expected SSAS Developer Edition, but '$ssasServer' reports '$analysisServicesEdition'."
    }
    $installationMessage = "SSAS $SsasVersion $Mode $analysisServicesEdition instance '$ssasServer' is running, reports mode '$actualMode', and product version '$actualSsasProductVersion'."
    $selectedVersion = Select-AnalysisServicesDeploymentExeVersion -PreferredVersion latest
    if ($selectedVersion -ne $SsmsMajor) {
        throw "Expected SSMS $SsmsMajor deployment utility, but DeployCube selected product major '$selectedVersion'."
    }
    $selectedPath = Get-AnalysisServicesDeploymentExePath -Version $selectedVersion
    $selectedDeploymentUtility = $inventory | Where-Object {
        [System.StringComparer]::OrdinalIgnoreCase.Equals($_.Path, $selectedPath)
    } | Select-Object -First 1
    if (-not $selectedDeploymentUtility -or $selectedDeploymentUtility.ProductMajorVersion -ne [int]$SsmsMajor) {
        throw "Selected deployment utility metadata does not match SSMS $SsmsMajor."
    }

    if ($Mode -eq 'Multidimensional') {
        $unsupportedReason = 'The repository currently has no checked-in or buildable Multidimensional .asdatabase fixture. The server installation and mode are verified, but a deployment is not claimed.'
        $outcome = 'Unsupported'
    }
    else {
        $failureCategory = 'Test fixture validity'
        $modelPath = & (Join-Path $PSScriptRoot 'Build-CompatibilityModel.ps1') `
            -CompatibilityLevel ([string]$modelCompatibilityLevel) `
            -LogDirectory $LogDirectory
        $fixture = [Microsoft.AnalysisServices.Tabular.JsonSerializer]::DeserializeDatabase(
            (Get-Content -LiteralPath $modelPath -Raw))
        if ($fixture.CompatibilityLevel -ne $modelCompatibilityLevel) {
            throw 'TOM fixture validation returned an unexpected compatibility level.'
        }

        $failureCategory = 'Deployment Utility compatibility'
        & (Join-Path $PSScriptRoot 'Test-DeploymentUtilityCompatibility.ps1') `
            -DeploymentUtilityPath $selectedPath -ModelPath $modelPath `
            -Server $ssasServer -LogDirectory $LogDirectory
        $utilityProbe = Get-Content -LiteralPath (Join-Path $LogDirectory 'utility-probe\compatibility-probe.json') -Raw | ConvertFrom-Json

        $env:COMPAT_SSAS_VERSION = $SsasVersion
        $env:COMPAT_SSAS_MODE = $Mode
        $env:COMPAT_SSMS_MAJOR = $SsmsMajor
        $env:COMPAT_MODEL_PATH = $modelPath
        $env:COMPAT_MODEL_COMPATIBILITY = [string]$modelCompatibilityLevel
        $env:COMPAT_DEPLOYMENT_LOG_PATH = Join-Path (Split-Path -Parent $modelPath) 'Publish-Cube-deployment.log'

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
        $outcome = if ($testResult.FailedCount -eq 0 -and $testResult.PassedCount -eq 3) { 'Passed' } else { 'Failed' }
        $failureCategory = $env:COMPAT_FAILURE_CATEGORY
        if ($outcome -eq 'Failed') {
            $testMessage += "`n" + (($testResult.Failed | ForEach-Object { $_.ErrorRecord | Out-String }) -join "`n")
        }
    }
}
catch {
    $testMessage = $_.Exception.ToString()
    $outcome = 'Failed'
}

$report = @{
    SchemaVersion = 1
    TestSurface = 'SSAS deployment integration'
    Target = "SSAS $SsasVersion $Mode, SSMS $SsmsMajor deployment utility"
    Outcome = $outcome
    FailureCategory = if ($outcome -eq 'Failed') { $failureCategory } else { $null }
    UtilityCompatibilityProbe = $utilityProbe
    DatabaseExistsAfterPublish = $env:COMPAT_DATABASE_EXISTS -eq 'True'
    CleanupResult = $env:COMPAT_CLEANUP_RESULT
    AnalysisServicesService = if ($service) { @{ Name = $service.Name; Status = [string]$service.Status } } else { $null }
    SsmsInstallation = $ssmsInstallation.Installation
    InstallationDurationSeconds = $ssmsInstallation.InstallationDurationSeconds
    SsasVersion = $SsasVersion
    SsasMode = $Mode
    SsmsMajor = $SsmsMajor
    DeploymentUtilityVersion = $selectedVersion
    SelectedDeploymentUtility = $selectedDeploymentUtility
    AnalysisServicesEdition = $analysisServicesEdition
    ActualSsasProductVersion = $actualSsasProductVersion
    SetupProductVersion = $ssasInstallation.SetupProductVersion
    SsasInstallationDurationSeconds = $ssasInstallation.InstallationDurationSeconds
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
        'The self-contained calculated-table fixture does not test external data sources or processing.'
    )
}

& (Join-Path $PSScriptRoot 'Write-CompatibilityReport.ps1') `
    -Report $report `
    -ReportPath $ReportPath `
    -SummaryPath $env:GITHUB_STEP_SUMMARY

if ($outcome -ne 'Passed') {
    throw "SSAS compatibility outcome is '$outcome'. See the JSON report, setup logs, and NUnit results."
}
