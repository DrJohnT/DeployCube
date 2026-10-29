[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$LogDirectory,
    [Parameter(Mandatory = $true)][string]$SourceReportPath,
    [switch]$CleanupOnly
)

$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
$LogDirectory = (Resolve-Path -LiteralPath $LogDirectory).Path
$reportPath = Join-Path $LogDirectory 'tabular-processing-report.json'
$databaseNames = @(
    'DeployCubeTabularProcessingGood',
    'DeployCubeTabularProcessingInvalidSource',
    'DeployCubeTabularProcessingMissingTable'
)
$report = @{
    Outcome = 'Failed'
    FailureCategory = 'Prerequisites'
    Error = $null
    RunUrl = "https://github.com/$env:GITHUB_REPOSITORY/actions/runs/$env:GITHUB_RUN_ID"
    SsasVersion = $null
    ServerMode = $null
    DeploymentUtility = $null
    Source = $null
    Fixture = 'Not tested'
    PublishCube = 'Not tested'
    Processing = 'Not tested'
    DaxQuery = 'EVALUATE ROW("TotalAmount", [Total Amount])'
    DaxResult = $null
    NegativeTests = @()
    OwnedDatabases = @()
    RemainingTestDatabases = @()
    Cleanup = 'Not tested'
    CleanupErrors = @()
}

function Save-TabularProcessingReport {
    $report | ConvertTo-Json -Depth 14 |
        Set-Content -LiteralPath $reportPath -Encoding UTF8
}

function Invoke-TabularSourceSql {
    param([Parameter(Mandatory = $true)][string]$Query)
    $connection = New-Object System.Data.SqlClient.SqlConnection(
        'Data Source=lpc:.\DCUBESOURCE;Initial Catalog=master;Integrated Security=True;Connect Timeout=15')
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

function Get-TabularNegativeDiagnostic {
    param([string]$ErrorText, [string]$ModelDirectory)
    $details = [System.Collections.Generic.List[string]]::new()
    if ($ErrorText) { $details.Add($ErrorText) }
    $utilityLog = Join-Path $ModelDirectory 'AnalysisServicesDeploymentExeLog.txt'
    if (Test-Path -LiteralPath $utilityLog) {
        $details.Add((Get-Content -LiteralPath $utilityLog -Raw))
    }
    return ($details -join [Environment]::NewLine)
}

function Invoke-TabularDeployment {
    param(
        [Parameter(Mandatory = $true)][string]$ModelPath,
        [Parameter(Mandatory = $true)][string]$DatabaseName,
        [Parameter(Mandatory = $true)][string]$TranscriptPath
    )
    $watch = [Diagnostics.Stopwatch]::StartNew()
    try {
        Publish-Cube -AsDatabasePath $ModelPath -Server 'localhost\DCUBE' `
            -CubeDatabase $DatabaseName -PreferredVersion 22 -ProcessingOption Full *>&1 |
            Tee-Object -FilePath $TranscriptPath | Out-Host
        return [pscustomobject]@{ Succeeded = $true; DurationSeconds = [math]::Round($watch.Elapsed.TotalSeconds, 2); Error = $null }
    }
    catch {
        return [pscustomobject]@{
            Succeeded = $false
            DurationSeconds = [math]::Round($watch.Elapsed.TotalSeconds, 2)
            Error = $_.Exception.ToString()
        }
    }
}

function Remove-OwnedTabularDatabases {
    param([Parameter(Mandatory = $true)]$Server)
    $errors = @()
    foreach ($name in $databaseNames) {
        try {
            $Server.Refresh($true)
            $database = $Server.Databases.FindByName($name)
            if ($database) {
                Unpublish-Cube -Server 'localhost\DCUBE' -CubeDatabase $name -ErrorAction Stop | Out-Host
            }
            $Server.Refresh($true)
            if ($Server.Databases.FindByName($name)) {
                throw "SSAS database '$name' remains after Unpublish-Cube."
            }
        }
        catch { $errors += $_.Exception.ToString() }
    }
    return $errors
}

Import-Module (Join-Path $PSScriptRoot '../../DeployCube/DeployCube.psd1') -Force -ErrorAction Stop
Import-Module SqlServer -ErrorAction Stop
. (Join-Path $PSScriptRoot 'TabularProcessingEvidence.ps1')
. (Join-Path $PSScriptRoot 'SsasProcessingEvidence.ps1')

if ($CleanupOnly) {
    if (Test-Path -LiteralPath $reportPath) {
        $saved = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
        foreach ($property in $saved.PSObject.Properties) {
            if ($report.ContainsKey($property.Name)) { $report[$property.Name] = $property.Value }
        }
    }
    $cleanupServer = New-Object Microsoft.AnalysisServices.Server
    try {
        $cleanupServer.Connect('localhost\DCUBE')
        $report.Cleanup = 'Attempted'
        $report.CleanupErrors = @(Remove-OwnedTabularDatabases -Server $cleanupServer)
        $cleanupServer.Refresh($true)
        $report.RemainingTestDatabases = @($databaseNames | Where-Object { $cleanupServer.Databases.FindByName($_) })
        if ($report.RemainingTestDatabases.Count) { $report.CleanupErrors += 'One or more Phase H databases remain.' }
        $report.Cleanup = if ($report.CleanupErrors.Count) { 'Failed' } else { 'Passed' }
    }
    catch {
        $report.Cleanup = 'Failed'
        $report.CleanupErrors += $_.Exception.ToString()
    }
    finally {
        if ($cleanupServer.Connected) { $cleanupServer.Disconnect() }
        Save-TabularProcessingReport
    }
    if ($report.Cleanup -ne 'Passed') { throw 'Phase H fallback cleanup failed; inspect tabular-processing-report.json.' }
    return
}

$server = New-Object Microsoft.AnalysisServices.Server
$tomServer = $null
try {
    $server.Connect('localhost\DCUBE')
    $report.FailureCategory = 'SSAS server verification'
    $report.SsasVersion = $server.Version.ToString()
    $report.ServerMode = [string]$server.ServerMode
    $report.Edition = [string]$server.Edition
    Assert-SsasProcessingTarget -SsasVersion '2022' -ProductVersion $report.SsasVersion `
        -ServerMode $report.ServerMode -Edition $report.Edition | Out-Null

    $report.FailureCategory = 'Deployment Utility verification'
    $inventory = @(& (Join-Path $PSScriptRoot 'Get-DeploymentToolInventory.ps1') |
        Where-Object { $_.ProductMajorVersion -eq 22 })
    if ($inventory.Count -ne 1) { throw 'Expected exactly one SSMS 22 Deployment Utility.' }
    $selectedUtilityPath = Get-AnalysisServicesDeploymentExePath -Version 22
    if (-not [System.StringComparer]::OrdinalIgnoreCase.Equals($inventory[0].Path, $selectedUtilityPath)) {
        throw 'DeployCube utility selection did not match the inventoried SSMS 22 executable.'
    }
    $report.DeploymentUtility = $inventory[0]
    $service = Get-CimInstance Win32_Service -Filter "Name='MSOLAP`$DCUBE'" -ErrorAction Stop
    if ($service.State -ne 'Running' -or $service.StartName -ine 'NT Service\MSOLAP$DCUBE') {
        throw "Unexpected SSAS service state or identity: '$($service.State)' / '$($service.StartName)'."
    }
    $report.ServiceAccount = $service.StartName

    $report.FailureCategory = 'SQL source validation'
    $sourceRaw = Get-Content -LiteralPath $SourceReportPath -Raw -ErrorAction Stop
    if ($sourceRaw -match '(?i)(password|pwd|user\s*id)\s*=') {
        throw 'Refusing to use a source report containing SQL credentials.'
    }
    $report.Source = $sourceRaw | ConvertFrom-Json
    if ($report.Source.Outcome -ne 'Passed' -or
        $report.Source.EngineVersion -notmatch '^16\.' -or
        $report.Source.EngineEdition -notmatch 'Developer' -or
        $report.Source.RecordCount -ne 1 -or $report.Source.ExpectedSum -ne 10 -or
        $report.Source.PermissionCheck.Login -ine 'NT SERVICE\MSOLAP$DCUBE' -or
        $report.Source.PermissionCheck.CanSelect -ne 1 -or
        $report.Source.PermissionCheck.IsSysadmin -ne 0 -or
        $report.Source.PermissionCheck.CanInsert -ne 0) {
        throw 'SQL source report did not prove SQL Server 2022 Developer, one row summing to 10, and least-privilege SSAS access.'
    }
    $sourceData = Invoke-TabularSourceSql -Query @'
SELECT (SELECT COUNT(*) FROM sys.tables WHERE object_id=OBJECT_ID('DeployCubeFixtureSource.dbo.Fact')) AS TableCount,
 (SELECT COUNT(*) FROM DeployCubeFixtureSource.sys.columns
   WHERE object_id=OBJECT_ID('DeployCubeFixtureSource.dbo.Fact')
     AND name IN ('ItemKey','Amount') AND system_type_id=56 AND is_nullable=0) AS ColumnCount,
 COUNT(*) AS SourceRecordCount, MIN(ItemKey) AS ItemKey, SUM(Amount) AS SumAmount
FROM DeployCubeFixtureSource.dbo.Fact;
'@
    Assert-ProcessingSource -Row $sourceData.Rows[0]
    $permission = Invoke-TabularSourceSql -Query @'
EXECUTE AS LOGIN = 'NT SERVICE\MSOLAP$DCUBE';
SELECT HAS_PERMS_BY_NAME('DeployCubeFixtureSource.dbo.Fact','OBJECT','SELECT') AS CanSelect,
 HAS_PERMS_BY_NAME('DeployCubeFixtureSource.dbo.Fact','OBJECT','INSERT') AS CanInsert,
 HAS_PERMS_BY_NAME('DeployCubeFixtureSource.dbo.Fact','OBJECT','UPDATE') AS CanUpdate,
 HAS_PERMS_BY_NAME('DeployCubeFixtureSource.dbo.Fact','OBJECT','DELETE') AS CanDelete,
 HAS_PERMS_BY_NAME('DeployCubeFixtureSource.dbo.Fact','OBJECT','ALTER') AS CanAlter,
 IS_SRVROLEMEMBER('sysadmin') AS IsSysadmin;
REVERT;
'@
    $permissionRow = $permission.Rows[0]
    if ($permissionRow.CanSelect -ne 1 -or $permissionRow.CanInsert -ne 0 -or
        $permissionRow.CanUpdate -ne 0 -or $permissionRow.CanDelete -ne 0 -or
        $permissionRow.CanAlter -ne 0 -or $permissionRow.IsSysadmin -ne 0) {
        throw 'SSAS source identity must have SELECT only, no write/ALTER permissions, and no sysadmin role.'
    }
    $report.SourcePermissionVerification = @{
        CanSelect = [int]$permissionRow.CanSelect
        CanInsert = [int]$permissionRow.CanInsert
        CanUpdate = [int]$permissionRow.CanUpdate
        CanDelete = [int]$permissionRow.CanDelete
        CanAlter = [int]$permissionRow.CanAlter
        IsSysadmin = [int]$permissionRow.IsSysadmin
    }

    foreach ($name in $databaseNames) {
        if ($server.Databases.FindByName($name)) { throw "Refusing to overwrite existing Phase H database '$name'." }
    }
    $report.FailureCategory = 'Tabular fixture build or validation'
    $modelPath = & (Join-Path $PSScriptRoot 'Build-TabularProcessingModel.ps1') `
        -LogDirectory (Join-Path $LogDirectory 'fixtures') -DatabaseName $databaseNames[0]
    $report.Fixture = Get-Content -LiteralPath (Join-Path (Split-Path -Parent $modelPath) 'fixture-validation.json') -Raw |
        ConvertFrom-Json
    $report.ModelCompatibilityLevel = 1500

    $report.OwnedDatabases += $databaseNames[0]
    Save-TabularProcessingReport
    $report.FailureCategory = 'DeployCube deployment and full processing'
    $publish = Invoke-TabularDeployment -ModelPath $modelPath -DatabaseName $databaseNames[0] `
        -TranscriptPath (Join-Path $LogDirectory 'publish-full-processing.log')
    $report.PublishCube = if ($publish.Succeeded) { 'Passed' } else { 'Failed' }
    $report.ProcessingDurationSeconds = $publish.DurationSeconds
    if (-not $publish.Succeeded) { throw $publish.Error }

    $report.FailureCategory = 'Server-side processing verification'
    $tomServer = New-Object Microsoft.AnalysisServices.Tabular.Server
    $tomServer.Connect('localhost\DCUBE')
    $tabularDatabase = $tomServer.Databases.FindByName($databaseNames[0])
    $table = if ($tabularDatabase) { $tabularDatabase.Model.Tables.Find('Fact') }
    $partition = if ($table) { $table.Partitions.Find('Fact') }
    $measure = if ($table) { $table.Measures.Find('Total Amount') }
    if (-not $tabularDatabase -or $tabularDatabase.CompatibilityLevel -ne 1500 -or
        -not $table -or -not $partition -or -not $measure -or
        $table.State -ne [Microsoft.AnalysisServices.Tabular.ObjectState]::Ready -or
        $partition.State -ne [Microsoft.AnalysisServices.Tabular.ObjectState]::Ready) {
        throw 'TOM server metadata did not confirm the compatibility-1500 Fact table and partition are processed.'
    }
    $report.TabularMetadata = @{
        DatabaseExists = $true
        CompatibilityLevel = $tabularDatabase.CompatibilityLevel
        Table = $table.Name
        TableState = [string]$table.State
        Partition = $partition.Name
        PartitionState = [string]$partition.State
        Measure = $measure.Name
        MeasureExpression = $measure.Expression
    }
    $report.Processing = 'Passed'

    $report.FailureCategory = 'DAX query execution and result validation'
    $daxResult = Get-TabularDaxResult -DatabaseName $databaseNames[0] `
        -Query $report.DaxQuery -MeasureColumn 'TotalAmount'
    $report.DaxResult = $daxResult.Value
    $report.DaxResultType = $daxResult.Type
    $report.DaxOutcome = 'Passed'
    @{
        Query = $report.DaxQuery
        Column = 'TotalAmount'
        Value = $report.DaxResult
        Type = $report.DaxResultType
        Xml = $daxResult.Xml
        Source = 'Processed SSAS Tabular model'
    } |
        ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $LogDirectory 'dax-result.json') -Encoding UTF8

    foreach ($scenario in @('InvalidSource', 'MissingTable')) {
        $name = if ($scenario -eq 'InvalidSource') { $databaseNames[1] } else { $databaseNames[2] }
        $report.OwnedDatabases += $name
        Save-TabularProcessingReport
        $report.FailureCategory = "Negative processing test: $scenario"
        $options = @{
            LogDirectory = Join-Path $LogDirectory 'fixtures'
            DatabaseName = $name
        }
        if ($scenario -eq 'InvalidSource') {
            $options.SourceConnectionString = 'Provider=MSOLEDBSQL;Data Source=tcp:127.0.0.1,1;Initial Catalog=NoSuchDatabase;Integrated Security=SSPI;Connect Timeout=3;'
        }
        else {
            $options.SourceQuery = 'SELECT ItemKey, Amount FROM dbo.DeployCubePhaseHMissingTable'
            $options.AllowInvalidSource = $true
        }
        $negativeModelPath = & (Join-Path $PSScriptRoot 'Build-TabularProcessingModel.ps1') @options
        $negativePublish = Invoke-TabularDeployment -ModelPath $negativeModelPath -DatabaseName $name `
            -TranscriptPath (Join-Path $LogDirectory "$scenario-publish.log")
        $tomServer.Disconnect()
        $tomServer.Connect('localhost\DCUBE')
        $negativeDatabase = $tomServer.Databases.FindByName($name)
        $negativeTable = if ($negativeDatabase) { $negativeDatabase.Model.Tables.Find('Fact') }
        $negativePartition = if ($negativeTable) { $negativeTable.Partitions.Find('Fact') }
        $unexpectedSuccess = $negativePublish.Succeeded -and $negativePartition -and
            $negativePartition.State -eq [Microsoft.AnalysisServices.Tabular.ObjectState]::Ready
        $diagnostic = Get-TabularNegativeDiagnostic -ErrorText $negativePublish.Error `
            -ModelDirectory (Split-Path -Parent $negativeModelPath)
        if ($scenario -eq 'InvalidSource') {
            $expectedDiagnostic = $diagnostic -match '(?i)(08001|HYT00|connection|server.*not found|could not open a connection|network-related|login timeout)'
            $category = 'Connectivity failure'
        }
        else {
            $expectedDiagnostic = $diagnostic -match '(?i)(\b208\b|invalid object|object .*(not found|does not exist|could not be found)|table .*(not found|does not exist|could not be found))'
            $category = 'Missing source object'
        }
        if ($unexpectedSuccess -or -not $expectedDiagnostic) {
            throw "Negative $scenario did not produce the expected $category. Utility exit succeeded: $($negativePublish.Succeeded). See '$LogDirectory'. Diagnostic: $diagnostic"
        }
        $report.NegativeTests += @{
            Scenario = $scenario
            Outcome = 'Passed'
            ExpectedFailureCategory = $category
            ProcessingDurationSeconds = $negativePublish.DurationSeconds
            Diagnostic = $diagnostic
        }
        Save-TabularProcessingReport
    }
    if ($report.NegativeTests.Count -ne 2) { throw 'Both isolated negative processing tests are required.' }
    $report.Outcome = 'Passed'
    $report.FailureCategory = $null
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
            $report.Cleanup = 'Attempted'
            $cleanupErrors += Remove-OwnedTabularDatabases -Server $server
            $server.Refresh($true)
            $report.RemainingTestDatabases = @($databaseNames | Where-Object { $server.Databases.FindByName($_) })
            if ($report.RemainingTestDatabases.Count) { $cleanupErrors += 'One or more Phase H databases remain.' }
        }
        else { $cleanupErrors += 'Cannot connect to SSAS to verify Phase H cleanup.' }
    }
    catch { $cleanupErrors += $_.Exception.ToString() }
    finally {
        if ($tomServer -and $tomServer.Connected) { $tomServer.Disconnect() }
        if ($server.Connected) { $server.Disconnect() }
        $report.Cleanup = if ($cleanupErrors.Count) { 'Failed' } else { 'Passed' }
        $report.CleanupErrors = $cleanupErrors
        if ($report.Cleanup -ne 'Passed') {
            $report.Outcome = 'Failed'
            $report.FailureCategory = 'Cleanup'
        }
        Save-TabularProcessingReport
    }
}

if ($report.Outcome -ne 'Passed') {
    throw "Phase H failed at '$($report.FailureCategory)'. See '$reportPath'. $($report.Error)"
}
