$ModulePath = Split-Path -Parent $MyInvocation.MyCommand.Path;
$ModulePath = Resolve-Path "$ModulePath\..\DeployCube\DeployCube.psd1";
import-Module -Name $ModulePath;

Describe "Ping-SsasServer" {
    Context "Testing Inputs" {
        It "Should have ServerName as a mandatory parameter" {
            (Get-Command Ping-SsasServer).Parameters['ServerName'].Attributes.mandatory | Should -Be $true
        }
        It "Empty server" {
            { Ping-SsasServer -ServerName "" } | Should Throw;
        }
        It "Null server" {
            { Ping-SsasServer -ServerName $null } | Should Throw;
        }

    }

    Context "Checking Inputs" {
        It "Invalid server" {
            Ping-SsasServer -ServerName "InvalidServer"
            #( Ping-SsasServer -ServerName "InvalidServer" ) | Should -Be $false;
          }

        It "Valid server" {
            ( Ping-SsasServer -ServerName "localhost" ) | Should -Be $true;
        }
    }
}

Remove-Module -Name DeployCube
