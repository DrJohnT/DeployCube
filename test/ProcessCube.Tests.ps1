BeforeAll { 
    $CurrentFolder = Split-Path -Parent $PSScriptRoot;
    $ModulePath = Resolve-Path "$CurrentFolder\DeployCube\DeployCube.psd1";
    import-Module -Name $ModulePath;

    function Get-PathToCubeProject {
        $CurrentFolder = Split-Path -Parent $PSScriptRoot;
        return Resolve-Path "$CurrentFolder\examples\CubeToPublish\MyTabularProject\bin\Model.asdatabase";
    }
}

Describe "ProcessCube" {
    Context "Publish and Process Cube" {
        It "Publish and Process Cube" {
            $Server = 'localhost';
            $CubeDatabase = "TestProcessing";
            $AsDatabasePath = Get-PathToCubeProject;

            { Publish-Cube -AsDatabasePath $AsDatabasePath -Server $Server -CubeDatabase $CubeDatabase } | Should -Not -Throw;
            { Update-TabularCubeDataSource -Server $Server -CubeDatabase $CubeDatabase -SourceSqlServer $Server -SourceSqlDatabase 'DatabaseToPublish' -ImpersonationMode ImpersonateServiceAccount } | Should -Not -Throw;
            { Invoke-ProcessTabularCubeDatabase -Server $Server -CubeDatabase $CubeDatabase -RefreshType Full } | Should -Not -Throw;

        }
    }

}

AfterAll {
    Remove-Module -Name DeployCube
}
