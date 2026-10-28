function Assert-MicrosoftMediaUri {
    param([Parameter(Mandatory = $true)][uri]$Uri)

    if ($Uri.Scheme -ne 'https' -or $Uri.UserInfo -or $Uri.Query -or
        $Uri.Host -notmatch '^download(\.[a-z0-9-]+)*\.microsoft\.com$') {
        throw 'Installation media must use a direct, uncredentialed HTTPS download.microsoft.com URL without query tokens. Bootstrapper URLs are not installation media.'
    }
}

function Assert-SqlServerIso {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [long]$MinimumBytes = 1GB
    )

    $file = Get-Item -LiteralPath $Path -ErrorAction Stop
    if ($file.Length -lt $MinimumBytes) {
        throw "Installation ISO is too small: $($file.Length) bytes; expected at least $MinimumBytes."
    }
    $stream = [System.IO.File]::OpenRead($file.FullName)
    try {
        $identifier = New-Object byte[] 5
        $recognized = $false
        foreach ($sector in 16..31) {
            $stream.Position = $sector * 2048 + 1
            if ($stream.Read($identifier, 0, 5) -eq 5 -and
                [System.Text.Encoding]::ASCII.GetString($identifier) -in @('CD001', 'NSR02', 'NSR03')) {
                $recognized = $true
                break
            }
        }
        if (-not $recognized) {
            throw 'Downloaded file is not an ISO9660/UDF installation image (missing volume descriptor).'
        }
    }
    finally {
        $stream.Dispose()
    }
}

function Assert-SqlServerMediaRoot {
    param(
        [Parameter(Mandatory = $true)][string]$MediaRoot,
        [Parameter(Mandatory = $true)][int]$ExpectedMajor
    )

    $setupPath = Join-Path $MediaRoot 'setup.exe'
    if (-not (Test-Path -LiteralPath $setupPath -PathType Leaf) -or
        -not (Test-Path -LiteralPath (Join-Path $MediaRoot 'x64/Setup') -PathType Container)) {
        throw "Incomplete SQL Server x64 installation media at '$MediaRoot': setup.exe or x64/Setup is missing."
    }
    $signature = Get-AuthenticodeSignature -FilePath $setupPath
    if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'O=Microsoft Corporation') {
        throw "SQL Server setup.exe does not have a valid Microsoft signature (status: $($signature.Status))."
    }
    $version = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($setupPath).ProductVersion
    if ($version -notmatch ('^\s*' + $ExpectedMajor + '\.')) {
        throw "SQL Server setup version '$version' does not match expected major '$ExpectedMajor'."
    }
    return $version
}
