BeforeAll {
    . (Join-Path $PSScriptRoot 'infrastructure/Assert-MultidimensionalMetadata.ps1')
    function New-MetadataCollection {
        param([hashtable]$Entries)
        $collection = [pscustomobject]@{ Entries = $Entries }
        $collection | Add-Member ScriptMethod Find { param($Id) return $this.Entries[$Id] }
        return $collection
    }
}

Describe 'Multidimensional server-side deployment evidence' {
    BeforeEach {
        $script:group = [pscustomobject]@{
            ID = 'Fact'
            Measures = New-MetadataCollection @{ Amount = [pscustomobject]@{ ID = 'Amount' } }
            Partitions = New-MetadataCollection @{ Fact = [pscustomobject]@{ ID = 'Fact' } }
            Dimensions = New-MetadataCollection @{ Item = [pscustomobject]@{ ID = 'Item' } }
        }
        $script:cube = [pscustomobject]@{
            ID = 'FixtureCube'
            State = 'Unprocessed'
            Dimensions = New-MetadataCollection @{ Item = [pscustomobject]@{ ID = 'Item' } }
            MeasureGroups = New-MetadataCollection @{ Fact = $script:group }
        }
        $script:database = [pscustomobject]@{
            Name = 'ProbeDatabase'
            DataSources = New-MetadataCollection @{ LocalFixture = [pscustomobject]@{ ID = 'LocalFixture' } }
            DataSourceViews = New-MetadataCollection @{ FixtureView = [pscustomobject]@{ ID = 'FixtureView' } }
            Dimensions = New-MetadataCollection @{
                Item = [pscustomobject]@{
                    ID = 'Item'
                    Attributes = New-MetadataCollection @{ ItemKey = [pscustomobject]@{ ID = 'ItemKey' } }
                }
            }
            Cubes = New-MetadataCollection @{ FixtureCube = $script:cube }
        }
    }

    It 'requires real deployed cube objects but not processing' {
        $result = Assert-MultidimensionalMetadata -Database $script:database
        $result.Outcome | Should -Be 'Passed'
        $result.Cube | Should -Be 'FixtureCube'
        $result.Measure | Should -Be 'Amount'
        $result.CubeState | Should -Be 'Unprocessed'
        $result.Processing | Should -Be 'Not requested'
    }

    It 'rejects missing <Collection> metadata' -ForEach @(
        @{ Collection = 'DataSources'; Id = 'LocalFixture' }
        @{ Collection = 'DataSourceViews'; Id = 'FixtureView' }
        @{ Collection = 'Dimensions'; Id = 'Item' }
        @{ Collection = 'Cubes'; Id = 'FixtureCube' }
    ) {
        $script:database.$Collection.Entries.Remove($Id)
        { Assert-MultidimensionalMetadata -Database $script:database } | Should -Throw '*metadata validation failed*'
    }

    It 'rejects missing measure group <Collection> metadata' -ForEach @(
        @{ Collection = 'Measures'; Id = 'Amount' }
        @{ Collection = 'Partitions'; Id = 'Fact' }
        @{ Collection = 'Dimensions'; Id = 'Item' }
    ) {
        $script:group.$Collection.Entries.Remove($Id)
        { Assert-MultidimensionalMetadata -Database $script:database } | Should -Throw '*metadata validation failed*'
    }

    It 'rejects a cube without the expected measure group' {
        $script:cube.MeasureGroups.Entries.Clear()
        { Assert-MultidimensionalMetadata -Database $script:database } | Should -Throw '*metadata validation failed*'
    }
}
