$ModulePath = Split-Path -Parent $MyInvocation.MyCommand.Path;
$ModulePath = Resolve-Path "$ModulePath\..\DeployCube\DeployCube.psd1";
import-Module -Name $ModulePath;

[string]$ExeName = "*Microsoft.AnalysisServices.Deployment.exe";

Describe "Get-AnalysisServicesDeploymentExePath" {

    Context "Testing Inputs" {
        It "Should have Version as a mandatory parameter" {
            (Get-Command Get-AnalysisServicesDeploymentExePath).Parameters['Version'].Attributes.mandatory | Should -Be $true
        }
    }

    Context "Finding Microsoft.AnalysisServices.Deployment.exe version" {
        It "Does not find version 150" {
            ( Get-AnalysisServicesDeploymentExePath -Version 150 ) -like $ExeName | Should -Not -Be $true
        }

        It "Finds version 140" {
            ( Get-AnalysisServicesDeploymentExePath -Version 140 ) -like $ExeName | Should -Be $true
        }

        It "Does not find version 130" {
            ( Get-AnalysisServicesDeploymentExePath -Version 130 ) -like $ExeName | Should -Not -Be $true
        }

        It "Does not find version 120" {
            ( Get-AnalysisServicesDeploymentExePath -Version 120 ) -like $ExeName | Should -Not -Be $true
        }

        It "Does not find version 110"  {
            ( Get-AnalysisServicesDeploymentExePath -Version 110 ) -like $ExeName | Should -Not -Be $true
        }

        It "Unsupported version 100 so should Throw" {
            { Get-AnalysisServicesDeploymentExePath -Version 100 } | Should Throw;
        }

        It "Invalid version XXX should Throw" {
            { Get-AnalysisServicesDeploymentExePath -Version XXX } | Should Throw;
        }

    }
}

Remove-Module -Name DeployCube