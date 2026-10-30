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
    try { Unpublish-Cube -Server $Settings.Server -CubeDatabase 'TestProcessing' } catch { Write-Warning "Cleanup of TestProcessing failed: $_" }
    $global:ErrorActionPreference = $SavedErrorActionPreference
}

Describe "Process-Cube" -Tag 'Integration', 'SSAS', 'Round3' -Skip:$skipIntegration {
    Context "Publish and Process Cube" {
        It "Publish and Process Cube" {
            $CubeDatabase = "TestProcessing";

            { Publish-Cube -AsDatabasePath $Settings.AsDatabasePath1200 -Server $Settings.Server -CubeDatabase $CubeDatabase } | Should -Not -Throw;
            { Update-TabularCubeDataSource -Server $Settings.Server -CubeDatabase $CubeDatabase -SourceSqlServer $Settings.SourceSqlServer -SourceSqlDatabase $Settings.SourceSqlDatabase -ImpersonationMode ImpersonateServiceAccount } | Should -Not -Throw;
            { Invoke-ProcessTabularCubeDatabase -Server $Settings.Server -CubeDatabase $CubeDatabase -RefreshType Full } | Should -Not -Throw;
        }
    }
}
