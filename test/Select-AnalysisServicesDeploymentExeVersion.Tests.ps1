BeforeAll { 
    $CurrentFolder = Split-Path -Parent $PSScriptRoot;
    $ModulePath = Resolve-Path "$CurrentFolder\DeployCube\DeployCube.psd1";
    import-Module -Name $ModulePath;
    function ResetEnv {
        $value = [Environment]::GetEnvironmentVariable("CustomAsDwInstallLocation");
        if ("$value" -ne "") {
            Clear-Item -Path Env:CustomAsDwInstallLocation;
        }
    }
    ResetEnv;
}

Describe "Select-AnalysisServicesDeploymentExeVersion"  -Tag "Round1" {

    Context "Testing Inputs" {
        It "Should have PreferredVersion as a mandatory parameter" {
            (Get-Command Select-AnalysisServicesDeploymentExeVersion).Parameters['PreferredVersion'].Attributes.mandatory | Should -BeTrue;
        }
    }

    Context "Finding Versions" {
        It "Finds latest version" {
            $expected = $null
            foreach ($version in @('22', '21', '20', '16', '15', '14', '13', '12', '11')) {
                if (Get-AnalysisServicesDeploymentExePath -Version $version) {
                    $expected = $version
                    break
                }
            }
            Select-AnalysisServicesDeploymentExeVersion -PreferredVersion latest | Should -Be $expected
        }
        
        It "Finds version 15" {
            Select-AnalysisServicesDeploymentExeVersion -PreferredVersion 15 | Should -Be '15'
        }
        
        It "Does not find version 14" {
            Select-AnalysisServicesDeploymentExeVersion -PreferredVersion 14 | Should -Not -Be '14'
        }

        It "Does not find version 13" {
            Select-AnalysisServicesDeploymentExeVersion -PreferredVersion 13 | Should -Not -Be '13'
        }

        It "Does not find version 12" {
            Select-AnalysisServicesDeploymentExeVersion -PreferredVersion 12 | Should -Not -Be '12'
        }

        It "Does not find version 11" {
            Select-AnalysisServicesDeploymentExeVersion -PreferredVersion 11 | Should -Not -Be 11;
        }

        It "Now finds version 11" {
            ResetEnv;
            $ExePath = Split-Path -Parent $PSScriptRoot;
            $ExePath = Resolve-Path "$ExePath\examples\ForTests\DeploymentWizard";
            $env:CustomAsDwInstallLocation = $ExePath;
            Select-AnalysisServicesDeploymentExeVersion -PreferredVersion 11 | Should -Be 11;
        }

        It "Unsupported AnalysisServicesDeploymentExe version 10 so should Throw" {
            { Select-AnalysisServicesDeploymentExeVersion -PreferredVersion 10 } | Should -Throw;
        }

        It "Invalid version XX so should throw" {
            { Select-AnalysisServicesDeploymentExeVersion -PreferredVersion XX } | Should -Throw;
        }
    }

    Context "Version 21 support" {
        It "selects version 21 explicitly and uses it as latest when version 22 is absent" {
            Mock -ModuleName DeployCube Get-AnalysisServicesDeploymentExePath {
                param($Version)
                if ($Version -in @('20', '21')) {
                    return "C:\Deployment\$Version\Microsoft.AnalysisServices.Deployment.exe"
                }
            }

            Select-AnalysisServicesDeploymentExeVersion -PreferredVersion 21 | Should -Be '21'
            Select-AnalysisServicesDeploymentExeVersion -PreferredVersion latest | Should -Be '21'
        }

        It "prefers version 22 over version 21 and 20 for latest" {
            Mock -ModuleName DeployCube Get-AnalysisServicesDeploymentExePath {
                param($Version)
                if ($Version -in @('20', '21', '22')) {
                    return "C:\Deployment\$Version\Microsoft.AnalysisServices.Deployment.exe"
                }
            }

            Select-AnalysisServicesDeploymentExeVersion -PreferredVersion latest | Should -Be '22'
        }
    }
}

AfterAll {
    Remove-Module -Name DeployCube
}