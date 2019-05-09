$CurrentFolder = Split-Path -Parent $MyInvocation.MyCommand.Path;
$ModulePath = Resolve-Path "$CurrentFolder\..\DeployCube\DeployCube.psd1";
import-Module -Name $ModulePath;

Describe "Update-TabularCubeDataSource" {
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
        It "Should have ImpersonationPassword as a optional parameter" {
            (Get-Command Update-TabularCubeDataSource).Parameters['ImpersonationPassword'].Attributes.mandatory | Should -Be $false
        }


        It "Empty server" {
            { Update-TabularCubeDataSource -Server ""  -CubeDatabase "MyCube" -SourceSqlServer "localhost" -SourceSqlDatabase 'MyDB' -ImpersonationMode 'ImpersonateServiceAccount' } | Should Throw;
        }
        It "Null server" {
            { Update-TabularCubeDataSource -Server $null  -CubeDatabase "MyCube" -SourceSqlServer "localhost" -SourceSqlDatabase 'MyDB' -ImpersonationMode 'ImpersonateServiceAccount' } | Should Throw;
        }
        It "Empty database" {
            { Update-TabularCubeDataSource -Server "localhost"  -CubeDatabase "" -SourceSqlServer "localhost" -SourceSqlDatabase 'MyDB' -ImpersonationMode 'ImpersonateServiceAccount' } | Should Throw;
        }
        It "Null database" {
            { Update-TabularCubeDataSource -Server 'localhost'  -CubeDatabase $null -SourceSqlServer "localhost" -SourceSqlDatabase 'MyDB' -ImpersonationMode 'ImpersonateServiceAccount' } | Should Throw;
        }
        It "Empty SourceSqlServer" {
            { Update-TabularCubeDataSource -Server 'localhost' -CubeDatabase "master" -SourceSqlServer "" -SourceSqlDatabase 'MyDB' -ImpersonationMode 'ImpersonateServiceAccount'} | Should Throw;
        }
        It "Null SourceSqlServer" {
            { Update-TabularCubeDataSource -Server 'localhost' -CubeDatabase "master" -SourceSqlServer $null -SourceSqlDatabase 'MyDB' -ImpersonationMode 'ImpersonateServiceAccount'} | Should Throw;
        }

        It "Null SourceSqlServer" {
            { Update-TabularCubeDataSource -Server 'localhost' -CubeDatabase "master" -SourceSqlServer $null -SourceSqlDatabase 'MyDB' -ImpersonationMode 'ImpersonateServiceAccount'} | Should Throw;
        }

        It "Null ImpersonationAccount when ImpersonationMode=ImpersonateAccount" {
            { Update-TabularCubeDataSource -Server 'localhost' -CubeDatabase "master" -SourceSqlServer $null -SourceSqlDatabase 'MyDB' -ImpersonationMode 'ImpersonateAccount' -ImpersonationAccount $null -ImpersonationPassword 'test' } | Should Throw;
        }

        It "Null ImpersonationPassword when ImpersonationMode=ImpersonateAccount" {
            { Update-TabularCubeDataSource -Server 'localhost' -CubeDatabase "master" -SourceSqlServer $null -SourceSqlDatabase 'MyDB' -ImpersonationMode 'ImpersonateAccount' -ImpersonationAccount 'test' -ImpersonationPassword $null } | Should Throw;
        }
    }

    Context "Invalid inputs" {
        It "Invalid server" {
            { Update-TabularCubeDataSource -Server 'InvalidServer' -CubeDatabase "CubeToPublish" -SourceSqlServer "localhost" -SourceSqlDatabase 'DatabaseToPublish' -ImpersonationMode 'ImpersonateServiceAccount'} | Should Throw;
        }

        It "Valid server and invalid CubeDatabase" {
            { Update-TabularCubeDataSource -Server 'localhost' -CubeDatabase "TrashInput" -SourceSqlServer "localhost" -SourceSqlDatabase 'DatabaseToPublish' -ImpersonationMode 'ImpersonateServiceAccount'} | Should Throw;
        }
    }

    Context "Valid inputs" {
        It "Valid inputs - CompatibilityLevel < 1400 - ImpersonateAccount" {
            { Update-TabularCubeDataSource -Server 'localhost' -CubeDatabase "CubeToPublish" -SourceSqlServer "localhost" -SourceSqlDatabase 'DatabaseToPublish' -ImpersonationMode 'ImpersonateAccount' -ImpersonationAccount 'qregroup\QReSvcSWBuild' -ImpersonationPassword 'OSzkzmvdVC-n9+BT' } | Should not Throw;
        }

        It "Valid inputs - CompatibilityLevel < 1400 - ImpersonateServiceAccount" {
            { Update-TabularCubeDataSource -Server 'localhost' -CubeDatabase "CubeToPublish" -SourceSqlServer "localhost" -SourceSqlDatabase 'DatabaseToPublish' -ImpersonationMode 'ImpersonateServiceAccount'} | Should Not Throw;
        }


    }
}

Remove-Module -Name DeployCube