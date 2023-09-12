
param (
    [Parameter(Mandatory)]
    [string] $ApiKey,
    [Parameter(Mandatory=$false)]
    [string] $repository
    
)

#$VerbosePreference = 'Continue';
$ErrorActionPreference = 'Stop';

$baseDir = $PSScriptRoot;

$PsdPath = Resolve-Path "$PSScriptRoot\DeployCube\DeployCube.psd1";
$psd = Import-PowershellDataFile $PsdPath;
$ModuleVersion = $psd.ModuleVersion;
Write-Host "Module Version to be published to the Gallery: $ModuleVersion" -ForegroundColor Yellow;

$confirmation = Read-Host "Are you Sure?  Type Y to Proceed."
if ($confirmation -eq 'Y') {        
    .\UpdateHelp.ps1
    try {
        $buildDir = "$baseDir\DeployCube";
        Write-Information $buildDir;
        Write-Verbose 'Importing PowerShellGet module'
        $psGet = Import-Module PowerShellGet -PassThru -Verbose:$false
        & $psGet { [CmdletBinding()] param () Install-NuGetClientBinaries -CallerPSCmdlet $PSCmdlet -BootstrapNuGetExe -Force }

        Write-Host 'Publishing module using PowerShellGet'
        if(!($repository)){
            $null = Publish-Module -Path $buildDir -NuGetApiKey $ApiKey -Confirm:$false;
        } else {
            $null = Publish-Module -Path $buildDir -NuGetApiKey $ApiKey -Confirm:$false -Repository $repository;
        }
    }
    catch {
        Write-Error -ErrorRecord $_
        exit 1
    }
}
