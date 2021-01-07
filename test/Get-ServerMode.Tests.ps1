BeforeAll { 
    $ModulePath = Split-Path -Parent $PSScriptRoot;
    $ModulePath = Resolve-Path "$ModulePath\DeployCube\DeployCube.psd1";
    import-Module -Name $ModulePath;
}

Describe "Get-ServerMode" -Tag "Round1"  {
    Context "Testing Inputs" {
        It "Should have Server as a mandatory parameter" {
            (Get-Command Get-ServerMode).Parameters['Server'].Attributes.mandatory | Should -BeTrue;
        }
        It "Empty server" {
            { Get-ServerMode -Server "" } | Should -Throw;
        }
        It "Null server" {
            { Get-ServerMode -Server $null } | Should -Throw;
        }

    }

    Context "Checking Inputs" {
        It "Invalid server" {
            { Get-ServerMode -Server "InvalidServer" } | Should -Throw;
          }

        It "Valid server" {
            ( Get-ServerMode -Server "localhost" ) | Should -Be "Tabular";
        }


    }
}

AfterAll {
    Remove-Module -Name DeployCube
}
