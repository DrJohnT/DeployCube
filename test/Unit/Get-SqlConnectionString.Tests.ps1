BeforeDiscovery {
    # Get-SqlConnectionString uses System.Data.OleDb, which is available in Windows PowerShell 5.1 but not in PowerShell 7
    # (on non-Windows the type may load yet throw PlatformNotSupportedException when constructed).
    $oleDbUnavailable = $true
    try {
        $null = New-Object -TypeName System.Data.OleDb.OleDbConnectionStringBuilder
        $oleDbUnavailable = $false
    } catch {
        $oleDbUnavailable = $true
    }
}

BeforeAll {
    . (Join-Path -Path (Split-Path -Parent $PSScriptRoot) -ChildPath 'TestHelpers.ps1')
    Import-DeployCubeForTest

    function ConvertTo-NormalizedConnectionString {
        # Connection string keywords are case-insensitive and unordered, and OleDbConnectionStringBuilder orders and
        # cases them differently on .NET Framework and .NET, so compare sorted 'keyword=value' pairs. Values stay exact.
        param([string]$ConnectionString)
        $pairs = foreach ($part in ($ConnectionString -split ';' | Where-Object { $_.Trim() })) {
            $keyword, $value = $part -split '=', 2
            "$($keyword.Trim().ToLowerInvariant())=$value"
        }
        return (($pairs | Sort-Object) -join ';')
    }
}

Describe "Get-SqlConnectionString"  -Tag 'Unit' {

    Context "Testing Inputs" {
        It "Should have SourceSqlServer as a mandatory parameter" {
            (Get-Command Get-SqlConnectionString).Parameters['SourceSqlServer'].Attributes.mandatory | Should -BeTrue;
        }
        It "Should have SourceSqlDatabase as a mandatory parameter" {
            (Get-Command Get-SqlConnectionString).Parameters['SourceSqlDatabase'].Attributes.mandatory | Should -BeTrue;
        }
        It "Should have ExistingConnectionString as an mandatory parameter" {
            (Get-Command Get-SqlConnectionString).Parameters['ExistingConnectionString'].Attributes.mandatory | Should -BeTrue;
        }

    }

    Context "Should return correct connection strings" -Skip:$oleDbUnavailable {
        It "Should return correct connection string 1" {
            
            [string]$connString1 = "Provider=SQLNCLI11;Data Source=localhost;Initial Catalog=DatabaseToPublish;Integrated Security=SSPI;Persist Security Info=false";
            [string]$expectedConnString1 = "Provider=SQLNCLI11;Data Source=myserver;Persist Security Info=False;Integrated Security=SSPI;Initial Catalog=mydatabase";

            $actual = Get-SqlConnectionString -SourceSqlServer "myserver" -SourceSqlDatabase "mydatabase" -ExistingConnectionString $connString1;
            ConvertTo-NormalizedConnectionString $actual | Should -BeExactly (ConvertTo-NormalizedConnectionString $expectedConnString1);
        }

        It "Should build an encrypted SQLNCLI11 connection string for Azure SQL with SQL authentication" {
            $connString = Get-SqlConnectionString -SourceSqlServer "myserver.database.windows.net" -SourceSqlDatabase "mydatabase" -ExistingConnectionString "Provider=SQLNCLI11;Data Source=old" -SqlUserID "sqluser" -SqlUserPwd "sqlpwd";
            $connString | Should -Match 'Provider=SQLNCLI11';
            $connString | Should -Match 'Data Source=myserver\.database\.windows\.net';
            $connString | Should -Match 'Initial Catalog=mydatabase';
            $connString | Should -Match 'Encrypt=True';
            $connString | Should -Match 'User ID=sqluser';
            $connString | Should -Match 'Persist Security Info=True';
        }

        It "Should not add credentials for Azure SQL when no SQL user is supplied" {
            $connString = Get-SqlConnectionString -SourceSqlServer "myserver.database.windows.net" -SourceSqlDatabase "mydatabase" -ExistingConnectionString "Provider=SQLNCLI11;Data Source=old";
            $connString | Should -Not -Match 'User ID';
            $connString | Should -Not -Match 'Password';
        }
    }

}

AfterAll {
    Remove-Module -Name DeployCube
}