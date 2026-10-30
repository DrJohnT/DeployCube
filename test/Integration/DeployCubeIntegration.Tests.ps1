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
    # Best-effort cleanup in case a scenario failed part-way through.
    foreach ($cube in @('IntegrationTestCube1200', 'IntegrationTestCube1500')) {
        try {
            if (Ping-SsasDatabase -Server $Settings.Server -CubeDatabase $cube) { Unpublish-Cube -Server $Settings.Server -CubeDatabase $cube }
        } catch { Write-Warning "Cleanup of $cube failed: $_" }
    }
    $global:ErrorActionPreference = $SavedErrorActionPreference
}

Describe "DeployCube Integration Tests" -Tag 'Integration', 'SSAS', 'Round4' -Skip:$skipIntegration {
    Context "Deploy update and Process 1200" {
        BeforeAll {
            $CubeDatabase = "IntegrationTestCube1200";
        }

        It "Deploy cube should not throw" {
            { Publish-Cube -AsDatabasePath $Settings.AsDatabasePath1200 -Server $Settings.Server -CubeDatabase $CubeDatabase } | Should -Not -Throw;
        }

        It "Check the cube deployed OK" {
            ( Ping-SsasDatabase -Server $Settings.Server -CubeDatabase $CubeDatabase ) | Should -BeTrue;
        }

        It "Update cube connection string with ImpersonateServiceAccount" {
            ( Update-TabularCubeDataSource -Server $Settings.Server -CubeDatabase $CubeDatabase -SourceSqlServer $Settings.SourceSqlServer -SourceSqlDatabase $Settings.SourceSqlDatabase -ImpersonationMode 'ImpersonateServiceAccount' )[1] | Should -BeTrue;
        }

        It "Process cube should not throw" {
            { Invoke-ProcessTabularCubeDatabase -Server $Settings.Server -CubeDatabase $CubeDatabase -RefreshType Full }  | Should -Not -Throw;
        }

        It "Drop cube should not throw" {
            # clean up
            { Unpublish-Cube -Server $Settings.Server -CubeDatabase $CubeDatabase } | Should -Not -Throw;
        }

        It "Check the cube dropped" {
            ( Ping-SsasDatabase -Server $Settings.Server -CubeDatabase $CubeDatabase ) | Should -BeFalse;
        }
    }

    Context "Deploy update and Process 1500" {
        BeforeAll {
            $CubeDatabase = "IntegrationTestCube1500";
        }

        It "Deploy cube should not throw" {
            { Publish-Cube -AsDatabasePath $Settings.AsDatabasePath1500 -Server $Settings.Server -CubeDatabase $CubeDatabase } | Should -Not -Throw;
        }

        It "Check the cube deployed OK" {
            ( Ping-SsasDatabase -Server $Settings.Server -CubeDatabase $CubeDatabase ) | Should -BeTrue;
        }

        It "Update cube connection string with ImpersonateServiceAccount" {
            ( Update-TabularCubeDataSource -Server $Settings.Server -CubeDatabase $CubeDatabase -SourceSqlServer $Settings.SourceSqlServer -SourceSqlDatabase $Settings.SourceSqlDatabase -ImpersonationMode 'ImpersonateServiceAccount' )[1] | Should -BeTrue;
        }

        It "Process cube should not throw" {
            { Invoke-ProcessTabularCubeDatabase -Server $Settings.Server -CubeDatabase $CubeDatabase -RefreshType Full }  | Should -Not -Throw;
        }

        It "Drop cube should not throw" {
            # clean up
            { Unpublish-Cube -Server $Settings.Server -CubeDatabase $CubeDatabase } | Should -Not -Throw;
        }

        It "Check the cube dropped" {
            ( Ping-SsasDatabase -Server $Settings.Server -CubeDatabase $CubeDatabase ) | Should -BeFalse;
        }
    }

    Context "Deploy Cube with ProcessFull" {
        It "Deploy cube should throw" {
            # The original test referenced an undefined $InvalidDataSourceConnection and passed the string 'true';
            # use a TestDrive copy of the fixture so the tracked file is not rewritten.
            $InvalidDataSourceConnection = Copy-DeployCubeFixture -Name 'InvalidDataSourceConnection' -Destination $TestDrive
            $CubeDatabase = "$(New-Guid)";  # this ensures we cannot fake the test result
            try {
                { Publish-Cube -AsDatabasePath $InvalidDataSourceConnection -Server $Settings.Server -CubeDatabase $CubeDatabase -ProcessingOption "Full" -TransactionalDeployment $true } | Should -Throw;
                ( Ping-SsasDatabase -Server $Settings.Server -CubeDatabase $CubeDatabase ) | Should -BeFalse;
            } finally {
                try {
                    if (Ping-SsasDatabase -Server $Settings.Server -CubeDatabase $CubeDatabase) { Unpublish-Cube -Server $Settings.Server -CubeDatabase $CubeDatabase }
                } catch { Write-Warning "Cleanup of $CubeDatabase failed: $_" }
            }
        }
    }
}
