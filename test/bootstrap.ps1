using namespace Microsoft.PowerShell.Commands
[CmdletBinding()]
param(
    [ValidateSet("CurrentUser", "AllUsers")]
    $Scope = "CurrentUser"
)
$ErrorActionPreference = 'Stop'

[ModuleSpecification[]]$RequiredModules = Import-LocalizedData -BaseDirectory $PSScriptRoot -FileName RequiredModules
$Policy = (Get-PSRepository PSGallery).InstallationPolicy
Set-PSRepository PSGallery -InstallationPolicy Trusted

try {
    foreach ($RequiredModule in $RequiredModules) {
        $installed = Get-Module -ListAvailable -Name $RequiredModule.Name | Where-Object { $_.Version -eq $RequiredModule.RequiredVersion }
        if ($installed) {
            Write-Verbose "$($RequiredModule.Name) $($RequiredModule.RequiredVersion) is already installed"
            continue
        }
        # -Force -SkipPublisherCheck are required to install Pester 5 side-by-side with the Pester 3.4 that ships with Windows PowerShell 5.1
        Install-Module -Name $RequiredModule.Name -RequiredVersion $RequiredModule.RequiredVersion -Scope $Scope -Repository PSGallery -Force -SkipPublisherCheck -AllowClobber
    }
}
finally {
    Set-PSRepository PSGallery -InstallationPolicy $Policy
}

foreach ($RequiredModule in $RequiredModules) {
    Import-Module -Name $RequiredModule.Name -RequiredVersion $RequiredModule.RequiredVersion -Force
}
