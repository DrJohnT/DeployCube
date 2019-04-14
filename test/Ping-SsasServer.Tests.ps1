$ModulePath = Split-Path -Parent $MyInvocation.MyCommand.Path;
$ModulePath = Resolve-Path "$ModulePath\..\DeployCube\DeployCube.psd1";
import-Module -Name $ModulePath;

Describe "Ping-SsasServer" {
    Context "Testing Inputs" {
        It "Should have Server as a mandatory parameter" {
            (Get-Command Ping-SsasServer).Parameters['Server'].Attributes.mandatory | Should -Be $true
        }
        It "Empty server" {
            { Ping-SsasServer -Server "" } | Should Throw;
        }
        It "Null server" {
            { Ping-SsasServer -Server $null } | Should Throw;
        }

    }

    Context "Checking Inputs" {
        It "Invalid server" {
            Ping-SsasServer -Server "InvalidServer"
            #( Ping-SsasServer -Server "InvalidServer" ) | Should -Be $false;
          }

        It "Valid server" {
            ( Ping-SsasServer -Server "localhost" ) | Should -Be $true;
        }
    }
}

Remove-Module -Name DeployCube
