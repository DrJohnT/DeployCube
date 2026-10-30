# Deterministic (mocked) discovery tests live in test/Unit/DeploymentExeDiscovery.Tests.ps1.
# These tests check discovery against the deployment utility actually installed on the test machine.
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

Describe "Find-AnalysisServicesDeploymentExeLocations" -Tag 'Integration', 'SSAS', 'Round1' -Skip:$skipIntegration {
    BeforeEach {
        Remove-Item -Path Env:CustomAsDwInstallLocation -ErrorAction SilentlyContinue
    }

    Context "Should return output" {
        It "Finds the installed version" {
            $lines = @(Find-AnalysisServicesDeploymentExeLocations)
            $lines.Count | Should -BeGreaterOrEqual 1
            ($lines | Where-Object { $_ -like "$($Settings.ExpectedDeploymentExeVersion)*" }) | Should -Not -BeNullOrEmpty
        }

        It "Valid folder location and Microsoft.AnalysisServices.Deployment.exe present" {
            $installed = @(Find-AnalysisServicesDeploymentExeLocations).Count
            $env:CustomAsDwInstallLocation = Get-DeployCubeFixturePath -Name 'DeploymentWizard'
            $lines = @(Find-AnalysisServicesDeploymentExeLocations)
            $lines.Count | Should -Be ($installed + 1)
        }
    }
}
