BeforeAll { 
    $CurrentFolder = Split-Path -Parent $PSScriptRoot;
    $ModulePath = Resolve-Path "$CurrentFolder\DeployCube\DeployCube.psd1";
    import-Module -Name $ModulePath;

    function Get-PathToCubeProject {
        $CurrentFolder = Split-Path -Parent $PSScriptRoot;
        return Resolve-Path "$CurrentFolder\examples\CubeToPublish\MyTabularProject\bin\Model.asdatabase";
    }    

    function Get-AzureAsServer {
        return "???";
    }
}

Describe "Publish-Cube Integration Tests" {
    Context "Deploy Cube, update connection and process" {
        
        It "Deploy cube should not throw" {
            $AsDatabasePath = Get-PathToCubeProject;
            $ServerName = Get-AzureAsServer;
            $CubeDatabase = "AzureTestCube";  
            # Unable to obtain authentication token using the credentials provided. If your Active Directory tenant administrator has configured Multi-Factor Authentication 
            # or if your account is a Microsoft Account, please remove the user name and password from the connection string, and then retry. You should then be prompted to enter your credentials.
            { Publish-Cube -AsDatabasePath $AsDatabasePath -Server $ServerName -CubeDatabase $CubeDatabase  } | Should -Not -Throw
            

        }
<#
        It "Check the cube deployed OK" {
            $ServerName = Get-AzureAsServer;
            $CubeDatabase = "AzureTestCube";  
            ( Ping-SsasDatabase -Server $ServerName -CubeDatabase $CubeDatabase ) | Should -Be $true;
        }

        It "Update cube connection string with ImpersonateServiceAccount" {
            $ServerName = Get-AzureAsServer;
            $CubeDatabase = "AzureTestCube";  
            ( Update-TabularCubeDataSource -Server $ServerName -CubeDatabase $CubeDatabase -SourceSqlServer $ServerName -SourceSqlDatabase 'DatabaseToPublish' -ImpersonationMode 'ImpersonateServiceAccount' ) | Should -Be $true;
        }

        It "Process cube should not throw" {
            $ServerName = Get-AzureAsServer;
            $CubeDatabase = "AzureTestCube";  
            { Invoke-ProcessTabularCubeDatabase -Server $ServerName -CubeDatabase $CubeDatabase -RefreshType Full }  | Should -Not -Throw;
        }

        It "Drop cube should not throw" {
            # clean up
            $ServerName = Get-AzureAsServer;
            $CubeDatabase = "AzureTestCube";  
            { Unpublish-Cube -Server $ServerName -CubeDatabase $CubeDatabase } | Should -Not -Throw;
        }

        It "Check the cube dropped" {
            $ServerName = Get-AzureAsServer;
            $CubeDatabase = "AzureTestCube";  
            ( Ping-SsasDatabase -Server $ServerName -CubeDatabase $CubeDatabase ) | Should -Be $false;
        }
    }

    Context "Deploy Cube with ProcessFull" {
        It "Deploy cube should throw" {
            $CubeDatabase = New-Guid;  # this ensures we cannot fake the test result
            $ServerName = Get-AzureAsServer;
            { Publish-Cube -AsDatabasePath $InvalidDataSourceConnection -Server $ServerName -CubeDatabase $CubeDatabase -ProcessingOption "Full" -TransactionalDeployment true } | Should -Throw;
            ( Ping-SsasDatabase -Server $ServerName -CubeDatabase $CubeDatabase ) | Should -Be $false;
        }
#>
    }

}

AfterAll {
    Remove-Module -Name DeployCube;
}