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

Describe "Get-ServerMode" -Tag 'Integration', 'SSAS', 'Round1' -Skip:$skipIntegration {
    Context "Checking Inputs" {
        It "Invalid server" {
            { Get-ServerMode -Server "InvalidServer" } | Should -Throw;
        }

        It "Valid server" {
            ( Get-ServerMode -Server $Settings.Server ) | Should -Be "Tabular";
        }
    }
}
