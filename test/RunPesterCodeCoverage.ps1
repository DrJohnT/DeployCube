$BootStrapPath = Join-Path -Path $PSScriptRoot -ChildPath '.\bootstrap.ps1' -Resolve;

. $BootStrapPath;

Invoke-Pester -Script .\Find-AnalysisServicesDeploymentExeLocations.Tests.ps1 -CodeCoverage .\..\DeployCube\public\Get-AnalysisServicesDeploymentExePath.ps1
Invoke-Pester -Script .\Get-AnalysisServicesDeploymentExePath.Tests.ps1 -CodeCoverage .\..\DeployCube\public\Get-AnalysisServicesDeploymentExePath.ps1
Invoke-Pester -Script .\Select-AnalysisServicesDeploymentExeVersion.Tests.ps1 -CodeCoverage .\..\DeployCube\public\Select-AnalysisServicesDeploymentExeVersion.ps1
#Invoke-Pester -Script .\test\Publish-Cube.Tests.ps1 -CodeCoverage .\..\DeployCube\public\Publish-Cube.ps1
