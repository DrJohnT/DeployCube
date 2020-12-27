BeforeAll { 
    $CurrentFolder = Split-Path -Parent $PSScriptRoot;
    $ModulePath = Resolve-Path "$CurrentFolder\DeployCube\DeployCube.psd1";
    import-Module -Name $ModulePath;

    function Get-PathToCubeProject {
        $CurrentFolder = Split-Path -Parent $PSScriptRoot;
        return Resolve-Path "$CurrentFolder\examples\CubeToPublish\MyTabularProject\bin\Model.asdatabase";
    }    

}

Describe "Publish-Cube Integration Tests" {
    Context "Deploy Cube, update connection and process" {
        
        It "Deploy cube should not throw" {
            $AsDatabasePath = Get-PathToCubeProject;
            $ServerName = 'localhost';
            $CubeDatabase = "IntegrationTestCube";  
            { Publish-Cube -AsDatabasePath $AsDatabasePath -Server $ServerName -CubeDatabase $CubeDatabase } | Should -Not -Throw;
        }

        It "Check the cube deployed OK" {
            $ServerName = 'localhost';
            $CubeDatabase = "IntegrationTestCube";  
            ( Ping-SsasDatabase -Server $ServerName -CubeDatabase $CubeDatabase ) | Should -Be $true;
        }

        It "Update cube connection string with ImpersonateServiceAccount" {
            $ServerName = 'localhost';
            $CubeDatabase = "IntegrationTestCube";  
            ( Update-TabularCubeDataSource -Server $ServerName -CubeDatabase $CubeDatabase -SourceSqlServer $ServerName -SourceSqlDatabase 'DatabaseToPublish' -ImpersonationMode 'ImpersonateServiceAccount' ) | Should -Be $true;
        }

        It "Process cube should not throw" {
            $ServerName = 'localhost';
            $CubeDatabase = "IntegrationTestCube";  
            { Invoke-ProcessTabularCubeDatabase -Server $ServerName -CubeDatabase $CubeDatabase -RefreshType Full }  | Should -Not -Throw;
        }

        It "Drop cube should not throw" {
            # clean up
            $ServerName = 'localhost';
            $CubeDatabase = "IntegrationTestCube";  
            { Unpublish-Cube -Server $ServerName -CubeDatabase $CubeDatabase } | Should -Not -Throw;
        }

        It "Check the cube dropped" {
            $ServerName = 'localhost';
            $CubeDatabase = "IntegrationTestCube";  
            ( Ping-SsasDatabase -Server $ServerName -CubeDatabase $CubeDatabase ) | Should -Be $false;
        }
    }

    Context "Deploy Cube with ProcessFull" {
        It "Deploy cube should throw" {
            $CubeDatabase = New-Guid;  # this ensures we cannot fake the test result
            $ServerName = 'localhost';
            { Publish-Cube -AsDatabasePath $InvalidDataSourceConnection -Server $ServerName -CubeDatabase $CubeDatabase -ProcessingOption "Full" -TransactionalDeployment true } | Should -Throw;
            ( Ping-SsasDatabase -Server $ServerName -CubeDatabase $CubeDatabase ) | Should -Be $false;
        }

    }

}

AfterAll {
    Remove-Module -Name DeployCube;
}