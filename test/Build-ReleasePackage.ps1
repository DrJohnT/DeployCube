[CmdletBinding()]
param(
    [string]$Tag,
    [string]$OutputPath = (Join-Path (Split-Path $PSScriptRoot -Parent) 'TestResults/package')
)
$ErrorActionPreference = 'Stop'
$manifestPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'DeployCube/DeployCube.psd1'
$manifest = Test-ModuleManifest $manifestPath -ErrorAction Stop
if ($Tag -and $Tag -cne "v$($manifest.Version)") {
    throw "Tag '$Tag' must exactly match manifest version 'v$($manifest.Version)'."
}
if (Test-Path $OutputPath) {
    throw "Package output already exists: $OutputPath. Use a fresh output directory."
}
New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
$OutputPath = (Resolve-Path $OutputPath).Path
$modulePath = Join-Path $OutputPath 'DeployCube'
Copy-Item (Split-Path $manifestPath -Parent) $modulePath -Recurse
$feedPath = Join-Path $OutputPath 'feed'
New-Item -ItemType Directory -Path $feedPath | Out-Null
$repositoryName = "DeployCubeBuild-$([guid]::NewGuid().ToString('N'))"
try {
    Register-PSRepository -Name $repositoryName -SourceLocation $feedPath -PublishLocation $feedPath -InstallationPolicy Trusted
    # Build through the real publishing toolchain, but only to an empty local filesystem repository.
    Publish-Module -Path $modulePath -Repository $repositoryName -ErrorAction Stop
    $packages = @(Get-ChildItem $feedPath -Filter '*.nupkg')
    if ($packages.Count -ne 1 -or $packages[0].Name -ne "DeployCube.$($manifest.Version).nupkg") {
        throw "Package build did not produce the expected versioned NuGet package DeployCube.$($manifest.Version).nupkg; found: $($packages.Name -join ', ')."
    }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($packages[0].FullName)
    try {
        foreach ($required in @('DeployCube.psd1', 'DeployCube.psm1', 'public/Publish-Cube.ps1')) {
            if ($required -notin $archive.Entries.FullName) { throw "Package is missing $required." }
        }
    } finally { $archive.Dispose() }
    Write-Information "Built and inspected $($packages[0].Name) without publishing to PowerShell Gallery." -InformationAction Continue
} finally {
    if (Get-PSRepository -Name $repositoryName -ErrorAction SilentlyContinue) {
        Unregister-PSRepository -Name $repositoryName -ErrorAction Stop
    }
}
