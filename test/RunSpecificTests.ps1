$BootStrapPath = Join-Path -Path $PSScriptRoot -ChildPath '.\bootstrap.ps1' -Resolve;

#. $BootStrapPath;

#Invoke-Pester -Script .\AnalyzePSScripts.Tests.ps1
Invoke-Pester -Script .\Find-AnalysisServicesDeploymentExeLocations.Tests.ps1
Invoke-Pester -Script .\Get-AnalysisServicesDeploymentExePath.Tests.ps1
Invoke-Pester -Script .\Get-ServerMode.Tests.ps1
Invoke-Pester -Script .\Get-SqlConnectionString.Tests.ps1

Invoke-Pester -Script .\Ping-SsasDatabase.Tests.ps1
Invoke-Pester -Script .\Ping-SsasServer.Tests.ps1

Invoke-Pester -Script .\Publish-Cube.Tests.ps1

Invoke-Pester -Script .\Select-AnalysisServicesDeploymentExeVersion.Tests.ps1
Invoke-Pester -Script .\Unpublish-Cube.Tests.ps1
Invoke-Pester -Script .\Update-AnalysisServicesConfig.Tests.ps1
Invoke-Pester -Script .\Update-CubeDataSource.Tests.ps1

Invoke-Pester -Script .\Integration.Tests.ps1

<#
$CurrentFolder = Split-Path -Parent $MyInvocation.MyCommand.Path;
$ModulePath = Resolve-Path "$CurrentFolder\..\DeployCube\DeployCube.psd1";
import-Module -Name $ModulePath;

$exampleFolder =  Resolve-Path "$CurrentFolder\..\examples";
$AsDatabasePath = Resolve-Path "$exampleFolder\CubeToPublish\MyTabularProject\bin\Model.asdatabase";

$Server = 'localhost';
$CubeDatabase = "WillFailToDeploy";
$password = 'OSzkzmvdVC-n9+BT'

Publish-Cube -AsDatabasePath $AsDatabasePath -Server $Server -CubeDatabase $CubeDatabase -PreferredVersion latest -ProcessingOption Full -TransactionalDeployment true;
#Update-CubeDataSource -Server $Server -CubeDatabase 'CubeToPublish' -SourceSqlServer $Server -SourceSqlDatabase 'DatabaseToPublish' -ImpersonationMode 'ImpersonateAccount' -ImpersonationAccount 'qregroup\QReSvcSWBuild' -ImpersonationPassword $password

Remove-Module -Name DeployCube
#>