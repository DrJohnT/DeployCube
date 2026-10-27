function Get-AnalysisServicesDeploymentExeProductMajorVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileSystemInfo]$DeploymentExe
    )

    $productVersion = $DeploymentExe.VersionInfo.ProductVersion
    if ($productVersion -notmatch '^\s*(\d+)') {
        Write-Warning "Skipping '$($DeploymentExe.FullName)' because it has no readable product major version."
        return $null
    }

    return $matches[1]
}

function Find-AnalysisServicesDeploymentExeLocations {
    [CmdletBinding()]
    param()

<#
    .SYNOPSIS
    Lists all locations of Microsoft.AnalysisServices.Deployment.exe files on the machine

    .DESCRIPTION
    Finds and lists the location path to every version of Microsoft.AnalysisServices.Deployment.exe on the machine.
    Also checks the custom install location defined by Environment variable CustomAsDwInstallLocation

    .EXAMPLE
    Find-AnalysisServicesDeploymentExeLocations

    .INPUTS
    None

    .OUTPUTS
    Output is written to standard output.

    .LINK
    https://github.com/DrJohnT/DeployCube

    .NOTES
    Written by (c) Dr. John Tunnicliffe, 2019-2021 https://github.com/DrJohnT/DeployCube
    This PowerShell script is released under the MIT license http://www.opensource.org/licenses/MIT
#>

    try {
        [string]$ExeName = "Microsoft.AnalysisServices.Deployment.exe";
        # Get SQL Server locations

        #Up to v17 (140)
        $SqlServerToolsPath = "${env:ProgramFiles(x86)}\Microsoft SQL Server\*\Tools\Binn";
        Write-Debug "Searching for '$ExeName' in '$SqlServerToolsPath'.";
        [System.IO.FileSystemInfo[]]$AnalysisServicesDeploymentExes = Get-Childitem -Path $SqlServerToolsPath -Recurse -Include $ExeName -ErrorAction SilentlyContinue;

        #V18 (SSMS - 150)
        $SsmsX86Path = "${env:ProgramFiles(x86)}\Microsoft SQL Server Management Studio *\Common7";
        Write-Debug "Searching for '$ExeName' in '$SsmsX86Path'.";
        $AnalysisServicesDeploymentExes += Get-Childitem -Path $SsmsX86Path -Recurse -Include $ExeName -ErrorAction SilentlyContinue;
        $SsmsPath = "${env:ProgramFiles}\Microsoft SQL Server Management Studio *\Release\Common7";
        Write-Debug "Searching for '$ExeName' in '$SsmsPath'.";
        $AnalysisServicesDeploymentExes += Get-Childitem -Path $SsmsPath -Recurse -Include $ExeName -ErrorAction SilentlyContinue;
        
        # Custom install location defined by Environment variable CustomAsDwInstallLocation
        $CustomAsDwInstallLocation = [Environment]::GetEnvironmentVariable('CustomAsDwInstallLocation');
        if ("$CustomAsDwInstallLocation" -ne "") {
            if (Test-Path $CustomAsDwInstallLocation) {
                Write-Debug "Searching for '$ExeName' in custom install location '$CustomAsDwInstallLocation'.";
                $AnalysisServicesDeploymentExes += Get-Childitem -Path "$CustomAsDwInstallLocation\" -Recurse -Include $ExeName -ErrorAction SilentlyContinue;
            } else {
                throw "Invalid custom environment variable path: CustomAsDwInstallLocation";
            }        
        }
        
        
        $seenPaths = @{}

        # list all the unique locations found
        foreach ($AnalysisServicesDeploymentExe in $AnalysisServicesDeploymentExes) {
            $fullPath = [System.IO.Path]::GetFullPath($AnalysisServicesDeploymentExe.FullName)
            if ($seenPaths.ContainsKey($fullPath)) {
                continue
            }
            $seenPaths[$fullPath] = $true

            $ProductMajorVersion = Get-AnalysisServicesDeploymentExeProductMajorVersion `
                -DeploymentExe $AnalysisServicesDeploymentExe
            if ($null -eq $ProductMajorVersion) {
                continue
            }
            Write-Debug "Found '$ExeName': '$fullPath' (product major version $ProductMajorVersion).";
            Write-Output "$ProductMajorVersion  $fullPath";
        }
    }
    catch {
        Write-Error "Find-AnalysisServicesDeploymentExeLocations failed with error: $_";
    }
}
