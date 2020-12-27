BeforeAll { 
    $CurrentFolder = Split-Path -Parent $PSScriptRoot;
    $ModulePath = Resolve-Path "$CurrentFolder\DeployCube\DeployCube.psd1";
    import-Module -Name $ModulePath;
    Write-Host "CurrentFolder: $CurrentFolder ModulePath: $ModulePath";
}


Describe "Find-AnalysisServicesDeploymentExeLocations" {

    It "Finds some version" {
        ( Find-AnalysisServicesDeploymentExeLocations ) | Should -Not -Be $null
    }

}

AfterAll {
   Remove-Module -Name DeployCube
}
