# Parameter validation (including the Drop-Cube alias) and mocked response tests live in test/Unit/SsasCommands.Tests.ps1.
BeforeDiscovery {
    . (Join-Path -Path (Split-Path -Parent $PSScriptRoot) -ChildPath 'TestHelpers.ps1')
    $skipIntegration = -not (Test-DeployCubeIntegrationEnabled)
}

BeforeAll {
    . (Join-Path -Path (Split-Path -Parent $PSScriptRoot) -ChildPath 'TestHelpers.ps1')
    Import-DeployCubeForTest
    $Settings = Get-DeployCubeIntegrationSettings
}

Describe "Unpublish-Cube" -Tag 'Integration', 'SSAS', 'Round2' -Skip:$skipIntegration {
    Context "Main Tests" {
        It "Invalid server" {
            { Unpublish-Cube -Server "InvalidServer" -CubeDatabase "CubeAtCompatibility1200" } | Should -Throw;
        }

        It "Valid server and invalid database" {
            { Unpublish-Cube -Server $Settings.Server -CubeDatabase "InvalidDatabase" } | Should -Not -Throw;
        }
    }
}
