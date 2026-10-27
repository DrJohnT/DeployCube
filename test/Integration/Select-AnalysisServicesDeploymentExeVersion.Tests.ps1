# Deterministic (mocked) version selection tests live in test/Unit/DeploymentExeDiscovery.Tests.ps1.
# These tests check selection against the deployment utility actually installed on the test machine.
BeforeDiscovery {
    . (Join-Path -Path (Split-Path -Parent $PSScriptRoot) -ChildPath 'TestHelpers.ps1')
    $skipIntegration = -not (Test-DeployCubeIntegrationEnabled)
}

BeforeAll {
    . (Join-Path -Path (Split-Path -Parent $PSScriptRoot) -ChildPath 'TestHelpers.ps1')
    Import-DeployCubeForTest
    $Settings = Get-DeployCubeIntegrationSettings
    $OriginalCustomLocation = $env:CustomAsDwInstallLocation
}

AfterAll {
    $env:CustomAsDwInstallLocation = $OriginalCustomLocation
}

Describe "Select-AnalysisServicesDeploymentExeVersion" -Tag 'Integration', 'SSAS', 'Round1' -Skip:$skipIntegration {
    BeforeEach {
        Remove-Item -Path Env:CustomAsDwInstallLocation -ErrorAction SilentlyContinue
    }

    Context "Finding Versions" {
        It "Finds latest version" {
            Select-AnalysisServicesDeploymentExeVersion -PreferredVersion latest | Should -Be $Settings.ExpectedDeploymentExeVersion
        }

        It "Finds the expected installed version" {
            Select-AnalysisServicesDeploymentExeVersion -PreferredVersion $Settings.ExpectedDeploymentExeVersion | Should -Be $Settings.ExpectedDeploymentExeVersion
        }

        It "Now finds version 11" {
            $env:CustomAsDwInstallLocation = Get-DeployCubeFixturePath -Name 'DeploymentWizard'
            Select-AnalysisServicesDeploymentExeVersion -PreferredVersion 11 | Should -Be 11;
        }
    }
}
