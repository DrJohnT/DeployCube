BeforeAll {
    . (Join-Path -Path (Split-Path -Parent $PSScriptRoot) -ChildPath 'TestHelpers.ps1')
    Import-DeployCubeForTest

    $script:OriginalCustomLocation = $env:CustomAsDwInstallLocation

    function Set-FakeInstallLocation {
        # The fixture executable reports ProductVersion 11.x.
        $folder = Join-Path -Path $TestDrive -ChildPath 'DeploymentWizard'
        if (-not (Test-Path -Path $folder)) {
            Copy-Item -Path (Get-DeployCubeFixturePath -Name 'DeploymentWizard') -Destination $folder -Recurse
        }
        $env:CustomAsDwInstallLocation = $folder
        return (Join-Path -Path $folder -ChildPath 'Microsoft.AnalysisServices.Deployment.exe')
    }
}

AfterAll {
    $env:CustomAsDwInstallLocation = $script:OriginalCustomLocation
}

Describe "Deployment utility discovery" -Tag 'Unit' {
    BeforeAll {
        # Hide any SSDT/SSMS installation on the test machine so results are deterministic.
        Mock -ModuleName DeployCube Get-ChildItem -ParameterFilter { $Path -like '*Microsoft SQL Server*' } -MockWith {}
    }

    BeforeEach {
        Remove-Item -Path Env:CustomAsDwInstallLocation -ErrorAction SilentlyContinue
    }

    Context "Find-AnalysisServicesDeploymentExeLocations" {
        It "Returns nothing when no deployment utility is installed" {
            Find-AnalysisServicesDeploymentExeLocations | Should -BeNullOrEmpty
        }

        It "Lists the utility found in CustomAsDwInstallLocation with its major version" {
            $exe = Set-FakeInstallLocation
            $lines = @(Find-AnalysisServicesDeploymentExeLocations)
            $lines.Count | Should -Be 1
            $lines[0] | Should -BeLike "11*"
            $lines[0] | Should -BeLike "*Microsoft.AnalysisServices.Deployment.exe"
        }

        It "Reports an invalid CustomAsDwInstallLocation as an error record" {
            # Reported through Write-Error inside the function's own try/catch, so capture the error stream.
            # -ErrorAction Continue pins the default behaviour; GitHub's 'powershell' shell runs with ErrorActionPreference=Stop.
            $env:CustomAsDwInstallLocation = Join-Path -Path $TestDrive -ChildPath 'xxx'
            $output = @(Find-AnalysisServicesDeploymentExeLocations -ErrorAction Continue 2>&1)
            $errors = @($output | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })
            $errors.Count | Should -Be 1
            "$($errors[0])" | Should -BeLike '*Invalid custom environment variable path: CustomAsDwInstallLocation*'
        }
    }

    Context "Search locations" {
        It "Find-AnalysisServicesDeploymentExeLocations searches <Description>" -ForEach @(
            @{ Description = 'SQL Server Tools\Binn (SSDT up to v17)'; Pattern = '*\Microsoft SQL Server\`*\Tools\Binn' }
            @{ Description = 'SSMS (x86) Common7'; Pattern = '*\Microsoft SQL Server Management Studio `*\Common7' }
            @{ Description = 'SSMS 21+ Release\Common7'; Pattern = '*\Microsoft SQL Server Management Studio `*\Release\Common7' }
        ) {
            Find-AnalysisServicesDeploymentExeLocations | Out-Null
            Should -Invoke -ModuleName DeployCube Get-ChildItem -Times 1 -Exactly -ParameterFilter { $Path -like $Pattern }
        }

        It "Get-AnalysisServicesDeploymentExePath searches <Description>" -ForEach @(
            @{ Description = 'SQL Server Tools\Binn (SSDT up to v17)'; Pattern = '*\Microsoft SQL Server\`*\Tools\Binn' }
            @{ Description = 'SSMS (x86) Common7\IDE'; Pattern = '*\Microsoft SQL Server Management Studio `*\Common7\IDE' }
            @{ Description = 'SSMS 21+ Release\Common7\IDE'; Pattern = '*\Microsoft SQL Server Management Studio `*\Release\Common7\IDE' }
        ) {
            Get-AnalysisServicesDeploymentExePath -Version 15 | Out-Null
            Should -Invoke -ModuleName DeployCube Get-ChildItem -Times 1 -Exactly -ParameterFilter { $Path -like $Pattern }
        }

        It "Returns a utility found under an SSMS install folder" {
            $exe = Join-Path -Path (Join-Path -Path $TestDrive -ChildPath 'SsmsIde') -ChildPath 'Microsoft.AnalysisServices.Deployment.exe'
            $null = New-Item -Path (Split-Path -Parent $exe) -ItemType Directory -Force
            Copy-Item -Path (Join-Path -Path (Get-DeployCubeFixturePath -Name 'DeploymentWizard') -ChildPath 'Microsoft.AnalysisServices.Deployment.exe') -Destination $exe -Force
            Mock -ModuleName DeployCube Get-ChildItem -ParameterFilter { $Path -like '*\Release\Common7\IDE' } -MockWith { Get-Item -LiteralPath $exe }.GetNewClosure()
            Get-AnalysisServicesDeploymentExePath -Version 11 | Should -Be $exe
        }
    }

    Context "Get-AnalysisServicesDeploymentExePath" {
        It "Should have Version as a mandatory parameter" {
            (Get-Command Get-AnalysisServicesDeploymentExePath).Parameters['Version'].Attributes.mandatory | Should -BeTrue;
        }

        It "Unsupported version 10 so should Throw" {
            { Get-AnalysisServicesDeploymentExePath -Version 10 } | Should -Throw;
        }

        It "Invalid version XX should Throw" {
            { Get-AnalysisServicesDeploymentExePath -Version XX } | Should -Throw;
        }

        It "Does not find version <_> when nothing is installed" -ForEach @('22', '20', '16', '15', '14', '13', '12', '11') {
            Get-AnalysisServicesDeploymentExePath -Version $_ | Should -BeNullOrEmpty
        }

        It "Valid folder but Microsoft.AnalysisServices.Deployment.exe is not present in folder" {
            $env:CustomAsDwInstallLocation = (New-Item -Path (Join-Path -Path $TestDrive -ChildPath 'EmptyFolder') -ItemType Directory -Force).FullName
            ( Get-AnalysisServicesDeploymentExePath -Version 13 ) -like "*Microsoft.AnalysisServices.Deployment.exe" | Should -BeFalse;
        }

        It "Invalid folder location for CustomAsDwInstallLocation" {
            $env:CustomAsDwInstallLocation = Join-Path -Path $TestDrive -ChildPath 'xxx'
            { Get-AnalysisServicesDeploymentExePath -Version 13 } | Should -Throw;
        }

        It "Valid folder location and Microsoft.AnalysisServices.Deployment.exe present" {
            $exe = Set-FakeInstallLocation
            Get-AnalysisServicesDeploymentExePath -Version 11 | Should -Be $exe
        }

        It "Does not return the custom utility for a different version" {
            $null = Set-FakeInstallLocation
            Get-AnalysisServicesDeploymentExePath -Version 15 | Should -BeNullOrEmpty
        }
    }

    Context "Select-AnalysisServicesDeploymentExeVersion" {
        It "Should have PreferredVersion as a mandatory parameter" {
            (Get-Command Select-AnalysisServicesDeploymentExeVersion).Parameters['PreferredVersion'].Attributes.mandatory | Should -BeTrue;
        }

        It "Unsupported AnalysisServicesDeploymentExe version 10 so should Throw" {
            { Select-AnalysisServicesDeploymentExeVersion -PreferredVersion 10 } | Should -Throw;
        }

        It "Invalid version XX so should throw" {
            { Select-AnalysisServicesDeploymentExeVersion -PreferredVersion XX } | Should -Throw;
        }

        It "Returns nothing and warns when no utility is installed" {
            $result = Select-AnalysisServicesDeploymentExeVersion -PreferredVersion latest -WarningVariable warnings -WarningAction SilentlyContinue
            $result | Should -BeNullOrEmpty
            $warnings | Should -Not -BeNullOrEmpty
        }

        It "Finds latest version" {
            $null = Set-FakeInstallLocation
            Select-AnalysisServicesDeploymentExeVersion -PreferredVersion latest | Should -Be '11'
        }

        It "Now finds version 11" {
            $null = Set-FakeInstallLocation
            Select-AnalysisServicesDeploymentExeVersion -PreferredVersion 11 | Should -Be '11'
        }

        It "Falls back to an installed version when the preferred version is missing" {
            $null = Set-FakeInstallLocation
            Select-AnalysisServicesDeploymentExeVersion -PreferredVersion 15 -InformationAction SilentlyContinue | Should -Be '11'
        }

        It "Prefers the newest installed version" {
            $null = Set-FakeInstallLocation
            Mock -ModuleName DeployCube Get-AnalysisServicesDeploymentExePath -ParameterFilter { $Version -eq '16' } -MockWith { 'C:\Fake\Microsoft.AnalysisServices.Deployment.exe' }
            Select-AnalysisServicesDeploymentExeVersion -PreferredVersion latest | Should -Be '16'
        }
    }
}
