[CmdletBinding()]
param()

$roots = @(
    (Join-Path ${env:ProgramFiles(x86)} 'Microsoft SQL Server Management Studio*'),
    (Join-Path $env:ProgramFiles 'Microsoft SQL Server Management Studio*')
) | Where-Object { $_ -and (Test-Path -Path $_) }

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
            $major = if ($productMatch.Success) {
                [int]$productMatch.Groups[1].Value
            }
            elseif ($folderMatch.Success) {
                [int]$folderMatch.Groups[1].Value
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
