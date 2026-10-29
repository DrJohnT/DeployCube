[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$LogDirectory,
    [Parameter(Mandatory = $true)][string]$SourceReportPath,
    [Parameter(Mandatory = $true)][ValidateSet('2019', '2022', '2025')][string]$SsasVersion,
    [switch]$CleanupOnly
)

$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
$LogDirectory = (Resolve-Path $LogDirectory).Path
$reportPath = Join-Path $LogDirectory 'processing-report.json'
Import-Module (Join-Path $PSScriptRoot '../../DeployCube/DeployCube.psd1') -Force -ErrorAction Stop
Import-Module SqlServer -ErrorAction Stop
. (Join-Path $PSScriptRoot 'SsasProcessingEvidence.ps1')
. (Join-Path $PSScriptRoot 'Assert-MultidimensionalMetadata.ps1')
$names = @('DeployCubeProcessingGood', 'DeployCubeProcessingInvalidSource', 'DeployCubeProcessingMissingTable')
$report = @{
    Outcome = 'Failed'; FailureCategory = 'Prerequisites'; Error = $null
    RunUrl = "https://github.com/$env:GITHUB_REPOSITORY/actions/runs/$env:GITHUB_RUN_ID"
    OwnedDatabases = @(); PublishCube = 'Not tested'; Processing = 'Not tested'
    NegativeTests = @(); Cleanup = 'Not tested'; CleanupErrors = @()
}
if ($CleanupOnly -and (Test-Path -LiteralPath $reportPath)) {
    $report = @{}
    $saved = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
    foreach ($property in $saved.PSObject.Properties) { $report[$property.Name] = $property.Value }
}
function Save-ProcessingReport {
    $report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $reportPath -Encoding UTF8
}
function Publish-ProcessingFixture {
    param([string]$Name)
    if ($server.Databases.FindByName($Name)) { throw "Refusing to overwrite existing SSAS database '$Name'." }
    $report.OwnedDatabases += $Name
    Save-ProcessingReport
    $path = & (Join-Path $PSScriptRoot 'Build-MultidimensionalModel.ps1') `
        -SourceType SqlEngine -LogDirectory (Join-Path $LogDirectory $Name)
    Publish-Cube -AsDatabasePath $path -Server 'localhost\DCUBE' -CubeDatabase $Name `
        -PreferredVersion 22 -ProcessingOption DoNotProcess *>&1 |
        Tee-Object -FilePath (Join-Path (Split-Path -Parent $path) 'publish.log') | Out-Host
    $server.Refresh($true)
    $database = $server.Databases.FindByName($Name)
    if (-not $database) { throw "Publish-Cube returned without creating '$Name'." }
    $metadata = Assert-MultidimensionalMetadata -Database $database
    $metadata | ConvertTo-Json | Set-Content -LiteralPath (Join-Path (Split-Path -Parent $path) 'deployed-metadata.json') -Encoding UTF8
    return $path
}

$server = New-Object Microsoft.AnalysisServices.Server
try {
    $server.Connect('Data Source=localhost\DCUBE;Timeout=120;Connect Timeout=30')
    if (-not $CleanupOnly) {
        $report.ActualSsasVersion = [string]$server.Version
        $report.ActualMode = [string]$server.ServerMode
        $report.Edition = [string]$server.Edition
        $expectedMajor = Assert-SsasProcessingTarget -SsasVersion $SsasVersion `
            -ProductVersion $server.Version.ToString() -ServerMode ([string]$server.ServerMode) `
            -Edition ([string]$server.Edition)
        $report.DeploymentUtility = @(& (Join-Path $PSScriptRoot 'Get-DeploymentToolInventory.ps1') |
            Where-Object ProductMajorVersion -eq 22)
        if ($report.DeploymentUtility.Count -ne 1) { throw 'Expected exactly one SSMS 22 Deployment Utility.' }
        $report.Source = Get-Content -LiteralPath $SourceReportPath -Raw | ConvertFrom-Json
        if ($report.Source.Outcome -ne 'Passed') { throw 'SQL source provisioning must pass first.' }
        foreach ($name in $names) {
            if ($server.Databases.FindByName($name)) { throw "Test database '$name' already exists; refusing to run." }
        }
        $report.FailureCategory = 'DeployCube deployment'
        $modelPath = Publish-ProcessingFixture -Name $names[0]
        $report.PublishCube = 'Passed'

        $report.FailureCategory = 'Source connectivity / service permissions / dimension processing'
        Invoke-RecordedProcessFull -Server $server -Database $names[0] -DimensionOnly `
            -Path (Join-Path $LogDirectory 'dimension-processing.json')
        $server.Refresh($true)
        $dimensionState = [string]$server.Databases.FindByName($names[0]).Dimensions.Find('Item').State
        if ($dimensionState -ne 'Processed') { throw "Dimension state is '$dimensionState', expected Processed." }
        $report.DimensionState = $dimensionState
        $events = Invoke-ProcessingSourceSql -Query @'
SELECT CONVERT(nvarchar(max),t.target_data) AS Events FROM sys.dm_xe_sessions s
JOIN sys.dm_xe_session_targets t ON s.address=t.event_session_address
WHERE s.name='DeployCubeSourceReads' AND t.target_name='ring_buffer';
'@
        [xml]$eventXml = $events.Rows[0].Events
        $reads = @($eventXml.RingBufferTarget.event | Where-Object {
            $_.SelectSingleNode("action[@name='server_principal_name']/value").InnerText -ieq 'NT SERVICE\MSOLAP$DCUBE' -and
            $_.SelectSingleNode("action[@name='database_name']/value").InnerText -eq 'DeployCubeFixtureSource' -and
            $_.SelectSingleNode("data[@name='statement']/value").InnerText -match 'Fact'
        })
        if ($reads.Count -eq 0) { throw 'No SQL-side read by the actual SSAS service account was captured; service connectivity is not proven.' }
        $readEvidence = @($reads | ForEach-Object {
            [pscustomobject]@{
                Principal = $_.SelectSingleNode("action[@name='server_principal_name']/value").InnerText
                Database = $_.SelectSingleNode("action[@name='database_name']/value").InnerText
                Statement = $_.SelectSingleNode("data[@name='statement']/value").InnerText
            }
        })
        $readEvidence | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $LogDirectory 'ssas-service-source-reads.json') -Encoding UTF8
        $report.SourceConnectivity = @{ Outcome = 'Passed'; ServiceAccount = $report.Source.ServiceAccount; SqlReadCount = $reads.Count }

        $report.FailureCategory = 'Cube processing'
        $watch = [Diagnostics.Stopwatch]::StartNew()
        $report.ProcessingCommand = 'Publish-Cube -ProcessingOption Full -PreferredVersion 22 (Deployment Utility ProcessFull)'
        try {
            Publish-Cube -AsDatabasePath $modelPath -Server 'localhost\DCUBE' -CubeDatabase $names[0] `
                -PreferredVersion 22 -ProcessingOption Full *>&1 |
                Tee-Object -FilePath (Join-Path $LogDirectory 'publish-full-processing.log') | Out-Host
            $server.Refresh($true)
            $database = $server.Databases.FindByName($names[0])
            $cube = $database.Cubes.Find('FixtureCube')
            $report.CubeState = [string]$cube.State
            $report.PartitionState = [string]$cube.MeasureGroups.Find('Fact').Partitions.Find('Fact').State
            $report.DimensionState = [string]$database.Dimensions.Find('Item').State
            if ($report.CubeState -ne 'Processed' -or $report.PartitionState -ne 'Processed' -or $report.DimensionState -ne 'Processed') {
                throw 'Full processing did not leave the cube, partition and dimension Processed.'
            }
            $report.Processing = 'Passed'
        }
        finally {
            $report.ProcessingDurationSeconds = [math]::Round($watch.Elapsed.TotalSeconds, 2)
            Copy-Item -LiteralPath (Join-Path (Split-Path -Parent $modelPath) 'AnalysisServicesDeploymentExeLog.txt') `
                -Destination (Join-Path $LogDirectory 'full-processing-utility.log') -ErrorAction Stop
            $report.ProcessingDiagnostics = @(Get-Content -LiteralPath (Join-Path $LogDirectory 'full-processing-utility.log') |
                Where-Object { $_ -match '(?i)warning|error' })
        }

        $report.FailureCategory = 'MDX query execution'
        $report.MdxQuery = 'SELECT {[Measures].[Amount]} ON COLUMNS FROM [Fixture Cube]'
        $xml = Invoke-ASCmd -Server 'localhost\DCUBE' -Database $names[0] `
            -Query $report.MdxQuery -QueryTimeout 120 -ConnectionTimeout 30 -ErrorAction Stop
        $xml | Set-Content -LiteralPath (Join-Path $LogDirectory 'mdx-result.xml') -Encoding UTF8
        $report.FailureCategory = 'Incorrect measure values'
        $report.MdxResult = Assert-MdxMeasureValue -Xml $xml
        $report.MdxOutcome = 'Passed'

        foreach ($scenario in @('InvalidSource', 'MissingTable')) {
            $report.FailureCategory = "Negative test: $scenario"
            $name = if ($scenario -eq 'InvalidSource') { $names[1] } else { $names[2] }
            $null = Publish-ProcessingFixture -Name $name
            $database = $server.Databases.FindByName($name)
            if ($scenario -eq 'InvalidSource') {
                if (Get-Service -Name 'MSSQL$DCUBE_PHASEG_NONEXISTENT' -ErrorAction SilentlyContinue) {
                    throw 'Invalid-source test target unexpectedly exists.'
                }
                $source = $database.DataSources.Find('LocalFixture')
                $source.ConnectionString = 'Provider=MSOLEDBSQL;Data Source=lpc:.\DCUBE_PHASEG_NONEXISTENT;Initial Catalog=DeployCubeFixtureSource;Integrated Security=SSPI;Connect Timeout=2;'
                $source.Update()
            }
            else {
                $partition = $database.Cubes.Find('FixtureCube').MeasureGroups.Find('Fact').Partitions.Find('Fact')
                $partition.Source = New-Object Microsoft.AnalysisServices.QueryBinding('LocalFixture',
                    'SELECT ItemKey, Amount FROM dbo.DeployCubePhaseGMissingTable')
                $partition.Update()
            }
            $errorText = $null
            try {
                Invoke-RecordedProcessFull -Server $server -Database $name `
                    -Path (Join-Path $LogDirectory "$scenario-processing.json")
            }
            catch { $errorText = $_.Exception.ToString() }
            if (-not $errorText) { throw "Negative $scenario processing unexpectedly succeeded." }
            $expected = if ($scenario -eq 'InvalidSource') {
                'connection|connect|server.*not.*found|instance|provider|login|network'
            } else { 'DeployCubePhaseGMissingTable|Invalid object name' }
            if ($errorText -notmatch $expected) {
                throw "Negative $scenario failed for an unexpected reason: $errorText"
            }
            $report.NegativeTests += @{ Scenario = $scenario; Outcome = 'Passed'; ProcessingOutcome = 'Expected failure'; Diagnostic = $errorText }
            Save-ProcessingReport
        }
        if ($report.NegativeTests.Count -ne 2) { throw 'Both isolated negative tests are required.' }
        $report.Outcome = 'Passed'
        $report.FailureCategory = $null
    }
}
catch {
    $report.Outcome = 'Failed'
    $report.Error = $_.Exception.ToString()
    Write-Error -Message $report.Error -ErrorAction Continue
}
finally {
    $cleanupErrors = @()
    try {
        if ($server.Connected) {
            foreach ($name in @($report.OwnedDatabases)) {
                try {
                    if ($name -notin $names) { throw "Unexpected cleanup database '$name'." }
                    $server.Refresh($true)
                    if ($server.Databases.FindByName($name)) {
                        Unpublish-Cube -Server 'localhost\DCUBE' -CubeDatabase $name -ErrorAction Stop | Out-Host
                    }
                    $server.Refresh($true)
                    if ($server.Databases.FindByName($name)) { throw "SSAS database '$name' remains after Unpublish-Cube." }
                }
                catch { $cleanupErrors += $_.Exception.ToString() }
            }
            $report.RemainingTestDatabases = @($names | Where-Object { $server.Databases.FindByName($_) })
            if ($report.RemainingTestDatabases.Count) { $cleanupErrors += 'One or more Phase G SSAS databases remain.' }
        }
        else { $cleanupErrors += 'Cannot connect to SSAS to verify cleanup.' }
    }
    finally {
        if ($server.Connected) { $server.Disconnect() }
        $report.Cleanup = if ($cleanupErrors.Count) { 'Failed' } else { 'Passed' }
        $report.CleanupErrors = $cleanupErrors
        if ($cleanupErrors.Count) { $report.Outcome = 'Failed'; $report.FailureCategory = 'Cleanup' }
        Save-ProcessingReport
    }
}
if ($report.Outcome -ne 'Passed') {
    throw "Phase G $($report.Outcome) at '$($report.FailureCategory)'. See '$reportPath'. $($report.Error)"
}
