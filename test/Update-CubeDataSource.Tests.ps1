$CurrentFolder = Split-Path -Parent $MyInvocation.MyCommand.Path;
$ModulePath = Resolve-Path "$CurrentFolder\..\DeployCube\DeployCube.psd1";
import-Module -Name $ModulePath;

Describe "Update-CubeDataSource" {
    Context "Testing Inputs" {
        It "Should have Server as a mandatory parameter" {
            (Get-Command Update-CubeDataSource).Parameters['Server'].Attributes.mandatory | Should -Be $true
        }
        It "Should have CubeDatabase as a mandatory parameter" {
            (Get-Command Update-CubeDataSource).Parameters['CubeDatabase'].Attributes.mandatory | Should -Be $true
        }
        It "Should have SourceSqlServer as a mandatory parameter" {
            (Get-Command Update-CubeDataSource).Parameters['SourceSqlServer'].Attributes.mandatory | Should -Be $true
        }
        It "Should have SourceSqlDatabase as a mandatory parameter" {
            (Get-Command Update-CubeDataSource).Parameters['SourceSqlDatabase'].Attributes.mandatory | Should -Be $true
        }
        It "Should have ImpersonationMode as a mandatory parameter" {
            (Get-Command Update-CubeDataSource).Parameters['ImpersonationMode'].Attributes.mandatory | Should -Be $true
        }
        It "Should have ImpersonationAccount as a optional parameter" {
            (Get-Command Update-CubeDataSource).Parameters['ImpersonationAccount'].Attributes.mandatory | Should -Be $false
        }
        It "Should have ImpersonationPassword as a optional parameter" {
            (Get-Command Update-CubeDataSource).Parameters['ImpersonationPassword'].Attributes.mandatory | Should -Be $false
        }


        It "Empty server" {
            { Update-CubeDataSource -Server ""  -CubeDatabase "MyCube" -SourceSqlServer "localhost" -SourceSqlDatabase 'MyDB' -ImpersonationMode 'ImpersonateServiceAccount' } | Should Throw;
        }
        It "Null server" {
            { Update-CubeDataSource -Server $null  -CubeDatabase "MyCube" -SourceSqlServer "localhost" -SourceSqlDatabase 'MyDB' -ImpersonationMode 'ImpersonateServiceAccount' } | Should Throw;
        }
        It "Empty database" {
            { Update-CubeDataSource -Server "localhost"  -CubeDatabase "" -SourceSqlServer "localhost" -SourceSqlDatabase 'MyDB' -ImpersonationMode 'ImpersonateServiceAccount' } | Should Throw;
        }
        It "Null database" {
            { Update-CubeDataSource -Server 'localhost'  -CubeDatabase $null -SourceSqlServer "localhost" -SourceSqlDatabase 'MyDB' -ImpersonationMode 'ImpersonateServiceAccount' } | Should Throw;
        }
        It "Empty SourceSqlServer" {
            { Update-CubeDataSource -Server 'localhost' -CubeDatabase "master" -SourceSqlServer "" -SourceSqlDatabase 'MyDB' -ImpersonationMode 'ImpersonateServiceAccount'} | Should Throw;
        }
        It "Null SourceSqlServer" {
            { Update-CubeDataSource -Server 'localhost' -CubeDatabase "master" -SourceSqlServer $null -SourceSqlDatabase 'MyDB' -ImpersonationMode 'ImpersonateServiceAccount'} | Should Throw;
        }
    }

    Context "Main Tests" {
        It "Invalid server" {
            { Update-CubeDataSource -Server 'InvalidServer' -CubeDatabase "CubeToPublish" -SourceSqlServer "localhost" -SourceSqlDatabase 'DatabaseToPublish' -ImpersonationMode 'ImpersonateServiceAccount'} | Should Throw;
        }

        It "Valid server and invalid CubeDatabase" {
            { Update-CubeDataSource -Server 'localhost' -CubeDatabase "TrashInput" -SourceSqlServer "localhost" -SourceSqlDatabase 'DatabaseToPublish' -ImpersonationMode 'ImpersonateServiceAccount'} | Should Throw;
        }


    }
}

Remove-Module -Name DeployCube