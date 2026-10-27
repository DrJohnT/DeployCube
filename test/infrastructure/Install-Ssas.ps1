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
$bootstrapperUrl = 'https://go.microsoft.com/fwlink/?linkid=2215158&clcid=0x409'
$downloadPath = Join-Path $env:TEMP "sql-server-$SsasVersion-developer.iso"
$bootstrapperPath = Join-Path $env:TEMP "sql-server-$SsasVersion-developer-setup.exe"
$mediaDirectory = Join-Path $env:TEMP "sql-server-$SsasVersion-developer-media"
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
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$outcome = 'Failed'
$setupResults = @()
$failureCategory = 'SSAS prerequisites'
$mediaDurationSeconds = $null
$setupDurationSeconds = $null
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
    $isDirectMicrosoftMedia = $MediaUri.Scheme -eq 'https' -and
        -not $MediaUri.UserInfo -and
        -not $MediaUri.Query -and
        $MediaUri.Host -match '^download(\.[a-z0-9-]+)*\.microsoft\.com$'
    $mediaQuery = $MediaUri.Query.TrimStart('?')
    $isOfficialSql2022DeveloperBootstrapper = $SsasVersion -eq '2022' -and
        $MediaUri.Scheme -eq 'https' -and
        $MediaUri.Host -eq 'go.microsoft.com' -and
        $MediaUri.AbsolutePath -eq '/fwlink/' -and
        $mediaQuery -match '(^|&)linkid=2215158(&|$)' -and
        $mediaQuery -match '(^|&)clcid=0x409(&|$)'
    if (-not $isDirectMicrosoftMedia -and -not $isOfficialSql2022DeveloperBootstrapper) {
        throw "MediaUri must be a direct, public Microsoft ISO URL or the exact official SQL Server 2022 Developer bootstrapper URL '$bootstrapperUrl'."
    }

    $systemDrive = [System.IO.DriveInfo]::new($env:SystemDrive + '\')
    $freeSpaceGB = [math]::Floor($systemDrive.AvailableFreeSpace / 1GB)
    if ($freeSpaceGB -lt $MinimumFreeSpaceGB) {
        throw "Insufficient disk space for SQL Server $SsasVersion media and SSAS installation: $freeSpaceGB GB free on $($systemDrive.Name), at least $MinimumFreeSpaceGB GB required."
    }

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $failureCategory = 'SSAS media acquisition'
    $mediaStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    if ($isOfficialSql2022DeveloperBootstrapper) {
        Invoke-WebRequest -Uri $MediaUri -OutFile $bootstrapperPath -UseBasicParsing -ErrorAction Stop
        if (-not (Test-Path -LiteralPath $bootstrapperPath) -or (Get-Item -LiteralPath $bootstrapperPath).Length -eq 0) {
            throw 'Microsoft SQL Server 2022 Developer bootstrapper download was empty.'
        }

        $bootstrapperSignature = Get-AuthenticodeSignature -FilePath $bootstrapperPath
        if ($bootstrapperSignature.Status -ne 'Valid' -or $bootstrapperSignature.SignerCertificate.Subject -notmatch 'Microsoft') {
            throw "SQL Server Developer bootstrapper did not have a valid Microsoft Authenticode signature (status: $($bootstrapperSignature.Status))."
        }

        New-Item -ItemType Directory -Path $mediaDirectory -Force | Out-Null
        $bootstrapperArguments = @(
            '/Action=Download',
            '/MediaType=Full',
            "/MediaPath=`"$mediaDirectory`"",
            '/IAcceptSqlServerLicenseTerms=True',
            '/Quiet=True',
            '/HideProgressBar=True'
        )
        $downloadProcess = Start-Process `
            -FilePath $bootstrapperPath `
            -ArgumentList $bootstrapperArguments `
            -Wait `
            -PassThru `
            -RedirectStandardOutput (Join-Path $logDirectory 'media-download.stdout.log') `
            -RedirectStandardError (Join-Path $logDirectory 'media-download.stderr.log')
        if ($downloadProcess.ExitCode -notin @(0, 3010)) {
            throw "The signed Microsoft SQL Server 2022 Developer bootstrapper returned exit code $($downloadProcess.ExitCode) while downloading full installation media."
        }

        $downloadedIso = Get-ChildItem -LiteralPath $mediaDirectory -Filter '*.iso' -File -Recurse -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($downloadedIso) {
            $downloadPath = $downloadedIso.FullName
        }
        else {
            $mediaRoot = (Get-ChildItem -LiteralPath $mediaDirectory -Filter 'setup.exe' -File -Recurse -ErrorAction SilentlyContinue |
                Select-Object -First 1 |
                ForEach-Object { Split-Path -Parent $_.FullName })
            if (-not $mediaRoot) {
                throw "The official Developer bootstrapper completed with exit code $($downloadProcess.ExitCode), but produced neither an ISO nor a directory containing setup.exe under '$mediaDirectory'. See media-download logs."
            }
        }
    }
    else {
        $downloadedIso = $downloadPath
        Invoke-WebRequest -Uri $MediaUri -OutFile $downloadPath -UseBasicParsing -ErrorAction Stop
        if (-not (Test-Path -LiteralPath $downloadPath) -or (Get-Item -LiteralPath $downloadPath).Length -eq 0) {
            throw "Microsoft SQL Server $SsasVersion media download was empty."
        }
    }

    if ($downloadedIso -is [System.IO.FileInfo] -or $downloadedIso -eq $downloadPath) {
        try {
            $mountedImage = Mount-DiskImage -ImagePath ([string]$downloadedIso) -PassThru -ErrorAction Stop
        }
        catch {
            throw "Downloaded media could not be mounted as a SQL Server ISO. $($_.Exception.Message)"
        }
        $volume = $mountedImage | Get-Volume -ErrorAction Stop
        $mediaRoot = "$($volume.DriveLetter):\"
    }

    $setupPath = Join-Path $mediaRoot 'setup.exe'
    if (-not (Test-Path -LiteralPath $setupPath -PathType Leaf)) {
        throw "The Microsoft SQL Server $SsasVersion media does not contain setup.exe at '$setupPath'."
    }

    $signature = Get-AuthenticodeSignature -FilePath $setupPath
    if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'Microsoft') {
        throw "SQL Server setup.exe did not have a valid Microsoft Authenticode signature (status: $($signature.Status))."
    }
    $setupProductVersion = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($setupPath).ProductVersion
    $expectedSetupPattern = '^\s*' + $setupMajorVersions[$SsasVersion] + '\.'
    if ($setupProductVersion -notmatch $expectedSetupPattern) {
        throw "The selected media contains SQL Server setup version '$setupProductVersion', not SQL Server $SsasVersion. This avoids installing a different release than the matrix label."
    }
    $mediaStopwatch.Stop()
    $mediaDurationSeconds = [math]::Round($mediaStopwatch.Elapsed.TotalSeconds, 2)
    $failureCategory = 'SSAS installation'
    $setupStopwatch = [System.Diagnostics.Stopwatch]::StartNew()

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

    foreach ($serviceName in @($analysisServicesServiceName, $browserServiceName)) {
        $service = Get-Service -Name $serviceName -ErrorAction Stop
        $service.WaitForStatus([System.ServiceProcess.ServiceControllerStatus]::Running, [TimeSpan]::FromMinutes(5))
    }
    $setupStopwatch.Stop()
    $setupDurationSeconds = [math]::Round($setupStopwatch.Elapsed.TotalSeconds, 2)
    $stopwatch.Stop()
    $outcome = 'Installed'
}
catch {
    $failureMessage = $_.Exception.Message
    [pscustomobject]@{
        SsasVersion = $SsasVersion
        Mode = $Mode
        Outcome = 'Failed'
        Error = $failureMessage
        ErrorDetails = $_.Exception.ToString()
        FailureCategory = $failureCategory
        MediaHost = $MediaUri.Host
        SetupResults = $setupResults
        MediaAcquisitionDurationSeconds = $mediaDurationSeconds
        SetupDurationSeconds = $setupDurationSeconds
        OperatingSystem = if ($os) { $os.Caption } else { $null }
        DiskFreeBeforeGB = $freeSpaceGB
        InstallationDurationSeconds = [math]::Round($stopwatch.Elapsed.TotalSeconds, 2)
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
    if ($downloadPath -and (Test-Path -LiteralPath $downloadPath)) {
        Remove-Item -LiteralPath $downloadPath -Force -ErrorAction SilentlyContinue
    }
    foreach ($temporaryPath in @($bootstrapperPath, $mediaDirectory)) {
        if (Test-Path -LiteralPath $temporaryPath) {
            Remove-Item -LiteralPath $temporaryPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    Copy-SsasSetupLogs
}

[pscustomobject]@{
    SsasVersion = $SsasVersion
    Mode = $Mode
    Outcome = $outcome
    MediaHost = $MediaUri.Host
    InstallationMedia = if ($isOfficialSql2022DeveloperBootstrapper) { 'SQL Server 2022 Developer' } else { 'Microsoft SQL Server ISO' }
    SetupProductVersion = $setupProductVersion
    Edition = if ($isOfficialSql2022DeveloperBootstrapper) { 'Developer' } else { $null }
    AnalysisServicesService = $analysisServicesServiceName
    SqlBrowserService = $browserServiceName
    InstanceName = $instanceName
    SetupResults = $setupResults
    OperatingSystem = $os.Caption
    DiskFreeBeforeGB = $freeSpaceGB
    DiskFreeAfterGB = [math]::Floor($systemDrive.AvailableFreeSpace / 1GB)
    InstallationDurationSeconds = [math]::Round($stopwatch.Elapsed.TotalSeconds, 2)
    InstalledAtUtc = [DateTime]::UtcNow.ToString('o')
} | ConvertTo-Json -Depth 7 |
    Set-Content -LiteralPath (Join-Path $logDirectory 'ssas-install.json') -Encoding UTF8
