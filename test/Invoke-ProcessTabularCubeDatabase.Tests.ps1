BeforeAll { 
    $CurrentFolder = Split-Path -Parent $PSScriptRoot;
    $ModulePath = Resolve-Path "$CurrentFolder\DeployCube\DeployCube.psd1";
    import-Module -Name $ModulePath;

    #$exampleFolder =  Resolve-Path "$CurrentFolder\examples";
    #$AsDatabasePath = Resolve-Path "$exampleFolder\CubeToPublish\MyTabularProject\bin\Model.asdatabase";
    function Get-PathToCubeProject {
        $CurrentFolder = Split-Path -Parent $PSScriptRoot;
        return Resolve-Path "$CurrentFolder\examples\CubeToPublish\MyTabularProject\bin\Model.asdatabase";
    }
}



Describe "Invoke-ProcessTabularCubeDatabase" -Tag "Round2" {
    Context "Testing Inputs" {
        It "Should have Server as a mandatory parameter" {
            (Get-Command Invoke-ProcessTabularCubeDatabase).Parameters['Server'].Attributes.mandatory | Should -Be $true
        }
        It "Should have CubeDatabase as a mandatory parameter" {
            (Get-Command Invoke-ProcessTabularCubeDatabase).Parameters['CubeDatabase'].Attributes.mandatory | Should -Be $true
        }
        It "Should have CubeDatabase as a mandatory parameter" {
            (Get-Command Invoke-ProcessTabularCubeDatabase).Parameters['RefreshType'].Attributes.mandatory | Should -Be $false
        }

        It "Empty server" {
            { Invoke-ProcessTabularCubeDatabase -Server "" -CubeDatabase 'MyCube' } | Should -Throw;
        }
        It "Null server" {
            { Invoke-ProcessTabularCubeDatabase -Server $null -CubeDatabase 'MyCube' } | Should -Throw;
        }
        It "Empty CubeDatabase" {
            { Invoke-ProcessTabularCubeDatabase -Server 'localhost' -CubeDatabase '' } | Should -Throw;
        }
        It "Null CubeDatabase" {
            { Invoke-ProcessTabularCubeDatabase -Server 'localhost' -CubeDatabase $null } | Should -Throw;
        }

    }

    Context 'Invalid inputs' {
        It 'Process NonExistantServer should Throw' {
            { Invoke-ProcessTabularCubeDatabase -Server 'NonExistantServer' -CubeDatabase 'NonExistantCube' } | Should -Throw;
        }
        It 'Process NonExistantCube should Throw' {
            { Invoke-ProcessTabularCubeDatabase -Server 'localhost' -CubeDatabase 'NonExistantCube' } | Should -Throw;
        }

        It 'Process NonExistantRefreshType should Throw' {
            { Invoke-ProcessTabularCubeDatabase -Server 'localhost' -CubeDatabase 'CubeToPublish' -RefreshType 'NonExistantRefreshType' } | Should -Throw;
        }

        It 'Process cube with invalid data source should throw' {
            $ServerName = 'localhost';
            $CubeDatabase = 'CubeWithInvalidDataSource';
            $AsDatabasePath = Get-PathToCubeProject;
            Publish-Cube -AsDatabasePath $AsDatabasePath -Server $ServerName -CubeDatabase $CubeDatabase;
            Update-TabularCubeDataSource -Server $ServerName -CubeDatabase $CubeDatabase -SourceSqlServer $ServerName -SourceSqlDatabase 'NonExistantDB' -ImpersonationMode 'ImpersonateServiceAccount';
            { Invoke-ProcessTabularCubeDatabase -Server $ServerName -CubeDatabase $CubeDatabase -RefreshType Full } | Should -Throw;
            Unpublish-Cube -Server $ServerName -CubeDatabase $CubeDatabase;
        }
    }

    Context 'Valid input' {
        It 'Process cube correctly' {
            $ServerName = 'localhost';
            $CubeDatabase = 'CubeToProcess';
            $AsDatabasePath = Get-PathToCubeProject;
            Publish-Cube -AsDatabasePath $AsDatabasePath -Server $ServerName -CubeDatabase $CubeDatabase;
            Update-TabularCubeDataSource -Server $ServerName -CubeDatabase $CubeDatabase -SourceSqlServer $ServerName -SourceSqlDatabase 'DatabaseToPublish' -ImpersonationMode 'ImpersonateServiceAccount';
            { Invoke-ProcessTabularCubeDatabase -Server $ServerName -CubeDatabase $CubeDatabase -RefreshType Full } | Should Not Throw;
            Unpublish-Cube -Server $ServerName -CubeDatabase $CubeDatabase;
        }

    }
}

AfterAll {
    Remove-Module -Name DeployCube
}