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
        It "Should have Server as a mandatory parameter" {
            (Get-Command Update-AnalysisServicesConfig).Parameters['Server'].Attributes.mandatory | Should -Be $true;
        }
        It "Should have CubeDatabase as an optional parameter" {
            (Get-Command Update-AnalysisServicesConfig).Parameters['CubeDatabase'].Attributes.mandatory | Should -Be $true;
        }
        It "Should have ProcessingOption as an optional parameter" {
            (Get-Command Update-AnalysisServicesConfig).Parameters['ProcessingOption'].Attributes.mandatory | Should -Be $false;
        }

        It "Should have TransactionalDeployment as an optional parameter" {
            (Get-Command Update-AnalysisServicesConfig).Parameters['TransactionalDeployment'].Attributes.mandatory | Should -Be $false;
        }
        It "Should have PartitionDeployment as an optional parameter" {
            (Get-Command Update-AnalysisServicesConfig).Parameters['PartitionDeployment'].Attributes.mandatory | Should -Be $false;
        }
        It "Should have RoleDeployment as an optional parameter" {
            (Get-Command Update-AnalysisServicesConfig).Parameters['RoleDeployment'].Attributes.mandatory | Should -Be $false;
        }
        It "Should have ConfigurationSettingsDeployment as an optional parameter" {
            (Get-Command Update-AnalysisServicesConfig).Parameters['ConfigurationSettingsDeployment'].Attributes.mandatory | Should -Be $false;
        }
        It "Should have OptimizationSettingsDeployment as an optional parameter" {
            (Get-Command Update-AnalysisServicesConfig).Parameters['OptimizationSettingsDeployment'].Attributes.mandatory | Should -Be $false;
        }
        It "Should have WriteBackTableCreation as an optional parameter" {
            (Get-Command Update-AnalysisServicesConfig).Parameters['WriteBackTableCreation'].Attributes.mandatory | Should -Be $false;
        }
    }

    Context "Invalid Inputs" {
        It "Invalid AsDatabasePath should Throw" {
            { Update-AnalysisServicesConfig -AsDatabasePath "SomeTrashPath" -Server "SomeTrashServe" -CubeDatabase "MyDatabase" } | Should Throw;
        }

        It "Null AsDatabasePath should Throw" {
            { Update-AnalysisServicesConfig -AsDatabasePath $null -Server "SomeTrashServe" -CubeDatabase "MyDatabase" } | Should Throw;
        }

        It "Null Server should Throw" {
            { Update-AnalysisServicesConfig -AsDatabasePath $AsDatabasePath -Server $null -CubeDatabase "MyDatabase" } | Should Throw;
        }

        It "Empty Server should Throw" {
            { Update-AnalysisServicesConfig -AsDatabasePath $AsDatabasePath -Server "" -CubeDatabase "MyDatabase" } | Should Throw;
        }

        It "Null CubeDatabase should Throw" {
            { Update-AnalysisServicesConfig -AsDatabasePath $AsDatabasePath -Server "SomeTrashServe" -CubeDatabase $null } | Should Throw;
        }

        It "Empty CubeDatabase should Throw" {
            { Update-AnalysisServicesConfig -AsDatabasePath $AsDatabasePath -Server "SomeTrashServe" -CubeDatabase "" } | Should Throw;
        }

        It "Missing DeploymentTargets should Throw" {
            { Update-AnalysisServicesConfig -AsDatabasePath $MissingDeploymentTargets -Server "SomeTrashServe" -CubeDatabase "MyDatabase" } | Should Throw;
        }

        It "Missing DeploymentOptions should Throw" {
            { Update-AnalysisServicesConfig -AsDatabasePath $MissingDeploymentOptions -Server "SomeTrashServe" -CubeDatabase "MyDatabase" } | Should Throw;
        }

        It "Invalid ProcessingOption should Throw" {
            { Update-AnalysisServicesConfig -AsDatabasePath $AsDatabasePath -Server "MyServer" -CubeDatabase "MyDatabase" -ProcessingOption "SomethingSilly" } | Should Throw;
        }

        It "Invalid TransactionalDeployment should Throw" {
            { Update-AnalysisServicesConfig -AsDatabasePath $AsDatabasePath -Server "MyServer" -CubeDatabase "MyDatabase" -TransactionalDeployment "SomethingSilly" } | Should Throw;
        }
        It "Invalid PartitionDeployment should Throw" {
            { Update-AnalysisServicesConfig -AsDatabasePath $AsDatabasePath -Server "MyServer" -CubeDatabase "MyDatabase" -PartitionDeployment "SomethingSilly" } | Should Throw;
        }
        It "Invalid RoleDeployment should Throw" {
            { Update-AnalysisServicesConfig -AsDatabasePath $AsDatabasePath -Server "MyServer" -CubeDatabase "MyDatabase" -RoleDeployment "SomethingSilly" } | Should Throw;
        }
        It "Invalid ConfigurationSettingsDeployment should Throw" {
            { Update-AnalysisServicesConfig -AsDatabasePath $AsDatabasePath -Server "MyServer" -CubeDatabase "MyDatabase" -ConfigurationSettingsDeployment "SomethingSilly" } | Should Throw;
        }
        It "Invalid OptimizationSettingsDeployment should Throw" {
            { Update-AnalysisServicesConfig -AsDatabasePath $AsDatabasePath -Server "MyServer" -CubeDatabase "MyDatabase" -OptimizationSettingsDeployment "SomethingSilly" } | Should Throw;
        }
        It "Invalid WriteBackTableCreation should Throw" {
            { Update-AnalysisServicesConfig -AsDatabasePath $AsDatabasePath -Server "MyServer" -CubeDatabase "MyDatabase" -WriteBackTableCreation "SomethingSilly" } | Should Throw;
        }

        It "Empty TransactionalDeployment should Throw" {
            { Update-AnalysisServicesConfig -AsDatabasePath $AsDatabasePath -Server "MyServer" -CubeDatabase "MyDatabase" -TransactionalDeployment "" } | Should Throw;
        }
        It "Null TransactionalDeployment should Throw" {
            { Update-AnalysisServicesConfig -AsDatabasePath $AsDatabasePath -Server "MyServer" -CubeDatabase "MyDatabase" -TransactionalDeployment $null } | Should Throw;
        }
    }



    Context "Updated DeploymentTargets and DeploymentOptions" {


        # generate a unique guid which we can check has been written into the file correctly
        $Server = New-Guid;
        $CubeDatabase = New-Guid;
        Update-AnalysisServicesConfig -AsDatabasePath $AsDatabasePath -Server $Server -CubeDatabase $CubeDatabase;

        $configFolder = Split-Path -Path $AsDatabasePath -Parent;
        [string]$ModelName = (Get-Item $AsDatabasePath).Basename;

        $deploymentTargetsPath = Join-Path $configFolder "$ModelName.deploymenttargets";
        [xml]$deploymentTargets = [xml](Get-Content $deploymentTargetsPath);

        It "Check DeploymentTargets Database" {
            $deploymentTargets.DeploymentTarget.Database | Should -Be $CubeDatabase;
        }

        It "Check DeploymentTargets Server" {
            $deploymentTargets.DeploymentTarget.Server | Should -Be $Server;
        }

        It "Check DeploymentTargets ConnectionString" {
            $deploymentTargets.DeploymentTarget.ConnectionString | Should -Be "DataSource=$Server;Timeout=0"
        }

        It "Check DeploymentOptions file has DoNotProcess" {
            $deploymentOptionsPath = Join-Path $configFolder "$ModelName.deploymentoptions";
            [xml]$deploymentOptions = [xml](Get-Content $deploymentOptionsPath);
            $deploymentOptions.DeploymentOptions.ProcessingOption | Should -Be "DoNotProcess";
        }

    }
}
Remove-Module -Name DeployCube