$ModulePath = Split-Path -Parent $MyInvocation.MyCommand.Path;
$ModulePath = Resolve-Path "$ModulePath\..\DeployCube\DeployCube.psd1";
import-Module -Name $ModulePath;

Describe "Get-ServerMode" {
    Context "Testing Inputs" {
        It "Should have Server as a mandatory parameter" {
            (Get-Command Get-ServerMode).Parameters['Server'].Attributes.mandatory | Should -Be $true
        }
        It "Empty server" {
            { Get-ServerMode -Server "" } | Should Throw;
        }
        It "Null server" {
            { Get-ServerMode -Server $null } | Should Throw;
        }

    }

    Context "Checking Inputs" {
        It "Invalid server" {
            { Get-ServerMode -Server "InvalidServer" } | Should Throw;
          }

        It "Valid server" {
            ( Get-ServerMode -Server "localhost" ) | Should -Be "Tabular";
        }

        It "Valid Tabular server" {
            ( Get-ServerMode -Server "SZRH3012.qregroup.net" ) | Should -Be "Tabular";
        }

        It "Valid Multidimentional server" {
            ( Get-ServerMode -Server "01-dev.db.qregroup.net" ) | Should -Be "Multidimensional";
        }
    }
}

Remove-Module -Name DeployCube
