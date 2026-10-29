function New-TabularProcessingModel {
    param(
        [Parameter(Mandatory = $true)][string]$DatabaseName,
        [string]$SourceConnectionString = 'Provider=MSOLEDBSQL;Data Source=lpc:.\DCUBESOURCE;Initial Catalog=DeployCubeFixtureSource;Integrated Security=SSPI;Connect Timeout=5;',
        [string]$SourceQuery = 'SELECT ItemKey, Amount FROM dbo.Fact'
    )

    if ($SourceConnectionString -match '(?i)(?:^|;)\s*(?:password|pwd|user\s*id|uid)\s*=') {
        throw 'The Tabular processing fixture must not contain SQL credentials.'
    }

    return [pscustomobject]@{
        name = $DatabaseName
        id = $DatabaseName
        compatibilityLevel = 1500
        model = [pscustomobject]@{
            culture = 'en-US'
            dataSources = @(
                [pscustomobject]@{
                    name = 'ProcessingSource'
                    connectionString = $SourceConnectionString
                    impersonationMode = 'impersonateServiceAccount'
                }
            )
            tables = @(
                [pscustomobject]@{
                    name = 'Fact'
                    columns = @(
                        [pscustomobject]@{
                            name = 'ItemKey'
                            dataType = 'int64'
                            sourceColumn = 'ItemKey'
                            isHidden = $true
                            summarizeBy = 'none'
                        },
                        [pscustomobject]@{
                            name = 'Amount'
                            dataType = 'int64'
                            sourceColumn = 'Amount'
                            summarizeBy = 'none'
                        }
                    )
                    measures = @(
                        [pscustomobject]@{
                            name = 'Total Amount'
                            expression = 'SUM(Fact[Amount])'
                            formatString = '0'
                        }
                    )
                    partitions = @(
                        [pscustomobject]@{
                            name = 'Fact'
                            mode = 'import'
                            source = [pscustomobject]@{
                                type = 'query'
                                query = $SourceQuery
                                dataSource = 'ProcessingSource'
                            }
                        }
                    )
                }
            )
            annotations = @(
                [pscustomobject]@{
                    name = 'ClientCompatibilityLevel'
                    value = '600'
                }
            )
        }
    }
}

function Assert-TabularProcessingModel {
    param(
        [Parameter(Mandatory = $true)]$Model,
        [Parameter(Mandatory = $true)][string]$DatabaseName,
        [switch]$AllowInvalidSource
    )

    if ($Model.compatibilityLevel -ne 1500 -or $Model.name -ne $DatabaseName -or $Model.id -ne $DatabaseName) {
        throw 'Tabular fixture must target the requested database at compatibility level 1500.'
    }
    if (@($Model.model.dataSources).Count -ne 1 -or $Model.model.dataSources[0].name -ne 'ProcessingSource' -or
        $Model.model.dataSources[0].impersonationMode -ne 'impersonateServiceAccount') {
        throw 'Tabular fixture must have one ProcessingSource that impersonates the SSAS service account.'
    }
    $tables = @($Model.model.tables)
    if ($tables.Count -ne 1 -or $tables[0].name -ne 'Fact') {
        throw 'Tabular fixture must have exactly one imported Fact table.'
    }
    $columns = @($tables[0].columns)
    if ($columns.Count -ne 2 -or
        $columns[0].name -ne 'ItemKey' -or $columns[0].dataType -ne 'int64' -or $columns[0].sourceColumn -ne 'ItemKey' -or
        $columns[1].name -ne 'Amount' -or $columns[1].dataType -ne 'int64' -or $columns[1].sourceColumn -ne 'Amount') {
        throw 'Fact columns must map the SQL int ItemKey and Amount source columns to Tabular int64 columns.'
    }
    $measures = @($tables[0].measures)
    if ($measures.Count -ne 1 -or $measures[0].name -ne 'Total Amount' -or
        $measures[0].expression -ne 'SUM(Fact[Amount])') {
        throw 'Tabular fixture must define Total Amount as SUM(Fact[Amount]).'
    }
    $partitions = @($tables[0].partitions)
    if ($partitions.Count -ne 1 -or $partitions[0].name -ne 'Fact' -or $partitions[0].mode -ne 'import' -or
        $partitions[0].source.type -ne 'query' -or $partitions[0].source.dataSource -ne 'ProcessingSource') {
        throw 'Fact must have one import query partition bound to ProcessingSource.'
    }
    if (-not $AllowInvalidSource -and $partitions[0].source.query -ne 'SELECT ItemKey, Amount FROM dbo.Fact') {
        throw 'The successful fixture partition must query dbo.Fact.'
    }
    if ($AllowInvalidSource -and $partitions[0].source.query -notmatch '(?i)\bDeployCubePhaseHMissingTable\b') {
        throw 'The missing-table fixture must target its isolated nonexistent source object.'
    }
    if ([string]$Model.model.dataSources[0].connectionString -match
        '(?i)(?:^|;)\s*(?:password|pwd|user\s*id|uid)\s*=') {
        throw 'The Tabular processing fixture must not contain SQL credentials.'
    }
}

function Assert-TabularDaxResult {
    param([Parameter(Mandatory = $true)]$Value)

    if ($null -eq $Value -or $Value -is [string] -or $Value -is [DBNull]) {
        throw 'DAX result must be a non-null numeric value.'
    }
    try {
        $number = [decimal]::Parse(
            [string]$Value,
            [System.Globalization.NumberStyles]::Float,
            [System.Globalization.CultureInfo]::InvariantCulture
        )
    }
    catch {
        throw "DAX result '$Value' is not numeric."
    }
    if ($number -ne 10) {
        throw "Incorrect DAX result: expected numeric 10; got '$number'."
    }
    return $number
}

function New-TabularDaxXmlaQuery {
    param([Parameter(Mandatory = $true)][string]$DatabaseName, [Parameter(Mandatory = $true)][string]$Query)
    $document = New-Object System.Xml.XmlDocument
    $execute = $document.CreateElement('Execute', 'urn:schemas-microsoft-com:xml-analysis')
    $document.AppendChild($execute) | Out-Null
    $command = $document.CreateElement('Command', $execute.NamespaceURI)
    $execute.AppendChild($command) | Out-Null
    $statement = $document.CreateElement('Statement', $execute.NamespaceURI)
    $statement.InnerText = $Query
    $command.AppendChild($statement) | Out-Null
    $properties = $document.CreateElement('Properties', $execute.NamespaceURI)
    $execute.AppendChild($properties) | Out-Null
    $propertyList = $document.CreateElement('PropertyList', $execute.NamespaceURI)
    $properties.AppendChild($propertyList) | Out-Null
    $catalog = $document.CreateElement('Catalog', $execute.NamespaceURI)
    $catalog.InnerText = $DatabaseName
    $propertyList.AppendChild($catalog) | Out-Null
    foreach ($property in @(
        @{ Name = 'Format'; Value = 'Tabular' }
        @{ Name = 'Content'; Value = 'Data' }
    )) {
        $element = $document.CreateElement($property.Name, $execute.NamespaceURI)
        $element.InnerText = $property.Value
        $propertyList.AppendChild($element) | Out-Null
    }
    return $document.OuterXml
}

function Get-TabularDaxResult {
    param(
        [Parameter(Mandatory = $true)][string]$DatabaseName,
        [Parameter(Mandatory = $true)][string]$Query,
        [Parameter(Mandatory = $true)][string]$MeasureColumn
    )
    $xmla = New-TabularDaxXmlaQuery -DatabaseName $DatabaseName -Query $Query
    $response = Invoke-ASCmd -Server 'localhost\DCUBE' -Database $DatabaseName `
        -Query $xmla -QueryTimeout 120 -ConnectionTimeout 30 -ErrorAction Stop
    $responseXml = [string]($response | Out-String)
    return ConvertFrom-TabularDaxResponse -Xml $responseXml -MeasureColumn $MeasureColumn
}

function ConvertFrom-TabularDaxResponse {
    param([Parameter(Mandatory = $true)][string]$Xml, [Parameter(Mandatory = $true)][string]$MeasureColumn)
    [xml]$document = $Xml
    $rows = $document.SelectNodes("//*[local-name()='row']")
    if ($rows.Count -ne 1) { throw "DAX query must return exactly one row, got $($rows.Count)." }
    $valueNode = $rows[0].SelectSingleNode("*[local-name()='$MeasureColumn']")
    if (-not $valueNode) { throw "DAX result did not contain the '$MeasureColumn' column." }
    $schemaColumn = $document.SelectSingleNode(
        "//*[local-name()='schema']//*[local-name()='element' and @name='$MeasureColumn']")
    $typeName = if ($schemaColumn) { $schemaColumn.GetAttribute('type') } else { $null }
    if ($typeName -notmatch '(^|:)(byte|short|int|integer|long|unsignedByte|unsignedShort|unsignedInt|unsignedLong|decimal|float|double)$') {
        throw "DAX result column '$MeasureColumn' is not declared numeric (XML type '$typeName')."
    }
    $parsedValue = [decimal]0
    if (-not [decimal]::TryParse(
        $valueNode.InnerText,
        [System.Globalization.NumberStyles]::Float,
        [System.Globalization.CultureInfo]::InvariantCulture,
        [ref]$parsedValue
    )) {
        throw "DAX result '$($valueNode.InnerText)' is not a valid numeric value."
    }
    $numericValue = Assert-TabularDaxResult -Value $parsedValue
    return [pscustomobject]@{
        Value = $numericValue
        Type = $typeName
        Xml = $Xml
    }
}
