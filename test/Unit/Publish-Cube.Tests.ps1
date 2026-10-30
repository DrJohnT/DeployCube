BeforeAll {
    . (Join-Path -Path (Split-Path -Parent $PSScriptRoot) -ChildPath 'TestHelpers.ps1')
    Import-DeployCubeForTest

    # Publish-Cube sets $global:ErrorActionPreference = 'Stop' (assessment F03); restore it after every test.
    $script:OriginalGlobalErrorActionPreference = $global:ErrorActionPreference

    function Get-FixtureCopy {
        param([string]$Name)
        $path = Join-Path -Path (Join-Path -Path $TestDrive -ChildPath $Name) -ChildPath 'Model.asdatabase'
        if (-not (Test-Path -Path $path)) {
            $path = Copy-DeployCubeFixture -Name $Name -Destination $TestDrive
        }
        return $path
    }

    function Get-PathToCubeProject {
        return Get-FixtureCopy -Name 'InvalidDataSourceConnection'
    }

    function Get-MissingDeploymentTargets {
        return Get-FixtureCopy -Name 'MissingDeploymentTargets'
    }

    function Get-MissingDeploymentOptions {
        return Get-FixtureCopy -Name 'MissingDeploymentOptions'
    }

    # A real (tiny) executable with version information so Publish-Cube can read ProductVersion without SSDT/SSMS.
    function Get-FakeDeploymentExe {
        $folder = Join-Path -Path $TestDrive -ChildPath 'DeploymentWizard'
        $exe = Join-Path -Path $folder -ChildPath 'Microsoft.AnalysisServices.Deployment.exe'
        if (-not (Test-Path -Path $exe)) {
            $null = New-Item -Path $folder -ItemType Directory -Force
            Copy-Item -Path (Join-Path -Path (Get-DeployCubeFixturePath -Name 'DeploymentWizard') -ChildPath 'Microsoft.AnalysisServices.Deployment.exe') -Destination $exe
        }
        return $exe
    }
}

Describe "Publish-Cube" -Tag 'Unit' {
    AfterEach {
        $global:ErrorActionPreference = $script:OriginalGlobalErrorActionPreference
    }

    Context "Testing Inputs" {
        It "Should have AsDatabasePath as a mandatory parameter" {
            (Get-Command Publish-Cube).Parameters['AsDatabasePath'].Attributes.mandatory | Should -BeTrue;
        }
        It "Should have Server as a mandatory parameter" {
            (Get-Command Publish-Cube).Parameters['Server'].Attributes.mandatory | Should -BeTrue;
        }
        It "Should have CubeDatabase as an mandatory parameter" {
            (Get-Command Publish-Cube).Parameters['CubeDatabase'].Attributes.mandatory | Should -BeTrue;
        }
        It "Should have PreferredVersion as an optional parameter" {
            (Get-Command Publish-Cube).Parameters['PreferredVersion'].Attributes.mandatory | Should -BeFalse;
        }
        It "Should have ProcessingOption as an optional parameter" {
            (Get-Command Publish-Cube).Parameters['ProcessingOption'].Attributes.mandatory | Should -BeFalse;
        }
        It "Should have TransactionalDeployment as an optional parameter" {
            (Get-Command Publish-Cube).Parameters['TransactionalDeployment'].Attributes.mandatory | Should -BeFalse;
        }
        It "Should have PartitionDeployment as an optional parameter" {
            (Get-Command Publish-Cube).Parameters['PartitionDeployment'].Attributes.mandatory | Should -BeFalse;
        }
        It "Should have RoleDeployment as an optional parameter" {
            (Get-Command Publish-Cube).Parameters['RoleDeployment'].Attributes.mandatory | Should -BeFalse;
        }
        It "Should have ConfigurationSettingsDeployment as an optional parameter" {
            (Get-Command Publish-Cube).Parameters['ConfigurationSettingsDeployment'].Attributes.mandatory | Should -BeFalse;
        }
        It "Should have OptimizationSettingsDeployment as an optional parameter" {
            (Get-Command Publish-Cube).Parameters['OptimizationSettingsDeployment'].Attributes.mandatory | Should -BeFalse;
        }
        It "Should have WriteBackTableCreation as an optional parameter" {
            (Get-Command Publish-Cube).Parameters['WriteBackTableCreation'].Attributes.mandatory | Should -BeFalse;
        }
    }

    Context "Testing Inputs for alias Deploy-Cube" {
        It "Should have AsDatabasePath as a mandatory parameter" {
            (Get-Alias Deploy-Cube).Parameters['AsDatabasePath'].Attributes.mandatory | Should -BeTrue;
        }
        It "Should have Server as a mandatory parameter" {
            (Get-Alias Deploy-Cube).Parameters['Server'].Attributes.mandatory | Should -BeTrue;
        }
        It "Should have CubeDatabase as an mandatory parameter" {
            (Get-Alias Deploy-Cube).Parameters['CubeDatabase'].Attributes.mandatory | Should -BeTrue;
        }
        It "Should have PreferredVersion as an optional parameter" {
            (Get-Alias Deploy-Cube).Parameters['PreferredVersion'].Attributes.mandatory | Should -BeFalse;
        }
        It "Should have ProcessingOption as an optional parameter" {
            (Get-Alias Deploy-Cube).Parameters['ProcessingOption'].Attributes.mandatory | Should -BeFalse;
        }
    }

    Context "Invalid AnalysisServicesDeploymentExe" {
        BeforeAll {
            Mock -ModuleName DeployCube Invoke-ExternalCommand {}
        }

        It "Invalid AnalysisServicesDeploymentExe path" {
            $AsDatabasePath = Get-PathToCubeProject;
            Mock -ModuleName DeployCube Get-AnalysisServicesDeploymentExePath { return (Join-Path -Path $TestDrive -ChildPath 'NoSqlPackage') };
            Mock -ModuleName DeployCube Select-AnalysisServicesDeploymentExeVersion { return '15' };
            { Publish-Cube -AsDatabasePath $AsDatabasePath -Server "localhost" -CubeDatabase "MyTabularCube" -PreferredVersion latest } | Should -Throw -ExpectedMessage '*Could not find Microsoft.AnalysisServices.Deployment.exe*';
            Should -Invoke -ModuleName DeployCube Invoke-ExternalCommand -Times 0 -Exactly
        }
    }

    Context "Invalid Inputs" {
        BeforeAll {
            Mock -ModuleName DeployCube Invoke-ExternalCommand {}
            Mock -ModuleName DeployCube Select-AnalysisServicesDeploymentExeVersion { return '15' }
            Mock -ModuleName DeployCube Get-AnalysisServicesDeploymentExePath { return (Get-FakeDeploymentExe) }
        }

        It "Invalid ProcessingOption should Throw" {
            $AsDatabasePath = Get-PathToCubeProject;
            { Publish-Cube -AsDatabasePath $AsDatabasePath -Server "localhost" -CubeDatabase "MyTabularCube" -PreferredVersion latest -ProcessingOption "fsadsa" } | Should -Throw;
        }

        It "Invalid AsDatabasePath should Throw" {
            { Publish-Cube -AsDatabasePath (Join-Path -Path $TestDrive -ChildPath 'NoAsDatabasePath') -Server "localhost" -CubeDatabase "MyTabularCube" -PreferredVersion latest } | Should -Throw -ExpectedMessage '*AsDatabase path does not exist*';
        }

        It "Invalid PreferredVersion Should Throw" {
            $AsDatabasePath = Get-PathToCubeProject;
            { Publish-Cube -AsDatabasePath $AsDatabasePath -Server "localhost" -CubeDatabase "MyTabularCubePreferredVersion" -PreferredVersion "SomethingSilly" } | Should -Throw;
        }

        It "Empty Server" {
            $AsDatabasePath = Get-PathToCubeProject;
            { Publish-Cube -AsDatabasePath $AsDatabasePath -Server "" -CubeDatabase "MyTabularCubeInvalidServer" -PreferredVersion latest } | Should -Throw;
        }

        It "Null Server" {
            $AsDatabasePath = Get-PathToCubeProject;
            { Publish-Cube -AsDatabasePath $AsDatabasePath -Server $null -CubeDatabase "MyTabularCubeInvalidServer" -PreferredVersion latest } | Should -Throw;
        }

        It "Empty CubeDatabase" {
            $AsDatabasePath = Get-PathToCubeProject;
            { Publish-Cube -AsDatabasePath $AsDatabasePath -Server "MyServer" -CubeDatabase "" -PreferredVersion latest } | Should -Throw;
        }

        It "Null CubeDatabase" {
            $AsDatabasePath = Get-PathToCubeProject;
            { Publish-Cube -AsDatabasePath $AsDatabasePath -Server "MyServer" -CubeDatabase $null -PreferredVersion latest } | Should -Throw;
        }

        It "Invalid ProcessingOption SomethingSilly should Throw" {
            $AsDatabasePath = Get-PathToCubeProject;
            { Publish-Cube -AsDatabasePath $AsDatabasePath -Server "MyServer" -CubeDatabase "MyTabularCube" -PreferredVersion latest -ProcessingOption "SomethingSilly" } | Should -Throw;
        }

        It "Invalid TransactionalDeployment should Throw" {
            $AsDatabasePath = Get-PathToCubeProject;
            { Publish-Cube -AsDatabasePath $AsDatabasePath -Server "MyServer" -CubeDatabase "MyTabularCube" -TransactionalDeployment "SomethingSilly" } | Should -Throw;
        }
        It "Invalid PartitionDeployment should Throw" {
            $AsDatabasePath = Get-PathToCubeProject;
            { Publish-Cube -AsDatabasePath $AsDatabasePath -Server "MyServer" -CubeDatabase "MyTabularCube" -PartitionDeployment "SomethingSilly" } | Should -Throw;
        }
        It "Invalid RoleDeployment should Throw" {
            $AsDatabasePath = Get-PathToCubeProject;
            { Publish-Cube -AsDatabasePath $AsDatabasePath -Server "MyServer" -CubeDatabase "MyTabularCube" -RoleDeployment "SomethingSilly" } | Should -Throw;
        }
        It "Invalid ConfigurationSettingsDeployment should Throw" {
            $AsDatabasePath = Get-PathToCubeProject;
            { Publish-Cube -AsDatabasePath $AsDatabasePath -Server "MyServer" -CubeDatabase "MyTabularCube" -ConfigurationSettingsDeployment "SomethingSilly" } | Should -Throw;
        }
        It "Invalid OptimizationSettingsDeployment should Throw" {
            $AsDatabasePath = Get-PathToCubeProject;
            { Publish-Cube -AsDatabasePath $AsDatabasePath -Server "MyServer" -CubeDatabase "MyTabularCube" -OptimizationSettingsDeployment "SomethingSilly" } | Should -Throw;
        }
        It "Invalid WriteBackTableCreation should Throw" {
            $AsDatabasePath = Get-PathToCubeProject;
            { Publish-Cube -AsDatabasePath $AsDatabasePath -Server "MyServer" -CubeDatabase "MyTabularCube" -WriteBackTableCreation "SomethingSilly" } | Should -Throw;
        }

        It "Missing DeploymentTargets should Throw" {
            $MissingDeploymentTargets = Get-MissingDeploymentTargets;
            { Publish-Cube -AsDatabasePath $MissingDeploymentTargets -Server "MyServer" -CubeDatabase "MyTabularCube" -PreferredVersion latest } | Should -Throw -ExpectedMessage '*deploymenttargets file does not exist*';
        }

        It "Missing DeploymentOptions should Throw" {
            $MissingDeploymentOptions = Get-MissingDeploymentOptions;
            { Publish-Cube -AsDatabasePath $MissingDeploymentOptions -Server "MyServer" -CubeDatabase "MyTabularCube" -PreferredVersion latest } | Should -Throw -ExpectedMessage '*deploymentoptions file does not exist*';
        }

        It "Invalid inputs never invoke the deployment utility" {
            Should -Invoke -ModuleName DeployCube Invoke-ExternalCommand -Times 0 -Exactly -Scope Context
        }
    }

    Context "Valid Parameters with mocked Invoke-ExternalCommand" {
        BeforeAll {
            Mock -ModuleName DeployCube Invoke-ExternalCommand {}
            Mock -ModuleName DeployCube Select-AnalysisServicesDeploymentExeVersion { return '15' }
            Mock -ModuleName DeployCube Get-AnalysisServicesDeploymentExePath { return (Get-FakeDeploymentExe) }
        }

        It "Miniumal valid Parameters" {
            $AsDatabasePath = Get-PathToCubeProject;
            { Publish-Cube -AsDatabasePath $AsDatabasePath -Server "localhost" -CubeDatabase "MyTabularCube" } | Should -Not -Throw;
        }

        It "Specific PreferredVersion should not Throw" {
            $AsDatabasePath = Get-PathToCubeProject;
            { Publish-Cube -AsDatabasePath $AsDatabasePath -Server "localhost" -CubeDatabase "MyTabularCube" -PreferredVersion 15 } | Should -Not -Throw;
            Should -Invoke -ModuleName DeployCube Select-AnalysisServicesDeploymentExeVersion -ParameterFilter { $PreferredVersion -eq '15' }
        }

        It "Missing PreferredVersion defaults to latest" {
            $AsDatabasePath = Get-PathToCubeProject;
            { Publish-Cube -AsDatabasePath $AsDatabasePath -Server "localhost" -CubeDatabase "MyTabularCube" } | Should -Not -Throw;
            Should -Invoke -ModuleName DeployCube Select-AnalysisServicesDeploymentExeVersion -ParameterFilter { $PreferredVersion -eq 'latest' }
        }

        It "Writes ProcessingOption <ProcessingOption> into the deploymentoptions file read by the utility" -ForEach @(
            @{ ProcessingOption = 'Full' }, @{ ProcessingOption = 'Default' }, @{ ProcessingOption = 'DoNotProcess' }
        ) {
            $AsDatabasePath = Get-PathToCubeProject;
            $optionsPath = [System.IO.Path]::ChangeExtension($AsDatabasePath, 'deploymentoptions')
            Publish-Cube -AsDatabasePath $AsDatabasePath -Server "localhost" -CubeDatabase "MyTabularCube" -ProcessingOption $ProcessingOption | Out-Null;
            ([xml](Get-Content -Path $optionsPath)).DeploymentOptions.ProcessingOption | Should -Be $ProcessingOption
        }

        It "Defaults ProcessingOption to DoNotProcess, overriding the value in the deploymentoptions file" {
            $AsDatabasePath = Get-PathToCubeProject;
            $optionsPath = [System.IO.Path]::ChangeExtension($AsDatabasePath, 'deploymentoptions')
            Publish-Cube -AsDatabasePath $AsDatabasePath -Server "localhost" -CubeDatabase "MyTabularCube" -ProcessingOption Full | Out-Null;
            Publish-Cube -AsDatabasePath $AsDatabasePath -Server "localhost" -CubeDatabase "MyTabularCube" | Out-Null;
            ([xml](Get-Content -Path $optionsPath)).DeploymentOptions.ProcessingOption | Should -Be 'DoNotProcess'
        }

        It "Invokes the deployment utility once in silent mode with the asdatabase file and a log path" {
            $AsDatabasePath = Get-PathToCubeProject;
            $Exe = Get-FakeDeploymentExe;
            Publish-Cube -AsDatabasePath $AsDatabasePath -Server "localhost" -CubeDatabase "MyTabularCube" | Out-Null;
            Should -Invoke -ModuleName DeployCube Invoke-ExternalCommand -Times 1 -Exactly -ParameterFilter {
                $Command -eq $Exe -and
                $Arguments.Count -eq 2 -and
                $Arguments[0] -eq $AsDatabasePath -and
                $Arguments[1] -like '/s:*AnalysisServicesDeploymentExeLog.txt' -and
                $PipeOutNull -eq $true
            }
        }

        It "Writes the target server and database into the deploymenttargets file before deploying" {
            $AsDatabasePath = Get-PathToCubeProject;
            Publish-Cube -AsDatabasePath $AsDatabasePath -Server "UnitTestServer" -CubeDatabase "UnitTestCube" | Out-Null;
            $targetsPath = [System.IO.Path]::ChangeExtension($AsDatabasePath, 'deploymenttargets')
            [xml]$targets = Get-Content -Path $targetsPath
            $targets.DeploymentTarget.Server | Should -Be 'UnitTestServer'
            $targets.DeploymentTarget.Database | Should -Be 'UnitTestCube'
        }

        It "Reports the resolved parameters on the output stream" {
            $AsDatabasePath = Get-PathToCubeProject;
            $output = Publish-Cube -AsDatabasePath $AsDatabasePath -Server "localhost" -CubeDatabase "MyTabularCube" -ProcessingOption Full;
            ($output -join "`n") | Should -BeLike '*ProcessingOption*: Full*'
            ($output -join "`n") | Should -BeLike '*v11*'
        }

        It "Characterization: leaves the global ErrorActionPreference set to Stop (assessment F03)" {
            $global:ErrorActionPreference = 'Continue'
            $AsDatabasePath = Get-PathToCubeProject;
            Publish-Cube -AsDatabasePath $AsDatabasePath -Server "localhost" -CubeDatabase "MyTabularCube" | Out-Null;
            $global:ErrorActionPreference | Should -Be 'Stop'
        }
    }

    Context "Deployment utility failure" {
        BeforeAll {
            Mock -ModuleName DeployCube Select-AnalysisServicesDeploymentExeVersion { return '15' }
            Mock -ModuleName DeployCube Get-AnalysisServicesDeploymentExePath { return (Get-FakeDeploymentExe) }
            Mock -ModuleName DeployCube Write-Host {}
        }

        It "Throws and surfaces the utility log when the deployment utility returns a non-zero exit code" {
            Mock -ModuleName DeployCube Invoke-ExternalCommand {
                $logPath = $Arguments[1].Substring(3)
                Set-Content -Path $logPath -Value 'Simulated deployment failure'
                throw "Error executing $Command"
            }
            $AsDatabasePath = Get-PathToCubeProject;
            { Publish-Cube -AsDatabasePath $AsDatabasePath -Server "localhost" -CubeDatabase "MyTabularCube" } | Should -Throw -ExpectedMessage '*Error executing*Microsoft.AnalysisServices.Deployment.exe*';
            Should -Invoke -ModuleName DeployCube Write-Host -ParameterFilter { "$Object" -eq 'Simulated deployment failure' }
        }

        It "Characterization: when the utility fails without writing a log, the missing log masks the real error (assessment F04)" {
            Mock -ModuleName DeployCube Invoke-ExternalCommand { throw "Error executing $Command" }
            $AsDatabasePath = Get-PathToCubeProject;
            # Current behaviour: reading the absent log throws first, so 'Error executing ...' never reaches the caller.
            # Update this expectation when F04 is fixed.
            { Publish-Cube -AsDatabasePath $AsDatabasePath -Server "localhost" -CubeDatabase "MyTabularCube" } | Should -Throw -ExpectedMessage '*AnalysisServicesDeploymentExeLog.txt*';
        }
    }
}
