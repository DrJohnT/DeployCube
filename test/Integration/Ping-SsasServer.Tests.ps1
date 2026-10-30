# Parameter validation tests live in test/Unit/SsasCommands.Tests.ps1.
BeforeDiscovery {
    . (Join-Path -Path (Split-Path -Parent $PSScriptRoot) -ChildPath 'TestHelpers.ps1')
    $skipIntegration = -not (Test-DeployCubeIntegrationEnabled)
}

BeforeAll {
    . (Join-Path -Path (Split-Path -Parent $PSScriptRoot) -ChildPath 'TestHelpers.ps1')
    Import-DeployCubeForTest
    $Settings = Get-DeployCubeIntegrationSettings
}

Describe "Ping-SsasServer" -Tag 'Integration', 'SSAS', 'Round1' -Skip:$skipIntegration {
    Context "Checking Inputs" {
        It "Invalid server" {
            ( Ping-SsasServer -Server "InvalidServer" ) | Should -BeFalse;
        }

        It "Valid server" {
            ( Ping-SsasServer -Server $Settings.Server ) | Should -BeTrue;
        }
    }
}
