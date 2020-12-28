BeforeAll { 
    $CurrentFolder = Split-Path -Parent $PSScriptRoot;
    $ModulePath = Resolve-Path "$CurrentFolder\DeployCube\DeployCube.psd1";
    import-Module -Name $ModulePath;
}


Describe "Find-AnalysisServicesDeploymentExeLocations" -Tag "Round1" {
    Context "Should return output" {
        It "Finds some version" {
            ( Find-AnalysisServicesDeploymentExeLocations ) | Should -Not -Be $null
        }
    }
}

AfterAll {
   Remove-Module -Name DeployCube
}
