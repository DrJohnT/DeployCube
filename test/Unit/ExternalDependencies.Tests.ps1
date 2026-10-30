BeforeAll {
    . (Join-Path -Path (Split-Path -Parent $PSScriptRoot) -ChildPath 'TestHelpers.ps1')
    Import-DeployCubeForTest

    # Use a PowerShell executable as a harmless, always-available native command.
    $script:Shell = if ($PSVersionTable.PSEdition -eq 'Desktop') {
        Join-Path -Path $PSHOME -ChildPath 'powershell.exe'
    } else {
        (Get-Command -Name pwsh -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
    }
}

Describe "Invoke-ExternalCommand" -Tag 'Unit' {
    Context "Testing Inputs" {
        It "Should have Command as a mandatory parameter" {
            (Get-Command Invoke-ExternalCommand).Parameters['Command'].Attributes.mandatory | Should -BeTrue
        }
        It "Should have Arguments as a mandatory parameter" {
            (Get-Command Invoke-ExternalCommand).Parameters['Arguments'].Attributes.mandatory | Should -BeTrue
        }
        It "Should have PipeOutNull as an optional parameter" {
            (Get-Command Invoke-ExternalCommand).Parameters['PipeOutNull'].Attributes.mandatory | Should -BeFalse
        }
        It "Empty Command should Throw" {
            { Invoke-ExternalCommand -Command '' -Arguments @('x') } | Should -Throw
        }
        It "Empty Arguments should Throw" {
            { Invoke-ExternalCommand -Command $script:Shell -Arguments @() } | Should -Throw
        }
    }

    Context "Exit codes" {
        It "Succeeds and returns output when the command exits with 0" {
            $output = Invoke-ExternalCommand -Command $script:Shell -Arguments @('-NoProfile', '-NonInteractive', '-Command', "Write-Output 'hello'; exit 0")
            $output | Should -Be 'hello'
            $global:LASTEXITCODE | Should -Be 0
        }

        It "Suppresses output when PipeOutNull is set" {
            $output = Invoke-ExternalCommand -Command $script:Shell -Arguments @('-NoProfile', '-NonInteractive', '-Command', "Write-Output 'hello'; exit 0") -PipeOutNull $true
            $output | Should -BeNullOrEmpty
        }

        It "Throws 'Error executing <command>' when the command exits with a non-zero code" {
            { Invoke-ExternalCommand -Command $script:Shell -Arguments @('-NoProfile', '-NonInteractive', '-Command', 'exit 3') -PipeOutNull $true } |
                Should -Throw -ExpectedMessage "Error executing $script:Shell"
            $global:LASTEXITCODE | Should -Be 3
        }

        It "Resets a stale LASTEXITCODE before running" {
            $global:LASTEXITCODE = 42
            { Invoke-ExternalCommand -Command $script:Shell -Arguments @('-NoProfile', '-NonInteractive', '-Command', 'exit 0') -PipeOutNull $true } | Should -Not -Throw
        }

        It "Throws when the command does not exist" {
            { Invoke-ExternalCommand -Command (Join-Path -Path $TestDrive -ChildPath 'missing.exe') -Arguments @('x') } | Should -Throw
        }
    }
}

Describe "Get-ModuleByName" -Tag 'Unit' {
    BeforeAll {
        Mock -ModuleName DeployCube Install-PackageProvider {}
        Mock -ModuleName DeployCube Install-Module {}
        Mock -ModuleName DeployCube Import-Module {}
    }

    It "Should have Name as a mandatory parameter" {
        (Get-Command Get-ModuleByName).Parameters['Name'].Attributes.mandatory | Should -BeTrue
    }

    It "Empty Name should Throw" {
        { Get-ModuleByName -Name '' } | Should -Throw
    }

    It "Does not install a module that is already available" {
        Mock -ModuleName DeployCube Get-Module -ParameterFilter { $ListAvailable } -MockWith { [pscustomobject]@{ Name = 'SqlServer' } }
        Mock -ModuleName DeployCube Get-Module -ParameterFilter { -not $ListAvailable } -MockWith { $null }
        Get-ModuleByName -Name 'SqlServer'
        Should -Invoke -ModuleName DeployCube Install-Module -Times 0 -Exactly
        Should -Invoke -ModuleName DeployCube Import-Module -Times 1 -Exactly -ParameterFilter { $Name -eq 'SqlServer' }
    }

    It "Does not re-import a module that is already loaded" {
        Mock -ModuleName DeployCube Get-Module { [pscustomobject]@{ Name = 'SqlServer' } }
        Get-ModuleByName -Name 'SqlServer'
        Should -Invoke -ModuleName DeployCube Install-Module -Times 0 -Exactly
        Should -Invoke -ModuleName DeployCube Import-Module -Times 0 -Exactly
    }

    It "Characterization: installs a missing module for the current user from PSGallery (assessment F11)" {
        Mock -ModuleName DeployCube Get-Module { $null }
        $output = Get-ModuleByName -Name 'SqlServer'
        $output | Should -BeLike '*Installing PowerShell module SqlServer*'
        Should -Invoke -ModuleName DeployCube Install-Module -Times 1 -Exactly -ParameterFilter {
            $Name -eq 'SqlServer' -and $Scope -eq 'CurrentUser' -and $Repository -eq 'PSGallery'
        }
        Should -Invoke -ModuleName DeployCube Import-Module -Times 1 -Exactly
    }

    It "Reports install failures as non-terminating errors (assessment F11)" {
        Mock -ModuleName DeployCube Get-Module { $null }
        Mock -ModuleName DeployCube Install-Module { throw 'gallery unavailable' }
        { Get-ModuleByName -Name 'SqlServer' -ErrorAction SilentlyContinue } | Should -Not -Throw
        { Get-ModuleByName -Name 'SqlServer' -ErrorAction Stop } | Should -Throw -ExpectedMessage '*gallery unavailable*'
    }
}
