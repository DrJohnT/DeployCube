#Invoke-Pester 

Invoke-Pester -Tag ( "Round1" ,"Round2", "Round3" ,"Round4" );
#Invoke-Pester -Tag "Round1";
#Invoke-Pester -Tag "Round2";
#Invoke-Pester -Tag "Round3";
#Invoke-Pester -Tag "Round4";

#Invoke-Pester -Script .\AnalyzePSScripts.Tests.ps1

#Invoke-Pester -Script .\AzureAS.Tests.ps1

#Invoke-Pester -Script .\Find-AnalysisServicesDeploymentExeLocations.Tests.ps1
#Invoke-Pester -Script .\Get-AnalysisServicesDeploymentExePath.Tests.ps1 

#$CurrentFolder = Split-Path -Parent $PSScriptRoot;
#$ModulePath = Resolve-Path "$CurrentFolder\DeployCube\DeployCube.psd1";
#import-Module -Name $ModulePath;
#$val = Find-AnalysisServicesDeploymentExeLocations | Measure-Object 
##| Select-Object -Property Count 
#write-host $val.Count;
#$val = Find-AnalysisServicesDeploymentExeLocations | Measure-Object | Where-Object {$_.Count -eq "2"}
#write-host $val;
#{$_.Count};

#Invoke-Pester -Script .\Get-CubeDatabaseCompatibilityLevel.Tests.ps1
#Invoke-Pester -Script .\Get-ServerMode.Tests.ps1

#Invoke-Pester -Script .\Get-SqlAsPath.Tests.ps1
#Invoke-Pester -Script .\Get-SqlConnectionString.Tests.ps1

#Invoke-Pester -Script .\Integration.Tests.ps1

#Invoke-Pester -Script .\Invoke-ProcessTabularCubeDatabase.Tests.ps1


#Invoke-Pester -Script .\Ping-SsasDatabase.Tests.ps1
#Invoke-Pester -Script .\Ping-SsasServer.Tests.ps1

#Invoke-Pester -Script .\ProcessCube.Tests.ps1
#Invoke-Pester -Script .\Publish-Cube.Tests.ps1

#Invoke-Pester -Script .\Select-AnalysisServicesDeploymentExeVersion.Tests.ps1

#Invoke-Pester -Script .\Unpublish-Cube.Tests.ps1

#Invoke-Pester -Script .\Update-AnalysisServicesConfig.Tests.ps1
#Invoke-Pester -Script .\Update-TabularCubeDataSource.Tests.ps1

