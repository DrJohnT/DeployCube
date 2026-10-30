BeforeAll {
    . (Join-Path -Path (Split-Path -Parent $PSScriptRoot) -ChildPath 'TestHelpers.ps1')
    Import-DeployCubeForTest
    Register-DeployCubeAsCmdStub

    function Get-LegacyDataSourceRowset {
        New-DeployCubeXmlaRowset -Rows @(
            @{ name = 'SqlServer localhost DatabaseToPublish'; type = '1'; ConnectionString = 'Provider=SQLNCLI11;Data Source=old;Initial Catalog=olddb;Integrated Security=SSPI'; MaxConnections = '10' }
        )
    }

    function Get-StructuredDataSourceRowset {
        New-DeployCubeXmlaRowset -Rows @(
            @{ name = 'SQL/localhost;DatabaseToPublish'; type = '2'
                ConnectionDetails = '{"protocol":"tds","address":{"server":"old","database":"olddb"},"authentication":null,"query":null}'
                Credential = '{"AuthenticationKind":"ServiceAccount","EncryptConnection":false}' }
        )
    }

    function Invoke-UpdateWithMocks {
        param([int]$CompatibilityLevel, [hashtable]$Parameters)

        $script:SentTmsl = $null
        Mock -ModuleName DeployCube Get-CubeDatabaseCompatibilityLevel { $CompatibilityLevel }.GetNewClosure()
        $rowset = if ($CompatibilityLevel -ge 1400) { Get-StructuredDataSourceRowset } else { Get-LegacyDataSourceRowset }
        Mock -ModuleName DeployCube Invoke-ASCmd -ParameterFilter { $Query -like '*TMSCHEMA_DATA_SOURCES*' } -MockWith { $rowset }.GetNewClosure()
        Mock -ModuleName DeployCube Invoke-ASCmd -ParameterFilter { $Query -like '*createOrReplace*' } -MockWith { New-DeployCubeXmlaEmptyResult }

        $base = @{
            Server            = 'unit'
            CubeDatabase      = 'MyCube'
            SourceSqlServer   = 'newserver'
            SourceSqlDatabase = 'newdb'
            ImpersonationMode = 'ImpersonateServiceAccount'
        }
        foreach ($key in $Parameters.Keys) { $base[$key] = $Parameters[$key] }
        return (Update-TabularCubeDataSource @base)
    }

    function Get-CreateOrReplace {
        $script:Captured = $null
        Should -Invoke -ModuleName DeployCube Invoke-ASCmd -Times 1 -Exactly -ParameterFilter {
            if ($Query -like '*createOrReplace*') { $script:Captured = $Query | ConvertFrom-Json; $true } else { $false }
        } -Scope It
        return $script:Captured.createOrReplace
    }
}

AfterAll {
    Unregister-DeployCubeAsCmdStub
}

Describe "Update-TabularCubeDataSource" -Tag 'Unit' {

    Context "Testing Inputs" {
        It "Should have Server as a mandatory parameter" {
            (Get-Command Update-TabularCubeDataSource).Parameters['Server'].Attributes.mandatory | Should -BeTrue;
        }
        It "Should have CubeDatabase as a mandatory parameter" {
            (Get-Command Update-TabularCubeDataSource).Parameters['CubeDatabase'].Attributes.mandatory | Should -BeTrue;
        }
        It "Should have SourceSqlServer as a mandatory parameter" {
            (Get-Command Update-TabularCubeDataSource).Parameters['SourceSqlServer'].Attributes.mandatory | Should -BeTrue;
        }
        It "Should have SourceSqlDatabase as a mandatory parameter" {
            (Get-Command Update-TabularCubeDataSource).Parameters['SourceSqlDatabase'].Attributes.mandatory | Should -BeTrue;
        }
        It "Should have ImpersonationMode as a mandatory parameter" {
            (Get-Command Update-TabularCubeDataSource).Parameters['ImpersonationMode'].Attributes.mandatory | Should -BeTrue;
        }
        It "Should have ImpersonationAccount as a optional parameter" {
            (Get-Command Update-TabularCubeDataSource).Parameters['ImpersonationAccount'].Attributes.mandatory | Should -BeFalse;
        }
        It "Should have ImpersonationPwd as a optional parameter" {
            (Get-Command Update-TabularCubeDataSource).Parameters['ImpersonationPwd'].Attributes.mandatory | Should -BeFalse;
        }
        It "Should have DataSource as a optional parameter" {
            (Get-Command Update-TabularCubeDataSource).Parameters['DataSource'].Attributes.mandatory | Should -BeFalse;
        }
        It "Should have CommandTimeout as a optional parameter" {
            (Get-Command Update-TabularCubeDataSource).Parameters['CommandTimeout'].Attributes.mandatory | Should -BeFalse;
        }
        It "Should accept ImpersonationPassword and AuthenticationKind aliases" {
            $parameters = (Get-Command Update-TabularCubeDataSource).Parameters
            $parameters['ImpersonationPwd'].Aliases | Should -Contain 'ImpersonationPassword'
            $parameters['ImpersonationMode'].Aliases | Should -Contain 'AuthenticationKind'
        }

        It "Empty server" {
            { Update-TabularCubeDataSource -Server ""  -CubeDatabase "MyCube" -SourceSqlServer "localhost" -SourceSqlDatabase 'MyDB' -ImpersonationMode 'ImpersonateServiceAccount' } | Should -Throw;
        }
        It "Null server" {
            { Update-TabularCubeDataSource -Server $null  -CubeDatabase "MyCube" -SourceSqlServer "localhost" -SourceSqlDatabase 'MyDB' -ImpersonationMode 'ImpersonateServiceAccount' } | Should -Throw;
        }
        It "Empty database" {
            { Update-TabularCubeDataSource -Server "localhost"  -CubeDatabase "" -SourceSqlServer "localhost" -SourceSqlDatabase 'MyDB' -ImpersonationMode 'ImpersonateServiceAccount' } | Should -Throw;
        }
        It "Null database" {
            { Update-TabularCubeDataSource -Server 'localhost'  -CubeDatabase $null -SourceSqlServer "localhost" -SourceSqlDatabase 'MyDB' -ImpersonationMode 'ImpersonateServiceAccount' } | Should -Throw;
        }
        It "Empty SourceSqlServer" {
            { Update-TabularCubeDataSource -Server 'localhost' -CubeDatabase "master" -SourceSqlServer "" -SourceSqlDatabase 'MyDB' -ImpersonationMode 'ImpersonateServiceAccount'} | Should -Throw;
        }
        It "Null SourceSqlServer" {
            { Update-TabularCubeDataSource -Server 'localhost' -CubeDatabase "master" -SourceSqlServer $null -SourceSqlDatabase 'MyDB' -ImpersonationMode 'ImpersonateServiceAccount'} | Should -Throw;
        }
        It "Invalid ImpersonationMode" {
            { Update-TabularCubeDataSource -Server 'localhost' -CubeDatabase "master" -SourceSqlServer 'localhost' -SourceSqlDatabase 'MyDB' -ImpersonationMode 'Nonsense'} | Should -Throw;
        }

        # The original tests passed a null SourceSqlServer here, so they passed on parameter binding instead of
        # exercising the ImpersonateAccount checks. These versions reach the function body.
        It "Null ImpersonationAccount when ImpersonationMode=ImpersonateAccount" {
            { Update-TabularCubeDataSource -Server 'localhost' -CubeDatabase "master" -SourceSqlServer 'localhost' -SourceSqlDatabase 'MyDB' -ImpersonationMode 'ImpersonateAccount' -ImpersonationAccount $null -ImpersonationPassword 'test' } | Should -Throw -ExpectedMessage '*ImpersonationAccount not set*';
        }

        It "Null ImpersonationPwd when ImpersonationMode=ImpersonateAccount" {
            { Update-TabularCubeDataSource -Server 'localhost' -CubeDatabase "master" -SourceSqlServer 'localhost' -SourceSqlDatabase 'MyDB' -ImpersonationMode 'ImpersonateAccount' -ImpersonationAccount 'test' -ImpersonationPwd $null } | Should -Throw -ExpectedMessage '*ImpersonationPassword not set*';
        }

        It "Invalid CommandTimeout <_>" -ForEach @(0, -5) {
            { Update-TabularCubeDataSource -Server 'localhost' -CubeDatabase "master" -SourceSqlServer 'localhost' -SourceSqlDatabase 'MyDB' -ImpersonationMode 'ImpersonateServiceAccount' -CommandTimeout $_ } | Should -Throw -ExpectedMessage '*CommandTimeout cannot be zero or a negative number*';
        }
    }

    Context "Mocked compatibility level 1200 (provider data source)" {
        BeforeAll {
            Mock -ModuleName DeployCube Get-SqlConnectionString { "Provider=SQLNCLI11;Data Source=$SourceSqlServer;Initial Catalog=$SourceSqlDatabase" }
        }

        It "Sends a createOrReplace with the new connection string and service account impersonation" {
            $result = Invoke-UpdateWithMocks -CompatibilityLevel 1200 -Parameters @{}
            $result[-1] | Should -BeTrue
            $tmsl = Get-CreateOrReplace
            $tmsl.object.database | Should -Be 'MyCube'
            $tmsl.object.dataSource | Should -Be 'SqlServer localhost DatabaseToPublish'
            $tmsl.dataSource.connectionString | Should -Be 'Provider=SQLNCLI11;Data Source=newserver;Initial Catalog=newdb'
            $tmsl.dataSource.impersonationMode | Should -Be 'ImpersonateServiceAccount'
            $tmsl.dataSource.maxConnections | Should -Be 10
            $tmsl.dataSource.PSObject.Properties.Name | Should -Not -Contain 'account'
            $tmsl.dataSource.PSObject.Properties.Name | Should -Not -Contain 'timeout'
            Should -Invoke -ModuleName DeployCube Get-SqlConnectionString -ParameterFilter { $ExistingConnectionString -like '*Data Source=old*' }
        }

        It "Includes the impersonation account and password for ImpersonateAccount" {
            $result = Invoke-UpdateWithMocks -CompatibilityLevel 1200 -Parameters @{ ImpersonationMode = 'ImpersonateAccount'; ImpersonationAccount = 'DOMAIN\svc'; ImpersonationPwd = 'unit-test-only' }
            $result[-1] | Should -BeTrue
            $tmsl = Get-CreateOrReplace
            $tmsl.dataSource.impersonationMode | Should -Be 'ImpersonateAccount'
            $tmsl.dataSource.account | Should -Be 'DOMAIN\svc'
            $tmsl.dataSource.password | Should -Be 'unit-test-only'
        }

        It "Converts CommandTimeout minutes into seconds" {
            $null = Invoke-UpdateWithMocks -CompatibilityLevel 1200 -Parameters @{ CommandTimeout = 60 }
            (Get-CreateOrReplace).dataSource.timeout | Should -Be 3600
        }

        It "Throws when the named DataSource does not exist" {
            { Invoke-UpdateWithMocks -CompatibilityLevel 1200 -Parameters @{ DataSource = 'InvalidDataSource' } } | Should -Throw -ExpectedMessage '*not found or does not have a data source*'
        }

        It "Selects the named DataSource" {
            $result = Invoke-UpdateWithMocks -CompatibilityLevel 1200 -Parameters @{ DataSource = 'SqlServer localhost DatabaseToPublish' }
            $result[-1] | Should -BeTrue
        }

        It "Characterization: returns a leading 0 before the boolean result (assessment F22)" {
            $result = Invoke-UpdateWithMocks -CompatibilityLevel 1200 -Parameters @{}
            $result.Count | Should -Be 2
            $result[0] | Should -Be 0
            $result[1] | Should -BeTrue
        }

        It "Returns false and writes an error when the server reports an error" {
            $null = Invoke-UpdateWithMocks -CompatibilityLevel 1200 -Parameters @{}
            Mock -ModuleName DeployCube Invoke-ASCmd -ParameterFilter { $Query -like '*createOrReplace*' } -MockWith { New-DeployCubeXmlaEmptyResult -ErrorDescription 'Invalid data source' }
            $base = @{ Server = 'unit'; CubeDatabase = 'MyCube'; SourceSqlServer = 'newserver'; SourceSqlDatabase = 'newdb'; ImpersonationMode = 'ImpersonateServiceAccount' }
            $result = Update-TabularCubeDataSource @base -ErrorAction SilentlyContinue -ErrorVariable errors
            $result[-1] | Should -BeFalse
            "$errors" | Should -BeLike '*Invalid data source*'
        }
    }

    Context "Mocked compatibility level 1500 (structured data source)" {
        It "Sends a structured data source with service account credentials" {
            $result = Invoke-UpdateWithMocks -CompatibilityLevel 1500 -Parameters @{}
            $result[-1] | Should -BeTrue
            $tmsl = Get-CreateOrReplace
            $tmsl.object.dataSource | Should -Be 'SQL/localhost;DatabaseToPublish'
            $tmsl.dataSource.type | Should -Be 'structured'
            $tmsl.dataSource.connectionDetails.protocol | Should -Be 'tds'
            $tmsl.dataSource.connectionDetails.address.server | Should -Be 'newserver'
            $tmsl.dataSource.connectionDetails.address.database | Should -Be 'newdb'
            $tmsl.dataSource.credential.AuthenticationKind | Should -Be 'ServiceAccount'
            $tmsl.dataSource.credential.path | Should -Be 'newserver;newdb'
            $tmsl.dataSource.PSObject.Properties.Name | Should -Not -Contain 'options'
        }

        It "Uses Windows credentials for ImpersonateAccount" {
            $null = Invoke-UpdateWithMocks -CompatibilityLevel 1500 -Parameters @{ ImpersonationMode = 'ImpersonateAccount'; ImpersonationAccount = 'DOMAIN\svc'; ImpersonationPwd = 'unit-test-only' }
            $credential = (Get-CreateOrReplace).dataSource.credential
            $credential.AuthenticationKind | Should -Be 'Windows'
            $credential.Username | Should -Be 'DOMAIN\svc'
            $credential.Password | Should -Be 'unit-test-only'
        }

        It "Uses SQL credentials for UsernamePassword" {
            $null = Invoke-UpdateWithMocks -CompatibilityLevel 1500 -Parameters @{ ImpersonationMode = 'UsernamePassword'; ImpersonationAccount = 'sqluser'; ImpersonationPwd = 'unit-test-only' }
            $credential = (Get-CreateOrReplace).dataSource.credential
            $credential.AuthenticationKind | Should -Be 'UsernamePassword'
            $credential.kind | Should -Be 'SQL'
            $credential.Username | Should -Be 'sqluser'
        }

        It "Formats CommandTimeout <Minutes> minutes as <Expected>" -ForEach @(
            @{ Minutes = 60; Expected = 'PT1H' },
            @{ Minutes = 90; Expected = 'PT1H30M' },
            @{ Minutes = 1500; Expected = 'P1DT1H' },
            @{ Minutes = 1.5; Expected = 'PT1M30S' }
        ) {
            $null = Invoke-UpdateWithMocks -CompatibilityLevel 1500 -Parameters @{ CommandTimeout = $Minutes }
            (Get-CreateOrReplace).dataSource.options.commandTimeout | Should -Be $Expected
        }

        It "Throws when the named DataSource does not exist" {
            { Invoke-UpdateWithMocks -CompatibilityLevel 1500 -Parameters @{ DataSource = 'InvalidDataSource' } } | Should -Throw -ExpectedMessage '*not found or does not have a data source*'
        }
    }

    Context "Credential pass-through" {
        It "Uses the supplied credential for every SSAS call" {
            $credential = New-Object System.Management.Automation.PSCredential('user', (ConvertTo-SecureString 'not-a-real-password' -AsPlainText -Force))
            $null = Invoke-UpdateWithMocks -CompatibilityLevel 1500 -Parameters @{ Credential = $credential }
            Should -Invoke -ModuleName DeployCube Get-CubeDatabaseCompatibilityLevel -ParameterFilter { $Credential.UserName -eq 'user' }
            Should -Invoke -ModuleName DeployCube Invoke-ASCmd -Times 2 -Exactly -ParameterFilter { $Credential.UserName -eq 'user' }
        }
    }
}
