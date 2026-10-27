# Parameter validation and mocked TMSL generation tests live in test/Unit/Update-TabularCubeDataSource.Tests.ps1.
BeforeDiscovery {
    . (Join-Path -Path (Split-Path -Parent $PSScriptRoot) -ChildPath 'TestHelpers.ps1')
    $skipIntegration = -not (Test-DeployCubeIntegrationEnabled)
}

BeforeAll {
    . (Join-Path -Path (Split-Path -Parent $PSScriptRoot) -ChildPath 'TestHelpers.ps1')
    Import-DeployCubeForTest
    $Settings = Get-DeployCubeIntegrationSettings
    $Server = $Settings.Server
    $SourceSqlServer = $Settings.SourceSqlServer
    $SourceSqlDatabase = $Settings.SourceSqlDatabase
}

Describe "Update-TabularCubeDataSource" -Tag 'Integration', 'SSAS', 'Round2' -Skip:$skipIntegration {
    BeforeAll {
        Initialize-DeployCubeIntegrationBaseline
    }

    Context "Invalid inputs" {
        It "PreTest Check Cube Exists 1200" {
            ( Ping-SsasDatabase -Server $Server -CubeDatabase "CubeAtCompatibility1200" ) | Should -BeTrue;
        }
        It "PreTest Check Cube Exists 1500" {
            ( Ping-SsasDatabase -Server $Server -CubeDatabase "CubeAtCompatibility1500" ) | Should -BeTrue;
        }

        It "Invalid server" {
            { Update-TabularCubeDataSource -Server 'InvalidServer' -CubeDatabase "CubeAtCompatibility1200" -SourceSqlServer $SourceSqlServer -SourceSqlDatabase $SourceSqlDatabase -ImpersonationMode 'ImpersonateServiceAccount'} | Should -Throw;
        }

        It "Valid server and invalid CubeDatabase" {
            { Update-TabularCubeDataSource -Server $Server -CubeDatabase "TrashInput" -SourceSqlServer $SourceSqlServer -SourceSqlDatabase $SourceSqlDatabase -ImpersonationMode 'ImpersonateServiceAccount'} | Should -Throw;
        }

        It "Invalid DataSource 1200" {
            { Update-TabularCubeDataSource -Server $Server -CubeDatabase "CubeAtCompatibility1200" -SourceSqlServer $SourceSqlServer -SourceSqlDatabase $SourceSqlDatabase -ImpersonationMode 'ImpersonateAccount' -ImpersonationAccount 'xx\sd' -ImpersonationPwd 'OSzkzmdT' -DataSource "InvalidDataSource" } | Should -Throw;
        }

        It "Invalid DataSource 1500" {
            { Update-TabularCubeDataSource -Server $Server -CubeDatabase "CubeAtCompatibility1500" -SourceSqlServer $SourceSqlServer -SourceSqlDatabase $SourceSqlDatabase -ImpersonationMode 'ImpersonateAccount' -ImpersonationAccount 'xx\yy' -ImpersonationPwd 'mypasswrd' -DataSource "InvalidDataSource" } | Should -Throw;
        }

        It "Invalid CommandTimeout 1200" {
            { Update-TabularCubeDataSource -Server $Server -CubeDatabase "CubeAtCompatibility1200" -SourceSqlServer $SourceSqlServer -SourceSqlDatabase $SourceSqlDatabase -ImpersonationMode 'ImpersonateAccount' -ImpersonationAccount 'xx\yy' -ImpersonationPwd 'mypasswrd' -DataSource "DatabaseToPublish" -CommandTimeout 0 } | Should -Throw;
        }

        It "Invalid CommandTimeout 1500" {
            { Update-TabularCubeDataSource -Server $Server -CubeDatabase "CubeAtCompatibility1500" -SourceSqlServer $SourceSqlServer -SourceSqlDatabase $SourceSqlDatabase -ImpersonationMode 'ImpersonateAccount' -ImpersonationAccount 'xx\yy' -ImpersonationPwd 'mypasswrd' -DataSource "SQL/localhost;DatabaseToPublish" -CommandTimeout 0 } | Should -Throw;
        }
    }

    Context "Valid inputs" {
        It "PreTest Check Cube Exists 1200" {
            ( Ping-SsasDatabase -Server $Server -CubeDatabase "CubeAtCompatibility1200" ) | Should -BeTrue;
        }
        It "PreTest Check Cube Exists 1500" {
            ( Ping-SsasDatabase -Server $Server -CubeDatabase "CubeAtCompatibility1500" ) | Should -BeTrue;
        }

        It "Valid inputs - ImpersonateServiceAccount 1200" {
            ( Update-TabularCubeDataSource -Server $Server -CubeDatabase "CubeAtCompatibility1200" -SourceSqlServer $SourceSqlServer -SourceSqlDatabase $SourceSqlDatabase -ImpersonationMode 'ImpersonateServiceAccount' )[1] | Should -BeTrue;
        }

        It "Valid inputs - ImpersonateAccount 1200" {
            ( Update-TabularCubeDataSource -Server $Server -CubeDatabase "CubeAtCompatibility1200" -SourceSqlServer $SourceSqlServer -SourceSqlDatabase $SourceSqlDatabase -ImpersonationMode 'ImpersonateAccount' -ImpersonationAccount 'xx\sd' -ImpersonationPwd 'OSzkzmdT' )[1] | Should -BeTrue;
        }

        It "Valid inputs - ImpersonateAccount using alias ImpersonationPassword 1200" {
            ( Update-TabularCubeDataSource -Server $Server -CubeDatabase "CubeAtCompatibility1200" -SourceSqlServer $SourceSqlServer -SourceSqlDatabase $SourceSqlDatabase -ImpersonationMode 'ImpersonateAccount' -ImpersonationAccount 'xx\sd' -ImpersonationPassword 'OSzkzmdT' )[1] | Should -BeTrue;
        }

        It "Valid inputs - ImpersonateAccount 1500" {
            ( Update-TabularCubeDataSource -Server $Server -CubeDatabase "CubeAtCompatibility1500" -SourceSqlServer $SourceSqlServer -SourceSqlDatabase $SourceSqlDatabase -ImpersonationMode 'ImpersonateAccount' -ImpersonationAccount 'xx\yy' -ImpersonationPassword 'mypasswrd')[1] | Should -BeTrue;
        }

        It "Valid inputs - UsernamePassword 1500" {
            ( Update-TabularCubeDataSource -Server $Server -CubeDatabase "CubeAtCompatibility1500" -SourceSqlServer $SourceSqlServer -SourceSqlDatabase $SourceSqlDatabase -ImpersonationMode 'UsernamePassword' -ImpersonationAccount 'ea' -ImpersonationPassword 'open' )[1] | Should -BeTrue;
        }

        It "Valid inputs - ImpersonateAccount 1200 DataSource" {
            ( Update-TabularCubeDataSource -Server $Server -CubeDatabase "CubeAtCompatibility1200" -SourceSqlServer $SourceSqlServer -SourceSqlDatabase $SourceSqlDatabase -ImpersonationMode 'ImpersonateAccount' -ImpersonationAccount 'xx\sd' -ImpersonationPwd 'OSzkzmdT' -DataSource "DatabaseToPublish")[1] | Should -BeTrue;
        }

        It "Valid inputs - ImpersonateAccount 1500 DataSource" {
            ( Update-TabularCubeDataSource -Server $Server -CubeDatabase "CubeAtCompatibility1500" -SourceSqlServer $SourceSqlServer -SourceSqlDatabase $SourceSqlDatabase -ImpersonationMode 'ImpersonateAccount' -ImpersonationAccount 'xx\yy' -ImpersonationPwd 'mypasswrd' -DataSource "SQL/localhost;DatabaseToPublish")[1] | Should -BeTrue;
        }

        It "Valid inputs - ImpersonateAccount 1200 DataSource Empty" {
            ( Update-TabularCubeDataSource -Server $Server -CubeDatabase "CubeAtCompatibility1200" -SourceSqlServer $SourceSqlServer -SourceSqlDatabase $SourceSqlDatabase -ImpersonationMode 'ImpersonateAccount' -ImpersonationAccount 'xx\sd' -ImpersonationPwd 'OSzkzmdT' -DataSource "")[1] | Should -BeTrue;
        }

        It "Valid inputs - ImpersonateAccount 1500 DataSource Empty" {
            ( Update-TabularCubeDataSource -Server $Server -CubeDatabase "CubeAtCompatibility1500" -SourceSqlServer $SourceSqlServer -SourceSqlDatabase $SourceSqlDatabase -ImpersonationMode 'ImpersonateAccount' -ImpersonationAccount 'xx\yy' -ImpersonationPwd 'mypasswrd' -DataSource "")[1] | Should -BeTrue;
        }

        It "Valid inputs - ImpersonateAccount 1200 CommandTimeout Empty" {
            ( Update-TabularCubeDataSource -Server $Server -CubeDatabase "CubeAtCompatibility1200" -SourceSqlServer $SourceSqlServer -SourceSqlDatabase $SourceSqlDatabase -ImpersonationMode 'ImpersonateAccount' -ImpersonationAccount 'xx\yy' -ImpersonationPwd 'mypasswrd' -DataSource "DatabaseToPublish")[1] | Should -BeTrue;
        }

        It "Valid inputs - ImpersonateAccount 1200 CommandTimeout" {
            ( Update-TabularCubeDataSource -Server $Server -CubeDatabase "CubeAtCompatibility1200" -SourceSqlServer $SourceSqlServer -SourceSqlDatabase $SourceSqlDatabase -ImpersonationMode 'ImpersonateAccount' -ImpersonationAccount 'xx\yy' -ImpersonationPwd 'mypasswrd' -DataSource "DatabaseToPublish" -CommandTimeout 60)[1] | Should -BeTrue;
        }

        It "Valid inputs - ImpersonateAccount 1500 CommandTimeout Empty" {
            ( Update-TabularCubeDataSource -Server $Server -CubeDatabase "CubeAtCompatibility1500" -SourceSqlServer $SourceSqlServer -SourceSqlDatabase $SourceSqlDatabase -ImpersonationMode 'ImpersonateAccount' -ImpersonationAccount 'xx\yy' -ImpersonationPwd 'mypasswrd' -DataSource "DatabaseToPublish")[1] | Should -BeTrue;
        }

        It "Valid inputs - ImpersonateAccount 1500 CommandTimeout" {
            ( Update-TabularCubeDataSource -Server $Server -CubeDatabase "CubeAtCompatibility1500" -SourceSqlServer $SourceSqlServer -SourceSqlDatabase $SourceSqlDatabase -ImpersonationMode 'ImpersonateAccount' -ImpersonationAccount 'xx\yy' -ImpersonationPwd 'mypasswrd' -DataSource "SQL/localhost;DatabaseToPublish" -CommandTimeout 60)[1] | Should -BeTrue;
        }
    }
}
