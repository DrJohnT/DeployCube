# Parameter validation, alias, invalid-input and mocked deployment tests live in test/Unit/Publish-Cube.Tests.ps1.
BeforeDiscovery {
    . (Join-Path -Path (Split-Path -Parent $PSScriptRoot) -ChildPath 'TestHelpers.ps1')
    $skipIntegration = -not (Test-DeployCubeIntegrationEnabled)
}

BeforeAll {
    . (Join-Path -Path (Split-Path -Parent $PSScriptRoot) -ChildPath 'TestHelpers.ps1')
    Import-DeployCubeForTest
    $Settings = Get-DeployCubeIntegrationSettings
    $SavedErrorActionPreference = $global:ErrorActionPreference
}

AfterAll {
    $global:ErrorActionPreference = $SavedErrorActionPreference
}

Describe "Publish-Cube" -Tag 'Integration', 'SSAS', 'Round3' -Skip:$skipIntegration {
    Context "Invalid Inputs" {
        It "Invalid Server should Throw" {
            { Publish-Cube -AsDatabasePath $Settings.AsDatabasePath1200 -Server "MyTabularCubeInvalidServer" -CubeDatabase "MyDB" -PreferredVersion latest } | Should -Throw;
        }
    }

    Context "Valid parameters so deploy" {
        It "Valid parameters so deploy <Label> cube and test it is present" -ForEach @(
            @{ Label = '1200'; PathProperty = 'AsDatabasePath1200' },
            @{ Label = '1500'; PathProperty = 'AsDatabasePath1500' }
        ) {
            $CubeDatabase = "$(New-Guid)";  # this ensures we cannot fake the test result
            try {
                Publish-Cube -AsDatabasePath $Settings.$PathProperty -Server $Settings.Server -CubeDatabase $CubeDatabase;
                ( Ping-SsasDatabase -Server $Settings.Server -CubeDatabase $CubeDatabase ) | Should -BeTrue;
            } finally {
                # clean up
                try { Unpublish-Cube -Server $Settings.Server -CubeDatabase $CubeDatabase } catch { Write-Warning "Cleanup of $CubeDatabase failed: $_" }
            }
        }
    }
}
