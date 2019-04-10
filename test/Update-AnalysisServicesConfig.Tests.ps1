$CurrentFolder = Split-Path -Parent $MyInvocation.MyCommand.Path;
$ModulePath = Resolve-Path "$CurrentFolder\..\DeployCube\DeployCube.psd1";
import-Module -Name $ModulePath;

$exampleFolder =  Resolve-Path "$CurrentFolder\..\examples";
$AsDatabasePath = Resolve-Path "$exampleFolder\CubeToPublish\MyTabularProject\bin\Model.asdatabase";
$MissingDeploymentTargets = Resolve-Path "$exampleFolder\CubeToPublish\ForTests\MissingDeploymentTargets\Model.asdatabase";
$MissingDeploymentOptions = Resolve-Path "$exampleFolder\CubeToPublish\ForTests\MissingDeploymentOptions\Model.asdatabase";

Describe "Update-AnalysisServicesConfig" {
    Context "Testing Inputs" {
        It "Should have AsDatabasePath as a mandatory parameter" {
            (Get-Command Update-AnalysisServicesConfig).Parameters['AsDatabasePath'].Attributes.mandatory | Should -Be $true;
        }
        It "Should have TargetServerName as a mandatory parameter" {
            (Get-Command Update-AnalysisServicesConfig).Parameters['TargetServerName'].Attributes.mandatory | Should -Be $true;
        }
        It "Should have TargetDatabaseName as an optional parameter" {
            (Get-Command Update-AnalysisServicesConfig).Parameters['TargetDatabaseName'].Attributes.mandatory | Should -Be $true;
        }
        It "Should have ProcessingOption as an optional parameter" {
            (Get-Command Update-AnalysisServicesConfig).Parameters['ProcessingOption'].Attributes.mandatory | Should -Be $false;
        }
    }

    Context "Invalid Inputs" {
        It "Invalid AsDatabasePath should Throw" {
            { Update-AnalysisServicesConfig -AsDatabasePath "SomeTrashPath" -TargetServerName "SomeTrashServe" -TargetDatabaseName "MyDatabase" } | Should Throw;
        }

        It "Null AsDatabasePath should Throw" {
            { Update-AnalysisServicesConfig -AsDatabasePath $null -TargetServerName "SomeTrashServe" -TargetDatabaseName "MyDatabase" } | Should Throw;
        }

        It "Null TargetServerName should Throw" {
            { Update-AnalysisServicesConfig -AsDatabasePath $AsDatabasePath -TargetServerName $null -TargetDatabaseName "MyDatabase" } | Should Throw;
        }

        It "Empty TargetServerName should Throw" {
            { Update-AnalysisServicesConfig -AsDatabasePath $AsDatabasePath -TargetServerName "" -TargetDatabaseName "MyDatabase" } | Should Throw;
        }

        It "Null TargetDatabaseName should Throw" {
            { Update-AnalysisServicesConfig -AsDatabasePath $AsDatabasePath -TargetServerName "SomeTrashServe" -TargetDatabaseName $null } | Should Throw;
        }

        It "Empty TargetDatabaseName should Throw" {
            { Update-AnalysisServicesConfig -AsDatabasePath $AsDatabasePath -TargetServerName "SomeTrashServe" -TargetDatabaseName "" } | Should Throw;
        }

        It "Missing DeploymentTargets should Throw" {
            { Update-AnalysisServicesConfig -AsDatabasePath $MissingDeploymentTargets -TargetServerName "SomeTrashServe" -TargetDatabaseName "MyDatabase" } | Should Throw;
        }

        It "Missing DeploymentOptions should Throw" {
            { Update-AnalysisServicesConfig -AsDatabasePath $MissingDeploymentOptions -TargetServerName "SomeTrashServe" -TargetDatabaseName "MyDatabase" } | Should Throw;
        }

        It "Invalid ProcessingOption should Throw" {
            { Update-AnalysisServicesConfig -AsDatabasePath $AsDatabasePath -TargetServerName "MyServer" -TargetDatabaseName "MyDatabase" -ProcessingOption "SomethingSilly" } | Should Throw;
        }
    }



    Context "Updated DeploymentTargets and DeploymentOptions" {


        # generate a unique guid which we can check has been written into the file correctly
        $TargetServerName = New-Guid;
        $TargetDatabaseName = New-Guid;
        Update-AnalysisServicesConfig -AsDatabasePath $AsDatabasePath -TargetServerName $TargetServerName -TargetDatabaseName $TargetDatabaseName;

        $configFolder = Split-Path -Path $AsDatabasePath -Parent;
        [string]$ModelName = (Get-Item $AsDatabasePath).Basename;

        $deploymentTargetsPath = Join-Path $configFolder "$ModelName.deploymenttargets";
        [xml]$deploymentTargets = [xml](Get-Content $deploymentTargetsPath);

        It "Check DeploymentTargets Database" {
            $deploymentTargets.DeploymentTarget.Database | Should -Be $TargetDatabaseName;
        }

        It "Check DeploymentTargets Server" {
            $deploymentTargets.DeploymentTarget.Server | Should -Be $TargetServerName;
        }

        It "Check DeploymentTargets ConnectionString" {
            $deploymentTargets.DeploymentTarget.ConnectionString | Should -Be "DataSource=$TargetServerName;Timeout=0"
        }

        It "Check DeploymentOptions file has DoNotProcess" {
            $deploymentOptionsPath = Join-Path $configFolder "$ModelName.deploymentoptions";
            [xml]$deploymentOptions = [xml](Get-Content $deploymentOptionsPath);
            $deploymentOptions.DeploymentOptions.ProcessingOption | Should -Be "DoNotProcess";
        }

    }
}
Remove-Module -Name DeployCube