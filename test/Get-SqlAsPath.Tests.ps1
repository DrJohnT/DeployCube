BeforeAll { 
    $ModulePath = Split-Path -Parent $PSScriptRoot;
    $ModulePath = Resolve-Path "$ModulePath\DeployCube\DeployCube.psd1";
    import-Module -Name $ModulePath;
}

Describe "Get-SqlAsPath" {
    Context "Testing Inputs" {
        It "Should have Server as a mandatory parameter" {
            (Get-Command Get-SqlAsPath).Parameters['Server'].Attributes.mandatory | Should -Be $true
        }
        It "Should have CubeDatabase as a mandatory parameter" {
            (Get-Command Get-SqlAsPath).Parameters['CubeDatabase'].Attributes.mandatory | Should -Be $true
        }
        It "Empty server" {
            { Get-SqlAsPath -Server "" -CubeDatabase MyCube } | Should -Throw;
        }
        It "Null server" {
            { Get-SqlAsPath -Server $null -CubeDatabase MyCube } | Should -Throw;
        }
        It "Empty CubeDatabase" {
            { Get-SqlAsPath -Server localhost -CubeDatabase "" } | Should -Throw;
        }
        It "Null CubeDatabase" {
            { Get-SqlAsPath -Server localhost -CubeDatabase $null } | Should -Throw;
        }
    }

    Context "Check Get-SqlAsPath Results" {
        It "Test 1" {
            ( Get-SqlAsPath -Server localhost -CubeDatabase MyCube ) | Should -Be 'SQLSERVER:\SQLAS\localhost\DEFAULT\Databases\MyCube';
          }

        It "Test 2" {
            ( Get-SqlAsPath -Server YourServer -CubeDatabase YourCubeDatabase ) | Should -Be 'SQLSERVER:\SQLAS\YourServer\DEFAULT\Databases\YourCubeDatabase';
        }

        It "Test 3" {
            ( Get-SqlAsPath -Server 'YourServer\YourInstance' -CubeDatabase YourCubeDatabase  ) | Should -Be 'SQLSERVER:\SQLAS\YourServer\YourInstance\Databases\YourCubeDatabase';
        }
    }
}

AfterAll {
    Remove-Module -Name DeployCube
}
