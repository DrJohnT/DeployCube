BeforeAll {
    . (Join-Path $PSScriptRoot 'infrastructure/SsasProcessingEvidence.ps1')
    function New-MdxResult {
        param([string]$Type = 'xsd:int', [string]$Value = '10')
        return "<root xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance'><CellData><Cell CellOrdinal='0'><Value xsi:type='$Type'>$Value</Value></Cell></CellData></root>"
    }
}

Describe 'Phase G actual data assertions' {
    It 'accepts exactly the expected source schema and row' {
        { Assert-ProcessingSource -Row ([pscustomobject]@{
            TableCount = 1; ColumnCount = 2; RowCount = 1; ItemKey = 1; SumAmount = 10
        }) } | Should -Not -Throw
    }
    It 'rejects incorrect source <Field>' -ForEach @(
        @{ Field = 'TableCount'; Value = 0 }
        @{ Field = 'ColumnCount'; Value = 1 }
        @{ Field = 'RowCount'; Value = 2 }
        @{ Field = 'ItemKey'; Value = 2 }
        @{ Field = 'SumAmount'; Value = 20 }
    ) {
        $row = [pscustomobject]@{ TableCount = 1; ColumnCount = 2; RowCount = 1; ItemKey = 1; SumAmount = 10 }
        $row.$Field = $Value
        { Assert-ProcessingSource -Row $row } | Should -Throw '*Source database validation failed*'
    }
    It 'accepts a numeric MDX measure 10 of type <Type>' -ForEach @(
        @{ Type = 'xsd:int' }; @{ Type = 'xsd:long' }; @{ Type = 'xsd:double' }; @{ Type = 'xsd:decimal' }
    ) {
        Assert-MdxMeasureValue -Xml (New-MdxResult -Type $Type) | Should -Be 10
    }
    It 'rejects string data even when it contains 10' {
        { Assert-MdxMeasureValue -Xml (New-MdxResult -Type 'xsd:string') } | Should -Throw '*not numeric*'
    }
    It 'rejects an incorrect measure value' {
        { Assert-MdxMeasureValue -Xml (New-MdxResult -Value '11') } | Should -Throw '*Incorrect measure value*'
    }
    It 'rejects invalid numeric content' {
        { Assert-MdxMeasureValue -Xml (New-MdxResult -Value 'NaN') } | Should -Throw '*Incorrect measure value*'
    }
    It 'rejects missing measure cells and XMLA errors' {
        { Assert-MdxMeasureValue -Xml '<root><Error Description="MDX failed"/></root>' } | Should -Throw '*exactly one cell*'
    }
    It 'rejects an empty measure' {
        { Assert-MdxMeasureValue -Xml '<root><CellData><Cell/></CellData></root>' } | Should -Throw '*no measure value*'
    }
    It 'rejects ambiguous multiple cells' {
        { Assert-MdxMeasureValue -Xml '<root><CellData><Cell/><Cell/></CellData></root>' } | Should -Throw '*exactly one cell*'
    }
    It 'targets ProcessFull at a specific database and dimension for the connectivity gate' {
        [xml]$command = Get-ProcessFullXmla -Database 'PhaseG&Test' -DimensionOnly
        $command.Process.Type | Should -Be 'ProcessFull'
        $command.Process.Object.DatabaseID | Should -Be 'PhaseG&Test'
        $command.Process.Object.DimensionID | Should -Be 'Item'
    }
    It 'targets whole-database ProcessFull for isolated negative tests' {
        [xml]$command = Get-ProcessFullXmla -Database 'PhaseGNegative'
        $command.Process.Type | Should -Be 'ProcessFull'
        $command.Process.Object.DatabaseID | Should -Be 'PhaseGNegative'
        $command.Process.Object.DimensionID | Should -BeNullOrEmpty
    }
}
