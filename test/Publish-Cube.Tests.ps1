$CurrentFolder = Split-Path -Parent $MyInvocation.MyCommand.Path;
$ModulePath = Resolve-Path "$CurrentFolder\..\DeployCube\DeployCube.psd1";
import-Module -Name $ModulePath;

$exampleFolder =  Resolve-Path "$CurrentFolder\..\examples";
$AsDatabasePath = Resolve-Path "$exampleFolder\CubeToPublish\MyTabularProject\bin\Model.asdatabase";
$MissingDeploymentTargets = Resolve-Path "$exampleFolder\CubeToPublish\ForTests\MissingDeploymentTargets\Model.asdatabase";
$MissingDeploymentOptions = Resolve-Path "$exampleFolder\CubeToPublish\ForTests\MissingDeploymentOptions\Model.asdatabase";


Describe "Publish-Cube" {
    Context "Testing Inputs" {
        It "Should have AsDatabasePath as a mandatory parameter" {
            (Get-Command Publish-Cube).Parameters['AsDatabasePath'].Attributes.mandatory | Should -Be $true;
        }
        It "Should have Server as a mandatory parameter" {
            (Get-Command Publish-Cube).Parameters['Server'].Attributes.mandatory | Should -Be $true;
        }
        It "Should have CubeDatabase as an optional parameter" {
            (Get-Command Publish-Cube).Parameters['CubeDatabase'].Attributes.mandatory | Should -Be $false;
        }
        It "Should have PreferredVersion as an optional parameter" {
            (Get-Command Publish-Cube).Parameters['PreferredVersion'].Attributes.mandatory | Should -Be $false;
        }
        It "Should have ProcessingOption as an optional parameter" {
            (Get-Command Publish-Cube).Parameters['ProcessingOption'].Attributes.mandatory | Should -Be $false;
        }

    }

    Context "Testing Inputs for alias Deploy-Cube" {
        It "Should have AsDatabasePath as a mandatory parameter" {
            (Get-Alias Deploy-Cube).Parameters['AsDatabasePath'].Attributes.mandatory | Should -Be $true;
        }
        It "Should have Server as a mandatory parameter" {
            (Get-Alias Deploy-Cube).Parameters['Server'].Attributes.mandatory | Should -Be $true;
        }
        It "Should have CubeDatabase as an optional parameter" {
            (Get-Alias Deploy-Cube).Parameters['CubeDatabase'].Attributes.mandatory | Should -Be $false;
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
            Mock -ModuleName DeployCube Get-AnalysisServicesDeploymentExePath { return "NoSqlPackage" };
            Mock -ModuleName DeployCube Select-AnalysisServicesDeploymentExeVersion { return 150 };
            { Publish-Cube -AsDatabasePath $AsDatabasePath -Server "localhost" -CubeDatabase "MyTabularCube" -PreferredVersion latest } | Should Throw;
        }
    }

    Context "Invalid Parameters" {
        Mock -ModuleName DeployCube Invoke-ExternalCommand;
        It "Invalid ProcessingOption should Throw" {
            { Publish-Cube -AsDatabasePath $AsDatabasePath -Server "localhost" -CubeDatabase "MyTabularCube" -PreferredVersion latest $ProcessingOption "fsadsa" } | Should Throw;
        }

        It "Invalid AsDatabasePath should Throw" {
            { Publish-Cube -AsDatabasePath "NoAsDatabasePath" -Server "localhost" -CubeDatabase "MyTabularCube" -PreferredVersion latest } | Should Throw;
        }

        It "Invalid PreferredVersion Should Throw" {
            { Publish-Cube -AsDatabasePath $AsDatabasePath -Server "localhost" -CubeDatabase "MyTabularCubePreferredVersion" -PreferredVersion "SomethingSilly" } | Should Throw;
        }

        It "Invalid Server should Throw" {
            { Publish-Cube -AsDatabasePath $AsDatabasePath -Server "MyTabularCubeInvalidServer" -CubeDatabase "MyDB" -PreferredVersion latest } | Should Throw;
        }

        It "Empty Server" {
            { Publish-Cube -AsDatabasePath $AsDatabasePath -Server "" -CubeDatabase "MyTabularCubeInvalidServer" -PreferredVersion latest } | Should Throw;
        }

        It "Null Server" {
            { Publish-Cube -AsDatabasePath $AsDatabasePath -Server $null -CubeDatabase "MyTabularCubeInvalidServer" -PreferredVersion latest } | Should Throw;
        }

        It "Empty CubeDatabase" {
            { Publish-Cube -AsDatabasePath $AsDatabasePath -Server "MyServer" -CubeDatabase "" -PreferredVersion latest } | Should Throw;
        }

        It "Empty CubeDatabase" {
            { Publish-Cube -AsDatabasePath $AsDatabasePath -Server "MyServer" -CubeDatabase $null -PreferredVersion latest } | Should Throw;
        }

        It "Invalid ProcessingOption should Throw" {
            { Publish-Cube -AsDatabasePath $AsDatabasePath -Server "MyServer" -CubeDatabase "MyTabularCube" -PreferredVersion latest -ProcessingOption "SomethingSilly" } | Should Throw;
        }

        It "Missing DeploymentTargets should Throw" {
            { Publish-Cube -AsDatabasePath $MissingDeploymentTargets -Server "MyServer" -CubeDatabase "MyTabularCube" -PreferredVersion latest } | Should Throw;
        }

        It "Missing DeploymentOptions should Throw" {
            { Publish-Cube -AsDatabasePath $MissingDeploymentOptions -Server "MyServer" -CubeDatabase "MyTabularCube" -PreferredVersion latest } | Should Throw;
        }
    }

    Context "Valid Parameters with mocked Invoke-ExternalCommand" {
        Mock -ModuleName DeployCube Invoke-ExternalCommand;
        It "Miniumal valid Parameters" {
            { Publish-Cube -AsDatabasePath $AsDatabasePath -Server "localhost" } | Should Not Throw;;
        }

        It "Specific PreferredVersion should not Throw" {
            { Publish-Cube -AsDatabasePath $AsDatabasePath -Server "localhost" -PreferredVersion 150 } | Should Not Throw;
        }

        It "Missing PreferredVersion should not Throw" {
            { Publish-Cube -AsDatabasePath $AsDatabasePath -Server "localhost" -CubeDatabase "MyTabularCube" } | Should Not Throw;
        }

        It "Adding ProcessingOption should not Throw" {
            { Publish-Cube -AsDatabasePath $AsDatabasePath -Server "localhost" -ProcessingOption "ProcessFull" } | Should Not Throw;
        }
    }

    Context "Valid parameters so deploy" {
        It "Valid parameters so deploy a cube and test it is present" {
            $CubeDatabase = New-Guid;  # this ensures we cannot fake the test result
            Publish-Cube -AsDatabasePath $AsDatabasePath -Server "localhost" -CubeDatabase $CubeDatabase;
            ( Ping-SsasDatabase -Server "localhost" -CubeDatabase $CubeDatabase ) | Should Be $true;
            # clean up
            Unpublish-Cube -Server "localhost" -CubeDatabase $CubeDatabase;
        }
    }
}

Remove-Module -Name DeployCube