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

Describe "Ping-SsasDatabase" -Tag 'Integration', 'SSAS', 'Round1' -Skip:$skipIntegration {
    BeforeAll {
        Initialize-DeployCubeIntegrationBaseline
    }

    Context "Main Tests" {
        It "Invalid server" {
            { Ping-SsasDatabase -Server "InvalidServer" -CubeDatabase "CubeAtCompatibility1200" } | Should -Throw;
        }

        It "Valid server and invalid database" {
            ( Ping-SsasDatabase -Server $Settings.Server -CubeDatabase "InvalidDatabase" ) | Should -BeFalse;
        }

        It "Valid server and database" {
            ( Ping-SsasDatabase -Server $Settings.Server -CubeDatabase "CubeAtCompatibility1200" ) | Should -BeTrue;
        }
    }
}
