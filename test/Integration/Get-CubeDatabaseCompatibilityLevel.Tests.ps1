# Parameter validation and mocked response tests live in test/Unit/SsasCommands.Tests.ps1.
BeforeDiscovery {
    . (Join-Path -Path (Split-Path -Parent $PSScriptRoot) -ChildPath 'TestHelpers.ps1')
    $skipIntegration = -not (Test-DeployCubeIntegrationEnabled)
}

BeforeAll {
    . (Join-Path -Path (Split-Path -Parent $PSScriptRoot) -ChildPath 'TestHelpers.ps1')
    Import-DeployCubeForTest
    $Settings = Get-DeployCubeIntegrationSettings
}

Describe "Get-CubeDatabaseCompatibilityLevel" -Tag 'Integration', 'SSAS', 'Round1' -Skip:$skipIntegration {
    BeforeAll {
        Initialize-DeployCubeIntegrationBaseline
    }

    Context "Invalid Inputs" {
        It "Invalid server" {
            { Get-CubeDatabaseCompatibilityLevel -Server "InvalidServer" -CubeDatabase "MyCube" } | Should -Throw;
        }

        It "Valid server invalid cube database" {
            { Get-CubeDatabaseCompatibilityLevel -Server $Settings.Server -CubeDatabase "InvalidCube" } | Should -Throw;
        }
    }

    Context "Valid Inputs" {
        It "Valid server and cube CompatibilityLevel=1200" {
            ( Get-CubeDatabaseCompatibilityLevel -Server $Settings.Server -CubeDatabase "CubeAtCompatibility1200" ) | Should -Be 1200;
        }

        It "Valid server and cube CompatibilityLevel=1500" {
            ( Get-CubeDatabaseCompatibilityLevel -Server $Settings.Server -CubeDatabase "CubeAtCompatibility1500" ) | Should -Be 1500;
        }
    }
}
