[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$LogDirectory
)

$ErrorActionPreference = 'Stop'
Import-Module SqlServer -ErrorAction Stop
function New-IntegerDataItem {
    param([string]$Column)
    $item = New-Object Microsoft.AnalysisServices.DataItem('Fact', $Column)
    $integerName = if ([enum]::GetNames($item.Type.GetType()) -contains 'Int32') { 'Int32' } else { 'Integer' }
    $item.Type = [enum]::Parse($item.Type.GetType(), $integerName)
    return $item
}
$outputDirectory = Join-Path $LogDirectory 'fixture-multidimensional'
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
$database = New-Object Microsoft.AnalysisServices.Database('DeployCubeMultidimensional', 'DeployCubeMultidimensional')
$database.CompatibilityLevel = 1100
$validationServer = New-Object Microsoft.AnalysisServices.Server
$validationServer.Databases.Add($database) | Out-Null
$dataSource = New-Object Microsoft.AnalysisServices.RelationalDataSource('Local fixture', 'LocalFixture')
$dataSource.ConnectionString = 'Provider=MSOLEDBSQL;Data Source=(localdb)\DeployCubeFixture;Initial Catalog=DeployCubeFixtureSource;Integrated Security=SSPI;'
$dataSource.ImpersonationInfo = New-Object Microsoft.AnalysisServices.ImpersonationInfo(
    [Microsoft.AnalysisServices.ImpersonationMode]::ImpersonateServiceAccount)
$database.DataSources.Add($dataSource) | Out-Null

$schema = New-Object System.Data.DataSet('FixtureSchema')
$table = $schema.Tables.Add('Fact')
$table.ExtendedProperties.Add('DbSchemaName', 'dbo')
$table.ExtendedProperties.Add('DbTableName', 'Fact')
$table.ExtendedProperties.Add('FriendlyName', 'Fact')
$key = $table.Columns.Add('ItemKey', [int])
$key.AllowDBNull = $false
$amount = $table.Columns.Add('Amount', [int])
$amount.AllowDBNull = $false
$table.PrimaryKey = @($key)
$view = New-Object Microsoft.AnalysisServices.DataSourceView('Fixture view', 'FixtureView')
$view.DataSourceID = $dataSource.ID
$view.Schema = $schema
$database.DataSourceViews.Add($view) | Out-Null

$dimension = New-Object Microsoft.AnalysisServices.Dimension('Item', 'Item')
$dimension.Source = New-Object Microsoft.AnalysisServices.DataSourceViewBinding($view.ID)
$attribute = New-Object Microsoft.AnalysisServices.DimensionAttribute('Item', 'ItemKey')
$attribute.Usage = [Microsoft.AnalysisServices.AttributeUsage]::Key
$attribute.KeyColumns.Add((New-IntegerDataItem -Column 'ItemKey')) | Out-Null
$dimension.Attributes.Add($attribute) | Out-Null
$database.Dimensions.Add($dimension) | Out-Null

$cube = New-Object Microsoft.AnalysisServices.Cube('Fixture Cube', 'FixtureCube')
$database.Cubes.Add($cube) | Out-Null
$cube.Source = New-Object Microsoft.AnalysisServices.DataSourceViewBinding($view.ID)
$cube.Dimensions.Add($dimension.ID) | Out-Null
$measureGroup = New-Object Microsoft.AnalysisServices.MeasureGroup('Fact', 'Fact')
$measureGroup.StorageMode = [Microsoft.AnalysisServices.StorageMode]::Molap
$measure = New-Object Microsoft.AnalysisServices.Measure('Amount', 'Amount')
$measure.AggregateFunction = [Microsoft.AnalysisServices.AggregationFunction]::Sum
$measure.DataType = 'Integer'
$measure.Source = New-IntegerDataItem -Column 'Amount'
$measureGroup.Measures.Add($measure) | Out-Null
$groupDimension = New-Object Microsoft.AnalysisServices.RegularMeasureGroupDimension($dimension.ID)
$granularity = New-Object Microsoft.AnalysisServices.MeasureGroupAttribute($attribute.ID)
$granularity.Type = [Microsoft.AnalysisServices.MeasureGroupAttributeType]::Granularity
$granularity.KeyColumns.Add((New-IntegerDataItem -Column 'ItemKey')) | Out-Null
$groupDimension.Attributes.Add($granularity) | Out-Null
$measureGroup.Dimensions.Add($groupDimension) | Out-Null
$partition = New-Object Microsoft.AnalysisServices.Partition('Fact', 'Fact')
$partition.Source = New-Object Microsoft.AnalysisServices.QueryBinding($dataSource.ID, 'SELECT ItemKey, Amount FROM dbo.Fact')
$partition.StorageMode = [Microsoft.AnalysisServices.StorageMode]::Molap
$measureGroup.Partitions.Add($partition) | Out-Null
$cube.MeasureGroups.Add($measureGroup) | Out-Null
$mdx = New-Object Microsoft.AnalysisServices.MdxScript('Default', 'Default')
$mdx.Commands.Add((New-Object Microsoft.AnalysisServices.Command('CALCULATE;'))) | Out-Null
$cube.MdxScripts.Add($mdx) | Out-Null

$validation = New-Object Microsoft.AnalysisServices.ValidationResultCollection
if (-not $database.Validate($validation)) {
    throw "Multidimensional AMO fixture validation failed: $($validation | Out-String)"
}
$modelPath = Join-Path $outputDirectory 'Model.asdatabase'
$settings = New-Object System.Xml.XmlWriterSettings
$settings.Indent = $true
$writer = [System.Xml.XmlWriter]::Create($modelPath, $settings)
try {
    [Microsoft.AnalysisServices.Utils]::Serialize($writer, $database, $false)
}
finally {
    $writer.Dispose()
}
$reader = [System.Xml.XmlReader]::Create($modelPath)
try {
    $roundTrip = [Microsoft.AnalysisServices.Utils]::Deserialize($reader, (New-Object Microsoft.AnalysisServices.Database))
    . (Join-Path $PSScriptRoot 'Assert-MultidimensionalMetadata.ps1')
    $null = Assert-MultidimensionalMetadata -Database $roundTrip
    if ($roundTrip.Cubes.Count -ne 1 -or $roundTrip.Dimensions.Count -ne 1 -or
        $roundTrip.Cubes[0].MeasureGroups[0].Measures.Count -ne 1) {
        throw 'AMO XML round-trip lost required multidimensional fixture objects.'
    }
}
finally {
    $reader.Dispose()
}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'fixtures/Tabular1500/Model.deploymentoptions') -Destination $outputDirectory -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'fixtures/Tabular1500/Model.deploymenttargets') -Destination $outputDirectory -Force
[pscustomobject]@{
    Outcome = 'Passed'
    Format = 'AMO multidimensional Database XML'
    CompatibilityLevel = $database.CompatibilityLevel
    DataSource = $dataSource.ConnectionString
    Cube = $cube.ID
    Dimension = $dimension.ID
    MeasureGroup = $measureGroup.ID
    Measure = $measure.ID
    Processing = 'DoNotProcess'
} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $outputDirectory 'fixture-validation.json') -Encoding UTF8
return $modelPath
