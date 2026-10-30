[CmdletBinding()]
param()

$programFilesRoots = @(
    ${env:ProgramFiles(x86)},
    $env:ProgramFiles,
    ${env:ProgramW6432}
) |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    Sort-Object -Unique

$roots = foreach ($programFilesRoot in $programFilesRoots) {
    if (Test-Path -LiteralPath $programFilesRoot -PathType Container) {
        Get-ChildItem -LiteralPath $programFilesRoot -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like 'Microsoft SQL Server Management Studio*' } |
            ForEach-Object { $_.FullName }
    }
}

$instances = foreach ($root in $roots) {
    Get-ChildItem -Path $root -Filter 'Ssms.exe' -File -Recurse -ErrorAction SilentlyContinue |
        ForEach-Object {
            $versionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($_.FullName)
            $folderMatch = [regex]::Match(
                $_.FullName,
                'Microsoft SQL Server Management Studio\s+(\d+)',
                [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
            )
            $productMatch = [regex]::Match([string]$versionInfo.ProductVersion, '^\s*(\d+)')
            $installRootMatch = [regex]::Match(
                $_.FullName,
                '(?i)^(.+?Microsoft SQL Server Management Studio\s+\d+)(?:\\|$)'
            )
            $major = if ($folderMatch.Success) {
                [int]$folderMatch.Groups[1].Value
            }
            elseif ($productMatch.Success) {
                [int]$productMatch.Groups[1].Value
            }
            else {
                $null
            }

            [pscustomobject]@{
                MajorVersion = $major
                ExecutablePath = $_.FullName
                InstallRoot = if ($installRootMatch.Success) { $installRootMatch.Groups[1].Value } else { $null }
                FileVersion = $versionInfo.FileVersion
                ProductVersion = $versionInfo.ProductVersion
            }
        }
}

$instances | Sort-Object -Property ExecutablePath -Unique
