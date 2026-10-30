[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$OutputPath
)

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

$memory = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
$diagnostics = [pscustomobject]@{
    ComputerName = $env:COMPUTERNAME
    OperatingSystem = [System.Environment]::OSVersion.VersionString
    PowerShellVersion = $PSVersionTable.PSVersion.ToString()
    TotalPhysicalMemoryBytes = [int64]$memory.TotalVisibleMemorySize * 1KB
    FreePhysicalMemoryBytes = [int64]$memory.FreePhysicalMemory * 1KB
    Drives = $drives
    CollectedAtUtc = [DateTime]::UtcNow.ToString('o')
}

$directory = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $directory)) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
}

$diagnostics | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
$diagnostics | ConvertTo-Json -Depth 5
