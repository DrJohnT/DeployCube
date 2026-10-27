[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('2017', '2019', '2022', '2025')]
    [string]$SsasVersion,

    [Parameter(Mandatory = $true)]
    [ValidateSet('Tabular', 'Multidimensional')]
    [string]$Mode,

    [Parameter(Mandatory = $true)]
    [uri]$MediaUri,

    [Parameter(Mandatory = $true)]
    [string]$LogDirectory,

    [ValidateRange(1, 150)]
    [int]$MinimumFreeSpaceGB = 24
)

$ErrorActionPreference = 'Stop'
$instanceName = 'DCUBE'
$downloadPath = Join-Path $env:TEMP "sql-server-$SsasVersion-developer.iso"
$engineServiceName = 'MSSQLSERVER'
$analysisServicesServiceName = 'MSOLAP$DCUBE'
$browserServiceName = 'SQLBrowser'
$setupMajorVersions = @{
    '2017' = 14
    '2019' = 15
    '2022' = 16
    '2025' = 17
}
$logDirectory = [System.IO.Path]::GetFullPath($LogDirectory)
New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null

$os = $null
$serverRelease = $null
$systemDrive = $null
$freeSpaceGB = $null
$mountedImage = $null
$outcome = 'Failed'
$setupResults = @()
function Copy-SsasSetupLogs {
    try {
        $summaryFiles = @(
            Get-ChildItem -Path (Join-Path $env:ProgramFiles 'Microsoft SQL Server') -Filter 'Summary.txt' -File -Recurse -ErrorAction Stop |
                Sort-Object -Property LastWriteTime -Descending |
                Select-Object -First 2
        )
        foreach ($summaryFile in $summaryFiles) {
            $destination = Join-Path $logDirectory ("setup-log-" + [Guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $destination -Force -ErrorAction Stop | Out-Null
            $setupLogDirectory = Split-Path -Parent $summaryFile.FullName
            Copy-Item -Path (Join-Path $setupLogDirectory '*') -Destination $destination -Recurse -Force -ErrorAction Stop
        }
    }
    catch {
        Write-Warning "Unable to collect SQL Server setup logs: $($_.Exception.Message)"
    }
}

try {
    $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    if ($os.Caption -match 'Windows Server (2019|2022|2025)') {
        $serverRelease = [int]$matches[1]
    }
    $supportedServerOs = if ($SsasVersion -eq '2017') {
        $serverRelease -in @(2019, 2022)
    }
    else {
        $serverRelease -in @(2019, 2022, 2025)
    }
    if (-not $supportedServerOs) {
        throw "SQL Server $SsasVersion setup is not attempted on unsupported or unverified OS '$($os.Caption)'. See Microsoft's SQL Server $SsasVersion OS requirements."
    }
    if ($MediaUri.Scheme -ne 'https' -or
        $MediaUri.UserInfo -or
        $MediaUri.Query -or
        $MediaUri.Host -notmatch '^download(\.[a-z0-9-]+)*\.microsoft\.com$') {
        throw 'MediaUri must be a direct, public HTTPS Microsoft download URL without credentials or query tokens.'
    }

    $systemDrive = [System.IO.DriveInfo]::new($env:SystemDrive + '\')
    $freeSpaceGB = [math]::Floor($systemDrive.AvailableFreeSpace / 1GB)
    if ($freeSpaceGB -lt $MinimumFreeSpaceGB) {
        throw "Insufficient disk space for SQL Server $SsasVersion media and SSAS installation: $freeSpaceGB GB free on $($systemDrive.Name), at least $MinimumFreeSpaceGB GB required."
    }

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $MediaUri -OutFile $downloadPath -UseBasicParsing -ErrorAction Stop
    if (-not (Test-Path -LiteralPath $downloadPath) -or (Get-Item -LiteralPath $downloadPath).Length -eq 0) {
        throw "Microsoft SQL Server $SsasVersion media download was empty."
    }

    try {
        $mountedImage = Mount-DiskImage -ImagePath $downloadPath -PassThru -ErrorAction Stop
    }
    catch {
        throw "Downloaded media could not be mounted as a SQL Server ISO. MediaUri must resolve directly to the ISO image, not a bootstrapper or interactive downloader. $($_.Exception.Message)"
    }
    $volume = $mountedImage | Get-Volume -ErrorAction Stop
    $mediaRoot = "$($volume.DriveLetter):\"
    $setupPath = Join-Path $mediaRoot 'setup.exe'
    if (-not (Test-Path -LiteralPath $setupPath -PathType Leaf)) {
        throw "The mounted Microsoft SQL Server $SsasVersion ISO does not contain setup.exe at its root."
    }

    $signature = Get-AuthenticodeSignature -FilePath $setupPath
    if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'Microsoft') {
        throw "SQL Server setup.exe did not have a valid Microsoft Authenticode signature (status: $($signature.Status))."
    }
    $setupProductVersion = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($setupPath).ProductVersion
    $expectedSetupPattern = '^\s*' + $setupMajorVersions[$SsasVersion] + '\.'
    if ($setupProductVersion -notmatch $expectedSetupPattern) {
        throw "The selected ISO contains SQL Server setup version '$setupProductVersion', not SQL Server $SsasVersion. This avoids installing a different engine release than the matrix label."
    }

    $setupArguments = @(
        '/Q',
        '/ACTION=Install',
        '/IACCEPTSQLSERVERLICENSETERMS',
        '/SUPPRESSPRIVACYSTATEMENTNOTICE',
        '/INDICATEPROGRESS',
        '/FEATURES=SQL',
        '/INSTANCENAME=MSSQLSERVER',
        '/SQLSVCACCOUNT="NT Service\MSSQLSERVER"',
        '/SQLSYSADMINACCOUNTS="BUILTIN\Administrators"'
    )
    $engineProcess = Start-Process `
        -FilePath $setupPath `
        -ArgumentList $setupArguments `
        -Wait `
        -PassThru `
        -RedirectStandardOutput (Join-Path $logDirectory 'sql-engine-setup.stdout.log') `
        -RedirectStandardError (Join-Path $logDirectory 'sql-engine-setup.stderr.log')
    $setupResults += [pscustomobject]@{
        Feature = 'SQL'
        ExitCode = $engineProcess.ExitCode
    }
    if ($engineProcess.ExitCode -notin @(0, 3010)) {
        throw "SQL Server $SsasVersion Database Engine setup returned exit code $($engineProcess.ExitCode)."
    }

    $analysisServicesArguments = @(
        '/Q',
        '/ACTION=Install',
        '/IACCEPTSQLSERVERLICENSETERMS',
        '/SUPPRESSPRIVACYSTATEMENTNOTICE',
        '/INDICATEPROGRESS',
        '/FEATURES=AS',
        "/ASSERVERMODE=$($Mode.ToUpperInvariant())",
        "/INSTANCENAME=$instanceName",
        '/ASSVCACCOUNT="NT Service\MSOLAP$DCUBE"',
        '/ASSYSADMINACCOUNTS="BUILTIN\Administrators"'
    )
    $analysisServicesProcess = Start-Process `
        -FilePath $setupPath `
        -ArgumentList $analysisServicesArguments `
        -Wait `
        -PassThru `
        -RedirectStandardOutput (Join-Path $logDirectory 'analysis-services-setup.stdout.log') `
        -RedirectStandardError (Join-Path $logDirectory 'analysis-services-setup.stderr.log')
    $setupResults += [pscustomobject]@{
        Feature = 'AS'
        ExitCode = $analysisServicesProcess.ExitCode
    }
    if ($analysisServicesProcess.ExitCode -notin @(0, 3010)) {
        throw "SQL Server $SsasVersion Analysis Services setup returned exit code $($analysisServicesProcess.ExitCode)."
    }

    Set-Service -Name $browserServiceName -StartupType Automatic -ErrorAction Stop
    $browserService = Get-Service -Name $browserServiceName -ErrorAction Stop
    if ($browserService.Status -ne [System.ServiceProcess.ServiceControllerStatus]::Running) {
        Start-Service -Name $browserServiceName -ErrorAction Stop
    }

    foreach ($serviceName in @($engineServiceName, $analysisServicesServiceName, $browserServiceName)) {
        $service = Get-Service -Name $serviceName -ErrorAction Stop
        $service.WaitForStatus([System.ServiceProcess.ServiceControllerStatus]::Running, [TimeSpan]::FromMinutes(5))
    }
    $outcome = 'Installed'
}
catch {
    $failureMessage = $_.Exception.Message
    [pscustomobject]@{
        SsasVersion = $SsasVersion
        Mode = $Mode
        Outcome = 'Failed'
        Error = $failureMessage
        MediaHost = $MediaUri.Host
        SetupResults = $setupResults
        OperatingSystem = if ($os) { $os.Caption } else { $null }
        DiskFreeBeforeGB = $freeSpaceGB
        FailedAtUtc = [DateTime]::UtcNow.ToString('o')
    } | ConvertTo-Json -Depth 7 |
        Set-Content -LiteralPath (Join-Path $logDirectory 'ssas-install-failure.json') -Encoding UTF8
    Add-Content -LiteralPath $env:GITHUB_STEP_SUMMARY -Value "## SSAS $SsasVersion ($Mode) installation failed`n`n$failureMessage`n`nNo successful installation is claimed." -Encoding UTF8
    throw
}
finally {
    if ($mountedImage) {
        Dismount-DiskImage -ImagePath $downloadPath -ErrorAction SilentlyContinue
    }
    if (Test-Path -LiteralPath $downloadPath) {
        Remove-Item -LiteralPath $downloadPath -Force -ErrorAction SilentlyContinue
    }
    Copy-SsasSetupLogs
}

[pscustomobject]@{
    SsasVersion = $SsasVersion
    Mode = $Mode
    Outcome = $outcome
    MediaHost = $MediaUri.Host
    DatabaseEngineService = $engineServiceName
    AnalysisServicesService = $analysisServicesServiceName
    SqlBrowserService = $browserServiceName
    InstanceName = $instanceName
    SetupResults = $setupResults
    OperatingSystem = $os.Caption
    DiskFreeBeforeGB = $freeSpaceGB
    DiskFreeAfterGB = [math]::Floor($systemDrive.AvailableFreeSpace / 1GB)
    InstalledAtUtc = [DateTime]::UtcNow.ToString('o')
} | ConvertTo-Json -Depth 7 |
    Set-Content -LiteralPath (Join-Path $logDirectory 'ssas-install.json') -Encoding UTF8
