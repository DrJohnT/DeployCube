BeforeAll { 
    $CurrentFolder = Split-Path -Parent $PSScriptRoot;
    $ModulePath = Resolve-Path "$CurrentFolder\DeployCube\DeployCube.psd1";
    import-Module -Name $ModulePath;

    function Get-PathToCubeProject {
        $CurrentFolder = Split-Path -Parent $PSScriptRoot;
        return Resolve-Path "$CurrentFolder\examples\CubeToPublish\MyTabularProject\bin\Model.asdatabase";
    }

    function Get-MissingDeploymentTargets {
        $CurrentFolder = Split-Path -Parent $PSScriptRoot;
        return Resolve-Path "$CurrentFolder\examples\CubeToPublish\ForTests\MissingDeploymentTargets\Model.asdatabase";
    }

    function Get-MissingDeploymentOptions {
        $CurrentFolder = Split-Path -Parent $PSScriptRoot;
        return Resolve-Path "$CurrentFolder\examples\CubeToPublish\ForTests\MissingDeploymentOptions\Model.asdatabase";
    }
}

Describe "Publish-Cube" -Tag "Round3" {
    Context "Testing Inputs" {
        It "Should have AsDatabasePath as a mandatory parameter" {
            (Get-Command Publish-Cube).Parameters['AsDatabasePath'].Attributes.mandatory | Should -Be $true;
        }
        It "Should have Server as a mandatory parameter" {
            (Get-Command Publish-Cube).Parameters['Server'].Attributes.mandatory | Should -Be $true;
        }
        It "Should have CubeDatabase as an mandatory parameter" {
            (Get-Command Publish-Cube).Parameters['CubeDatabase'].Attributes.mandatory | Should -Be $true;
        }
        It "Should have PreferredVersion as an optional parameter" {
            (Get-Command Publish-Cube).Parameters['PreferredVersion'].Attributes.mandatory | Should -Be $false;
        }
        It "Should have ProcessingOption as an optional parameter" {
            (Get-Command Publish-Cube).Parameters['ProcessingOption'].Attributes.mandatory | Should -Be $false;
        }
        It "Should have TransactionalDeployment as an optional parameter" {
            (Get-Command Publish-Cube).Parameters['TransactionalDeployment'].Attributes.mandatory | Should -Be $false;
        }
        It "Should have PartitionDeployment as an optional parameter" {
            (Get-Command Publish-Cube).Parameters['PartitionDeployment'].Attributes.mandatory | Should -Be $false;
        }
        It "Should have RoleDeployment as an optional parameter" {
            (Get-Command Publish-Cube).Parameters['RoleDeployment'].Attributes.mandatory | Should -Be $false;
        }
        It "Should have ConfigurationSettingsDeployment as an optional parameter" {
            (Get-Command Publish-Cube).Parameters['ConfigurationSettingsDeployment'].Attributes.mandatory | Should -Be $false;
        }
        It "Should have OptimizationSettingsDeployment as an optional parameter" {
            (Get-Command Publish-Cube).Parameters['OptimizationSettingsDeployment'].Attributes.mandatory | Should -Be $false;
        }
        It "Should have WriteBackTableCreation as an optional parameter" {
            (Get-Command Publish-Cube).Parameters['WriteBackTableCreation'].Attributes.mandatory | Should -Be $false;
        }
    }

    Context "Testing Inputs for alias Deploy-Cube" {
        It "Should have AsDatabasePath as a mandatory parameter" {
            (Get-Alias Deploy-Cube).Parameters['AsDatabasePath'].Attributes.mandatory | Should -Be $true;
        }
        It "Should have Server as a mandatory parameter" {
            (Get-Alias Deploy-Cube).Parameters['Server'].Attributes.mandatory | Should -Be $true;
        }
        It "Should have CubeDatabase as an mandatory parameter" {
            (Get-Alias Deploy-Cube).Parameters['CubeDatabase'].Attributes.mandatory | Should -Be $true;
        }
        It "Should have PreferredVersion as an optional parameter" {
            (Get-Alias Deploy-Cube).Parameters['PreferredVersion'].Attributes.mandatory | Should -Be $false;
        }
        It "Should have ProcessingOption as an optional parameter" {
            (Get-Alias Deploy-Cube).Parameters['ProcessingOption'].Attributes.mandatory | Should -Be $false;
        }

    }


    Context "Invalid AnalysisServicesDeploymentExe" {
        It "Invalid AnalysisServicesDeploymentExe path" {
            $AsDatabasePath = Get-PathToCubeProject;
            Mock -ModuleName DeployCube Get-AnalysisServicesDeploymentExePath { return "NoSqlPackage" };
            Mock -ModuleName DeployCube Select-AnalysisServicesDeploymentExeVersion { return 150 };
            { Publish-Cube -AsDatabasePath $AsDatabasePath -Server "localhost" -CubeDatabase "MyTabularCube" -PreferredVersion latest } | Should -Throw;
        }
    }

    Context "Invalid Inputs" {
        Mock -ModuleName DeployCube Invoke-ExternalCommand;
        It "Invalid ProcessingOption should Throw" {
            $AsDatabasePath = Get-PathToCubeProject;
            { Publish-Cube -AsDatabasePath $AsDatabasePath -Server "localhost" -CubeDatabase "MyTabularCube" -PreferredVersion latest $ProcessingOption "fsadsa" } | Should -Throw;
        }

        It "Invalid AsDatabasePath should Throw" {
            { Publish-Cube -AsDatabasePath "NoAsDatabasePath" -Server "localhost" -CubeDatabase "MyTabularCube" -PreferredVersion latest } | Should -Throw;
        }

        It "Invalid PreferredVersion Should Throw" {
            $AsDatabasePath = Get-PathToCubeProject;
            { Publish-Cube -AsDatabasePath $AsDatabasePath -Server "localhost" -CubeDatabase "MyTabularCubePreferredVersion" -PreferredVersion "SomethingSilly" } | Should -Throw;
        }

        It "Invalid Server should Throw" {
            $AsDatabasePath = Get-PathToCubeProject;
            { Publish-Cube -AsDatabasePath $AsDatabasePath -Server "MyTabularCubeInvalidServer" -CubeDatabase "MyDB" -PreferredVersion latest } | Should -Throw;
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

        It "Empty CubeDatabase" {
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
            { Publish-Cube -AsDatabasePath $MissingDeploymentTargets -Server "MyServer" -CubeDatabase "MyTabularCube" -PreferredVersion latest } | Should -Throw;
        }

        It "Missing DeploymentOptions should Throw" {
            $MissingDeploymentOptions = Get-MissingDeploymentOptions;
            { Publish-Cube -AsDatabasePath $MissingDeploymentOptions -Server "MyServer" -CubeDatabase "MyTabularCube" -PreferredVersion latest } | Should -Throw;
        }
    }

    Context "Valid Parameters with mocked Invoke-ExternalCommand" {
        Mock -ModuleName DeployCube Invoke-ExternalCommand;
        It "Miniumal valid Parameters" {
            $AsDatabasePath = Get-PathToCubeProject;
            { Publish-Cube -AsDatabasePath $AsDatabasePath -Server "localhost" -CubeDatabase "MyTabularCube" } | Should -Not -Throw;
        }

        It "Specific PreferredVersion should not Throw" {
            $AsDatabasePath = Get-PathToCubeProject;
            { Publish-Cube -AsDatabasePath $AsDatabasePath -Server "localhost" -CubeDatabase "MyTabularCube" -PreferredVersion 15 } | Should -Not -Throw;
        }

        It "Missing PreferredVersion should not Throw" {
            $AsDatabasePath = Get-PathToCubeProject;
            { Publish-Cube -AsDatabasePath $AsDatabasePath -Server "localhost" -CubeDatabase "MyTabularCube" } | Should -Not -Throw;
        }

        It "Adding ProcessingOption should not Throw" {
            $AsDatabasePath = Get-PathToCubeProject;
            { Publish-Cube -AsDatabasePath $AsDatabasePath -Server "localhost" -CubeDatabase "MyTabularCube" -ProcessingOption "Full" } | Should -Not -Throw;
        }
    }

    Context "Valid parameters so deploy" {
        It "Valid parameters so deploy a cube and test it is present" {
            $CubeDatabase = New-Guid;  # this ensures we cannot fake the test result
            $AsDatabasePath = Get-PathToCubeProject;
            Publish-Cube -AsDatabasePath $AsDatabasePath -Server "localhost" -CubeDatabase $CubeDatabase;
            ( Ping-SsasDatabase -Server "localhost" -CubeDatabase $CubeDatabase ) | Should -Be $true;
            # clean up
            Unpublish-Cube -Server "localhost" -CubeDatabase $CubeDatabase;
        }
    }
}

AfterAll {
    Remove-Module -Name DeployCube
}