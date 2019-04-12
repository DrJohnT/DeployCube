$ModulePath = Split-Path -Parent $MyInvocation.MyCommand.Path;
$ModulePath = Resolve-Path "$ModulePath\..\DeployCube\DeployCube.psd1";
import-Module -Name $ModulePath;

Describe "Ping-SsasDatabase" {
    Context "Testing Inputs" {
        It "Should have ServerName as a mandatory parameter" {
            (Get-Command Ping-SsasDatabase).Parameters['ServerName'].Attributes.mandatory | Should -Be $true
        }
        It "Should have DatabaseName as a mandatory parameter" {
            (Get-Command Ping-SsasDatabase).Parameters['DatabaseName'].Attributes.mandatory | Should -Be $true
        }
        It "Empty server" {
            { Ping-SsasDatabase -ServerName ""  -DatabaseName "master" } | Should Throw;
        }
        It "Null server" {
            { Ping-SsasDatabase -ServerName $null  -DatabaseName "master" } | Should Throw;
        }
        It "Empty database" {
            { Ping-SsasDatabase -ServerName "localhost"  -DatabaseName "" } | Should Throw;
        }
        It "Null database" {
            { Ping-SsasDatabase -ServerName "localhost"  -DatabaseName $null } | Should Throw;
        }
    }

    Context "Main Tests" {
        It "Invalid server" {
            ( Ping-SsasDatabase -ServerName "InvalidServer" -DatabaseName "KernelCube" ) | Should -Be $false;
        }

        It "Valid server and invalid database" {
            ( Ping-SsasDatabase -ServerName "localhost" -DatabaseName "InvalidDatabase" ) | Should -Be $false;
        }

        It "Valid server and database" {
            ( Ping-SsasDatabase -ServerName "localhost" -DatabaseName "KernelCube" ) | Should -Be $true;
        }
    }
}

Remove-Module -Name DeployCube
