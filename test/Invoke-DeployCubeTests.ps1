[CmdletBinding()]
param(
    [ValidateSet('Unit', 'Analyzer')][string]$Type = 'Unit',
    [switch]$CodeCoverage,
    [string]$OutputPath = (Join-Path (Split-Path $PSScriptRoot -Parent) 'TestResults'),
    [switch]$CI
)
$ErrorActionPreference = 'Stop'
if ($CodeCoverage -and $Type -ne 'Unit') {
    throw 'Only the Unit suite supports module code coverage.'
}
$modules = Import-LocalizedData -BaseDirectory $PSScriptRoot -FileName RequiredModules
foreach ($module in $modules) {
    Import-Module -Name $module.ModuleName -RequiredVersion $module.RequiredVersion -Force -ErrorAction Stop
}
$selection = Import-PowerShellDataFile (Join-Path $PSScriptRoot 'TestSelection.psd1')
. (Join-Path $PSScriptRoot 'Assert-ValidationResult.ps1')
New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
$configuration = New-PesterConfiguration
$configuration.Run.Path = if ($Type -eq 'Unit') {
    @($selection.UnitPaths | ForEach-Object { (Resolve-Path (Join-Path $PSScriptRoot $_) -ErrorAction Stop).Path })
} else {
    @(Join-Path $PSScriptRoot 'Analyzer')
}
$configuration.Run.PassThru = $true
$configuration.Output.Verbosity = 'Normal'
if ($CI) { $configuration.Output.CIFormat = 'GithubActions' }
$configuration.TestResult.Enabled = $true
$configuration.TestResult.OutputFormat = 'NUnitXml'
$configuration.TestResult.OutputPath = Join-Path $OutputPath "TestResults-$Type.xml"
if ($CodeCoverage) {
    $configuration.CodeCoverage.Enabled = $true
    $configuration.CodeCoverage.Path = @(Join-Path (Split-Path $PSScriptRoot -Parent) $selection.CoveragePath)
    $configuration.CodeCoverage.OutputFormat = 'JaCoCo'
    $configuration.CodeCoverage.OutputPath = Join-Path $OutputPath 'Coverage-Unit.xml'
    $configuration.CodeCoverage.CoveragePercentTarget = $selection.MinimumCoverage
}
$result = Invoke-Pester -Configuration $configuration
if ($CodeCoverage) {
    $coverage = $result.CodeCoverage
    [ordered]@{
        CommandsAnalyzed = $coverage.CommandsAnalyzedCount
        CommandsExecuted = $coverage.CommandsExecutedCount
        FilesAnalyzed = $coverage.FilesAnalyzedCount
        MinimumPercent = $selection.MinimumCoverage
        Scope = $selection.CoveragePath
        MissedCommands = @($coverage.MissedCommands | Select-Object File, Function, Line, Command)
    } | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $OutputPath 'CoverageSummary.json') -Encoding UTF8
}
Assert-ValidationResult -Result $result -CodeCoverage:$CodeCoverage -MinimumCoverage $selection.MinimumCoverage
