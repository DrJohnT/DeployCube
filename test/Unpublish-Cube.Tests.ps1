BeforeAll { 
    $CurrentFolder = Split-Path -Parent $PSScriptRoot;
    $ModulePath = Resolve-Path "$CurrentFolder\DeployCube\DeployCube.psd1";
    import-Module -Name $ModulePath;
}

Describe "Unpublish-Cube" -Tag "Round2" {
    Context "Testing Inputs" {
        It "Should have Server as a mandatory parameter" {
            (Get-Command Unpublish-Cube).Parameters['Server'].Attributes.mandatory | Should -BeTrue;
        }
        It "Should have CubeDatabase as a mandatory parameter" {
            (Get-Command Unpublish-Cube).Parameters['CubeDatabase'].Attributes.mandatory | Should -BeTrue;
        }
        It "Empty server" {
            { Unpublish-Cube -Server ""  -CubeDatabase "master" } | Should -Throw;
        }
        It "Null server" {
            { Unpublish-Cube -Server $null  -CubeDatabase "master" } | Should -Throw;
        }
        It "Empty database" {
            { Unpublish-Cube -Server "localhost"  -CubeDatabase "" } | Should -Throw;
        }
        It "Null database" {
            { Unpublish-Cube -Server "localhost"  -CubeDatabase $null } | Should -Throw;
        }
    }

    Context "Testing Inputs for Alias Drop-Cube" {
        It "Should have Server as a mandatory parameter" {
            (Get-Command Drop-Cube).Parameters['Server'].Attributes.mandatory | Should -BeTrue;
        }
        It "Should have CubeDatabase as a mandatory parameter" {
            (Get-Command Drop-Cube).Parameters['CubeDatabase'].Attributes.mandatory | Should -BeTrue;
        }
        It "Empty server" {
            { Drop-Cube -Server ""  -CubeDatabase "master" } | Should -Throw;
        }
        It "Null server" {
            { Drop-Cube -Server $null  -CubeDatabase "master" } | Should -Throw;
        }
        It "Empty database" {
            { Drop-Cube -Server "localhost"  -CubeDatabase "" } | Should -Throw;
        }
        It "Null database" {
            { Drop-Cube -Server "localhost"  -CubeDatabase $null } | Should -Throw;
        }
    }

    Context "Main Tests" {
        It "Invalid server" {
            { Unpublish-Cube -Server "InvalidServer" -CubeDatabase "CubeAtCompatibility1200" } | Should -Throw;
        }

        It "Valid server and invalid database" {
            { Unpublish-Cube -Server "localhost" -CubeDatabase "InvalidDatabase" } | Should -Not -Throw;
        }


    }
}

AfterAll {
    Remove-Module -Name DeployCube
}
