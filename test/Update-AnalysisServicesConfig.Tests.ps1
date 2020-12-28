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

    function Get-DeploymentTargets {
        $AsDatabasePath = Get-PathToCubeProject;
        $configFolder = Split-Path -Path $AsDatabasePath -Parent;
        [string]$ModelName = (Get-Item $AsDatabasePath).Basename;

        $deploymentTargetsPath = Join-Path $configFolder "$ModelName.deploymenttargets";
        [xml]$deploymentTargets = [xml](Get-Content $deploymentTargetsPath);
        return $deploymentTargets;
    }
}

Describe "Update-AnalysisServicesConfig" -Tag "Round2" {
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
            { Update-AnalysisServicesConfig -AsDatabasePath "SomeTrashPath" -Server "SomeTrashServe" -CubeDatabase "MyDatabase" } | Should -Throw;
        }

        It "Null AsDatabasePath should Throw" {
            { Update-AnalysisServicesConfig -AsDatabasePath $null -Server "SomeTrashServe" -CubeDatabase "MyDatabase" } | Should -Throw;
        }

        It "Null Server should Throw" {
            $AsDatabasePath = Get-PathToCubeProject;
            { Update-AnalysisServicesConfig -AsDatabasePath $AsDatabasePath -Server $null -CubeDatabase "MyDatabase" } | Should -Throw;
        }

        It "Empty Server should Throw" {
            $AsDatabasePath = Get-PathToCubeProject;
            { Update-AnalysisServicesConfig -AsDatabasePath $AsDatabasePath -Server "" -CubeDatabase "MyDatabase" } | Should -Throw;
        }

        It "Null CubeDatabase should Throw" {
            $AsDatabasePath = Get-PathToCubeProject; 
            { Update-AnalysisServicesConfig -AsDatabasePath $AsDatabasePath -Server "SomeTrashServe" -CubeDatabase $null } | Should -Throw;
        }

        It "Empty CubeDatabase should Throw" {
            $AsDatabasePath = Get-PathToCubeProject;
            { Update-AnalysisServicesConfig -AsDatabasePath $AsDatabasePath -Server "SomeTrashServe" -CubeDatabase "" } | Should -Throw;
        }

        It "Missing DeploymentTargets should Throw" {
            $MissingDeploymentTargets = Get-MissingDeploymentTargets;
            { Update-AnalysisServicesConfig -AsDatabasePath $MissingDeploymentTargets -Server "SomeTrashServe" -CubeDatabase "MyDatabase" } | Should -Throw;
        }

        It "Missing DeploymentOptions should Throw" {
            $MissingDeploymentOptions = Get-MissingDeploymentOptions;
            { Update-AnalysisServicesConfig -AsDatabasePath $MissingDeploymentOptions -Server "SomeTrashServe" -CubeDatabase "MyDatabase" } | Should -Throw;
        }

        It "Invalid ProcessingOption should Throw" {
            $AsDatabasePath = Get-PathToCubeProject; 
            { Update-AnalysisServicesConfig -AsDatabasePath $AsDatabasePath -Server "MyServer" -CubeDatabase "MyDatabase" -ProcessingOption "SomethingSilly" } | Should -Throw;
        }

        It "Invalid TransactionalDeployment should Throw" {
            $AsDatabasePath = Get-PathToCubeProject; 
            { Update-AnalysisServicesConfig -AsDatabasePath $AsDatabasePath -Server "MyServer" -CubeDatabase "MyDatabase" -TransactionalDeployment "SomethingSilly" } | Should -Throw;
        }
        It "Invalid PartitionDeployment should Throw" {
            $AsDatabasePath = Get-PathToCubeProject; 
            { Update-AnalysisServicesConfig -AsDatabasePath $AsDatabasePath -Server "MyServer" -CubeDatabase "MyDatabase" -PartitionDeployment "SomethingSilly" } | Should -Throw;
        }
        It "Invalid RoleDeployment should Throw" {
            $AsDatabasePath = Get-PathToCubeProject; 
            { Update-AnalysisServicesConfig -AsDatabasePath $AsDatabasePath -Server "MyServer" -CubeDatabase "MyDatabase" -RoleDeployment "SomethingSilly" } | Should -Throw;
        }
        It "Invalid ConfigurationSettingsDeployment should Throw" {
            $AsDatabasePath = Get-PathToCubeProject; 
            { Update-AnalysisServicesConfig -AsDatabasePath $AsDatabasePath -Server "MyServer" -CubeDatabase "MyDatabase" -ConfigurationSettingsDeployment "SomethingSilly" } | Should -Throw;
        }
        It "Invalid OptimizationSettingsDeployment should Throw" {
            $AsDatabasePath = Get-PathToCubeProject; 
            { Update-AnalysisServicesConfig -AsDatabasePath $AsDatabasePath -Server "MyServer" -CubeDatabase "MyDatabase" -OptimizationSettingsDeployment "SomethingSilly" } | Should -Throw;
        }
        It "Invalid WriteBackTableCreation should Throw" {
            $AsDatabasePath = Get-PathToCubeProject; 
            { Update-AnalysisServicesConfig -AsDatabasePath $AsDatabasePath -Server "MyServer" -CubeDatabase "MyDatabase" -WriteBackTableCreation "SomethingSilly" } | Should -Throw;
        }

        It "Empty TransactionalDeployment should Throw" {
            $AsDatabasePath = Get-PathToCubeProject; 
            { Update-AnalysisServicesConfig -AsDatabasePath $AsDatabasePath -Server "MyServer" -CubeDatabase "MyDatabase" -TransactionalDeployment "" } | Should -Throw;
        }
        It "Null TransactionalDeployment should Throw" {
            $AsDatabasePath = Get-PathToCubeProject; 
            { Update-AnalysisServicesConfig -AsDatabasePath $AsDatabasePath -Server "MyServer" -CubeDatabase "MyDatabase" -TransactionalDeployment $null } | Should -Throw;
        }
    }

    Context "Updated DeploymentTargets and DeploymentOptions" {
        
        It "Check DeploymentTargets Database" {
            # generate a unique guid which we can check has been written into the file correctly
            $Server = "localhost";
            $CubeDatabase = New-Guid;
            $AsDatabasePath = Get-PathToCubeProject; 
            Update-AnalysisServicesConfig -AsDatabasePath $AsDatabasePath -Server $Server -CubeDatabase $CubeDatabase;
            $deploymentTargets = Get-DeploymentTargets;
            $deploymentTargets.DeploymentTarget.Database | Should -Be $CubeDatabase;
        }

        It "Check DeploymentTargets Server" {
            $Server = New-Guid;
            $CubeDatabase = "MyCube";
            $AsDatabasePath = Get-PathToCubeProject; 
            Update-AnalysisServicesConfig -AsDatabasePath $AsDatabasePath -Server $Server -CubeDatabase $CubeDatabase;

            $deploymentTargets = Get-DeploymentTargets;
            $deploymentTargets.DeploymentTarget.Server | Should -Be $Server;
        }

        It "Check DeploymentTargets ConnectionString" -TestCases @{ Server = $Server }  {
            $Server = New-Guid;
            $CubeDatabase = "MyCube";
            $AsDatabasePath = Get-PathToCubeProject; 
            Update-AnalysisServicesConfig -AsDatabasePath $AsDatabasePath -Server $Server -CubeDatabase $CubeDatabase;

            $deploymentTargets = Get-DeploymentTargets;
            $deploymentTargets.DeploymentTarget.ConnectionString | Should -Be "DataSource=$Server;Timeout=0"
        }

        It "Check DeploymentOptions file has DoNotProcess" {
            $AsDatabasePath = Get-PathToCubeProject;
            $configFolder = Split-Path -Path $AsDatabasePath -Parent;
            [string]$ModelName = (Get-Item $AsDatabasePath).Basename;
            $deploymentOptionsPath = Join-Path $configFolder "$ModelName.deploymentoptions";
            [xml]$deploymentOptions = [xml](Get-Content $deploymentOptionsPath);
            $deploymentOptions.DeploymentOptions.ProcessingOption | Should -Be "DoNotProcess";
        }

    }

}
AfterAll {
    Remove-Module -Name DeployCube;
}