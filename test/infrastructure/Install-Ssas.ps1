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
    [int]$MinimumFreeSpaceGB = 24,

    [ValidateRange(1, 240)]
    [int]$MediaTimeoutMinutes = 90,

    [ValidateRange(1, 240)]
    [int]$SetupTimeoutMinutes = 120,

    [ValidateRange(1, 60)]
    [int]$ServiceReadinessTimeoutMinutes = 15
)

$ErrorActionPreference = 'Stop'
$instanceName = 'DCUBE'
$bootstrapperUrl = 'https://go.microsoft.com/fwlink/?linkid=2215158&clcid=0x409'
$mediaDirectory = Join-Path $env:TEMP "sql-server-$SsasVersion-developer-media-$PID"
$downloadPath = Join-Path $mediaDirectory "sql-server-$SsasVersion-developer.iso"
$bootstrapperPath = Join-Path $env:TEMP "sql-server-$SsasVersion-developer-setup-$PID.exe"
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
$serviceReadinessDurationSeconds = $null
$mediaStopwatch = $null
$setupStopwatch = $null
$serviceStopwatch = $null
$serviceStatuses = @()
$setupProductVersion = $null
$setupStatePath = Join-Path $logDirectory 'provisioning-status.json'
$provisioningLogPath = Join-Path $logDirectory 'provisioning.log'
$provisioningState = [ordered]@{
    SsasVersion = $SsasVersion
    Mode = $Mode
    CurrentStage = 'Initializing'
    Outcome = 'Running'
    StartedAtUtc = [DateTime]::UtcNow.ToString('o')
    LastActivityAtUtc = [DateTime]::UtcNow.ToString('o')
}

function Write-ProvisioningLog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Stage,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $timestamp = [DateTime]::UtcNow.ToString('o')
    $line = "[$timestamp] [$Stage] $Message"
    Write-Host $line
    Add-Content -LiteralPath $provisioningLogPath -Value $line -Encoding UTF8
    $provisioningState.CurrentStage = $Stage
    $provisioningState.LastActivityAtUtc = $timestamp
    $provisioningState.LastMessage = $Message
    $provisioningState | ConvertTo-Json -Depth 7 |
        Set-Content -LiteralPath $setupStatePath -Encoding UTF8
}

function Invoke-BoundedProcess {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $true)]
        [string[]]$ArgumentList,

        [Parameter(Mandatory = $true)]
        [int]$TimeoutSeconds,

        [Parameter(Mandatory = $true)]
        [string]$Stage,

        [Parameter(Mandatory = $true)]
        [string]$StandardOutputPath,

        [Parameter(Mandatory = $true)]
        [string]$StandardErrorPath,

        [string]$ObservedDirectory
    )

    $process = Start-Process -FilePath $FilePath -ArgumentList $ArgumentList `
        -PassThru -RedirectStandardOutput $StandardOutputPath `
        -RedirectStandardError $StandardErrorPath -ErrorAction Stop
    $processStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    Write-ProvisioningLog -Stage $Stage -Message "Started process '$FilePath' (PID $($process.Id)); timeout ${TimeoutSeconds}s."

    while (-not $process.WaitForExit(30000)) {
        if ($processStopwatch.Elapsed.TotalSeconds -ge $TimeoutSeconds) {
            Write-ProvisioningLog -Stage $Stage -Message "Process PID $($process.Id) exceeded its timeout; terminating its process tree."
            $taskkillPath = Join-Path $env:SystemRoot 'System32\taskkill.exe'
            $killer = Start-Process -FilePath $taskkillPath `
                -ArgumentList @('/PID', [string]$process.Id, '/T', '/F') `
                -PassThru -WindowStyle Hidden -ErrorAction Stop
            if (-not $killer.WaitForExit(30000)) {
                $killer.Kill()
                throw "Unable to terminate timed-out process tree for PID $($process.Id) using taskkill."
            }
            if (-not $process.WaitForExit(15000)) {
                $process.Kill()
                if (-not $process.WaitForExit(15000)) {
                    throw "Timed-out process PID $($process.Id) did not exit after process-tree termination."
                }
            }
            throw [System.TimeoutException]::new(
                "Process '$FilePath' exceeded the $TimeoutSeconds-second timeout in stage '$Stage'."
            )
        }

        $progressMessage = "Process PID $($process.Id) is still running after $([math]::Round($processStopwatch.Elapsed.TotalMinutes, 1)) minutes."
        if ($ObservedDirectory -and (Test-Path -LiteralPath $ObservedDirectory -PathType Container)) {
            $files = @(Get-ChildItem -LiteralPath $ObservedDirectory -File -Recurse -ErrorAction SilentlyContinue)
            $totalBytes = ($files | Measure-Object -Property Length -Sum).Sum
            $latestFile = $files | Sort-Object -Property LastWriteTime -Descending | Select-Object -First 1
            $progressMessage += " Media files: $($files.Count); bytes: $totalBytes; latest file: $($latestFile.FullName)."
        }
        Write-ProvisioningLog -Stage $Stage -Message $progressMessage
    }

    $process.Refresh()
    $durationSeconds = [math]::Round($processStopwatch.Elapsed.TotalSeconds, 2)
    Write-ProvisioningLog -Stage $Stage -Message (
        "Process PID $($process.Id) exited with code $($process.ExitCode) after $durationSeconds seconds."
    )
    return [pscustomobject]@{
        ExitCode = $process.ExitCode
        DurationSeconds = $durationSeconds
        ProcessId = $process.Id
    }
}

function Copy-SsasSetupLogs {
    try {
        $setupLogRoots = @(
            (Join-Path $env:ProgramFiles "Microsoft SQL Server\$($setupMajorVersions[$SsasVersion])0\Setup Bootstrap\Log"),
            (Join-Path ${env:ProgramFiles(x86)} "Microsoft SQL Server\$($setupMajorVersions[$SsasVersion])0\Setup Bootstrap\Log")
        ) | Where-Object { Test-Path -LiteralPath $_ -PathType Container }
        $summaryFiles = @(
            foreach ($root in $setupLogRoots) {
                Get-ChildItem -LiteralPath $root -Filter 'Summary.txt' -File -Recurse -ErrorAction Stop
            }
        ) | Sort-Object -Property LastWriteTime -Descending |
            Select-Object -First 2
        foreach ($summaryFile in $summaryFiles) {
            $destination = Join-Path $logDirectory ("setup-log-" + [Guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $destination -Force -ErrorAction Stop | Out-Null
            $setupLogDirectory = Split-Path -Parent $summaryFile.FullName
            Copy-Item -Path (Join-Path $setupLogDirectory '*') -Destination $destination -Recurse -Force -ErrorAction Stop
            Write-ProvisioningLog -Stage 'Diagnostics' -Message "Copied SQL Server setup logs from '$setupLogDirectory'."
        }
    }
    catch {
        Write-ProvisioningLog -Stage 'Diagnostics' -Message "SQL Server setup log collection failed: $($_.Exception)"
    }

    try {
        $eventStart = (Get-Date).AddHours(-5)
        $events = Get-WinEvent -FilterHashtable @{
            LogName = 'Application'
            StartTime = $eventStart
        } -ErrorAction Stop |
            Where-Object { $_.ProviderName -match 'MSSQL|SQL.*Setup|MsiInstaller' } |
            Select-Object -First 500 TimeCreated, ProviderName, Id, LevelDisplayName, Message
        $events | Export-Clixml -LiteralPath (Join-Path $logDirectory 'sql-setup-application-events.xml')
        Write-ProvisioningLog -Stage 'Diagnostics' -Message "Collected $(@($events).Count) SQL Setup / installer Application events."
    }
    catch {
        Write-ProvisioningLog -Stage 'Diagnostics' -Message "Application event collection failed: $($_.Exception)"
    }
}

try {
    Write-ProvisioningLog -Stage 'Preflight' -Message "Beginning SQL Server $SsasVersion $Mode provisioning."
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
    Write-ProvisioningLog -Stage 'Preflight' -Message (
        "Runner OS '$($os.Caption)'; system drive free space $freeSpaceGB GB; media timeout ${MediaTimeoutMinutes}m, setup timeout ${SetupTimeoutMinutes}m, service readiness timeout ${ServiceReadinessTimeoutMinutes}m."
    )

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $failureCategory = 'SSAS media acquisition'
    $mediaStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    Write-ProvisioningLog -Stage $failureCategory -Message "Acquiring official Microsoft SQL Server $SsasVersion media from '$($MediaUri.Host)'."
    if ($isOfficialSql2022DeveloperBootstrapper) {
        $bootstrapperDownload = Invoke-BoundedProcess `
            -FilePath (Join-Path $env:SystemRoot 'System32\curl.exe') `
            -ArgumentList @('--location', '--fail', '--show-error', '--silent', '--connect-timeout', '60', '--max-time', '300', '--output', "`"$bootstrapperPath`"", $MediaUri.AbsoluteUri) `
            -TimeoutSeconds 300 -Stage 'SSAS bootstrapper download' `
            -StandardOutputPath (Join-Path $logDirectory 'bootstrapper-download.stdout.log') `
            -StandardErrorPath (Join-Path $logDirectory 'bootstrapper-download.stderr.log')
        if ($bootstrapperDownload.ExitCode -ne 0) {
            throw "Microsoft SQL Server 2022 Developer bootstrapper download returned curl exit code $($bootstrapperDownload.ExitCode)."
        }
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
            '/MediaType=ISO',
            "/MediaPath=`"$mediaDirectory`"",
            '/IAcceptSqlServerLicenseTerms=True',
            '/Quiet=True',
            '/HideProgressBar=True'
        )
        $downloadProcess = Invoke-BoundedProcess `
            -FilePath $bootstrapperPath -ArgumentList $bootstrapperArguments `
            -TimeoutSeconds ($MediaTimeoutMinutes * 60) -Stage 'SSAS media acquisition' `
            -StandardOutputPath (Join-Path $logDirectory 'media-download.stdout.log') `
            -StandardErrorPath (Join-Path $logDirectory 'media-download.stderr.log') `
            -ObservedDirectory $mediaDirectory
        if ($downloadProcess.ExitCode -notin @(0, 3010)) {
            throw "The signed Microsoft SQL Server 2022 Developer bootstrapper returned exit code $($downloadProcess.ExitCode) while downloading ISO media."
        }

        $downloadedIso = Get-ChildItem -LiteralPath $mediaDirectory -Filter '*.iso' -File -Recurse -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($downloadedIso) {
            $downloadPath = $downloadedIso.FullName
            Write-ProvisioningLog -Stage $failureCategory -Message (
                "Downloaded ISO '$($downloadedIso.FullName)' ($([math]::Round($downloadedIso.Length / 1GB, 2)) GB)."
            )
        }
        else {
            $mediaRoot = (Get-ChildItem -LiteralPath $mediaDirectory -Filter 'setup.exe' -File -Recurse -ErrorAction SilentlyContinue |
                Select-Object -First 1 |
                ForEach-Object { Split-Path -Parent $_.FullName })
            if (-not $mediaRoot) {
                throw "The official Developer bootstrapper completed with exit code $($downloadProcess.ExitCode), but produced neither an ISO nor a directory containing setup.exe under '$mediaDirectory'. See media-download logs."
            }
            Write-ProvisioningLog -Stage $failureCategory -Message "Bootstrapper produced extracted media at '$mediaRoot'."
        }
    }
    else {
        $downloadedIso = $downloadPath
        New-Item -ItemType Directory -Path $mediaDirectory -Force | Out-Null
        $mediaDownload = Invoke-BoundedProcess `
            -FilePath (Join-Path $env:SystemRoot 'System32\curl.exe') `
            -ArgumentList @('--location', '--fail', '--show-error', '--silent', '--connect-timeout', '60', '--max-time', [string]($MediaTimeoutMinutes * 60), '--output', "`"$downloadPath`"", $MediaUri.AbsoluteUri) `
            -TimeoutSeconds ($MediaTimeoutMinutes * 60) -Stage 'SSAS media acquisition' `
            -StandardOutputPath (Join-Path $logDirectory 'media-download.stdout.log') `
            -StandardErrorPath (Join-Path $logDirectory 'media-download.stderr.log') `
            -ObservedDirectory $mediaDirectory
        if ($mediaDownload.ExitCode -ne 0) {
            throw "Microsoft SQL Server $SsasVersion ISO download returned curl exit code $($mediaDownload.ExitCode)."
        }
        if (-not (Test-Path -LiteralPath $downloadPath) -or (Get-Item -LiteralPath $downloadPath).Length -eq 0) {
            throw "Microsoft SQL Server $SsasVersion media download was empty."
        }
        Write-ProvisioningLog -Stage $failureCategory -Message (
            "Downloaded ISO '$downloadPath' ($([math]::Round((Get-Item -LiteralPath $downloadPath).Length / 1GB, 2)) GB)."
        )
    }

    if ($downloadedIso -is [System.IO.FileInfo] -or $downloadedIso -eq $downloadPath) {
        try {
            $failureCategory = 'ISO mounting'
            $mountStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            Write-ProvisioningLog -Stage 'ISO mounting' -Message "Mounting '$downloadPath'."
            $mountedImage = Mount-DiskImage -ImagePath $downloadPath -PassThru -ErrorAction Stop
            $volume = $mountedImage | Get-Volume -ErrorAction Stop
            if (-not $volume.DriveLetter) {
                throw "Mounted SQL Server ISO '$downloadPath' has no drive letter."
            }
            $mountStopwatch.Stop()
            Write-ProvisioningLog -Stage 'ISO mounting' -Message (
                "Mounted ISO as '$($volume.DriveLetter):\' in $([math]::Round($mountStopwatch.Elapsed.TotalSeconds, 2)) seconds."
            )
        }
        catch {
            throw "ISO mounting failed for '$downloadPath'. $($_.Exception.ToString())"
        }
        $mediaRoot = "$($volume.DriveLetter):\"
    }

    $failureCategory = 'SSAS media validation'
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
    Write-ProvisioningLog -Stage $failureCategory -Message (
        "Verified signed SQL Server setup $setupProductVersion at '$setupPath'; installing Analysis Services instance '$instanceName' in $Mode mode."
    )

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
    $analysisServicesProcess = Invoke-BoundedProcess `
        -FilePath $setupPath -ArgumentList $analysisServicesArguments `
        -TimeoutSeconds ($SetupTimeoutMinutes * 60) -Stage 'SSAS installation' `
        -StandardOutputPath (Join-Path $logDirectory 'analysis-services-setup.stdout.log') `
        -StandardErrorPath (Join-Path $logDirectory 'analysis-services-setup.stderr.log')
    $setupResults += [pscustomobject]@{
        Feature = 'AS'
        ExitCode = $analysisServicesProcess.ExitCode
        DurationSeconds = $analysisServicesProcess.DurationSeconds
        ProcessId = $analysisServicesProcess.ProcessId
    }
    if ($analysisServicesProcess.ExitCode -notin @(0, 3010)) {
        throw "SQL Server $SsasVersion Analysis Services setup returned exit code $($analysisServicesProcess.ExitCode)."
    }
    $setupStopwatch.Stop()
    $setupDurationSeconds = [math]::Round($setupStopwatch.Elapsed.TotalSeconds, 2)

    $failureCategory = 'Windows service readiness'
    $serviceStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $serviceDeadline = [DateTime]::UtcNow.AddMinutes($ServiceReadinessTimeoutMinutes)
    Write-ProvisioningLog -Stage $failureCategory -Message (
        "Waiting up to ${ServiceReadinessTimeoutMinutes}m for '$analysisServicesServiceName' and '$browserServiceName'."
    )
    Set-Service -Name $browserServiceName -StartupType Automatic -ErrorAction Stop
    foreach ($serviceName in @($analysisServicesServiceName, $browserServiceName)) {
        $started = $false
        while ([DateTime]::UtcNow -lt $serviceDeadline) {
            try {
                $service = Get-Service -Name $serviceName -ErrorAction Stop
                if ($service.Status -eq [System.ServiceProcess.ServiceControllerStatus]::Running) {
                    $serviceStatuses += [pscustomobject]@{
                        Name = $service.Name
                        Status = [string]$service.Status
                    }
                    Write-ProvisioningLog -Stage $failureCategory -Message "Service '$serviceName' is Running."
                    break
                }
                if (-not $started -and $service.Status -eq [System.ServiceProcess.ServiceControllerStatus]::Stopped) {
                    Write-ProvisioningLog -Stage $failureCategory -Message "Starting service '$serviceName'."
                    Start-Service -Name $serviceName -ErrorAction Stop
                    $started = $true
                }
                Write-ProvisioningLog -Stage $failureCategory -Message (
                    "Service '$serviceName' status is '$($service.Status)'; polling again in 15 seconds."
                )
            }
            catch {
                if ($_.FullyQualifiedErrorId -like 'NoServiceFoundForGivenName*') {
                    Write-ProvisioningLog -Stage $failureCategory -Message "Service '$serviceName' is not registered yet; polling again in 15 seconds."
                }
                else {
                    throw
                }
            }
            Start-Sleep -Seconds 15
        }
        if (-not ($serviceStatuses | Where-Object { $_.Name -eq $serviceName })) {
            $lastStatus = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            throw "Timed out waiting for service '$serviceName' to reach Running (last status: $($lastStatus.Status))."
        }
    }
    $serviceStopwatch.Stop()
    $serviceReadinessDurationSeconds = [math]::Round($serviceStopwatch.Elapsed.TotalSeconds, 2)
    $failureCategory = 'SSAS server verification'
    Write-ProvisioningLog -Stage $failureCategory -Message 'Service readiness succeeded; server mode and product version will be verified by the next workflow step.'
    $stopwatch.Stop()
    $outcome = 'Installed'
}
catch {
    $failureMessage = $_.Exception.Message
    if ($mediaStopwatch -and $mediaStopwatch.IsRunning) {
        $mediaStopwatch.Stop()
        $mediaDurationSeconds = [math]::Round($mediaStopwatch.Elapsed.TotalSeconds, 2)
    }
    if ($setupStopwatch -and $setupStopwatch.IsRunning) {
        $setupStopwatch.Stop()
        $setupDurationSeconds = [math]::Round($setupStopwatch.Elapsed.TotalSeconds, 2)
    }
    if ($serviceStopwatch -and $serviceStopwatch.IsRunning) {
        $serviceStopwatch.Stop()
        $serviceReadinessDurationSeconds = [math]::Round($serviceStopwatch.Elapsed.TotalSeconds, 2)
    }
    $provisioningState.Outcome = 'Failed'
    $provisioningState.FailureCategory = $failureCategory
    $provisioningState.ErrorDetails = $_.Exception.ToString()
    $provisioningState.FinishedAtUtc = [DateTime]::UtcNow.ToString('o')
    $provisioningState | ConvertTo-Json -Depth 7 |
        Set-Content -LiteralPath $setupStatePath -Encoding UTF8
    Write-ProvisioningLog -Stage $failureCategory -Message "Provisioning failed: $($_.Exception.ToString())"
    [pscustomobject]@{
        SsasVersion = $SsasVersion
        Mode = $Mode
        Outcome = 'Failed'
        Error = $failureMessage
        ErrorDetails = $_.Exception.ToString()
        FailureCategory = $failureCategory
        MediaHost = $MediaUri.Host
        SetupProductVersion = $setupProductVersion
        SetupResults = $setupResults
        MediaAcquisitionDurationSeconds = $mediaDurationSeconds
        SetupDurationSeconds = $setupDurationSeconds
        ServiceReadinessDurationSeconds = $serviceReadinessDurationSeconds
        ServiceStatuses = $serviceStatuses
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
        try {
            Dismount-DiskImage -ImagePath $downloadPath -ErrorAction Stop
            Write-ProvisioningLog -Stage 'Cleanup' -Message "Dismounted '$downloadPath'."
        }
        catch {
            Write-ProvisioningLog -Stage 'Cleanup' -Message "ISO dismount failed: $($_.Exception.ToString())"
        }
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

$provisioningState.CurrentStage = 'Complete'
$provisioningState.Outcome = $outcome
$provisioningState.FinishedAtUtc = [DateTime]::UtcNow.ToString('o')
$provisioningState | ConvertTo-Json -Depth 7 |
    Set-Content -LiteralPath $setupStatePath -Encoding UTF8

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
    ServiceStatuses = $serviceStatuses
    OperatingSystem = $os.Caption
    DiskFreeBeforeGB = $freeSpaceGB
    DiskFreeAfterGB = [math]::Floor($systemDrive.AvailableFreeSpace / 1GB)
    InstallationDurationSeconds = [math]::Round($stopwatch.Elapsed.TotalSeconds, 2)
    MediaAcquisitionDurationSeconds = $mediaDurationSeconds
    SetupDurationSeconds = $setupDurationSeconds
    ServiceReadinessDurationSeconds = $serviceReadinessDurationSeconds
    InstalledAtUtc = [DateTime]::UtcNow.ToString('o')
} | ConvertTo-Json -Depth 7 |
    Set-Content -LiteralPath (Join-Path $logDirectory 'ssas-install.json') -Encoding UTF8
