$ModulePath = Split-Path -Parent $MyInvocation.MyCommand.Path;
$ModulePath = Resolve-Path "$ModulePath\..\DeployCube\DeployCube.psd1";
import-Module -Name $ModulePath;

Describe "Select-AnalysisServicesDeploymentExeVersion" {

    Context "Testing Inputs" {
        It "Should have PreferredVersion as a mandatory parameter" {
            (Get-Command Select-AnalysisServicesDeploymentExeVersion).Parameters['PreferredVersion'].Attributes.mandatory | Should -Be $true
        }
    }
    Context "Finding Versions" {
        It "Finds latest version" {
            Select-AnalysisServicesDeploymentExeVersion -PreferredVersion latest | Should -Be 140
        }
        It "Does not find version 150" {
            Select-AnalysisServicesDeploymentExeVersion -PreferredVersion 150 | Should -Not -Be 150
        }
        It "Finds version 140" {
            Select-AnalysisServicesDeploymentExeVersion -PreferredVersion 140 | Should -Be 140
        }
        It "Does not find version 130" {
            Select-AnalysisServicesDeploymentExeVersion -PreferredVersion 130 | Should -Not -Be 130
        }

        It "Does not find version 120" {
            Select-AnalysisServicesDeploymentExeVersion -PreferredVersion 120 | Should -Not -Be 120
        }

        It "Does not find version 110" {
            Select-AnalysisServicesDeploymentExeVersion -PreferredVersion 110 | Should -Not -Be 110;
        }

        It "Unsupported AnalysisServicesDeploymentExe version 100 so should Throw" {
            { Select-AnalysisServicesDeploymentExeVersion -PreferredVersion 100 } | Should Throw;
        }

        It "Invalid version XXX so should throw" {
            { Select-AnalysisServicesDeploymentExeVersion -PreferredVersion XXX } | Should Throw;
        }
    }
}

Remove-Module -Name DeployCube