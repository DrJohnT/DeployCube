BeforeAll { 
    $ModulePath = Split-Path -Parent $PSScriptRoot;
    $ModulePath = Resolve-Path "$ModulePath\DeployCube\DeployCube.psd1";
    import-Module -Name $ModulePath;
}

Describe "Get-SqlConnectionString"  -Tag "Round1" {

    Context "Testing Inputs" {
        It "Should have SourceSqlServer as a mandatory parameter" {
            (Get-Command Get-SqlConnectionString).Parameters['SourceSqlServer'].Attributes.mandatory | Should -Be $true;
        }
        It "Should have SourceSqlDatabase as a mandatory parameter" {
            (Get-Command Get-SqlConnectionString).Parameters['SourceSqlDatabase'].Attributes.mandatory | Should -Be $true;
        }
        It "Should have ExistingConnectionString as an mandatory parameter" {
            (Get-Command Get-SqlConnectionString).Parameters['ExistingConnectionString'].Attributes.mandatory | Should -Be $true;
        }

    }

    Context "Should return correct connection strings" {
        It "Should return correct connection string 1" {
            
            [string]$connString1 = "Provider=SQLNCLI11;Data Source=localhost;Initial Catalog=DatabaseToPublish;Integrated Security=SSPI;Persist Security Info=false";
            [string]$expectedConnString1 = "Provider=SQLNCLI11;Data Source=myserver;Persist Security Info=False;Integrated Security=SSPI;Initial Catalog=mydatabase";

            ( Get-SqlConnectionString -SourceSqlServer "myserver" -SourceSqlDatabase "mydatabase" -ExistingConnectionString $connString1 ) | Should -Be $expectedConnString1;
        }
    }

}

AfterAll {
    Remove-Module -Name DeployCube
}