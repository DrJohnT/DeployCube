$ModulePath = Split-Path -Parent $MyInvocation.MyCommand.Path;
$ModulePath = Resolve-Path "$ModulePath\..\DeployCube\DeployCube.psd1";
Import-Module -Name $ModulePath;

Describe "Unpublish-Cube" {
    Context "Testing Inputs" {
        It "Should have ServerName as a mandatory parameter" {
            (Get-Command Unpublish-Cube).Parameters['ServerName'].Attributes.mandatory | Should -Be $true
        }
        It "Should have DatabaseName as a mandatory parameter" {
            (Get-Command Unpublish-Cube).Parameters['DatabaseName'].Attributes.mandatory | Should -Be $true
        }
        It "Empty server" {
            { Unpublish-Cube -ServerName ""  -DatabaseName "master" } | Should Throw;
        }
        It "Null server" {
            { Unpublish-Cube -ServerName $null  -DatabaseName "master" } | Should Throw;
        }
        It "Empty database" {
            { Unpublish-Cube -ServerName "localhost"  -DatabaseName "" } | Should Throw;
        }
        It "Null database" {
            { Unpublish-Cube -ServerName "localhost"  -DatabaseName $null } | Should Throw;
        }
    }

    Context "Testing Inputs for Alias Drop-Cube" {
        It "Should have ServerName as a mandatory parameter" {
            (Get-Command Drop-Cube).Parameters['ServerName'].Attributes.mandatory | Should -Be $true
        }
        It "Should have DatabaseName as a mandatory parameter" {
            (Get-Command Drop-Cube).Parameters['DatabaseName'].Attributes.mandatory | Should -Be $true
        }
        It "Empty server" {
            { Drop-Cube -ServerName ""  -DatabaseName "master" } | Should Throw;
        }
        It "Null server" {
            { Drop-Cube -ServerName $null  -DatabaseName "master" } | Should Throw;
        }
        It "Empty database" {
            { Drop-Cube -ServerName "localhost"  -DatabaseName "" } | Should Throw;
        }
        It "Null database" {
            { Drop-Cube -ServerName "localhost"  -DatabaseName $null } | Should Throw;
        }
    }

    Context "Main Tests" {
        It "Invalid server" {
            { Unpublish-Cube -ServerName "InvalidServer" -DatabaseName "CubeToPublish" } | Should Throw;
        }

        It "Valid server and invalid database" {
            { Unpublish-Cube -ServerName "localhost" -DatabaseName "InvalidDatabase" } | Should Not Throw;
        }


    }
}

Remove-Module -Name DeployCube
