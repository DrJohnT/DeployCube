$CurrentFolder = Split-Path -Parent $MyInvocation.MyCommand.Path;
$ModulePath = Resolve-Path "$CurrentFolder\..\DeployCube\DeployCube.psd1";
import-Module -Name $ModulePath;

$exampleFolder =  Resolve-Path "$CurrentFolder\..\examples";
$AsDatabasePath = Resolve-Path "$exampleFolder\CubeToPublish\MyTabularProject\bin\Model.asdatabase";
#$MissingDeploymentTargets = Resolve-Path "$exampleFolder\CubeToPublish\ForTests\MissingDeploymentTargets\Model.asdatabase";
#$MissingDeploymentOptions = Resolve-Path "$exampleFolder\CubeToPublish\ForTests\MissingDeploymentOptions\Model.asdatabase";

Describe "Publish-Cube Integration Tests" {
    Context "Deploy Cube, update connection and process" {
        $CubeDatabase = New-Guid;  # this ensures we cannot fake the test result
        It "Deploy cube should not throw" {
            { Publish-Cube -AsDatabasePath $AsDatabasePath -Server "localhost" -CubeDatabase $CubeDatabase } | Should Not Throw;
        }

        It "Check the cube deployed OK" {
            ( Ping-SsasDatabase -Server "localhost" -CubeDatabase $CubeDatabase ) | Should Be $true;
        }

        It "Update cube connection string" {
            #$password = ConvertTo-SecureString -String '13Lilac!' -AsPlainText -Force
            $Server = 'CP0023';
            $password = '13Lilac!'
            ( Update-CubeDataSource -Server $Server -CubeDatabase $CubeDatabase -SourceSqlServer $Server -SourceSqlDatabase 'DatabaseToPublish' -ImpersonationMode 'ImpersonateAccount' -ImpersonationAccount 'qregroup\jtunnicliffe' -ImpersonationPassword $password ) | Should Be $true;
        }

        It "Process cube should not throw" {
            { Invoke-ProcessASDatabase -Server "localhost" -DatabaseName $CubeDatabase -RefreshType Full }  | Should Not Throw;
        }

        It "Drop cube should not throw" {
            # clean up
            { Unpublish-Cube -Server "localhost" -CubeDatabase $CubeDatabase } | Should Not Throw;
        }

        It "Check the cube dropped" {
            ( Ping-SsasDatabase -Server "localhost" -CubeDatabase $CubeDatabase ) | Should Be $false;
        }
    }
}

Remove-Module -Name DeployCube