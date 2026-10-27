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

Describe "Get-AnalysisServicesDeploymentExePath" -Tag 'Integration', 'SSAS', 'Round1' -Skip:$skipIntegration {
    BeforeEach {
        Remove-Item -Path Env:CustomAsDwInstallLocation -ErrorAction SilentlyContinue
    }

    Context "Finding Microsoft.AnalysisServices.Deployment.exe version" {
        It "Finds the expected installed version" {
            $path = Get-AnalysisServicesDeploymentExePath -Version $Settings.ExpectedDeploymentExeVersion
            $path | Should -BeLike "*Microsoft.AnalysisServices.Deployment.exe"
            (Get-Item -Path $path).VersionInfo.ProductVersion | Should -BeLike "$($Settings.ExpectedDeploymentExeVersion).*"
        }

        It "Valid folder location and Microsoft.AnalysisServices.Deployment.exe present" {
            $env:CustomAsDwInstallLocation = Get-DeployCubeFixturePath -Name 'DeploymentWizard'
            ( Get-AnalysisServicesDeploymentExePath -Version 11 ) -like "*Microsoft.AnalysisServices.Deployment.exe" | Should -BeTrue;
        }
    }
}
