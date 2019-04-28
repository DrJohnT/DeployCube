
$CurrentFolder = Split-Path -Parent $MyInvocation.MyCommand.Path;
$ModulePath = Resolve-Path "$CurrentFolder\..\DeployCube\DeployCube.psd1";
import-Module -Name $ModulePath;

$exampleFolder =  Resolve-Path "$CurrentFolder\..\examples";
$AsDatabasePath = Resolve-Path "$exampleFolder\CubeToPublish\MyTabularProject\bin\Model.asdatabase";

$Server = 'localhost';
$CubeDatabase = "TestProcessing";
$password = 'OSzkzmvdVC-n9+BT'

#Publish-Cube -AsDatabasePath $AsDatabasePath -Server $Server -CubeDatabase $CubeDatabase;
#Update-CubeDataSource -Server $Server -CubeDatabase $CubeDatabase -SourceSqlServer $Server -SourceSqlDatabase 'InvalidDatabase' -ImpersonationMode 'ImpersonateAccount' -ImpersonationAccount 'qregroup\QReSvcSWBuild' -ImpersonationPassword $password
Invoke-ProcessSsasDatabase -Server $Server -CubeDatabase $CubeDatabase -RefreshType Full

Remove-Module -Name DeployCube
