BeforeAll { 
    $ModulePath = Split-Path -Parent $PSScriptRoot;
    $ModulePath = Resolve-Path "$ModulePath\DeployCube\DeployCube.psd1";
    import-Module -Name $ModulePath;

    function ResetEnv {
        $value = [Environment]::GetEnvironmentVariable("CustomAsDwInstallLocation");
        if ("$value" -ne "") {
            Clear-Item -Path Env:CustomAsDwInstallLocation;
        }
    }
    
}

Describe "Get-AnalysisServicesDeploymentExePath"  -Tag "Round1" {
    

    Context "Testing Inputs" {
        It "Should have Version as a mandatory parameter" {
            (Get-Command Get-AnalysisServicesDeploymentExePath).Parameters['Version'].Attributes.mandatory | Should -Be $true
        }
    }

    Context "Finding Microsoft.AnalysisServices.Deployment.exe version" {

        It "Finds version 15" {
            ResetEnv;
            ( Get-AnalysisServicesDeploymentExePath -Version 15 ) -like "*Microsoft.AnalysisServices.Deployment.exe" | Should -Be $true
        }

        It "Does not find version 14" {
            ResetEnv;
            ( Get-AnalysisServicesDeploymentExePath -Version 14 ) -like "*Microsoft.AnalysisServices.Deployment.exe" | Should -Be $false
        }

        It "Does not find version 13" {
            ResetEnv;
            ( Get-AnalysisServicesDeploymentExePath -Version 13 ) -like "*Microsoft.AnalysisServices.Deployment.exe" | Should -Be $false
        }

        It "Does not find version 12" {
            ResetEnv;
            ( Get-AnalysisServicesDeploymentExePath -Version 12 ) -like "*Microsoft.AnalysisServices.Deployment.exe" | Should -Be $false
        }

        It "Does not find version 11"  {
            ResetEnv;
            ( Get-AnalysisServicesDeploymentExePath -Version 11 ) -like "*Microsoft.AnalysisServices.Deployment.exe" | Should -Be $false
        }

        It "Unsupported version 10 so should Throw" {
            ResetEnv;
            { Get-AnalysisServicesDeploymentExePath -Version 10 } | Should -Throw;
        }

        It "Invalid version XX should Throw" {
            ResetEnv;
            { Get-AnalysisServicesDeploymentExePath -Version XX } | Should -Throw;
        }

        It "Valid folder but Microsoft.AnalysisServices.Deployment.exe is not present in folder" {
            ResetEnv;
            $env:CustomAsDwInstallLocation = $PSScriptRoot;
            ( Get-AnalysisServicesDeploymentExePath -Version 13 ) -like "*Microsoft.AnalysisServices.Deployment.exe" | Should -Be $false;
        }

        It "Invalid folder location for CustomAsDwInstallLocation" {
            ResetEnv;
            $env:CustomAsDwInstallLocation = $PSScriptRoot + "\xxx";
            { Get-AnalysisServicesDeploymentExePath -Version 13 } | Should -Throw;
        }

        It "Valid folder location and Microsoft.AnalysisServices.Deployment.exe present" {
            ResetEnv;
            $ExePath = Split-Path -Parent $PSScriptRoot;
            $ExePath = Resolve-Path "$ExePath\examples\DeploymentWizard";
            $env:CustomAsDwInstallLocation = $ExePath;
            ( Get-AnalysisServicesDeploymentExePath -Version 11 ) -like "*Microsoft.AnalysisServices.Deployment.exe" | Should -Be $true;
        }
    }
}

AfterAll {
    Remove-Module -Name DeployCube
}
 