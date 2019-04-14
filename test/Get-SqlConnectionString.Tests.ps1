$CurrentFolder = Split-Path -Parent $MyInvocation.MyCommand.Path;
$ModulePath = Resolve-Path "$CurrentFolder\..\DeployCube\DeployCube.psd1";
import-Module -Name $ModulePath;

[string]$connString1 = "Provider=SQLNCLI11;Data Source=localhost;Initial Catalog=DatabaseToPublish;Integrated Security=SSPI;Persist Security Info=false";
[string]$expectedConnString1 = "Provider=SQLNCLI11;Data Source=myserver;Persist Security Info=False;Integrated Security=SSPI;Initial Catalog=mydatabase";

Describe "Get-SqlConnectionString" {

    Context "Testing Inputs" {
        It "Should have SourceSqlServer as a mandatory parameter" {
            (Get-Command Get-SqlConnectionString).Parameters['SourceSqlServer'].Attributes.mandatory | Should -Be $true;
        }
        It "Should have SourceSqlDatabase as a mandatory parameter" {
            (Get-Command Get-SqlConnectionString).Parameters['SourceSqlDatabase'].Attributes.mandatory | Should -Be $true;
        }
        It "Should have ExistingConnectionString as an mandatory parameter" {
            (Get-Command Get-SqlConnectionString).Parameters['ExistingConnectionString'].Attributes.mandatory | Should -Be $true;
        }

    }

    Context "Should return correct connection strings" {
        It "Should return correct connection string 1" {
            ( Get-SqlConnectionString -SourceSqlServer "myserver" -SourceSqlDatabase "mydatabase" -ExistingConnectionString $connString1 ) | Should -Be $expectedConnString1;
        }
    }

}

Remove-Module -Name DeployCube