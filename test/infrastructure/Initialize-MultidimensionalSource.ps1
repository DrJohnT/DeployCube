[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$LogDirectory
)

$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
. (Join-Path $PSScriptRoot 'Invoke-BoundedProcess.ps1')
function Write-ProvisioningLog {
    param([string]$Stage, [string]$Message)
    $line = "[$([DateTime]::UtcNow.ToString('o'))] [$Stage] $Message"
    Write-Host $line
    Add-Content -LiteralPath (Join-Path $LogDirectory 'fixture-source.log') -Value $line -Encoding UTF8
}
$report = @{ Outcome = 'Failed'; Server = '(localdb)\DeployCubeFixture'; Database = 'DeployCubeFixtureSource'; Error = $null }
try {
    $localDb = Get-ChildItem -Path "$env:ProgramFiles/Microsoft SQL Server/*/Tools/Binn/SqlLocalDB.exe" -File -ErrorAction Stop |
        Sort-Object -Property FullName -Descending | Select-Object -First 1
    if (-not $localDb) {
        throw 'GitHub runner SQL Server LocalDB is missing; the isolated fixture source cannot be created.'
    }
    foreach ($action in @('create', 'start')) {
        $result = Invoke-BoundedProcess -FilePath $localDb.FullName `
            -ArgumentList @($action, 'DeployCubeFixture') -TimeoutSeconds 60 -Stage "LocalDB $action" `
            -StandardOutputPath (Join-Path $LogDirectory "localdb-$action.stdout.log") `
            -StandardErrorPath (Join-Path $LogDirectory "localdb-$action.stderr.log")
        if ($result.ExitCode -ne 0) { throw "LocalDB $action failed with exit code $($result.ExitCode)." }
    }
    $connection = New-Object System.Data.SqlClient.SqlConnection(
        'Data Source=(localdb)\DeployCubeFixture;Initial Catalog=master;Integrated Security=True;Connect Timeout=30')
    try {
        $connection.Open()
        $command = $connection.CreateCommand()
        $command.CommandTimeout = 30
        $command.CommandText = 'CREATE DATABASE DeployCubeFixtureSource'
        $command.ExecuteNonQuery() | Out-Null
        $connection.ChangeDatabase('DeployCubeFixtureSource')
        $command.CommandText = 'CREATE TABLE dbo.Fact (ItemKey int NOT NULL PRIMARY KEY, Amount int NOT NULL); INSERT dbo.Fact VALUES (1, 10); SELECT SUM(Amount) FROM dbo.Fact;'
        $sum = $command.ExecuteScalar()
        if ($sum -ne 10) { throw "Fixture source verification expected sum 10, got '$sum'." }
        $report.Outcome = 'Passed'
        $report.RowCount = 1
        $report.SumAmount = $sum
        $report.LocalDbVersion = $localDb.VersionInfo.ProductVersion
        Write-ProvisioningLog -Stage 'Fixture source' -Message 'Created and queried one deterministic local row (ItemKey=1, Amount=10). Processing is not requested.'
    }
    finally {
        $connection.Dispose()
    }
}
catch {
    $report.Error = $_.Exception.ToString()
    throw
}
finally {
    $report | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $LogDirectory 'fixture-source.json') -Encoding UTF8
}
