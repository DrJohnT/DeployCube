[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$LogDirectory,
    [Parameter(Mandatory = $true)][string]$DatabaseName,
    [string]$SourceConnectionString = 'Provider=MSOLEDBSQL;Data Source=lpc:.\DCUBESOURCE;Initial Catalog=DeployCubeFixtureSource;Integrated Security=SSPI;Connect Timeout=5;',
    [string]$SourceQuery = 'SELECT ItemKey, Amount FROM dbo.Fact',
    [switch]$AllowInvalidSource
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'TabularProcessingEvidence.ps1')
Import-Module SqlServer -ErrorAction Stop

$outputDirectory = Join-Path $LogDirectory $DatabaseName
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
$model = New-TabularProcessingModel -DatabaseName $DatabaseName `
    -SourceConnectionString $SourceConnectionString -SourceQuery $SourceQuery
Assert-TabularProcessingModel -Model $model -DatabaseName $DatabaseName -AllowInvalidSource:$AllowInvalidSource
$modelPath = Join-Path $outputDirectory 'Model.asdatabase'
$json = $model | ConvertTo-Json -Depth 30
$json | Set-Content -LiteralPath $modelPath -Encoding UTF8

$tom = [Microsoft.AnalysisServices.Tabular.JsonSerializer]::DeserializeDatabase($json)
if ($tom.CompatibilityLevel -ne 1500 -or $tom.Name -ne $DatabaseName) {
    throw 'TOM rejected the processing fixture database identity or compatibility level.'
}
$table = $tom.Model.Tables.Find('Fact')
$partition = if ($table) { $table.Partitions.Find('Fact') }
$measure = if ($table) { $table.Measures.Find('Total Amount') }
if (-not $table -or -not $partition -or -not $measure -or
    $measure.Expression -ne 'SUM(Fact[Amount])' -or
    $partition.Source -isnot [Microsoft.AnalysisServices.Tabular.QueryPartitionSource] -or
    $partition.Source.DataSource.Name -ne 'ProcessingSource' -or
    $partition.Source.Query -ne $SourceQuery) {
    throw 'TOM round-trip did not preserve the Fact query partition, source binding, or numeric measure.'
}
$dataSource = $tom.Model.DataSources.Find('ProcessingSource')
if (-not $dataSource -or $dataSource.ImpersonationMode -ne
    [Microsoft.AnalysisServices.Tabular.ImpersonationMode]::ImpersonateServiceAccount) {
    throw 'TOM round-trip did not preserve the ProcessingSource service-account impersonation.'
}

Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'fixtures/Tabular1500/Model.deploymentoptions') `
    -Destination (Join-Path $outputDirectory 'Model.deploymentoptions') -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'fixtures/Tabular1500/Model.deploymenttargets') `
    -Destination (Join-Path $outputDirectory 'Model.deploymenttargets') -Force

[pscustomobject]@{
    Outcome = 'Passed'
    Database = $DatabaseName
    CompatibilityLevel = $tom.CompatibilityLevel
    Tables = @($table.Name)
    Columns = @($table.Columns | ForEach-Object { @{ Name = $_.Name; DataType = [string]$_.DataType; SourceColumn = $_.SourceColumn } })
    Partition = @{ Name = $partition.Name; Mode = [string]$partition.Mode; SourceType = $partition.Source.GetType().Name; Query = $partition.Source.Query }
    Measure = @{ Name = $measure.Name; Expression = $measure.Expression }
    DataSource = @{ Name = $dataSource.Name; ImpersonationMode = [string]$dataSource.ImpersonationMode }
    Format = 'TOM JSON accepted as an Analysis Services Deployment Utility project'
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $outputDirectory 'fixture-validation.json') -Encoding UTF8
return $modelPath
