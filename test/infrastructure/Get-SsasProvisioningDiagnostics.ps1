[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$directory = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Path $directory -Force | Out-Null
$serviceNames = @('MSOLAP$DCUBE', 'SQLBrowser')
$services = foreach ($serviceName in $serviceNames) {
    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    [pscustomobject]@{
        Name = $serviceName
        Status = if ($service) { [string]$service.Status } else { 'NotInstalled' }
        StartType = if ($service) { [string]$service.StartType } else { $null }
    }
}
$installerProcesses = @(
    Get-Process -ErrorAction SilentlyContinue |
        Where-Object { $_.ProcessName -match 'setup|sql|vs_setup|sqlservr' } |
        Select-Object ProcessName, Id
)
$setupMajor = switch ($env:COMPAT_SSAS_VERSION) {
    '2017' { '140' }
    '2019' { '150' }
    '2022' { '160' }
    '2025' { '170' }
    default { '160' }
}
$serverExecutableCandidates = @(
    (Join-Path $env:ProgramFiles "Microsoft SQL Server\MSAS$setupMajor.DCUBE\OLAP\bin\msmdsrv.exe"),
    (Join-Path $env:ProgramFiles "Microsoft SQL Server\$setupMajor\OLAP\bin\msmdsrv.exe"),
    (Join-Path ${env:ProgramFiles(x86)} "Microsoft SQL Server\MSAS$setupMajor.DCUBE\OLAP\bin\msmdsrv.exe"),
    (Join-Path ${env:ProgramFiles(x86)} "Microsoft SQL Server\$setupMajor\OLAP\bin\msmdsrv.exe")
)
$serverExecutables = foreach ($path in $serverExecutableCandidates | Select-Object -Unique) {
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        $versionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($path)
        [pscustomobject]@{
            Path = $path
            FileVersion = $versionInfo.FileVersion
            ProductVersion = $versionInfo.ProductVersion
        }
    }
}
$drives = @(
    [System.IO.DriveInfo]::GetDrives() |
        Where-Object { $_.IsReady } |
        ForEach-Object {
            [pscustomobject]@{
                Name = $_.Name
                TotalBytes = $_.TotalSize
                AvailableBytes = $_.AvailableFreeSpace
            }
        }
)
$result = [pscustomobject]@{
    CollectedAtUtc = [DateTime]::UtcNow.ToString('o')
    ComputerName = $env:COMPUTERNAME
    OperatingSystem = (Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop).Caption
    Services = @($services)
    InstallerProcesses = $installerProcesses
    AnalysisServicesExecutables = @($serverExecutables)
    Drives = $drives
}
$result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
$result | ConvertTo-Json -Depth 6
