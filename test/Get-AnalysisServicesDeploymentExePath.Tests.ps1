BeforeAll { 
    $ModulePath = Split-Path -Parent $PSScriptRoot;
    $ModulePath = Resolve-Path "$ModulePath\DeployCube\DeployCube.psd1";
    import-Module -Name $ModulePath;   
    
}



Describe "Get-AnalysisServicesDeploymentExePath"  -Tag "Round1" {
    

    Context "Testing Inputs" {
        It "Should have Version as a mandatory parameter" {
            (Get-Command Get-AnalysisServicesDeploymentExePath).Parameters['Version'].Attributes.mandatory | Should -Be $true
        }
    }

    Context "Finding Microsoft.AnalysisServices.Deployment.exe version" {

        It "Finds version 15" {
            ( Get-AnalysisServicesDeploymentExePath -Version 15 ) -like "*Microsoft.AnalysisServices.Deployment.exe" | Should -Be $true
        }

        It "Does not find version 14" {
            ( Get-AnalysisServicesDeploymentExePath -Version 14 ) -like "*Microsoft.AnalysisServices.Deployment.exe" | Should -Be $false
        }

        It "Does not find version 13" {
            ( Get-AnalysisServicesDeploymentExePath -Version 13 ) -like "*Microsoft.AnalysisServices.Deployment.exe" | Should -Be $false
        }

        It "Does not find version 12" {
            ( Get-AnalysisServicesDeploymentExePath -Version 12 ) -like "*Microsoft.AnalysisServices.Deployment.exe" | Should -Be $false
        }

        It "Does not find version 11"  {
            ( Get-AnalysisServicesDeploymentExePath -Version 11 ) -like "*Microsoft.AnalysisServices.Deployment.exe" | Should -Be $false
        }

        It "Unsupported version 10 so should Throw" {
            { Get-AnalysisServicesDeploymentExePath -Version 10 } | Should -Throw;
        }

        It "Invalid version XX should Throw" {
            { Get-AnalysisServicesDeploymentExePath -Version XX } | Should -Throw;
        }

    }
}

AfterAll {
    Remove-Module -Name DeployCube
}
 