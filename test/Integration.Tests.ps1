$CurrentFolder = Split-Path -Parent $MyInvocation.MyCommand.Path;
$ModulePath = Resolve-Path "$CurrentFolder\..\DeployCube\DeployCube.psd1";
import-Module -Name $ModulePath;

$exampleFolder =  Resolve-Path "$CurrentFolder\..\examples";
$AsDatabasePath = Resolve-Path "$exampleFolder\CubeToPublish\MyTabularProject\bin\Model.asdatabase";
#$MissingDeploymentTargets = Resolve-Path "$exampleFolder\CubeToPublish\ForTests\MissingDeploymentTargets\Model.asdatabase";
#$MissingDeploymentOptions = Resolve-Path "$exampleFolder\CubeToPublish\ForTests\MissingDeploymentOptions\Model.asdatabase";
$InvalidDataSourceConnection = Resolve-Path "$exampleFolder\CubeToPublish\ForTests\InvalidDataSourceConnection\Model.asdatabase";

Describe "Publish-Cube Integration Tests" {
    Context "Deploy Cube, update connection and process" {
        $CubeDatabase = New-Guid;  # this ensures we cannot fake the test result
        $ServerName = 'localhost';
        It "Deploy cube should not throw" {
            { Publish-Cube -AsDatabasePath $AsDatabasePath -Server $ServerName -CubeDatabase $CubeDatabase } | Should Not Throw;
        }

        It "Check the cube deployed OK" {
            ( Ping-SsasDatabase -Server $ServerName -CubeDatabase $CubeDatabase ) | Should Be $true;
        }

        It "Update cube connection string ImpersonationMode " {
            ( Update-CubeDataSource -Server $ServerName -CubeDatabase $CubeDatabase -SourceSqlServer $ServerName -SourceSqlDatabase 'DatabaseToPublish' -ImpersonationMode 'ImpersonateServiceAccount' ) | Should Be $true;
        }

        It "Process cube should not throw" {
            { Invoke-ProcessASDatabase -Server $ServerName -DatabaseName $CubeDatabase -RefreshType Full }  | Should Not Throw;
        }

        It "Drop cube should not throw" {
            # clean up
            { Unpublish-Cube -Server $ServerName -CubeDatabase $CubeDatabase } | Should Not Throw;
        }

        It "Check the cube dropped" {
            ( Ping-SsasDatabase -Server $ServerName -CubeDatabase $CubeDatabase ) | Should Be $false;
        }
    }

    Context "Deploy Cube with ProcessFull" {
        $CubeDatabase = New-Guid;  # this ensures we cannot fake the test result
        $ServerName = 'localhost';
        It "Deploy cube should throw" {
            { Publish-Cube -AsDatabasePath $InvalidDataSourceConnection -Server $ServerName -CubeDatabase $CubeDatabase -ProcessingOption "Full" -TransactionalDeployment true } | Should Throw;
        }

        It "Check the cube was not deployed" {
            ( Ping-SsasDatabase -Server $ServerName -CubeDatabase $CubeDatabase ) | Should Be $false;
        }
    }
}

Remove-Module -Name DeployCube