
#Invoke-Pester -Tag "Round1";
#Invoke-Pester -Tag "Round2";
#Invoke-Pester -Tag "Round3";

#Invoke-Pester -Script .\AnalyzePSScripts.Tests.ps1

#Invoke-Pester -Script .\AzureAS.Tests.ps1

#Invoke-Pester -Script .\Find-AnalysisServicesDeploymentExeLocations.Tests.ps1 -Tag 'Round1'
#Invoke-Pester -Script .\Get-AnalysisServicesDeploymentExePath.Tests.ps1 -Tag Round1


#Invoke-Pester -Script .\Get-CubeDatabaseCompatibilityLevel.Tests.ps1
#Invoke-Pester -Script .\Get-ServerMode.Tests.ps1

#Invoke-Pester -Script .\Get-SqlAsPath.Tests.ps1
#Invoke-Pester -Script .\Get-SqlConnectionString.Tests.ps1

#Invoke-Pester -Script .\Integration.Tests.ps1

#Invoke-Pester -Script .\Invoke-ProcessTabularCubeDatabase.Tests.ps1


Invoke-Pester -Script .\Ping-SsasDatabase.Tests.ps1
#Invoke-Pester -Script .\Ping-SsasServer.Tests.ps1

#Invoke-Pester -Script .\ProcessCube.Tests.ps1
#Invoke-Pester -Script .\Publish-Cube.Tests.ps1

#Invoke-Pester -Script .\Select-AnalysisServicesDeploymentExeVersion.Tests.ps1

#Invoke-Pester -Script .\Unpublish-Cube.Tests.ps1

#Invoke-Pester -Script .\Update-AnalysisServicesConfig.Tests.ps1
#Invoke-Pester -Script .\Update-TabularCubeDataSource.Tests.ps1

