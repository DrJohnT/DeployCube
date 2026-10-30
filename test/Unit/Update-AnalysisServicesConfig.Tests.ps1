BeforeAll {
    . (Join-Path -Path (Split-Path -Parent $PSScriptRoot) -ChildPath 'TestHelpers.ps1')
    Import-DeployCubeForTest

    # All fixtures are copied into TestDrive so the tests never need the (gitignored) Visual Studio build output
    # and never rewrite tracked files under examples/.
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

    function Get-DeploymentTargets {
        $AsDatabasePath = Get-PathToCubeProject;
        $configFolder = Split-Path -Path $AsDatabasePath -Parent;
        [string]$ModelName = (Get-Item $AsDatabasePath).Basename;

        $deploymentTargetsPath = Join-Path $configFolder "$ModelName.deploymenttargets";
        [xml]$deploymentTargets = [xml](Get-Content $deploymentTargetsPath);
        return $deploymentTargets;
    }

    function Get-DeploymentOptions {
        $AsDatabasePath = Get-PathToCubeProject;
        $deploymentOptionsPath = Join-Path (Split-Path -Path $AsDatabasePath -Parent) "Model.deploymentoptions";
        [xml]$deploymentOptions = [xml](Get-Content $deploymentOptionsPath);
        return $deploymentOptions;
    }
}

Describe "Update-AnalysisServicesConfig" -Tag 'Unit' {
    Context "Testing Inputs" {
        It "Should have AsDatabasePath as a mandatory parameter" {
            (Get-Command Update-AnalysisServicesConfig).Parameters['AsDatabasePath'].Attributes.mandatory | Should -BeTrue;
        }
        It "Should have Server as a mandatory parameter" {
            (Get-Command Update-AnalysisServicesConfig).Parameters['Server'].Attributes.mandatory | Should -BeTrue;
        }
        It "Should have CubeDatabase as an optional parameter" {
            (Get-Command Update-AnalysisServicesConfig).Parameters['CubeDatabase'].Attributes.mandatory | Should -BeTrue;
        }
        It "Should have ProcessingOption as an optional parameter" {
            (Get-Command Update-AnalysisServicesConfig).Parameters['ProcessingOption'].Attributes.mandatory | Should -BeFalse;
        }

        It "Should have TransactionalDeployment as an optional parameter" {
            (Get-Command Update-AnalysisServicesConfig).Parameters['TransactionalDeployment'].Attributes.mandatory | Should -BeFalse;
        }
        It "Should have PartitionDeployment as an optional parameter" {
            (Get-Command Update-AnalysisServicesConfig).Parameters['PartitionDeployment'].Attributes.mandatory | Should -BeFalse;
        }
        It "Should have RoleDeployment as an optional parameter" {
            (Get-Command Update-AnalysisServicesConfig).Parameters['RoleDeployment'].Attributes.mandatory | Should -BeFalse;
        }
        It "Should have ConfigurationSettingsDeployment as an optional parameter" {
            (Get-Command Update-AnalysisServicesConfig).Parameters['ConfigurationSettingsDeployment'].Attributes.mandatory | Should -BeFalse;
        }
        It "Should have OptimizationSettingsDeployment as an optional parameter" {
            (Get-Command Update-AnalysisServicesConfig).Parameters['OptimizationSettingsDeployment'].Attributes.mandatory | Should -BeFalse;
        }
        It "Should have WriteBackTableCreation as an optional parameter" {
            (Get-Command Update-AnalysisServicesConfig).Parameters['WriteBackTableCreation'].Attributes.mandatory | Should -BeFalse;
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

            [xml] $deploymentTargets = Get-DeploymentTargets;
            $deploymentTargets.DeploymentTarget.ConnectionString | Should -Be "Data Source=$Server;Timeout=0;"
        }

        It "Check DeploymentOptions file has DoNotProcess" {
            $AsDatabasePath = Get-PathToCubeProject;
            Update-AnalysisServicesConfig -AsDatabasePath $AsDatabasePath -Server "localhost" -CubeDatabase "MyCube";
            $configFolder = Split-Path -Path $AsDatabasePath -Parent;
            [string]$ModelName = (Get-Item $AsDatabasePath).Basename;
            $deploymentOptionsPath = Join-Path $configFolder "$ModelName.deploymentoptions";
            [xml]$deploymentOptions = [xml](Get-Content $deploymentOptionsPath);
            $deploymentOptions.DeploymentOptions.ProcessingOption | Should -Be "DoNotProcess";
        }

    }

    Context "Deployment options and credentials" {
        BeforeEach {
            # fresh copy of the fixture for every test
            Remove-Item -Path (Join-Path -Path $TestDrive -ChildPath 'InvalidDataSourceConnection') -Recurse -Force -ErrorAction SilentlyContinue;
        }

        It "Writes every deployment option to the deploymentoptions file" {
            $AsDatabasePath = Get-PathToCubeProject;
            Update-AnalysisServicesConfig -AsDatabasePath $AsDatabasePath -Server "MyServer" -CubeDatabase "MyCube" -ProcessingOption Full `
                -TransactionalDeployment $true -PartitionDeployment RetainPartitions -RoleDeployment RetainRoles `
                -ConfigurationSettingsDeployment Retain -OptimizationSettingsDeployment Retain -WriteBackTableCreation CreateAlways | Out-Null;

            $options = (Get-DeploymentOptions).DeploymentOptions;
            $options.ProcessingOption | Should -Be 'Full';
            $options.TransactionalDeployment | Should -Be 'true';
            $options.PartitionDeployment | Should -Be 'RetainPartitions';
            $options.RoleDeployment | Should -Be 'RetainRoles';
            $options.ConfigurationSettingsDeployment | Should -Be 'Retain';
            $options.OptimizationSettingsDeployment | Should -Be 'Retain';
            $options.WriteBackTableCreation | Should -Be 'CreateAlways';
        }

        It "Writes the documented defaults when only mandatory parameters are supplied" {
            $AsDatabasePath = Get-PathToCubeProject;
            Update-AnalysisServicesConfig -AsDatabasePath $AsDatabasePath -Server "MyServer" -CubeDatabase "MyCube" | Out-Null;

            $options = (Get-DeploymentOptions).DeploymentOptions;
            $options.ProcessingOption | Should -Be 'DoNotProcess';
            $options.TransactionalDeployment | Should -Be 'false';
            $options.PartitionDeployment | Should -Be 'DeployPartitions';
            $options.RoleDeployment | Should -Be 'DeployRolesRetainMembers';
            $options.ConfigurationSettingsDeployment | Should -Be 'Deploy';
            $options.OptimizationSettingsDeployment | Should -Be 'Deploy';
            $options.WriteBackTableCreation | Should -Be 'UseExisting';
        }

        It "Reports which files it altered" {
            $AsDatabasePath = Get-PathToCubeProject;
            $output = Update-AnalysisServicesConfig -AsDatabasePath $AsDatabasePath -Server "MyServer" -CubeDatabase "MyCube";
            $output | Should -Contain 'Altering Model.deploymenttargets';
            $output | Should -Contain 'Altering Model.deploymentoptions';
        }

        It "Uses Windows authentication (no credentials) in the target connection string by default" {
            $AsDatabasePath = Get-PathToCubeProject;
            Update-AnalysisServicesConfig -AsDatabasePath $AsDatabasePath -Server "MyServer" -CubeDatabase "MyCube" | Out-Null;
            (Get-DeploymentTargets).DeploymentTarget.ConnectionString | Should -Be 'Data Source=MyServer;Timeout=0;';
        }

        It "Characterization: writes UserID and Password into the deploymenttargets connection string (see assessment F02)" {
            $AsDatabasePath = Get-PathToCubeProject;
            Update-AnalysisServicesConfig -AsDatabasePath $AsDatabasePath -Server "asazure://region.asazure.windows.net/server" -CubeDatabase "MyCube" -UserID "deploy@contoso.com" -Password "NotARealSecret" | Out-Null;
            $connectionString = (Get-DeploymentTargets).DeploymentTarget.ConnectionString;
            $connectionString | Should -BeLike 'Data Source=asazure://region.asazure.windows.net/server;Timeout=0;User ID=deploy@contoso.com;Password=NotARealSecret;Persist Security Info=True;*';
        }

        It "Missing AsDatabase file throws" {
            { Update-AnalysisServicesConfig -AsDatabasePath (Join-Path $TestDrive 'nothing\Model.asdatabase') -Server "MyServer" -CubeDatabase "MyCube" } | Should -Throw '*AsDatabase file does not exist*';
        }

        It "Known defect F01: Multidimensional .configsettings handling calls an undefined helper" -Skip {
            # Update-AnalysisServicesConfig calls Get-SsasSourceConnectionString, which does not exist in the module.
            # Enable and rewrite this test when F01 (docs/MODERNIZATION_ASSESSMENT.md) is fixed.
        }
    }

}
AfterAll {
    Remove-Module -Name DeployCube;
}