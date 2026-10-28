[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('2017', '2019', '2022', '2025')]
    [string]$SsasVersion,

    [Parameter(Mandatory = $true)]
    [ValidateSet('Tabular', 'Multidimensional')]
    [string]$Mode,

    [Parameter(Mandatory = $true)]
    [string]$MediaRoot,

    [Parameter(Mandatory = $true)]
    [string]$MediaAcquisitionReportPath,

    [Parameter(Mandatory = $true)]
    [string]$LogDirectory,

    [ValidateRange(1, 150)]
    [int]$MinimumFreeSpaceGB = 24,

    [ValidateRange(1, 240)]
    [int]$SetupTimeoutMinutes = 120,

    [ValidateRange(1, 60)]
    [int]$ServiceReadinessTimeoutMinutes = 15
)

$ErrorActionPreference = 'Stop'
$instanceName = 'DCUBE'
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
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$outcome = 'Failed'
$setupResults = @()
$failureCategory = 'SSAS prerequisites'
$mediaDurationSeconds = $null
$setupDurationSeconds = $null
$serviceReadinessDurationSeconds = $null
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

. (Join-Path $PSScriptRoot 'Invoke-BoundedProcess.ps1')
. (Join-Path $PSScriptRoot 'SqlServerMedia.ps1')

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
    $systemDrive = [System.IO.DriveInfo]::new($env:SystemDrive + '\')
    $freeSpaceGB = [math]::Floor($systemDrive.AvailableFreeSpace / 1GB)
    if ($freeSpaceGB -lt $MinimumFreeSpaceGB) {
        throw "Insufficient disk space for SQL Server $SsasVersion media and SSAS installation: $freeSpaceGB GB free on $($systemDrive.Name), at least $MinimumFreeSpaceGB GB required."
    }
    Write-ProvisioningLog -Stage 'Preflight' -Message (
        "Runner OS '$($os.Caption)'; system drive free space $freeSpaceGB GB; setup timeout ${SetupTimeoutMinutes}m, service readiness timeout ${ServiceReadinessTimeoutMinutes}m."
    )

    $failureCategory = 'SSAS media validation'
    $mediaReport = Get-Content -LiteralPath $MediaAcquisitionReportPath -Raw | ConvertFrom-Json
    if ($mediaReport.Outcome -ne 'Passed') {
        throw 'Media acquisition did not pass; SQL Server setup will not run.'
    }
    $mediaDurationSeconds = $mediaReport.DownloadDurationSeconds
    $setupProductVersion = Assert-SqlServerMediaRoot -MediaRoot $MediaRoot -ExpectedMajor $setupMajorVersions[$SsasVersion]
    $setupPath = Join-Path $mediaRoot 'setup.exe'
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
        MediaSource = $mediaReport.Source
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
    MediaSource = $mediaReport.Source
    InstallationMedia = 'Microsoft SQL Server ISO'
    SetupProductVersion = $setupProductVersion
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
