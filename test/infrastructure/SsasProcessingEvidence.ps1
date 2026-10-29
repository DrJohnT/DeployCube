function Invoke-ProcessingSourceSql {
    param([Parameter(Mandatory = $true)][string]$Query, [string]$Database = 'master')
    $connection = New-Object System.Data.SqlClient.SqlConnection(
        "Data Source=lpc:.\DCUBESOURCE;Initial Catalog=$Database;Integrated Security=True;Connect Timeout=15")
    try {
        $connection.Open()
        $command = $connection.CreateCommand()
        $command.CommandTimeout = 30
        $command.CommandText = $Query
        $table = New-Object System.Data.DataTable
        $reader = $command.ExecuteReader()
        try { $table.Load($reader) } finally { $reader.Dispose() }
        return ,$table
    }
    finally { $connection.Dispose() }
}

function Assert-ProcessingSource {
    param([Parameter(Mandatory = $true)]$Row)
    if ($Row.TableCount -ne 1 -or $Row.ColumnCount -ne 2 -or
        $Row.SourceRecordCount -ne 1 -or $Row.ItemKey -ne 1 -or $Row.SumAmount -ne 10) {
        throw 'Source database validation failed: expected dbo.Fact(ItemKey int, Amount int), exactly one row (1,10) and sum 10.'
    }
}

function Assert-MdxMeasureValue {
    param([Parameter(Mandatory = $true)][string]$Xml)
    [xml]$result = $Xml
    $cells = $result.SelectNodes("//*[local-name()='CellData']/*[local-name()='Cell']")
    if ($cells.Count -ne 1) { throw "MDX result must contain exactly one cell, got $($cells.Count)." }
    $value = $cells[0].SelectSingleNode("*[local-name()='Value']")
    if (-not $value) { throw 'MDX result has no measure value.' }
    $type = $value.GetAttribute('type', 'http://www.w3.org/2001/XMLSchema-instance')
    if ($type -notmatch '(^|:)(byte|short|int|integer|long|unsignedByte|unsignedShort|unsignedInt|unsignedLong|decimal|float|double)$') {
        throw "MDX result is not numeric (XML type '$type')."
    }
    $number = [decimal]0
    if (-not [decimal]::TryParse($value.InnerText, [System.Globalization.NumberStyles]::Float,
            [System.Globalization.CultureInfo]::InvariantCulture, [ref]$number) -or $number -ne 10) {
        throw "Incorrect measure value: expected numeric 10; got '$($value.InnerText)'."
    }
    return $number
}

function Get-ProcessFullXmla {
    param([Parameter(Mandatory = $true)][string]$Database, [switch]$DimensionOnly)
    $id = [System.Security.SecurityElement]::Escape($Database)
    $dimension = if ($DimensionOnly) { '<DimensionID>Item</DimensionID>' } else { '' }
    return "<Process xmlns='http://schemas.microsoft.com/analysisservices/2003/engine'><Object><DatabaseID>$id</DatabaseID>$dimension</Object><Type>ProcessFull</Type></Process>"
}

function Assert-SsasProcessingTarget {
    param(
        [Parameter(Mandatory = $true)][ValidateSet('2019', '2022', '2025')][string]$SsasVersion,
        [Parameter(Mandatory = $true)][string]$ProductVersion,
        [Parameter(Mandatory = $true)][string]$ServerMode,
        [Parameter(Mandatory = $true)][string]$Edition
    )
    $major = @{ '2019' = 15; '2022' = 16; '2025' = 17 }[$SsasVersion]
    if ($ProductVersion -notmatch ('^' + $major + '\.') -or $ServerMode -ne 'Multidimensional' -or
        $Edition -notmatch 'Developer') {
        throw "Expected SSAS $SsasVersion Developer Multidimensional (major $major), but received $ProductVersion $Edition $ServerMode."
    }
    return $major
}

function Get-ProcessingSourceReadEvidence {
    param(
        [Parameter(Mandatory = $true)][string]$Xml,
        [Parameter(Mandatory = $true)][string]$ServiceAccount,
        [Parameter(Mandatory = $true)][string]$Database
    )
    [xml]$document = $Xml
    $events = $document.SelectNodes("//*[local-name()='RingBufferTarget']/*[local-name()='event']")
    $result = foreach ($event in $events) {
        $principal = $event.SelectSingleNode(
            ".//*[local-name()='action' and @name='server_principal_name']/*[local-name()='value']")
        $databaseNode = $event.SelectSingleNode(
            ".//*[local-name()='action' and @name='database_name']/*[local-name()='value']")
        $statement = $event.SelectSingleNode(
            ".//*[local-name()='data' and @name='statement']/*[local-name()='value']")
        $evidence = [pscustomobject]@{
            Principal = if ($principal) { $principal.InnerText } else { $null }
            Database = if ($databaseNode) { $databaseNode.InnerText } else { $null }
            Statement = if ($statement) { $statement.InnerText } else { $null }
        }
        if ($evidence.Principal -ieq $ServiceAccount -and $evidence.Database -eq $Database -and
            $evidence.Statement -match '(?i)\bFact\b') {
            $evidence
        }
    }
    return @($result)
}

function Invoke-RecordedProcessFull {
    param(
        [Parameter(Mandatory = $true)]$Server,
        [Parameter(Mandatory = $true)][string]$Database,
        [Parameter(Mandatory = $true)][string]$Path,
        [switch]$DimensionOnly
    )
    $xmla = Get-ProcessFullXmla -Database $Database -DimensionOnly:$DimensionOnly
    $record = @{ Command = $xmla; Outcome = 'Failed'; DurationSeconds = $null; Messages = @(); Error = $null }
    $watch = [Diagnostics.Stopwatch]::StartNew()
    try {
        $results = $Server.Execute($xmla)
        $errors = @()
        foreach ($result in $results) {
            foreach ($message in $result.Messages) {
                $record.Messages += [pscustomobject]@{
                    Type = $message.GetType().Name
                    Description = $message.Description
                    Code = if ($message -is [Microsoft.AnalysisServices.XmlaError]) { $message.ErrorCode } else { $message.WarningCode }
                }
                if ($message -is [Microsoft.AnalysisServices.XmlaError]) { $errors += $message.Description }
            }
        }
        if ($errors.Count) { throw ($errors -join [Environment]::NewLine) }
        $record.Outcome = 'Passed'
    }
    catch {
        $record.Error = $_.Exception.ToString()
        throw
    }
    finally {
        $record.DurationSeconds = [math]::Round($watch.Elapsed.TotalSeconds, 2)
        $record | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath $Path -Encoding UTF8
    }
}
