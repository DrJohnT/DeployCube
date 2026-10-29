BeforeAll {
    . (Join-Path $PSScriptRoot 'infrastructure/SsasProcessingEvidence.ps1')
    . (Join-Path $PSScriptRoot 'infrastructure/TabularProcessingEvidence.ps1')
}

Describe 'Phase H Tabular processing fixture and DAX assertions' {
    BeforeEach {
        $script:model = New-TabularProcessingModel -DatabaseName 'DeployCubeTabularProcessingGood'
    }

    It 'creates a processable compatibility-1500 import model with a numeric measure' {
        { Assert-TabularProcessingModel -Model $script:model `
            -DatabaseName 'DeployCubeTabularProcessingGood' } | Should -Not -Throw
        $script:model.compatibilityLevel | Should -Be 1500
        $script:model.model.tables.Count | Should -Be 1
        $script:model.model.tables[0].name | Should -Be 'Fact'
        $script:model.model.tables[0].columns.Count | Should -Be 2
        $script:model.model.tables[0].columns[1].sourceColumn | Should -Be 'Amount'
        $script:model.model.tables[0].partitions[0].source.query |
            Should -Be 'SELECT ItemKey, Amount FROM dbo.Fact'
        $script:model.model.tables[0].measures[0].expression | Should -Be 'SUM(Fact[Amount])'
    }

    It 'uses compatibility 1500 for SSAS 2019/2022 and 1700 for SSAS 2025' {
        Get-TabularProcessingCompatibilityLevel -SsasVersion 2019 | Should -Be 1500
        Get-TabularProcessingCompatibilityLevel -SsasVersion 2022 | Should -Be 1500
        Get-TabularProcessingCompatibilityLevel -SsasVersion 2025 | Should -Be 1700
        $model2025 = New-TabularProcessingModel -DatabaseName 'DeployCubeTabularProcessing2025Good' `
            -CompatibilityLevel (Get-TabularProcessingCompatibilityLevel -SsasVersion 2025)
        { Assert-TabularProcessingModel -Model $model2025 `
            -DatabaseName 'DeployCubeTabularProcessing2025Good' -ExpectedCompatibilityLevel 1700 } |
            Should -Not -Throw
    }

    It 'requires the DAX measure to use the exact Fact table and Amount column' {
        $script:model.model.tables[0].measures[0].expression = 'SUM(Other[Amount])'
        { Assert-TabularProcessingModel -Model $script:model `
            -DatabaseName 'DeployCubeTabularProcessingGood' } |
            Should -Throw '*define Total Amount*'
    }

    It 'requires one import query partition bound to the fixture data source' {
        $script:model.model.tables[0].partitions[0].source.dataSource = 'OtherSource'
        { Assert-TabularProcessingModel -Model $script:model `
            -DatabaseName 'DeployCubeTabularProcessingGood' } |
            Should -Throw '*import query partition*'
    }

    It 'rejects credentials in source connection strings' {
        { New-TabularProcessingModel -DatabaseName 'Fixture' `
            -SourceConnectionString 'Provider=MSOLEDBSQL;Data Source=localhost;User ID=user;Password=secret;' } |
            Should -Throw '*must not contain SQL credentials*'
    }

    It 'requires the missing-table scenario to use its isolated nonexistent object' {
        $script:model.model.tables[0].partitions[0].source.query = 'SELECT ItemKey, Amount FROM dbo.Fact'
        { Assert-TabularProcessingModel -Model $script:model -DatabaseName 'DeployCubeTabularProcessingGood' `
            -AllowInvalidSource } | Should -Throw '*isolated nonexistent source object*'
    }

    It 'counts only the exact fact-table source query as SSAS read evidence' {
        $xml = @'
<RingBufferTarget xmlns="urn:sql:xevent"><event><action name="server_principal_name"><value>NT SERVICE\MSOLAP$DCUBE</value></action><action name="database_name"><value>DeployCubeFixtureSource</value></action><data name="statement"><value>SELECT HAS_PERMS_BY_NAME('dbo.Fact','OBJECT','SELECT')</value></data></event><event><action name="server_principal_name"><value>NT SERVICE\MSOLAP$DCUBE</value></action><action name="database_name"><value>DeployCubeFixtureSource</value></action><data name="statement"><value>SELECT ItemKey, Amount FROM dbo.Fact</value></data></event></RingBufferTarget>
'@
        $reads = @(Get-TabularFactSourceReadEvidence -Xml $xml `
            -ServiceAccount 'NT SERVICE\MSOLAP$DCUBE' -Database 'DeployCubeFixtureSource')
        $reads.Count | Should -Be 1
        $reads[0].Statement | Should -Be 'SELECT ItemKey, Amount FROM dbo.Fact'
    }

    It 'preserves dynamic result fields when restoring a report for cleanup' {
        $report = @{ Outcome = 'Failed'; Cleanup = 'Not tested' }
        $saved = [pscustomobject]@{
            Outcome = 'Passed'
            DaxOutcome = 'Passed'
            DaxResultType = 'xsd:long'
            TabularMetadata = @{ PartitionState = 'Ready' }
        }
        $restored = Restore-TabularProcessingReport -Report $report -SavedReport $saved
        $restored.DaxOutcome | Should -Be 'Passed'
        $restored.DaxResultType | Should -Be 'xsd:long'
        $restored.TabularMetadata.PartitionState | Should -Be 'Ready'
        $restored.Cleanup | Should -Be 'Not tested'
    }

    It 'accepts a numeric DAX result of 10' {
        Assert-TabularDaxResult -Value ([long]10) | Should -Be 10
    }

    It 'wraps the exact DAX statement in XMLA for the deployed model catalog' {
        [xml]$xmla = New-TabularDaxXmlaQuery -DatabaseName 'DeployCubeTabularProcessingGood' `
            -Query 'EVALUATE ROW("TotalAmount", [Total Amount])'
        $xmla.Execute.Command.Statement |
            Should -Be 'EVALUATE ROW("TotalAmount", [Total Amount])'
        $xmla.Execute.Properties.PropertyList.Catalog |
            Should -Be 'DeployCubeTabularProcessingGood'
        $xmla.Execute.Properties.PropertyList.Format | Should -Be 'Tabular'
        $xmla.Execute.Properties.PropertyList.Content | Should -Be 'SchemaData'
    }

    It 'reads and validates the numeric measure from an XMLA DAX rowset' {
        $xml = @'
<root xmlns="urn:schemas-microsoft-com:xml-analysis:rowset" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><xsd:schema><xsd:element name="row"><xsd:complexType><xsd:sequence><xsd:element name="_x005B_TotalAmount_x005D_" type="xsd:long" minOccurs="0"/></xsd:sequence></xsd:complexType></xsd:element></xsd:schema><row><_x005B_TotalAmount_x005D_>10</_x005B_TotalAmount_x005D_></row></root>
'@
        $result = ConvertFrom-TabularDaxResponse -Xml $xml -MeasureColumn 'TotalAmount'
        $result.Value | Should -Be 10
        $result.Type | Should -Be 'xsd:long'
        $result.Xml | Should -Be $xml
    }

    It 'reports returned DAX columns when the requested alias is absent' {
        $xml = @'
<root xmlns="urn:schemas-microsoft-com:xml-analysis:rowset" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><xsd:schema><xsd:element name="row"><xsd:complexType><xsd:sequence><xsd:element name="ActualAlias" type="xsd:long" minOccurs="0"/></xsd:sequence></xsd:complexType></xsd:element></xsd:schema><row><ActualAlias>10</ActualAlias></row></root>
'@
        { ConvertFrom-TabularDaxResponse -Xml $xml -MeasureColumn 'TotalAmount' } |
            Should -Throw "*Returned columns: 'ActualAlias'*"
    }

    It 'rejects a non-numeric DAX rowset column type' {
        $xml = @'
<root xmlns="urn:schemas-microsoft-com:xml-analysis:rowset" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><xsd:schema><xsd:element name="row"><xsd:complexType><xsd:sequence><xsd:element name="TotalAmount" type="xsd:string" minOccurs="0"/></xsd:sequence></xsd:complexType></xsd:element></xsd:schema><row><TotalAmount>10</TotalAmount></row></root>
'@
        { ConvertFrom-TabularDaxResponse -Xml $xml -MeasureColumn 'TotalAmount' } |
            Should -Throw '*not declared numeric*'
    }

    It 'rejects non-numeric and incorrect DAX values' -ForEach @(
        @{ Value = '10'; Message = '*non-null numeric*' }
        @{ Value = 11; Message = '*expected numeric 10*' }
        @{ Value = [DBNull]::Value; Message = '*non-null numeric*' }
    ) {
        { Assert-TabularDaxResult -Value $Value } | Should -Throw $Message
    }
}
