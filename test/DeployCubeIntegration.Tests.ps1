BeforeAll { 
    $CurrentFolder = Split-Path -Parent $PSScriptRoot;
    $ModulePath = Resolve-Path "$CurrentFolder\DeployCube\DeployCube.psd1";
    import-Module -Name $ModulePath;

    function Get-PathToCubeProject {
        $CurrentFolder = Split-Path -Parent $PSScriptRoot;
        return Resolve-Path "$CurrentFolder\examples\CubeAtCompatibility1200\bin\Model.asdatabase";
    }    

    function Get-PathToCubeProject1500 {
        $CurrentFolder = Split-Path -Parent $PSScriptRoot;
        return Resolve-Path "$CurrentFolder\examples\CubeAtCompatibility1500\bin\Model.asdatabase";
    }   

}

Describe "DeployCube Integration Tests" -Tag "Round4" {
    Context "Deploy update and Process 1200" {
        
        It "Deploy cube should not throw" {
            $AsDatabasePath = Get-PathToCubeProject;
            $ServerName = 'localhost';
            $CubeDatabase = "IntegrationTestCube1200";  
            { Publish-Cube -AsDatabasePath $AsDatabasePath -Server $ServerName -CubeDatabase $CubeDatabase } | Should -Not -Throw;
        }

        It "Check the cube deployed OK" {
            $ServerName = 'localhost';
            $CubeDatabase = "IntegrationTestCube1200";  
            ( Ping-SsasDatabase -Server $ServerName -CubeDatabase $CubeDatabase ) | Should -BeTrue;
        }

        It "Update cube connection string with ImpersonateServiceAccount" {
            $ServerName = 'localhost';
            $CubeDatabase = "IntegrationTestCube1200";  
            ( Update-TabularCubeDataSource -Server $ServerName -CubeDatabase $CubeDatabase -SourceSqlServer $ServerName -SourceSqlDatabase 'DatabaseToPublish' -ImpersonationMode 'ImpersonateServiceAccount' )[1] | Should -BeTrue;
        }

        It "Process cube should not throw" {
            $ServerName = 'localhost';
            $CubeDatabase = "IntegrationTestCube1200";  
            { Invoke-ProcessTabularCubeDatabase -Server $ServerName -CubeDatabase $CubeDatabase -RefreshType Full }  | Should -Not -Throw;
        }

        It "Drop cube should not throw" {
            # clean up
            $ServerName = 'localhost';
            $CubeDatabase = "IntegrationTestCube1200";  
            { Unpublish-Cube -Server $ServerName -CubeDatabase $CubeDatabase } | Should -Not -Throw;
        }

        It "Check the cube dropped" {
            $ServerName = 'localhost';
            $CubeDatabase = "IntegrationTestCube1200";  
            ( Ping-SsasDatabase -Server $ServerName -CubeDatabase $CubeDatabase ) | Should -BeFalse;
        }
    }

    Context "Deploy update and Process 1500" {
        
        It "Deploy cube should not throw" {
            $AsDatabasePath = Get-PathToCubeProject1500;
            $ServerName = 'localhost';
            $CubeDatabase = "IntegrationTestCube1500";  
            { Publish-Cube -AsDatabasePath $AsDatabasePath -Server $ServerName -CubeDatabase $CubeDatabase } | Should -Not -Throw;
        }

        It "Check the cube deployed OK" {
            $ServerName = 'localhost';
            $CubeDatabase = "IntegrationTestCube1500";  
            ( Ping-SsasDatabase -Server $ServerName -CubeDatabase $CubeDatabase ) | Should -BeTrue;
        }

        It "Update cube connection string with ImpersonateServiceAccount" {
            $ServerName = 'localhost';
            $CubeDatabase = "IntegrationTestCube1500";  
            ( Update-TabularCubeDataSource -Server $ServerName -CubeDatabase $CubeDatabase -SourceSqlServer $ServerName -SourceSqlDatabase 'DatabaseToPublish' -ImpersonationMode 'ImpersonateServiceAccount' )[1] | Should -BeTrue;
        }

        It "Process cube should not throw" {
            $ServerName = 'localhost';
            $CubeDatabase = "IntegrationTestCube1500";  
            { Invoke-ProcessTabularCubeDatabase -Server $ServerName -CubeDatabase $CubeDatabase -RefreshType Full }  | Should -Not -Throw;
        }

        It "Drop cube should not throw" {
            # clean up
            $ServerName = 'localhost';
            $CubeDatabase = "IntegrationTestCube1500";  
            { Unpublish-Cube -Server $ServerName -CubeDatabase $CubeDatabase } | Should -Not -Throw;
        }

        It "Check the cube dropped" {
            $ServerName = 'localhost';
            $CubeDatabase = "IntegrationTestCube1500";  
            ( Ping-SsasDatabase -Server $ServerName -CubeDatabase $CubeDatabase ) | Should -BeFalse;
        }
    }

    Context "Deploy Cube with ProcessFull" {
        It "Deploy cube should throw" {
            $CubeDatabase = New-Guid;  # this ensures we cannot fake the test result
            $ServerName = 'localhost';
            { Publish-Cube -AsDatabasePath $InvalidDataSourceConnection -Server $ServerName -CubeDatabase $CubeDatabase -ProcessingOption "Full" -TransactionalDeployment true } | Should -Throw;
            ( Ping-SsasDatabase -Server $ServerName -CubeDatabase $CubeDatabase ) | Should -BeFalse;
        }

    }

}

AfterAll {
    Remove-Module -Name DeployCube;
}