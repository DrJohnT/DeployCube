using namespace Microsoft.PowerShell.Commands
[CmdletBinding()]
param(
    [ValidateSet("CurrentUser", "AllUsers")]
    $Scope = "CurrentUser"
)
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
[ModuleSpecification[]]$RequiredModules = Import-LocalizedData -BaseDirectory $PSScriptRoot -FileName RequiredModules
$Policy = (Get-PSRepository PSGallery).InstallationPolicy
Set-PSRepository PSGallery -InstallationPolicy Trusted

try {
    foreach ($module in $RequiredModules) {
        $installed = Get-Module -ListAvailable -Name $module.Name |
            Where-Object { $_.Version -eq $module.RequiredVersion }
        if (-not $installed) {
            Install-Module -Name $module.Name -RequiredVersion $module.RequiredVersion `
                -Scope $Scope -Repository PSGallery -Force -SkipPublisherCheck -AllowClobber -ErrorAction Stop
        }
    }
}
finally {
    Set-PSRepository PSGallery -InstallationPolicy $Policy
}
foreach ($module in $RequiredModules) {
    Import-Module -Name $module.Name -RequiredVersion $module.RequiredVersion -Force -ErrorAction Stop
}