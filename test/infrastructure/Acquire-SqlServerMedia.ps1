[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][uri]$MediaUri,
    [Parameter(Mandatory = $true)][string]$MediaDirectory,
    [Parameter(Mandatory = $true)][string]$LogDirectory,
    [ValidateRange(1, 60)][int]$TimeoutMinutes = 20,
    [ValidateRange(5, 120)][int]$InactivityTimeoutSeconds = 60
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'SqlServerMedia.ps1')
. (Join-Path $PSScriptRoot 'Invoke-BoundedProcess.ps1')
New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
$LogDirectory = (Resolve-Path -LiteralPath $LogDirectory).Path
$report = [ordered]@{
    Outcome = 'Running'
    Stage = 'Source validation'
    Source = "$($MediaUri.Scheme)://$($MediaUri.Host)$($MediaUri.AbsolutePath)"
    StartedAtUtc = [DateTime]::UtcNow.ToString('o')
    DownloadDurationSeconds = $null
    Bytes = 0
    Sha256 = $null
    Error = $null
}
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$isoPath = $null
$downloadStarted = $false
function Write-ProvisioningLog {
    param([string]$Stage, [string]$Message)
    $line = "[$([DateTime]::UtcNow.ToString('o'))] [$Stage] $Message"
    Write-Host $line
    Add-Content -LiteralPath (Join-Path $LogDirectory 'media-acquisition.log') -Value $line -Encoding UTF8
}
try {
    Assert-MicrosoftMediaUri -Uri $MediaUri
    $report.Source = $MediaUri.AbsoluteUri
    New-Item -ItemType Directory -Path $MediaDirectory -Force | Out-Null
    $MediaDirectory = (Resolve-Path -LiteralPath $MediaDirectory).Path
    $isoPath = Join-Path $MediaDirectory 'sql-server.iso'
    if (Test-Path -LiteralPath $isoPath) {
        throw "Media destination '$isoPath' already exists; refusing to reuse unverified media."
    }
    $downloadStarted = $true
    $report.Stage = 'Download'
    Write-ProvisioningLog -Stage $report.Stage -Message "Downloading '$MediaUri'; inactivity limit ${InactivityTimeoutSeconds}s; total limit ${TimeoutMinutes}m."
    $curl = (Get-Command curl.exe -ErrorAction Stop).Source
    $result = Invoke-BoundedProcess -FilePath $curl `
        -ArgumentList @(
            '--fail', '--show-error', '--location', '--proto', '=https', '--proto-redir', '=https',
            '--connect-timeout', '30', '--max-time', [string]($TimeoutMinutes * 60),
            '--speed-limit', '1', '--speed-time', [string]$InactivityTimeoutSeconds,
            '--output', "`"$isoPath`"", '--write-out', '"http_code=%{http_code} bytes=%{size_download} seconds=%{time_total} effective_url=%{url_effective}\n"',
            "`"$($MediaUri.AbsoluteUri)`""
        ) `
        -TimeoutSeconds ($TimeoutMinutes * 60 + 15) -Stage 'SQL Server media download' `
        -StandardOutputPath (Join-Path $LogDirectory 'curl.stdout.log') `
        -StandardErrorPath (Join-Path $LogDirectory 'curl.stderr.log') `
        -ObservedDirectory $MediaDirectory
    $report.DownloadDurationSeconds = $result.DurationSeconds
    if ($result.ExitCode -ne 0) {
        throw "Media download failed with curl exit code $($result.ExitCode). Inactivity limit: ${InactivityTimeoutSeconds}s; see curl.stderr.log."
    }
    $report.Stage = 'ISO validation'
    Assert-SqlServerIso -Path $isoPath
    $report.Bytes = (Get-Item -LiteralPath $isoPath).Length
    $manifestSizes = @{
        'https://download.microsoft.com/download/8/4/c/84c6c430-e0f5-476d-bf43-eaaa222a72e0/SQLServer2019-x64-ENU-Dev.iso' = 1433974784
        'https://download.microsoft.com/download/3/8/d/38de7036-2433-4207-8eae-06e247e17b25/SQLServer2022-x64-ENU-Dev.iso' = 1163053056
        'https://download.microsoft.com/download/dea8c210-c44a-4a9d-9d80-0c81578860c5/ENU/SQLServer2025-x64-ENU-EntDev.iso' = 1265688576
    }
    $expectedBytes = $manifestSizes[$MediaUri.AbsoluteUri]
    if ($expectedBytes -and $report.Bytes -ne $expectedBytes) {
        throw "Developer ISO size differs from Microsoft's media manifest: $($report.Bytes) bytes; expected $expectedBytes."
    }
    $report.Sha256 = (Get-FileHash -LiteralPath $isoPath -Algorithm SHA256).Hash
    if ($MediaUri.AbsoluteUri -eq 'https://download.microsoft.com/download/dea8c210-c44a-4a9d-9d80-0c81578860c5/ENU/SQLServer2025-x64-ENU-EntDev.iso' -and
        $report.Sha256 -ne 'f78f869d44e8c2cbf93be16ce6ea52dd811636f046ded29e7a74dd1352134851') {
        throw 'SQL Server 2025 Enterprise Developer ISO SHA-256 differs from the official bootstrapper media manifest.'
    }
    $report.IsoPath = $isoPath
    $report.Outcome = 'Passed'
    Write-ProvisioningLog -Stage $report.Stage -Message "Validated ISO: $($report.Bytes) bytes; SHA256 $($report.Sha256)."
    if ($env:GITHUB_OUTPUT) {
        Add-Content -LiteralPath $env:GITHUB_OUTPUT -Value "iso-path=$isoPath" -Encoding UTF8
    }
}
catch {
    $report.Outcome = 'Failed'
    $report.Error = $_.Exception.ToString()
    Write-ProvisioningLog -Stage $report.Stage -Message $report.Error
    throw
}
finally {
    if ($downloadStarted -and $isoPath -and (Test-Path -LiteralPath $isoPath)) {
        $report.Bytes = (Get-Item -LiteralPath $isoPath).Length
        if ($report.Outcome -ne 'Passed') {
            try {
                Remove-Item -LiteralPath $isoPath -Force -ErrorAction Stop
                $report.PartialMediaCleanup = 'Passed'
            }
            catch {
                $report.PartialMediaCleanup = 'Failed'
                $report.PartialMediaCleanupError = $_.Exception.ToString()
                Write-ProvisioningLog -Stage 'Cleanup' -Message $report.PartialMediaCleanupError
            }
        }
    }
    $report.DurationSeconds = [math]::Round($stopwatch.Elapsed.TotalSeconds, 2)
    $report.FinishedAtUtc = [DateTime]::UtcNow.ToString('o')
    $report | ConvertTo-Json -Depth 5 |
        Set-Content -LiteralPath (Join-Path $LogDirectory 'media-acquisition.json') -Encoding UTF8
}
