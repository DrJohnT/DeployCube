[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('2017', '2019', '2022', '2025')]
    [string]$SsasVersion,

    [Parameter(Mandatory = $true)]
    [ValidateSet('Tabular', 'Multidimensional')]
    [string]$Mode,

    [Parameter(Mandatory = $true)]
    [string]$InstallationReportPath,

    [Parameter(Mandatory = $true)]
    [string]$ReportPath,

    [Parameter(Mandatory = $true)]
    [string]$LogPath
)

$ErrorActionPreference = 'Stop'
$serverName = 'localhost\DCUBE'
$serviceName = 'MSOLAP$DCUBE'
. (Join-Path $PSScriptRoot 'Get-SsasProductMajor.ps1')
$expectedProductMajor = Get-SsasProductMajor -SsasVersion $SsasVersion
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$result = [ordered]@{
    Outcome = 'Failed'
    SsasVersion = $SsasVersion
    ExpectedMode = $Mode
    Server = $serverName
    ServiceName = $serviceName
    ServiceStatus = $null
    ActualMode = $null
    ProductVersion = $null
    Edition = $null
    VerificationDurationSeconds = $null
    Error = $null
}

function Write-VerificationLog {
    param([Parameter(Mandatory = $true)][string]$Message)
    $line = "[$([DateTime]::UtcNow.ToString('o'))] $Message"
    Write-Host $line
    Add-Content -LiteralPath $LogPath -Value $line -Encoding UTF8
}

try {
    New-Item -ItemType Directory -Path (Split-Path -Parent $ReportPath) -Force | Out-Null
    New-Item -ItemType Directory -Path (Split-Path -Parent $LogPath) -Force | Out-Null
    Write-VerificationLog -Message "Verifying SSAS $SsasVersion $Mode service '$serviceName'."
    $service = Get-Service -Name $serviceName -ErrorAction Stop
    $result.ServiceStatus = [string]$service.Status
    if ($service.Status -ne [System.ServiceProcess.ServiceControllerStatus]::Running) {
        throw "Expected service '$serviceName' to be Running; actual status is '$($service.Status)'."
    }

    if (-not (Get-Module -ListAvailable -Name SqlServer)) {
        Write-VerificationLog -Message 'SqlServer PowerShell module is missing; installing from PSGallery for AMO connectivity verification.'
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
        Install-Module -Name SqlServer -Force -Scope CurrentUser -ErrorAction Stop
    }
    Import-Module SqlServer -ErrorAction Stop

    $server = New-Object Microsoft.AnalysisServices.Server
    try {
        Write-VerificationLog -Message "Connecting to '$serverName' with AMO."
        $server.Connect($serverName)
        $result.ActualMode = [string]$server.ServerMode
        $result.ProductVersion = $server.Version.ToString()
        $result.Edition = [string]$server.Edition
    }
    finally {
        if ($server.Connected) {
            $server.Disconnect()
        }
    }

    if ($result.ProductVersion -notmatch ('^' + $expectedProductMajor + '\.')) {
        throw "Expected SQL Server Analysis Services $SsasVersion product major $expectedProductMajor; server reports '$($result.ProductVersion)'."
    }
    if ($result.ActualMode -ne $Mode) {
        throw "Expected SSAS mode '$Mode'; server reports '$($result.ActualMode)'."
    }
    if ($result.Edition -notmatch 'Developer') {
        throw "Expected Analysis Services Developer Edition; server reports '$($result.Edition)'."
    }
    $result.Outcome = 'Passed'
    Write-VerificationLog -Message (
        "PASS: service Running; server '$serverName' reports $($result.Edition), product $($result.ProductVersion), mode $($result.ActualMode)."
    )
}
catch {
    $result.Error = $_.Exception.ToString()
    Write-VerificationLog -Message "FAIL: $($result.Error)"
}
finally {
    $stopwatch.Stop()
    $result.VerificationDurationSeconds = [math]::Round($stopwatch.Elapsed.TotalSeconds, 2)
    $installation = $null
    if (Test-Path -LiteralPath $InstallationReportPath) {
        $installation = Get-Content -LiteralPath $InstallationReportPath -Raw | ConvertFrom-Json
    }
    $result.InstallationDurationSeconds = $installation.InstallationDurationSeconds
    $result.MediaAcquisitionDurationSeconds = $installation.MediaAcquisitionDurationSeconds
    $result.SetupDurationSeconds = $installation.SetupDurationSeconds
    $result.ServiceReadinessDurationSeconds = $installation.ServiceReadinessDurationSeconds
    $result.VerifiedAtUtc = [DateTime]::UtcNow.ToString('o')
    $result | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
}

if ($result.Outcome -ne 'Passed') {
    throw "SSAS provisioning verification failed. See '$ReportPath' and '$LogPath'."
}
