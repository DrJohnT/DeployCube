BeforeAll { 
    $CurrentFolder = Split-Path -Parent $PSScriptRoot;
    $ModulePath = Resolve-Path "$CurrentFolder\DeployCube\DeployCube.psd1";
    import-Module -Name $ModulePath;
}

Describe "Ping-SsasDatabase" -Tag "Round1" {
    Context "Testing Inputs" {
        It "Should have Server as a mandatory parameter" {
            (Get-Command Ping-SsasDatabase).Parameters['Server'].Attributes.mandatory | Should -Be $true
        }
        It "Should have CubeDatabase as a mandatory parameter" {
            (Get-Command Ping-SsasDatabase).Parameters['CubeDatabase'].Attributes.mandatory | Should -Be $true
        }
        It "Empty server" {
            { Ping-SsasDatabase -Server "" -CubeDatabase "master" } | Should -Throw;
        }
        It "Null server" {
            { Ping-SsasDatabase -Server $null  -CubeDatabase "master" } | Should -Throw;
        }
        It "Empty database" {
            { Ping-SsasDatabase -Server "localhost"  -CubeDatabase "" } | Should -Throw;
        }
        It "Null database" {
            { Ping-SsasDatabase -Server "localhost"  -CubeDatabase $null } | Should -Throw;
        }
    }

    Context "Main Tests" {
        It "Invalid server" {
            { Ping-SsasDatabase -Server "InvalidServer" -CubeDatabase "CubeToPublish" } | Should -Throw;
        }

        It "Valid server and invalid database" {
            ( Ping-SsasDatabase -Server "localhost" -CubeDatabase "InvalidDatabase" ) | Should -Be $false;
        }

        It "Valid server and database" {
            ( Ping-SsasDatabase -Server "localhost" -CubeDatabase "CubeToPublish" ) | Should -Be $true;
        }
    }
}

AfterAll {
    Remove-Module -Name DeployCube
}
