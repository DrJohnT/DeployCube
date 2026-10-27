[CmdletBinding()]
param()

$searchRoots = @(
    (Join-Path ${env:ProgramFiles(x86)} 'Microsoft SQL Server'),
    (Join-Path ${env:ProgramFiles(x86)} 'Microsoft SQL Server Management Studio*'),
    (Join-Path $env:ProgramFiles 'Microsoft SQL Server Management Studio*')
) | Where-Object { $_ -and (Test-Path -Path $_) }

$executables = @()
foreach ($root in $searchRoots) {
    $executables += Get-ChildItem -Path $root -Filter 'Microsoft.AnalysisServices.Deployment.exe' -File -Recurse -ErrorAction SilentlyContinue
}

$customRoot = [Environment]::GetEnvironmentVariable('CustomAsDwInstallLocation')
if (-not [string]::IsNullOrWhiteSpace($customRoot) -and (Test-Path -LiteralPath $customRoot)) {
    $executables += Get-ChildItem -Path $customRoot -Filter 'Microsoft.AnalysisServices.Deployment.exe' -File -Recurse -ErrorAction SilentlyContinue
}

$executables |
    Sort-Object -Property FullName -Unique |
    ForEach-Object {
        $versionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($_.FullName)
        [pscustomobject]@{
            Path = $_.FullName
            FileVersion = $versionInfo.FileVersion
            ProductVersion = $versionInfo.ProductVersion
            ProductMajorVersion = if ($versionInfo.ProductVersion -match '^\s*(\d+)') { [int]$matches[1] } else { $null }
            Length = $_.Length
        }
    }
