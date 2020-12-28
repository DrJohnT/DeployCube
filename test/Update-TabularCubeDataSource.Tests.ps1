BeforeAll { 
    $CurrentFolder = Split-Path -Parent $PSScriptRoot;
    $ModulePath = Resolve-Path "$CurrentFolder\DeployCube\DeployCube.psd1";
    import-Module -Name $ModulePath;
}

Describe "Update-TabularCubeDataSource" -Tag "Round2" {
    Context "Testing Inputs" {
        It "Should have Server as a mandatory parameter" {
            (Get-Command Update-TabularCubeDataSource).Parameters['Server'].Attributes.mandatory | Should -Be $true
        }
        It "Should have CubeDatabase as a mandatory parameter" {
            (Get-Command Update-TabularCubeDataSource).Parameters['CubeDatabase'].Attributes.mandatory | Should -Be $true
        }
        It "Should have SourceSqlServer as a mandatory parameter" {
            (Get-Command Update-TabularCubeDataSource).Parameters['SourceSqlServer'].Attributes.mandatory | Should -Be $true
        }
        It "Should have SourceSqlDatabase as a mandatory parameter" {
            (Get-Command Update-TabularCubeDataSource).Parameters['SourceSqlDatabase'].Attributes.mandatory | Should -Be $true
        }
        It "Should have ImpersonationMode as a mandatory parameter" {
            (Get-Command Update-TabularCubeDataSource).Parameters['ImpersonationMode'].Attributes.mandatory | Should -Be $true
        }
        It "Should have ImpersonationAccount as a optional parameter" {
            (Get-Command Update-TabularCubeDataSource).Parameters['ImpersonationAccount'].Attributes.mandatory | Should -Be $false
        }
        It "Should have ImpersonationPwd as a optional parameter" {
            (Get-Command Update-TabularCubeDataSource).Parameters['ImpersonationPwd'].Attributes.mandatory | Should -Be $false
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
        It "Invalid server" {
            { Update-TabularCubeDataSource -Server 'InvalidServer' -CubeDatabase "CubeToPublish" -SourceSqlServer "localhost" -SourceSqlDatabase 'DatabaseToPublish' -ImpersonationMode 'ImpersonateServiceAccount'} | Should -Throw;
        }

        It "Valid server and invalid CubeDatabase" {
            { Update-TabularCubeDataSource -Server 'localhost' -CubeDatabase "TrashInput" -SourceSqlServer "localhost" -SourceSqlDatabase 'DatabaseToPublish' -ImpersonationMode 'ImpersonateServiceAccount'} | Should -Throw;
        }
    }

    Context "Valid inputs" {
        It "Valid inputs - CompatibilityLevel < 1400 - ImpersonateAccount" {
            { Update-TabularCubeDataSource -Server "localhost" -CubeDatabase "CubeToPublish" -SourceSqlServer "localhost" -SourceSqlDatabase 'DatabaseToPublish' -ImpersonationMode 'ImpersonateAccount' -ImpersonationAccount 'xx\sd' -ImpersonationPwd 'OSzkzmdT' } | Should -Not -Throw;
        }

        It "Valid inputs - CompatibilityLevel < 1400 - ImpersonateServiceAccount" {
            { Update-TabularCubeDataSource -Server "localhost" -CubeDatabase "CubeToPublish" -SourceSqlServer "localhost" -SourceSqlDatabase 'DatabaseToPublish' -ImpersonationMode 'ImpersonateServiceAccount'} | Should -Not -Throw;
        }


    }
}

AfterAll {
    Remove-Module -Name DeployCube;
}