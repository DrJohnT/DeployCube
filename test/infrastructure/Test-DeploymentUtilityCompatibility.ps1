[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$DeploymentUtilityPath,

    [Parameter(Mandatory = $true)]
    [string]$ModelPath,

    [Parameter(Mandatory = $true)]
    [string]$Server,

    [Parameter(Mandatory = $true)]
    [string]$LogDirectory,

    [ValidateSet('Tabular', 'Multidimensional')]
    [string]$Mode = 'Tabular'
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Assert-MultidimensionalMetadata.ps1')
$probeDirectory = Join-Path $LogDirectory 'utility-probe'
New-Item -ItemType Directory -Path $probeDirectory -Force | Out-Null
$probeDirectory = (Resolve-Path -LiteralPath $probeDirectory).Path
$probeModelPath = Join-Path $probeDirectory 'Model.asdatabase'
Copy-Item -Path (Join-Path (Split-Path -Parent $ModelPath) 'Model.*') -Destination $probeDirectory -Force
$databaseName = 'DeployCubeUtilityCompatibilityProbe'
[xml]$targets = Get-Content -LiteralPath (Join-Path $probeDirectory 'Model.deploymenttargets') -Raw
$targets.DeploymentTarget.Database = $databaseName
$targets.DeploymentTarget.Server = $Server
$targets.DeploymentTarget.ConnectionString = "Data Source=$Server;Timeout=0"
$targets.Save((Join-Path $probeDirectory 'Model.deploymenttargets'))
$report = @{
    Outcome = 'Failed'
    Database = $databaseName
    ExitCode = $null
    DatabaseExists = $false
    CompatibilityLevel = $null
    Metadata = $null
    Cleanup = 'NotRun'
    Error = $null
    FailureCategory = 'Deployment Utility compatibility'
}
$connection = New-Object Microsoft.AnalysisServices.Server
try {
    $connection.Connect($Server)
    if ($connection.Databases.FindByName($databaseName)) {
        throw "Utility probe database '$databaseName' already exists; refusing to overwrite it."
    }
    $logPath = Join-Path $probeDirectory 'deployment.log'
    $process = Start-Process -FilePath $DeploymentUtilityPath `
        -ArgumentList @("`"$probeModelPath`"", "/s:`"$logPath`"") `
        -Wait -PassThru `
        -RedirectStandardOutput (Join-Path $probeDirectory 'stdout.log') `
        -RedirectStandardError (Join-Path $probeDirectory 'stderr.log')
    $report.ExitCode = $process.ExitCode
    if ($process.ExitCode -ne 0) {
        throw "Deployment Utility compatibility probe returned exit code $($process.ExitCode). See '$probeDirectory'."
    }
    $report.FailureCategory = 'Database verification'
    $connection.Refresh($true)
    $database = $connection.Databases.FindByName($databaseName)
    $report.DatabaseExists = $null -ne $database
    if (-not $database) {
        throw 'Deployment Utility returned success but the probe database does not exist.'
    }
    $report.CompatibilityLevel = $database.CompatibilityLevel
    if ($Mode -eq 'Multidimensional') {
        $report.FailureCategory = 'Server-side metadata validation'
        $report.Metadata = Assert-MultidimensionalMetadata -Database $database
    }
    elseif ($database.CompatibilityLevel -ne 1500) {
        throw "Utility probe database compatibility level was $($database.CompatibilityLevel), expected 1500."
    }
    $report.Outcome = 'Passed'
    $report.FailureCategory = $null
}
catch {
    $report.Error = $_.Exception.ToString()
    throw
}
finally {
    try {
        if ($connection.Connected) {
            $connection.Refresh($true)
            $database = $connection.Databases.FindByName($databaseName)
            if ($database -and $null -ne $report.ExitCode) {
                $database.Drop()
                $connection.Refresh($true)
                if ($connection.Databases.FindByName($databaseName)) {
                    throw "Utility probe database '$databaseName' still exists after cleanup."
                }
                $report.Cleanup = 'Passed'
            }
        }
    }
    catch {
        $report.Cleanup = 'Failed'
        $report.FailureCategory = 'Cleanup'
        $report.Outcome = 'Failed'
        $report.Error = "$($report.Error)`nCleanup: $($_.Exception)"
        throw
    }
    finally {
        if ($connection.Connected) {
            $connection.Disconnect()
        }
        $report | ConvertTo-Json -Depth 5 |
            Set-Content -LiteralPath (Join-Path $probeDirectory 'compatibility-probe.json') -Encoding UTF8
    }
}
