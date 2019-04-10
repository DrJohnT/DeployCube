$CurrentFolder = Split-Path -Parent $MyInvocation.MyCommand.Path;
$ModulePath = Resolve-Path "$CurrentFolder\..\DeployCube\DeployCube.psd1";
import-Module -Name $ModulePath;

[string]$connString1 = "Provider=SQLNCLI11;Data Source=localhost;Initial Catalog=DatabaseToPublish;Integrated Security=SSPI;Persist Security Info=false";
[string]$expectedConnString1 = "Provider=SQLNCLI11;Data Source=myserver;Persist Security Info=False;Integrated Security=SSPI;Initial Catalog=mydatabase";

Describe "Get-SsasSourceConnectionString" {

    Context "Testing Inputs" {
        It "Should have SourceServerName as a mandatory parameter" {
            (Get-Command Get-SsasSourceConnectionString).Parameters['SourceServerName'].Attributes.mandatory | Should -Be $true;
        }
        It "Should have SourceDatabaseName as a mandatory parameter" {
            (Get-Command Get-SsasSourceConnectionString).Parameters['SourceDatabaseName'].Attributes.mandatory | Should -Be $true;
        }
        It "Should have ExistingConnectionString as an mandatory parameter" {
            (Get-Command Get-SsasSourceConnectionString).Parameters['ExistingConnectionString'].Attributes.mandatory | Should -Be $true;
        }

    }

    Context "Should return correct connection strings" {
        It "Should return correct connection string 1" {
            $return =  Get-SsasSourceConnectionString -SourceDatabaseName "mydatabase" -SourceServerName "myserver" -ExistingConnectionString $connString1
            Write-Host $return
            $return | Should -Be $expectedConnString1;
        }
    }

}

Remove-Module -Name DeployCube