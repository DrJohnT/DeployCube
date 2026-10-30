[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('18', '19', '20', '21', '22')]
    [string]$SsmsMajor,

    [Parameter(Mandatory = $true)]
    [string]$LogDirectory,

    [ValidateRange(1, 100)]
    [int]$MinimumFreeSpaceGB = 8
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'SqlServerMedia.ps1')
$installerUrls = @{
    '18' = 'https://go.microsoft.com/fwlink/?linkid=2199013&clcid=0x409'
    '19' = 'https://go.microsoft.com/fwlink/?linkid=2257624&clcid=0x409'
    '20' = 'https://go.microsoft.com/fwlink/?linkid=2313753&clcid=0x409'
    '21' = 'https://aka.ms/ssms/21/release/vs_SSMS.exe'
    '22' = 'https://aka.ms/ssms/22/release/vs_SSMS.exe'
}

if (-not (Test-Path -LiteralPath $LogDirectory)) {
    New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
}

$installerPath = Join-Path $env:TEMP "ssms-$SsmsMajor-setup.exe"
$stdoutPath = Join-Path $LogDirectory "ssms-$SsmsMajor-setup.stdout.log"
$stderrPath = Join-Path $LogDirectory "ssms-$SsmsMajor-setup.stderr.log"
$systemDrive = $null
$freeSpaceGB = $null
$downloadDurationSeconds = $null
$installerSignature = $null
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

try {
    $systemDrive = [System.IO.DriveInfo]::new($env:SystemDrive + '\')
    $freeSpaceGB = [math]::Floor($systemDrive.AvailableFreeSpace / 1GB)
    if ($freeSpaceGB -lt $MinimumFreeSpaceGB) {
        throw "Insufficient disk space for SSMS $SsmsMajor installation: $freeSpaceGB GB free on $($systemDrive.Name), at least $MinimumFreeSpaceGB GB required."
    }

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Write-Host "Downloading official SSMS $SsmsMajor bootstrapper from $($installerUrls[$SsmsMajor])."
    $downloadStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    Invoke-WebRequest -Uri $installerUrls[$SsmsMajor] -OutFile $installerPath `
        -UseBasicParsing -TimeoutSec 300 -ErrorAction Stop
    $downloadStopwatch.Stop()
    $downloadDurationSeconds = [math]::Round($downloadStopwatch.Elapsed.TotalSeconds, 2)
    if (-not (Test-Path -LiteralPath $installerPath) -or (Get-Item -LiteralPath $installerPath).Length -eq 0) {
        throw "Microsoft's SSMS $SsmsMajor installer download was empty."
    }
    $installerSignature = Assert-MicrosoftAuthenticodeSignature -Path $installerPath
    Write-Host "Verified Microsoft Authenticode signature for SSMS $SsmsMajor bootstrapper ($((Get-Item -LiteralPath $installerPath).Length) bytes; $downloadDurationSeconds seconds)."

    if ([int]$SsmsMajor -ge 21) {
        $arguments = @(
            'install',
            '--productId',
            'Microsoft.VisualStudio.Product.SSMS',
            '--channelId',
            "SSMS.$SsmsMajor.SSMS.Release",
            '--all',
            '--quiet',
            '--norestart',
            '--wait'
        )
    }
    else {
        $arguments = @('/Quiet')
    }

    $previousTemp = $env:TEMP
    $previousTmp = $env:TMP
    try {
        $env:TEMP = $LogDirectory
        $env:TMP = $LogDirectory
        $process = Start-Process `
            -FilePath $installerPath `
            -ArgumentList $arguments `
            -Wait `
            -PassThru `
            -RedirectStandardOutput $stdoutPath `
            -RedirectStandardError $stderrPath
    }
    finally {
        $env:TEMP = $previousTemp
        $env:TMP = $previousTmp
    }

    if ($process.ExitCode -notin @(0, 3010)) {
        throw "Microsoft SSMS $SsmsMajor installer returned exit code $($process.ExitCode). See the installer logs under '$LogDirectory'."
    }

    $installedInstances = @(& (Join-Path $PSScriptRoot 'Get-InstalledSsmsInstances.ps1'))
    $matchingInstance = $installedInstances | Where-Object { $_.MajorVersion -eq [int]$SsmsMajor } | Select-Object -First 1
    if (-not $matchingInstance) {
        throw "SSMS $SsmsMajor setup returned exit code $($process.ExitCode), but no matching Ssms.exe installation was found. No installation success is claimed."
    }

    $stopwatch.Stop()
    [pscustomobject]@{
        SsmsMajor = $SsmsMajor
        InstallerUrl = $installerUrls[$SsmsMajor]
        InstallerExitCode = $process.ExitCode
        InstallerSignature = $installerSignature
        Installation = $matchingInstance
        InstallerLogDirectory = $LogDirectory
        StandardOutputLog = $stdoutPath
        StandardErrorLog = $stderrPath
        DiskFreeBeforeGB = $freeSpaceGB
        DiskFreeAfterGB = if ($systemDrive) { [math]::Floor($systemDrive.AvailableFreeSpace / 1GB) } else { $null }
        DownloadDurationSeconds = $downloadDurationSeconds
        InstallationDurationSeconds = [math]::Round($stopwatch.Elapsed.TotalSeconds, 2)
        InstalledAtUtc = [DateTime]::UtcNow.ToString('o')
    } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $LogDirectory "ssms-$SsmsMajor-install.json") -Encoding UTF8
}
catch {
    $stopwatch.Stop()
    $failure = [pscustomobject]@{
        SsmsMajor = $SsmsMajor
        InstallerUrl = $installerUrls[$SsmsMajor]
        Outcome = 'Failed'
        Error = $_.Exception.Message
        InstallerLogDirectory = $LogDirectory
        StandardOutputLog = $stdoutPath
        StandardErrorLog = $stderrPath
        DiskFreeBeforeGB = $freeSpaceGB
        DownloadDurationSeconds = $downloadDurationSeconds
        InstallationDurationSeconds = [math]::Round($stopwatch.Elapsed.TotalSeconds, 2)
        FailedAtUtc = [DateTime]::UtcNow.ToString('o')
    }
    $failure | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $LogDirectory "ssms-$SsmsMajor-install-failure.json") -Encoding UTF8
    Add-Content -LiteralPath $env:GITHUB_STEP_SUMMARY -Value "## SSMS $SsmsMajor installation failed`n`n$($failure.Error)`n`nNo successful installation is claimed." -Encoding UTF8
    throw
}
finally {
    if (Test-Path -LiteralPath $installerPath) {
        Remove-Item -LiteralPath $installerPath -Force -ErrorAction SilentlyContinue
    }
}
