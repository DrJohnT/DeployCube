$ModulePath = Split-Path -Parent $MyInvocation.MyCommand.Path;
$ModulePath = Resolve-Path "$ModulePath\..\DeployCube\DeployCube.psd1";
import-Module -Name $ModulePath;

Describe "Find-AnalysisServicesDeploymentExeLocations" {

    It "Finds some version" {
        ( Find-AnalysisServicesDeploymentExeLocations ) | Should -Not -Be $null
    }

}

Remove-Module -Name DeployCube