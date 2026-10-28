function Assert-MultidimensionalMetadata {
    param(
        [Parameter(Mandatory = $true)]
        $Database
    )

    if (-not $Database.DataSources -or -not $Database.DataSourceViews -or
        -not $Database.Dimensions -or -not $Database.Cubes) {
        throw 'Multidimensional metadata validation failed: required database object collections are missing.'
    }
    $source = $Database.DataSources.Find('LocalFixture')
    $view = $Database.DataSourceViews.Find('FixtureView')
    $dimension = $Database.Dimensions.Find('Item')
    $cube = $Database.Cubes.Find('FixtureCube')
    if (-not $source -or -not $view -or -not $dimension -or -not $cube) {
        throw 'Multidimensional metadata validation failed: expected data source, data source view, Item dimension and FixtureCube.'
    }
    $group = $cube.MeasureGroups.Find('Fact')
    if (-not $cube.Dimensions.Find('Item') -or -not $dimension.Attributes.Find('ItemKey') -or
        -not $group -or -not $group.Measures.Find('Amount') -or -not $group.Partitions.Find('Fact') -or
        -not $group.Dimensions.Find('Item')) {
        throw 'Multidimensional metadata validation failed: expected cube dimension, key, Fact measure group, Amount measure, partition and granularity binding.'
    }
    return [pscustomobject]@{
        Outcome = 'Passed'
        Database = $Database.Name
        DataSource = $source.ID
        DataSourceView = $view.ID
        Dimension = $dimension.ID
        Cube = $cube.ID
        MeasureGroup = $group.ID
        Measure = $group.Measures.Find('Amount').ID
        Partition = $group.Partitions.Find('Fact').ID
        CubeState = [string]$cube.State
        Processing = 'Not requested'
    }
}
