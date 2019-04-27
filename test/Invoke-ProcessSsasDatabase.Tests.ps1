$CurrentFolder = Split-Path -Parent $MyInvocation.MyCommand.Path;
$ModulePath = Resolve-Path "$CurrentFolder\..\DeployCube\DeployCube.psd1";
import-Module -Name $ModulePath;

$exampleFolder =  Resolve-Path "$CurrentFolder\..\examples";
$AsDatabasePath = Resolve-Path "$exampleFolder\CubeToPublish\MyTabularProject\bin\Model.asdatabase";

Describe "Invoke-ProcessSsasDatabase" {
    Context "Testing Inputs" {
        It "Should have Server as a mandatory parameter" {
            (Get-Command Invoke-ProcessSsasDatabase).Parameters['Server'].Attributes.mandatory | Should -Be $true
        }
        It "Should have CubeDatabase as a mandatory parameter" {
            (Get-Command Invoke-ProcessSsasDatabase).Parameters['CubeDatabase'].Attributes.mandatory | Should -Be $true
        }
        It "Should have CubeDatabase as a mandatory parameter" {
            (Get-Command Invoke-ProcessSsasDatabase).Parameters['RefreshType'].Attributes.mandatory | Should -Be $false
        }

        It "Empty server" {
            { Invoke-ProcessSsasDatabase -Server "" -CubeDatabase 'MyCube' } | Should Throw;
        }
        It "Null server" {
            { Invoke-ProcessSsasDatabase -Server $null -CubeDatabase 'MyCube' } | Should Throw;
        }
        It "Empty CubeDatabase" {
            { Invoke-ProcessSsasDatabase -Server 'localhost' -CubeDatabase '' } | Should Throw;
        }
        It "Null CubeDatabase" {
            { Invoke-ProcessSsasDatabase -Server 'localhost' -CubeDatabase $null } | Should Throw;
        }

    }

    Context 'Invalid inputs' {
        It 'Process NonExistantServer should Throw' {
            { Invoke-ProcessSsasDatabase -Server 'NonExistantServer' -CubeDatabase 'NonExistantCube' } | Should Throw;
        }
        It 'Process NonExistantCube should Throw' {
            { Invoke-ProcessSsasDatabase -Server 'localhost' -CubeDatabase 'NonExistantCube' } | Should Throw;
        }

        It 'Process NonExistantRefreshType should Throw' {
            { Invoke-ProcessSsasDatabase -Server 'localhost' -CubeDatabase 'CubeToPublish' -RefreshType 'NonExistantRefreshType' } | Should Throw;
        }

        It 'Process cube with invalid data source should throw' {
            $ServerName = 'localhost';
            $CubeDatabase = 'CubeWithInvalidDataSource';

            Publish-Cube -AsDatabasePath $AsDatabasePath -Server $ServerName -CubeDatabase $CubeDatabase;
            Update-CubeDataSource -Server $ServerName -CubeDatabase $CubeDatabase -SourceSqlServer $ServerName -SourceSqlDatabase 'NonExistantDB' -ImpersonationMode 'ImpersonateServiceAccount';
            { Invoke-ProcessSsasDatabase -Server $ServerName -CubeDatabase $CubeDatabase -RefreshType Full } | Should Throw;
            Unpublish-Cube -Server $ServerName -CubeDatabase $CubeDatabase;
        }
    }

    Context 'Valid input' {
        It 'Process cube correctly' {
            $ServerName = 'localhost';
            $CubeDatabase = 'CubeToProcess';

            Publish-Cube -AsDatabasePath $AsDatabasePath -Server $ServerName -CubeDatabase $CubeDatabase;
            Update-CubeDataSource -Server $ServerName -CubeDatabase $CubeDatabase -SourceSqlServer $ServerName -SourceSqlDatabase 'DatabaseToPublish' -ImpersonationMode 'ImpersonateServiceAccount';
            { Invoke-ProcessSsasDatabase -Server $ServerName -CubeDatabase $CubeDatabase -RefreshType Full } | Should Not Throw;
            Unpublish-Cube -Server $ServerName -CubeDatabase $CubeDatabase;
        }

    }
}

Remove-Module -Name DeployCube
