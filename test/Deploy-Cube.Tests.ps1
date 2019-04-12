$CurrentFolder = Split-Path -Parent $MyInvocation.MyCommand.Path;
$ModulePath = Resolve-Path "$CurrentFolder\..\DeployCube\DeployCube.psd1";
import-Module -Name $ModulePath;

$exampleFolder =  Resolve-Path "$CurrentFolder\..\examples";
$AsDatabasePath = Resolve-Path "$exampleFolder\CubeToPublish\MyTabularProject\bin\Model.asdatabase";
$MissingDeploymentTargets = Resolve-Path "$exampleFolder\CubeToPublish\ForTests\MissingDeploymentTargets\Model.asdatabase";
$MissingDeploymentOptions = Resolve-Path "$exampleFolder\CubeToPublish\ForTests\MissingDeploymentOptions\Model.asdatabase";


Describe "Deploy-Cube" {
    Context "Testing Inputs" {
        It "Should have AsDatabasePath as a mandatory parameter" {
            (Get-Command Deploy-Cube).Parameters['AsDatabasePath'].Attributes.mandatory | Should -Be $true;
        }
        It "Should have TargetServerName as a mandatory parameter" {
            (Get-Command Deploy-Cube).Parameters['TargetServerName'].Attributes.mandatory | Should -Be $true;
        }
        It "Should have TargetDatabaseName as an optional parameter" {
            (Get-Command Deploy-Cube).Parameters['TargetDatabaseName'].Attributes.mandatory | Should -Be $false;
        }
        It "Should have PreferredVersion as an optional parameter" {
            (Get-Command Deploy-Cube).Parameters['PreferredVersion'].Attributes.mandatory | Should -Be $false;
        }
        It "Should have ProcessingOption as an optional parameter" {
            (Get-Command Deploy-Cube).Parameters['ProcessingOption'].Attributes.mandatory | Should -Be $false;
        }

    }

    Context "Invalid AnalysisServicesDeploymentExe" {
        It "Invalid AnalysisServicesDeploymentExe path" {
            Mock -ModuleName DeployCube Get-AnalysisServicesDeploymentExePath { return "NoSqlPackage" };
            Mock -ModuleName DeployCube Select-AnalysisServicesDeploymentExeVersion { return 150 };
            { Deploy-Cube -AsDatabasePath $AsDatabasePath -TargetServerName "localhost" -TargetDatabaseName "MyTabularCube" -PreferredVersion latest } | Should Throw;
        }
    }

    Context "Invalid Parameters" {
        Mock -ModuleName DeployCube Invoke-ExternalCommand;
        It "Invalid ProcessingOption should Throw" {
            { Deploy-Cube -AsDatabasePath $AsDatabasePath -TargetServerName "localhost" -TargetDatabaseName "MyTabularCube" -PreferredVersion latest $ProcessingOption "fsadsa" } | Should Throw;
        }

        It "Invalid AsDatabasePath path" {
            { Deploy-Cube -AsDatabasePath "NoDacPac" -TargetServerName "localhost" -TargetDatabaseName "MyTabularCube" -PreferredVersion latest } | Should Throw;
        }

        It "Invalid PreferredVersion Should Throw" {
            { Deploy-Cube -AsDatabasePath $AsDatabasePath -TargetServerName "localhost" -TargetDatabaseName "MyTabularCubePreferredVersion" -PreferredVersion "SomethingSilly" } | Should Throw;
        }

        It "Invalid TargetServerName" {
            { Deploy-Cube -AsDatabasePath $AsDatabasePath -TargetServerName "MyTabularCubeInvalidServer" -TargetDatabaseName "MyDB" -PreferredVersion latest } | Should Throw;
        }

        It "Empty TargetServerName" {
            { Deploy-Cube -AsDatabasePath $AsDatabasePath -TargetServerName "" -TargetDatabaseName "MyTabularCubeInvalidServer" -PreferredVersion latest } | Should Throw;
        }

        It "Null TargetServerName" {
            { Deploy-Cube -AsDatabasePath $AsDatabasePath -TargetServerName $null -TargetDatabaseName "MyTabularCubeInvalidServer" -PreferredVersion latest } | Should Throw;
        }

        It "Empty TargetDatabaseName" {
            { Deploy-Cube -AsDatabasePath $AsDatabasePath -TargetServerName "MyServer" -TargetDatabaseName "" -PreferredVersion latest } | Should Throw;
        }

        It "Empty TargetDatabaseName" {
            { Deploy-Cube -AsDatabasePath $AsDatabasePath -TargetServerName "MyServer" -TargetDatabaseName $null -PreferredVersion latest } | Should Throw;
        }

        It "Invalid ProcessingOption should Throw" {
            { Deploy-Cube -AsDatabasePath $AsDatabasePath -TargetServerName "MyServer" -TargetDatabaseName "MyTabularCubeInvalidServer" -PreferredVersion latest -ProcessingOption "SomethingSilly" } | Should Throw;
        }

        It "Missing DeploymentTargets should Throw" {
            { Deploy-Cube -AsDatabasePath $MissingDeploymentTargets -TargetServerName "MyServer" -TargetDatabaseName "MyTabularCubeInvalidServer" -PreferredVersion latest } | Should Throw;
        }

        It "Missing DeploymentOptions should Throw" {
            { Deploy-Cube -AsDatabasePath $MissingDeploymentOptions -TargetServerName "MyServer" -TargetDatabaseName "MyTabularCubeInvalidServer" -PreferredVersion latest } | Should Throw;
        }
    }

    Context "Valid Parameters with mocked Invoke-ExternalCommand" {
        Mock -ModuleName DeployCube Invoke-ExternalCommand;
        It "Valid Parameters" {
            Deploy-Cube -AsDatabasePath $AsDatabasePath -TargetServerName "MyServer" -TargetDatabaseName "MyTabularCubeInvalidServer" -PreferredVersion latest
           # Deploy-Cube -AsDatabasePath $AsDatabasePath -TargetServerName "localhost" -TargetDatabaseName "MyTabularCube" -PreferredVersion latest
        #} | Should Not Throw;;
        }
    }

    Context "Valid parameters so deploy" {
        It "Valid parameters so deploy MyTabularCube4 cube" {
            #{ Deploy-Cube -AsDatabasePath $AsDatabasePath -TargetServerName "localhost" -TargetDatabaseName "MyTabularCube4" -PreferredVersion latest } | Should Not Throw;;
        }
    }
}

Remove-Module -Name DeployCube