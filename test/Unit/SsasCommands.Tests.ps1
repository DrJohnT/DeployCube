BeforeAll {
    . (Join-Path -Path (Split-Path -Parent $PSScriptRoot) -ChildPath 'TestHelpers.ps1')
    Import-DeployCubeForTest
    Register-DeployCubeAsCmdStub

    $script:Credential = New-Object System.Management.Automation.PSCredential('user', (ConvertTo-SecureString 'not-a-real-password' -AsPlainText -Force))
    $script:Catalogs = New-DeployCubeXmlaRowset -Rows @(
        @{ DATABASE_ID = 'CubeAtCompatibility1200'; COMPATIBILITY_LEVEL = '1200' },
        @{ DATABASE_ID = 'CubeAtCompatibility1500'; COMPATIBILITY_LEVEL = '1500' }
    )
}

AfterAll {
    Unregister-DeployCubeAsCmdStub
}

Describe "Ping-SsasDatabase" -Tag 'Unit' {
    BeforeAll {
        Mock -ModuleName DeployCube Get-ModuleByName {}
        Mock -ModuleName DeployCube Invoke-ASCmd { $script:Catalogs }
    }

    Context "Testing Inputs" {
        It "Should have Server as a mandatory parameter" {
            (Get-Command Ping-SsasDatabase).Parameters['Server'].Attributes.mandatory | Should -BeTrue;
        }
        It "Should have CubeDatabase as a mandatory parameter" {
            (Get-Command Ping-SsasDatabase).Parameters['CubeDatabase'].Attributes.mandatory | Should -BeTrue;
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

    Context "Mocked server responses" {
        It "Returns true when the database is listed" {
            Ping-SsasDatabase -Server 'unit' -CubeDatabase 'CubeAtCompatibility1500' | Should -BeTrue
            Should -Invoke -ModuleName DeployCube Get-ModuleByName -ParameterFilter { $Name -eq 'SqlServer' }
        }

        It "Returns false when the database is not listed" {
            Ping-SsasDatabase -Server 'unit' -CubeDatabase 'InvalidDatabase' | Should -BeFalse
        }

        It "Returns false when the server returns nothing" {
            Mock -ModuleName DeployCube Invoke-ASCmd { $null }
            Ping-SsasDatabase -Server 'unit' -CubeDatabase 'CubeAtCompatibility1200' | Should -BeFalse
        }

        It "Passes the credential through when supplied" {
            Ping-SsasDatabase -Server 'unit' -CubeDatabase 'CubeAtCompatibility1200' -Credential $script:Credential | Should -BeTrue
            Should -Invoke -ModuleName DeployCube Invoke-ASCmd -ParameterFilter { $Credential.UserName -eq 'user' -and $Query -like '*DBSCHEMA_CATALOGS*' }
        }
    }
}

Describe "Get-CubeDatabaseCompatibilityLevel" -Tag 'Unit' {
    BeforeAll {
        Mock -ModuleName DeployCube Get-ModuleByName {}
        Mock -ModuleName DeployCube Invoke-ASCmd { $script:Catalogs }
    }

    Context "Testing Inputs" {
        It "Should have Server as a mandatory parameter" {
            (Get-Command Get-CubeDatabaseCompatibilityLevel).Parameters['Server'].Attributes.mandatory | Should -BeTrue;
        }
        It "Should have CubeDatabase as a mandatory parameter" {
            (Get-Command Get-CubeDatabaseCompatibilityLevel).Parameters['CubeDatabase'].Attributes.mandatory | Should -BeTrue;
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

    Context "Mocked server responses" {
        It "Returns compatibility level <Level> for <Database>" -ForEach @(
            @{ Database = 'CubeAtCompatibility1200'; Level = 1200 },
            @{ Database = 'CubeAtCompatibility1500'; Level = 1500 }
        ) {
            $result = Get-CubeDatabaseCompatibilityLevel -Server 'unit' -CubeDatabase $Database
            $result | Should -Be $Level
            $result | Should -BeOfType [int]
        }

        # Characterization: the outer catch replaces the specific cause ('Failed to find cube database ...',
        # 'Invoke-ASCmd failed to return ...') with a generic 'SSAS Server <name> not found', even when the server answered.
        It "Characterization: throws a generic 'server not found' error when the cube database does not exist" {
            { Get-CubeDatabaseCompatibilityLevel -Server 'unit' -CubeDatabase 'InvalidCube' } | Should -Throw -ExpectedMessage 'SSAS Server unit not found*'
        }

        It "Characterization: throws a generic 'server not found' error when the server returns nothing" {
            Mock -ModuleName DeployCube Invoke-ASCmd { $null }
            { Get-CubeDatabaseCompatibilityLevel -Server 'unit' -CubeDatabase 'CubeAtCompatibility1200' } | Should -Throw -ExpectedMessage 'SSAS Server unit not found*'
        }
    }
}

Describe "Unpublish-Cube" -Tag 'Unit' {
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

    Context "Mocked server responses" {
        It "Sends a Delete command for the database and succeeds on an empty result" {
            Mock -ModuleName DeployCube Invoke-ASCmd { New-DeployCubeXmlaEmptyResult }
            { Unpublish-Cube -Server 'unit' -CubeDatabase 'MyCube' } | Should -Not -Throw
            Should -Invoke -ModuleName DeployCube Invoke-ASCmd -Times 1 -Exactly -ParameterFilter { $Server -eq 'unit' -and $Query -like '*<Delete*<DatabaseID>MyCube</DatabaseID>*' }
        }

        It "Throws when the server does not return an empty result" {
            Mock -ModuleName DeployCube Invoke-ASCmd { 'A connection cannot be made.' }
            { Unpublish-Cube -Server 'unit' -CubeDatabase 'MyCube' } | Should -Throw -ExpectedMessage '*Failed to drop cube MyCube*'
        }

        It "Passes the credential through when supplied" {
            Mock -ModuleName DeployCube Invoke-ASCmd { New-DeployCubeXmlaEmptyResult }
            Unpublish-Cube -Server 'unit' -CubeDatabase 'MyCube' -Credential $script:Credential
            Should -Invoke -ModuleName DeployCube Invoke-ASCmd -ParameterFilter { $Credential.UserName -eq 'user' }
        }
    }
}

Describe "Invoke-ProcessTabularCubeDatabase" -Tag 'Unit' {
    Context "Testing Inputs" {
        It "Should have Server as a mandatory parameter" {
            (Get-Command Invoke-ProcessTabularCubeDatabase).Parameters['Server'].Attributes.mandatory | Should -BeTrue;
        }
        It "Should have CubeDatabase as a mandatory parameter" {
            (Get-Command Invoke-ProcessTabularCubeDatabase).Parameters['CubeDatabase'].Attributes.mandatory | Should -BeTrue;
        }
        It "Should have RefreshType as an optional parameter" {
            (Get-Command Invoke-ProcessTabularCubeDatabase).Parameters['RefreshType'].Attributes.mandatory | Should -BeFalse;
        }
        It "Empty server" {
            { Invoke-ProcessTabularCubeDatabase -Server "" -CubeDatabase 'MyCube' } | Should -Throw;
        }
        It "Null server" {
            { Invoke-ProcessTabularCubeDatabase -Server $null -CubeDatabase 'MyCube' } | Should -Throw;
        }
        It "Empty CubeDatabase" {
            { Invoke-ProcessTabularCubeDatabase -Server 'localhost' -CubeDatabase '' } | Should -Throw;
        }
        It "Null CubeDatabase" {
            { Invoke-ProcessTabularCubeDatabase -Server 'localhost' -CubeDatabase $null } | Should -Throw;
        }
        It "Process NonExistantRefreshType should Throw" {
            { Invoke-ProcessTabularCubeDatabase -Server 'localhost' -CubeDatabase 'MyCube' -RefreshType 'NonExistantRefreshType' } | Should -Throw;
        }
    }

    Context "Mocked server responses" {
        It "Sends a TMSL refresh of type <RefreshType>" -ForEach @(
            @{ RefreshType = 'Full' }, @{ RefreshType = 'Automatic' }, @{ RefreshType = 'ClearValues' }, @{ RefreshType = 'Calculate' }
        ) {
            Mock -ModuleName DeployCube Invoke-ASCmd { New-DeployCubeXmlaEmptyResult }
            { Invoke-ProcessTabularCubeDatabase -Server 'unit' -CubeDatabase 'MyCube' -RefreshType $RefreshType } | Should -Not -Throw
            Should -Invoke -ModuleName DeployCube Invoke-ASCmd -Times 1 -Exactly -ParameterFilter {
                $tmsl = $Query | ConvertFrom-Json
                $tmsl.refresh.type -eq $RefreshType -and $tmsl.refresh.objects[0].database -eq 'MyCube'
            }
        }

        It "Defaults to a Full refresh" {
            Mock -ModuleName DeployCube Invoke-ASCmd { New-DeployCubeXmlaEmptyResult }
            Invoke-ProcessTabularCubeDatabase -Server 'unit' -CubeDatabase 'MyCube' | Out-Null
            Should -Invoke -ModuleName DeployCube Invoke-ASCmd -ParameterFilter { ($Query | ConvertFrom-Json).refresh.type -eq 'Full' }
        }

        It "Throws when processing returns an error message" {
            Mock -ModuleName DeployCube Invoke-ASCmd { New-DeployCubeXmlaEmptyResult -ErrorDescription 'Login failed for data source.' }
            { Invoke-ProcessTabularCubeDatabase -Server 'unit' -CubeDatabase 'MyCube' } | Should -Throw -ExpectedMessage '*Error processing MyCube*'
        }

        It "Throws when the server returns nothing" {
            Mock -ModuleName DeployCube Invoke-ASCmd { $null }
            { Invoke-ProcessTabularCubeDatabase -Server 'unit' -CubeDatabase 'MyCube' } | Should -Throw -ExpectedMessage '*Error processing MyCube*'
        }
    }
}

Describe "Get-SsasProcessingMessages" -Tag 'Unit' {
    It "Does not throw for an empty result without messages" {
        { Get-SsasProcessingMessages -ASCmdReturnString (New-DeployCubeXmlaEmptyResult) } | Should -Not -Throw
    }

    It "Throws the error description from the result" {
        { Get-SsasProcessingMessages -ASCmdReturnString (New-DeployCubeXmlaEmptyResult -ErrorDescription 'Something failed') } | Should -Throw -ExpectedMessage 'Something failed'
    }

    It "Rejects an empty string" {
        { Get-SsasProcessingMessages -ASCmdReturnString '' } | Should -Throw
    }
}

Describe "Ping-SsasServer" -Tag 'Unit' {
    Context "Testing Inputs" {
        It "Should have Server as a mandatory parameter" {
            (Get-Command Ping-SsasServer).Parameters['Server'].Attributes.mandatory | Should -BeTrue;
        }
        It "Empty server" {
            { Ping-SsasServer -Server "" } | Should -Throw;
        }
        It "Null server" {
            { Ping-SsasServer -Server $null } | Should -Throw;
        }
        It "Azure servers are unsupported by Ping-SsasServer" {
            { Ping-SsasServer -Server "asazure://uksouth.asazure.windows.net/xxx" } | Should -Throw -ExpectedMessage '*Azure Analysis Services not supported*';
        }
    }
}

Describe "Get-ServerMode" -Tag 'Unit' {
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
}
