[CmdletBinding()]
param(
    [string]$MediaRoot,
    [Parameter(Mandatory = $true)][string]$LogDirectory,
    [switch]$Cleanup
)

$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
$LogDirectory = (Resolve-Path $LogDirectory).Path
. (Join-Path $PSScriptRoot 'SsasProcessingEvidence.ps1')
. (Join-Path $PSScriptRoot 'Invoke-BoundedProcess.ps1')
. (Join-Path $PSScriptRoot 'SqlServerMedia.ps1')
function Write-ProvisioningLog {
    param([string]$Stage, [string]$Message)
    $line = "[$([DateTime]::UtcNow.ToString('o'))] [$Stage] $Message"
    Write-Host $line
    Add-Content -LiteralPath (Join-Path $LogDirectory 'source.log') -Value $line -Encoding UTF8
}
$report = @{ Outcome = 'Failed'; FailureCategory = 'Source database provisioning'; Error = $null }
$watch = [Diagnostics.Stopwatch]::StartNew()
try {
    if ($Cleanup) {
        $service = Get-Service -Name 'MSSQL$DCUBESOURCE' -ErrorAction SilentlyContinue
        if ($service -and $service.Status -eq 'Running') {
            $null = Invoke-ProcessingSourceSql -Query @'
IF EXISTS (SELECT 1 FROM sys.server_event_sessions WHERE name='DeployCubeSourceReads')
    DROP EVENT SESSION DeployCubeSourceReads ON SERVER;
IF DB_ID('DeployCubeFixtureSource') IS NOT NULL BEGIN
    ALTER DATABASE DeployCubeFixtureSource SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE DeployCubeFixtureSource;
END;
IF SUSER_ID('NT SERVICE\MSOLAP$DCUBE') IS NOT NULL DROP LOGIN [NT SERVICE\MSOLAP$DCUBE];
'@
            $rows = Invoke-ProcessingSourceSql -Query "SELECT DB_ID('DeployCubeFixtureSource') AS DatabaseId, SUSER_ID('NT SERVICE\MSOLAP`$DCUBE') AS LoginId"
            if ($rows.Rows[0].DatabaseId -isnot [DBNull] -or $rows.Rows[0].LoginId -isnot [DBNull]) {
                throw 'SQL source database or test login still exists after cleanup.'
            }
            Stop-Service -Name 'MSSQL$DCUBESOURCE' -ErrorAction Stop
            $service = Get-Service -Name 'MSSQL$DCUBESOURCE' -ErrorAction Stop
            $service.WaitForStatus([System.ServiceProcess.ServiceControllerStatus]::Stopped, [TimeSpan]::FromSeconds(60))
            $report.DatabaseRemoved = $true
            $report.LoginRemoved = $true
            $report.ServiceStatus = [string](Get-Service -Name 'MSSQL$DCUBESOURCE').Status
        }
        elseif ($service) {
            throw 'SQL source service is not Running; cannot verify database cleanup.'
        }
        else { $report.ServiceStatus = 'Not installed' }
        $report.Outcome = 'Passed'
        return
    }
    if (Get-Service -Name 'MSSQL$DCUBESOURCE' -ErrorAction SilentlyContinue) {
        throw 'Test SQL Engine instance DCUBESOURCE already exists; refusing to reuse it.'
    }
    $report.SetupVersion = Assert-SqlServerMediaRoot -MediaRoot $MediaRoot -ExpectedMajor 16
    $identity = Get-CimInstance Win32_Service -Filter 'Name=''MSOLAP$DCUBE''' -ErrorAction Stop
    if ($identity.StartName -ine 'NT Service\MSOLAP$DCUBE' -or $identity.State -ne 'Running') {
        throw "Unexpected SSAS service identity/state: '$($identity.StartName)' / '$($identity.State)'."
    }
    $report.ServiceAccount = $identity.StartName
    $result = Invoke-BoundedProcess -FilePath (Join-Path $MediaRoot 'setup.exe') -ArgumentList @(
        '/Q', '/ACTION=Install', '/IACCEPTSQLSERVERLICENSETERMS', '/SUPPRESSPRIVACYSTATEMENTNOTICE',
        '/INDICATEPROGRESS', '/FEATURES=SQLENGINE', '/INSTANCENAME=DCUBESOURCE',
        '/SQLSVCACCOUNT="NT Service\MSSQL$DCUBESOURCE"', '/SQLSVCSTARTUPTYPE=Manual',
        "/SQLSYSADMINACCOUNTS=`"$env:USERDOMAIN\$env:USERNAME`"",
        '/TCPENABLED=0', '/NPENABLED=0', '/UPDATEENABLED=False'
    ) -TimeoutSeconds 1200 -Stage 'SQL Engine setup' `
        -StandardOutputPath (Join-Path $LogDirectory 'setup.stdout.log') `
        -StandardErrorPath (Join-Path $LogDirectory 'setup.stderr.log')
    $report.SetupDurationSeconds = $result.DurationSeconds
    if ($result.ExitCode -notin @(0, 3010)) { throw "SQL Engine setup failed: exit $($result.ExitCode)." }
    Start-Service -Name 'MSSQL$DCUBESOURCE' -ErrorAction Stop
    (Get-Service -Name 'MSSQL$DCUBESOURCE').WaitForStatus(
        [System.ServiceProcess.ServiceControllerStatus]::Running, [TimeSpan]::FromSeconds(60))
    $report.FailureCategory = 'SQL authentication or connectivity'
    $engine = Invoke-ProcessingSourceSql -Query "SELECT CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(128)) AS ProductVersion, CAST(SERVERPROPERTY('Edition') AS nvarchar(128)) AS Edition"
    $report.EngineVersion = [string]$engine.Rows[0].ProductVersion
    $report.EngineEdition = [string]$engine.Rows[0].Edition
    if ($report.EngineVersion -notmatch '^16\.' -or $report.EngineEdition -notmatch 'Developer') {
        throw 'SQL source must be SQL Server 2022 Developer.'
    }
    $report.FailureCategory = 'Source database provisioning'
    $null = Invoke-ProcessingSourceSql -Query 'CREATE DATABASE DeployCubeFixtureSource'
    $null = Invoke-ProcessingSourceSql -Database 'DeployCubeFixtureSource' -Query @'
CREATE TABLE dbo.Fact (ItemKey int NOT NULL PRIMARY KEY, Amount int NOT NULL);
INSERT dbo.Fact VALUES (1,10);
CREATE LOGIN [NT SERVICE\MSOLAP$DCUBE] FROM WINDOWS;
CREATE USER [NT SERVICE\MSOLAP$DCUBE] FOR LOGIN [NT SERVICE\MSOLAP$DCUBE];
GRANT SELECT ON OBJECT::dbo.Fact TO [NT SERVICE\MSOLAP$DCUBE];
'@
    $data = Invoke-ProcessingSourceSql -Database 'DeployCubeFixtureSource' -Query @'
SELECT (SELECT COUNT(*) FROM sys.tables WHERE object_id=OBJECT_ID('dbo.Fact')) AS TableCount,
 (SELECT COUNT(*) FROM sys.columns WHERE object_id=OBJECT_ID('dbo.Fact') AND name IN ('ItemKey','Amount') AND system_type_id=56 AND is_nullable=0) AS ColumnCount,
 COUNT(*) AS RowCount, MIN(ItemKey) AS ItemKey, SUM(Amount) AS SumAmount FROM dbo.Fact;
'@
    Assert-ProcessingSource -Row $data.Rows[0]
    $report.RecordCount = [int]$data.Rows[0].RowCount
    $report.ExpectedSum = [int]$data.Rows[0].SumAmount
    $report.Database = 'DeployCubeFixtureSource'
    $report.SourceType = 'SQL Server 2022 Developer named instance; local shared memory; Windows authentication'
    $report.ConnectionString = 'Provider=MSOLEDBSQL;Data Source=lpc:.\DCUBESOURCE;Initial Catalog=DeployCubeFixtureSource;Integrated Security=SSPI;Connect Timeout=5;'
    if (-not (Test-Path 'Registry::HKEY_CLASSES_ROOT\MSOLEDBSQL')) {
        throw 'MSOLEDBSQL provider required by the fixture is not registered.'
    }
    $report.FailureCategory = 'SSAS service account permissions'
    $permission = Invoke-ProcessingSourceSql -Query @'
EXECUTE AS LOGIN = 'NT SERVICE\MSOLAP$DCUBE';
USE DeployCubeFixtureSource;
SELECT ORIGINAL_LOGIN() AS AdminLogin, SUSER_SNAME() AS SourceLogin, IS_SRVROLEMEMBER('sysadmin') AS IsSysadmin,
 HAS_PERMS_BY_NAME('dbo.Fact','OBJECT','SELECT') AS CanSelect,
 HAS_PERMS_BY_NAME('dbo.Fact','OBJECT','INSERT') AS CanInsert, COUNT(*) AS RowCount FROM dbo.Fact;
REVERT;
'@
    $p = $permission.Rows[0]
    if ($p.IsSysadmin -ne 0 -or $p.CanSelect -ne 1 -or $p.CanInsert -ne 0 -or $p.RowCount -ne 1) {
        throw 'SSAS source login must be non-sysadmin with SELECT and no INSERT privilege.'
    }
    $report.PermissionCheck = @{ Login = [string]$p.SourceLogin; IsSysadmin = [int]$p.IsSysadmin; CanSelect = [int]$p.CanSelect; CanInsert = [int]$p.CanInsert }
    $null = Invoke-ProcessingSourceSql -Query @'
CREATE EVENT SESSION DeployCubeSourceReads ON SERVER
 ADD EVENT sqlserver.sql_statement_completed(
 ACTION(sqlserver.server_principal_name,sqlserver.database_name,sqlserver.sql_text,sqlserver.client_app_name))
 ADD TARGET package0.ring_buffer(SET max_memory=1024)
 WITH (MAX_MEMORY=4096 KB,MAX_DISPATCH_LATENCY=1 SECONDS);
ALTER EVENT SESSION DeployCubeSourceReads ON SERVER STATE=START;
'@
    $report.Outcome = 'Passed'
    $report.FailureCategory = $null
    Write-ProvisioningLog -Stage 'Source validation' -Message 'One row, expected sum 10; SSAS service login has SELECT only. Real service connectivity will be verified during dimension processing with SQL Extended Events.'
}
catch {
    $report.Error = $_.Exception.ToString()
    Write-ProvisioningLog -Stage $report.FailureCategory -Message $report.Error
    throw
}
finally {
    $report.DurationSeconds = [math]::Round($watch.Elapsed.TotalSeconds, 2)
    $name = if ($Cleanup) { 'source-cleanup.json' } else { 'source-provisioning.json' }
    $report | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath (Join-Path $LogDirectory $name) -Encoding UTF8
    if (-not $Cleanup) {
        $setupLogs = Join-Path $env:ProgramFiles 'Microsoft SQL Server/160/Setup Bootstrap/Log'
        if (Test-Path $setupLogs) {
            Copy-Item -LiteralPath $setupLogs -Destination (Join-Path $LogDirectory 'sql-engine-setup-logs') -Recurse -Force -ErrorAction Stop
        }
    }
}
