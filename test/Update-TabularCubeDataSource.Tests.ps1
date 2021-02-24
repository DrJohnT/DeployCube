BeforeAll { 
    $CurrentFolder = Split-Path -Parent $PSScriptRoot;
    $ModulePath = Resolve-Path "$CurrentFolder\DeployCube\DeployCube.psd1";
    Import-Module -Name $ModulePath;
}

Describe "Update-TabularCubeDataSource" -Tag "Round2" {
    
    Context "Testing Inputs" {
        It "Should have Server as a mandatory parameter" {
            (Get-Command Update-TabularCubeDataSource).Parameters['Server'].Attributes.mandatory | Should -BeTrue;
        }
        It "Should have CubeDatabase as a mandatory parameter" {
            (Get-Command Update-TabularCubeDataSource).Parameters['CubeDatabase'].Attributes.mandatory | Should -BeTrue;
        }
        It "Should have SourceSqlServer as a mandatory parameter" {
            (Get-Command Update-TabularCubeDataSource).Parameters['SourceSqlServer'].Attributes.mandatory | Should -BeTrue;
        }
        It "Should have SourceSqlDatabase as a mandatory parameter" {
            (Get-Command Update-TabularCubeDataSource).Parameters['SourceSqlDatabase'].Attributes.mandatory | Should -BeTrue;
        }
        It "Should have ImpersonationMode as a mandatory parameter" {
            (Get-Command Update-TabularCubeDataSource).Parameters['ImpersonationMode'].Attributes.mandatory | Should -BeTrue;
        }
        It "Should have ImpersonationAccount as a optional parameter" {
            (Get-Command Update-TabularCubeDataSource).Parameters['ImpersonationAccount'].Attributes.mandatory | Should -BeFalse;
        }
        It "Should have ImpersonationPwd as a optional parameter" {
            (Get-Command Update-TabularCubeDataSource).Parameters['ImpersonationPwd'].Attributes.mandatory | Should -BeFalse;
        }
        It "Should have DataSource as a optional parameter" {
            (Get-Command Update-TabularCubeDataSource).Parameters['DataSource'].Attributes.mandatory | Should -BeFalse;
        }

        It "Empty server" {
            { Update-TabularCubeDataSource -Server ""  -CubeDatabase "MyCube" -SourceSqlServer "localhost" -SourceSqlDatabase 'MyDB' -ImpersonationMode 'ImpersonateServiceAccount' } | Should -Throw;
        }
        It "Null server" {
            { Update-TabularCubeDataSource -Server $null  -CubeDatabase "MyCube" -SourceSqlServer "localhost" -SourceSqlDatabase 'MyDB' -ImpersonationMode 'ImpersonateServiceAccount' } | Should -Throw;
        }
        It "Empty database" {
            { Update-TabularCubeDataSource -Server "localhost"  -CubeDatabase "" -SourceSqlServer "localhost" -SourceSqlDatabase 'MyDB' -ImpersonationMode 'ImpersonateServiceAccount' } | Should -Throw;
        }
        It "Null database" {
            { Update-TabularCubeDataSource -Server 'localhost'  -CubeDatabase $null -SourceSqlServer "localhost" -SourceSqlDatabase 'MyDB' -ImpersonationMode 'ImpersonateServiceAccount' } | Should -Throw;
        }
        It "Empty SourceSqlServer" {
            { Update-TabularCubeDataSource -Server 'localhost' -CubeDatabase "master" -SourceSqlServer "" -SourceSqlDatabase 'MyDB' -ImpersonationMode 'ImpersonateServiceAccount'} | Should -Throw;
        }
        It "Null SourceSqlServer" {
            { Update-TabularCubeDataSource -Server 'localhost' -CubeDatabase "master" -SourceSqlServer $null -SourceSqlDatabase 'MyDB' -ImpersonationMode 'ImpersonateServiceAccount'} | Should -Throw;
        }

        It "Null SourceSqlServer" {
            { Update-TabularCubeDataSource -Server 'localhost' -CubeDatabase "master" -SourceSqlServer $null -SourceSqlDatabase 'MyDB' -ImpersonationMode 'ImpersonateServiceAccount'} | Should -Throw;
        }

        It "Null ImpersonationAccount when ImpersonationMode=ImpersonateAccount" {
            { Update-TabularCubeDataSource -Server 'localhost' -CubeDatabase "master" -SourceSqlServer $null -SourceSqlDatabase 'MyDB' -ImpersonationMode 'ImpersonateAccount' -ImpersonationAccount $null -ImpersonationPassword 'test' } | Should -Throw;
        }

        It "Null ImpersonationPwd when ImpersonationMode=ImpersonateAccount" {
            { Update-TabularCubeDataSource -Server 'localhost' -CubeDatabase "master" -SourceSqlServer $null -SourceSqlDatabase 'MyDB' -ImpersonationMode 'ImpersonateAccount' -ImpersonationAccount 'test' -ImpersonationPwd $null } | Should -Throw;
        }
    }

    Context "Invalid inputs" {
        It "PreTest Check Cube Exists 1200" {
            ( Ping-SsasDatabase -Server "localhost" -CubeDatabase "CubeAtCompatibility1200" ) | Should -BeTrue;
        }
        It "PreTest Check Cube Exists 1500" {
            ( Ping-SsasDatabase -Server "localhost" -CubeDatabase "CubeAtCompatibility1500" ) | Should -BeTrue;
        }

        It "Invalid server" {
            { Update-TabularCubeDataSource -Server 'InvalidServer' -CubeDatabase "CubeAtCompatibility1200" -SourceSqlServer "localhost" -SourceSqlDatabase 'DatabaseToPublish' -ImpersonationMode 'ImpersonateServiceAccount'} | Should -Throw;
        }

        It "Valid server and invalid CubeDatabase" {
            { Update-TabularCubeDataSource -Server 'localhost' -CubeDatabase "TrashInput" -SourceSqlServer "localhost" -SourceSqlDatabase 'DatabaseToPublish' -ImpersonationMode 'ImpersonateServiceAccount'} | Should -Throw;
        }

        It "Invalid DataSource 1200" {
            { Update-TabularCubeDataSource -Server "localhost" -CubeDatabase "CubeAtCompatibility1200" -SourceSqlServer "localhost" -SourceSqlDatabase 'DatabaseToPublish' -ImpersonationMode 'ImpersonateAccount' -ImpersonationAccount 'xx\sd' -ImpersonationPwd 'OSzkzmdT' -DataSource "InvalidDataSource" } | Should -Throw;
        }

        It "Invalid DataSource 1500" {
            { Update-TabularCubeDataSource -Server "localhost" -CubeDatabase "CubeAtCompatibility1500" -SourceSqlServer "localhost" -SourceSqlDatabase 'DatabaseToPublish' -ImpersonationMode 'ImpersonateAccount' -ImpersonationAccount 'xx\yy' -ImpersonationPwd 'mypasswrd' -DataSource "InvalidDataSource" } | Should -Throw;
        }
    }

    Context "Valid inputs" {
        
        It "PreTest Check Cube Exists 1200" {
            ( Ping-SsasDatabase -Server "localhost" -CubeDatabase "CubeAtCompatibility1200" ) | Should -BeTrue;
        }
        It "PreTest Check Cube Exists 1500" {
            ( Ping-SsasDatabase -Server "localhost" -CubeDatabase "CubeAtCompatibility1500" ) | Should -BeTrue;
        }

        It "Valid inputs - ImpersonateServiceAccount 1200" {
            ( Update-TabularCubeDataSource -Server "localhost" -CubeDatabase "CubeAtCompatibility1200" -SourceSqlServer "localhost" -SourceSqlDatabase 'DatabaseToPublish' -ImpersonationMode 'ImpersonateServiceAccount' )[1] | Should -BeTrue;
        }
    
        It "Valid inputs - ImpersonateAccount 1200" {
            ( Update-TabularCubeDataSource -Server "localhost" -CubeDatabase "CubeAtCompatibility1200" -SourceSqlServer "localhost" -SourceSqlDatabase 'DatabaseToPublish' -ImpersonationMode 'ImpersonateAccount' -ImpersonationAccount 'xx\sd' -ImpersonationPwd 'OSzkzmdT' )[1] | Should -BeTrue;
        }
    
        It "Valid inputs - ImpersonateAccount using alias ImpersonationPassword 1200" {
            ( Update-TabularCubeDataSource -Server "localhost" -CubeDatabase "CubeAtCompatibility1200" -SourceSqlServer "localhost" -SourceSqlDatabase 'DatabaseToPublish' -ImpersonationMode 'ImpersonateAccount' -ImpersonationAccount 'xx\sd' -ImpersonationPassword 'OSzkzmdT' )[1] | Should -BeTrue;
        }

        It "Valid inputs - ImpersonateAccount 1500" {
            ( Update-TabularCubeDataSource -Server "localhost" -CubeDatabase "CubeAtCompatibility1500" -SourceSqlServer "localhost" -SourceSqlDatabase 'DatabaseToPublish' -ImpersonationMode 'ImpersonateAccount' -ImpersonationAccount 'xx\yy' -ImpersonationPassword 'mypasswrd')[1] | Should -BeTrue;
        }

        It "Valid inputs - UsernamePassword 1500" {
            ( Update-TabularCubeDataSource -Server "localhost" -CubeDatabase "CubeAtCompatibility1500" -SourceSqlServer "localhost" -SourceSqlDatabase 'DatabaseToPublish' -ImpersonationMode 'UsernamePassword' -ImpersonationAccount 'ea' -ImpersonationPassword 'open' )[1] | Should -BeTrue;
        }

        It "Valid inputs - ImpersonateAccount 1200 DataSource" {
            ( Update-TabularCubeDataSource -Server "localhost" -CubeDatabase "CubeAtCompatibility1200" -SourceSqlServer "localhost" -SourceSqlDatabase 'DatabaseToPublish' -ImpersonationMode 'ImpersonateAccount' -ImpersonationAccount 'xx\sd' -ImpersonationPwd 'OSzkzmdT' -DataSource "DatabaseToPublish")[1] | Should -BeTrue;
        }

        It "Valid inputs - ImpersonateAccount 1500 DataSource" {
            ( Update-TabularCubeDataSource -Server "localhost" -CubeDatabase "CubeAtCompatibility1500" -SourceSqlServer "localhost" -SourceSqlDatabase 'DatabaseToPublish' -ImpersonationMode 'ImpersonateAccount' -ImpersonationAccount 'xx\yy' -ImpersonationPwd 'mypasswrd' -DataSource "SQL/localhost;DatabaseToPublish")[1] | Should -BeTrue;
        }

        It "Valid inputs - ImpersonateAccount 1200 DataSource Empty" {
            ( Update-TabularCubeDataSource -Server "localhost" -CubeDatabase "CubeAtCompatibility1200" -SourceSqlServer "localhost" -SourceSqlDatabase 'DatabaseToPublish' -ImpersonationMode 'ImpersonateAccount' -ImpersonationAccount 'xx\sd' -ImpersonationPwd 'OSzkzmdT' -DataSource "")[1] | Should -BeTrue;
        }

        It "Valid inputs - ImpersonateAccount 1500 DataSource Empty" {
            ( Update-TabularCubeDataSource -Server "localhost" -CubeDatabase "CubeAtCompatibility1500" -SourceSqlServer "localhost" -SourceSqlDatabase 'DatabaseToPublish' -ImpersonationMode 'ImpersonateAccount' -ImpersonationAccount 'xx\yy' -ImpersonationPwd 'mypasswrd' -DataSource "")[1] | Should -BeTrue;
        }
    }
    
}

AfterAll {
    Remove-Module -Name DeployCube;
}