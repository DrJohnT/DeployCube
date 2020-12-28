BeforeAll { 
    $ModulePath = Split-Path -Parent $PSScriptRoot;
    $ModulePath = Resolve-Path "$ModulePath\DeployCube\DeployCube.psd1";
    import-Module -Name $ModulePath;
}

Describe "Get-CubeDatabaseCompatibilityLevel"  -Tag "Round1" {
    Context "Testing Inputs" {
        It "Should have Server as a mandatory parameter" {
            (Get-Command Get-CubeDatabaseCompatibilityLevel).Parameters['Server'].Attributes.mandatory | Should -Be $true
        }
        It "Should have CubeDatabase as a mandatory parameter" {
            (Get-Command Get-CubeDatabaseCompatibilityLevel).Parameters['CubeDatabase'].Attributes.mandatory | Should -Be $true
        }
        It "Empty server" {
            { Get-CubeDatabaseCompatibilityLevel -Server "" -CubeDatabase "master" } | Should -Throw;
        }
        It "Null server" {
            { Get-CubeDatabaseCompatibilityLevel -Server $null  -CubeDatabase "master" } | Should -Throw;
        }
        It "Empty database" {
            { Get-CubeDatabaseCompatibilityLevel -Server "localhost"  -CubeDatabase "" } | Should -Throw;
        }
        It "Null database" {
            { Get-CubeDatabaseCompatibilityLevel -Server "localhost"  -CubeDatabase $null } | Should -Throw;
        }

    }

    Context "Invalid Inputs" {
        It "Invalid server" {
            { Get-CubeDatabaseCompatibilityLevel -Server "InvalidServer" -CubeDatabase "MyCube" } | Should -Throw;
        }

        It "Valid server invalid cube database" {
            { Get-CubeDatabaseCompatibilityLevel -Server "localhost" -CubeDatabase "InvalidCube" } | Should -Throw;
        }
    }

    Context "Valid Inputs" {

        It "Valid server and cube CompatibilityLevel=1200" {
            ( Get-CubeDatabaseCompatibilityLevel -Server "localhost" -CubeDatabase "CubeToPublish" ) | Should -Be 1200;
        }
    }
}

AfterAll {
    Remove-Module -Name DeployCube
}