<#
.SYNOPSIS
    Runs the DeployCube Pester suites.

.DESCRIPTION
    Single entry point for local runs and CI.

      Analyzer     PSScriptAnalyzer gate for DeployCube/ (no infrastructure required)
      Unit         Mocked unit tests (no SQL Server, SSAS or deployment utility required)
      Integration  Live SSAS tests. Explicit opt-in: requires Windows, an SSAS Tabular instance,
                   Microsoft.AnalysisServices.Deployment.exe, the SqlServer module and the built example models.
      Azure        Live Azure Analysis Services tests. Explicit opt-in: requires the Azure* environment variables.

    Unit is the default. Integration/Azure set DEPLOYCUBE_RUN_INTEGRATION / DEPLOYCUBE_RUN_AZURE_INTEGRATION for this
    process only, which is what un-skips those suites.

.EXAMPLE
    ./test/Invoke-DeployCubeTests.ps1

.EXAMPLE
    ./test/Invoke-DeployCubeTests.ps1 -Type Analyzer, Unit -CodeCoverage -CI

.EXAMPLE
    $env:DEPLOYCUBE_SSAS_SERVER = 'ssas-test01'
    ./test/Invoke-DeployCubeTests.ps1 -Type Integration
#>
[CmdletBinding()]
param(
    [ValidateSet('Analyzer', 'Unit', 'Integration', 'Azure')]
    [string[]]$Type = @('Unit'),

    # Optional Pester tag filters applied in addition to -Type.
    [string[]]$Tag,
    [string[]]$ExcludeTag,

    # Collect code coverage for DeployCube/public (JaCoCo format).
    [switch]$CodeCoverage,

    # Folder for NUnit XML results and coverage. Defaults to <repo>/TestResults.
    [string]$OutputPath,

    # CI mode: emit CI-friendly (GitHub Actions) error annotations. Failures always throw, giving a non-zero exit code.
    [switch]$CI,

    # For Integration: skip the fast-fail prerequisite check.
    [switch]$SkipPrerequisiteCheck
)

$ErrorActionPreference = 'Stop'

. (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.ps1')

$requiredModules = Import-LocalizedData -BaseDirectory $PSScriptRoot -FileName RequiredModules
foreach ($spec in $requiredModules) {
    if (-not (Get-Module -ListAvailable -Name $spec.ModuleName | Where-Object { $_.Version -eq [version]$spec.RequiredVersion })) {
        throw "$($spec.ModuleName) $($spec.RequiredVersion) is not installed. Run ./test/bootstrap.ps1 first."
    }
}
Get-Module -Name Pester | Remove-Module -Force
$pesterSpec = $requiredModules | Where-Object { $_.ModuleName -eq 'Pester' }
Import-Module -Name Pester -RequiredVersion $pesterSpec.RequiredVersion -Force

$repoRoot = Get-DeployCubeRepositoryRoot
if (-not $OutputPath) {
    $OutputPath = Join-Path -Path $repoRoot -ChildPath 'TestResults'
}
if (-not (Test-Path -Path $OutputPath)) {
    New-Item -Path $OutputPath -ItemType Directory | Out-Null
}

$folders = @{
    Analyzer    = 'Analyzer'
    Unit        = 'Unit'
    Integration = 'Integration'
    Azure       = 'Integration'
}

$paths = New-Object System.Collections.Generic.List[string]
foreach ($t in $Type) {
    $p = Join-Path -Path $PSScriptRoot -ChildPath $folders[$t]
    if (-not $paths.Contains($p)) {
        $paths.Add($p)
    }
}

$includeTags = New-Object System.Collections.Generic.List[string]
$excludeTags = New-Object System.Collections.Generic.List[string]
if ($Tag) { $Tag | ForEach-Object { $includeTags.Add($_) } }
if ($ExcludeTag) { $ExcludeTag | ForEach-Object { $excludeTags.Add($_) } }

$runsIntegration = $Type -contains 'Integration'
$runsAzure = $Type -contains 'Azure'
if ($runsIntegration -xor $runsAzure) {
    # Integration and Azure share a folder; keep them apart unless both were requested.
    if ($runsAzure) { $includeTags.Add('Azure') } else { $excludeTags.Add('Azure') }
}

$previousIntegration = $env:DEPLOYCUBE_RUN_INTEGRATION
$previousAzure = $env:DEPLOYCUBE_RUN_AZURE_INTEGRATION
try {
    if ($runsIntegration) {
        $env:DEPLOYCUBE_RUN_INTEGRATION = '1'
        if (-not $SkipPrerequisiteCheck) {
            Import-DeployCubeForTest
            $issues = @(Get-DeployCubeIntegrationPrerequisiteIssues)
            if ($issues.Count -gt 0) {
                $issues | ForEach-Object { Write-Host "Integration prerequisite missing: $_" -ForegroundColor Red }
                throw 'SSAS integration prerequisites are not met. See test/README.md.'
            }
        }
    }
    if ($runsAzure) {
        $env:DEPLOYCUBE_RUN_AZURE_INTEGRATION = '1'
    }

    $config = New-PesterConfiguration
    $config.Run.Path = $paths.ToArray()
    $config.Run.PassThru = $true
    $config.Output.Verbosity = 'Detailed'
    if ($includeTags.Count -gt 0) { $config.Filter.Tag = $includeTags.ToArray() }
    if ($excludeTags.Count -gt 0) { $config.Filter.ExcludeTag = $excludeTags.ToArray() }

    $label = ($Type | Sort-Object) -join '-'
    $config.TestResult.Enabled = $true
    $config.TestResult.OutputFormat = 'NUnitXml'
    $config.TestResult.OutputPath = Join-Path -Path $OutputPath -ChildPath "TestResults-$label.xml"
    $config.TestResult.TestSuiteName = "DeployCube-$label"

    if ($CodeCoverage) {
        $publicPath = Join-Path -Path (Join-Path -Path $repoRoot -ChildPath 'DeployCube') -ChildPath 'public'
        $config.CodeCoverage.Enabled = $true
        $config.CodeCoverage.Path = @(Get-ChildItem -Path $publicPath -Filter '*.ps1' | Select-Object -ExpandProperty FullName)
        $config.CodeCoverage.OutputFormat = 'JaCoCo'
        $config.CodeCoverage.OutputPath = Join-Path -Path $OutputPath -ChildPath "Coverage-$label.xml"
    }

    if ($CI) {
        $config.Output.CIFormat = 'Auto'
    }

    $result = Invoke-Pester -Configuration $config

    if ($CodeCoverage -and $result.CodeCoverage) {
        $cc = $result.CodeCoverage
        $percent = if ($cc.CommandsAnalyzedCount -gt 0) { [math]::Round(100 * $cc.CommandsExecutedCount / $cc.CommandsAnalyzedCount, 1) } else { 0 }
        Write-Host "Code coverage (DeployCube/public): $percent% of $($cc.CommandsAnalyzedCount) commands"
    }

    if ($result.Result -ne 'Passed') {
        throw "Pester run '$label' finished with result '$($result.Result)' (failed: $($result.FailedCount), failed blocks: $($result.FailedBlocksCount), failed containers: $($result.FailedContainersCount))."
    }
}
finally {
    $env:DEPLOYCUBE_RUN_INTEGRATION = $previousIntegration
    $env:DEPLOYCUBE_RUN_AZURE_INTEGRATION = $previousAzure
}
