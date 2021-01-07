BeforeAll { 
    $CurrentFolder = Split-Path -Parent $PSScriptRoot;
    $ModulePath = Resolve-Path "$CurrentFolder\DeployCube\DeployCube.psd1";
    Import-Module -Name $ModulePath;

    function ResetEnv {
        $value = [Environment]::GetEnvironmentVariable("CustomAsDwInstallLocation");
        if ("$value" -ne "") {
            Clear-Item -Path Env:CustomAsDwInstallLocation;
        }
    }
    
    ResetEnv;
}


Describe "Find-AnalysisServicesDeploymentExeLocations" -Tag "Round1" {
    Context "Should return output" {
        It "Finds some version" {
            ResetEnv;
            ( Find-AnalysisServicesDeploymentExeLocations ) | Should -Not -Be $null
            $lines = Find-AnalysisServicesDeploymentExeLocations | Measure-Object;
            $lines.Count | Should -Be 1;
        }

        It "Valid folder location and Microsoft.AnalysisServices.Deployment.exe present" {
            ResetEnv;
            $ExePath = Split-Path -Parent $PSScriptRoot;
            $ExePath = Resolve-Path "$ExePath\examples\ForTests\DeploymentWizard";
            $env:CustomAsDwInstallLocation = $ExePath;

            $lines = Find-AnalysisServicesDeploymentExeLocations | Measure-Object;
            $lines.Count | Should -Be 2;
        }
    }
}

AfterAll {
   Remove-Module -Name DeployCube
}
