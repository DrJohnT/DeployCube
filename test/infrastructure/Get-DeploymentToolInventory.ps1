[CmdletBinding()]
param()

$programFilesRoots = @(
    ${env:ProgramFiles(x86)},
    $env:ProgramFiles,
    ${env:ProgramW6432}
) |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    Sort-Object -Unique

$searchRoots = foreach ($programFilesRoot in $programFilesRoots) {
    if (Test-Path -LiteralPath $programFilesRoot -PathType Container) {
        $sqlServerRoot = Join-Path $programFilesRoot 'Microsoft SQL Server'
        if (Test-Path -LiteralPath $sqlServerRoot -PathType Container) {
            $sqlServerRoot
        }

        Get-ChildItem -LiteralPath $programFilesRoot -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like 'Microsoft SQL Server Management Studio*' } |
            ForEach-Object { $_.FullName }
    }
}

$executables = @()
foreach ($root in $searchRoots) {
    $executables += Get-ChildItem -LiteralPath $root -Filter 'Microsoft.AnalysisServices.Deployment.exe' -File -Recurse -ErrorAction SilentlyContinue
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
