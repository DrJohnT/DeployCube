
function Update-AnalysisServicesConfig {
    <#
		.SYNOPSIS
        Deploy-Cube deploys a tabular or multidimenstional cube to a SQL Server Analysis Services instance.

		.DESCRIPTION
        Deploy-Cube deploys a tabular or multidimenstional cube to a SQL Server Analysis Services instance.

		Written by (c) Dr. John Tunnicliffe, 2019 https://github.com/DrJohnT/DeployCube
		This PowerShell script is released under the MIT license http://www.opensource.org/licenses/MIT

        .PARAMETER AsDatabasePath
        Full path to your database XMLA or TMSL file which has a .asdatabase file extension (e.g. C:\Dev\YourDB\bin\Debug\YourDB.asdatabase)

         .PARAMETER TargetServerName
        Name of the target server, including instance and port if required.

        .PARAMETER TargetDatabaseName
        The name of the database to be deployed.
    #>
    [CmdletBinding()]
	param
	(
        [String] [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $AsDatabasePath,

        [String] [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $TargetServerName,

        [String] [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $TargetDatabaseName,

        [String] [Parameter(Mandatory = $false)]
        [ValidateSet('ProcessFull', 'DoNotProcess')]
        $ProcessingOption
    )

    if (Test-Path $AsDatabasePath) {
        $configFolder = Split-Path -Path $AsDatabasePath -Parent;
        [string]$ModelName = (Get-Item $AsDatabasePath).Basename;

        # DeploymentTargets Config File
        $deploymentTargetsPath = Join-Path $configFolder "$ModelName.deploymenttargets";
        if (Test-Path($deploymentTargetsPath))
        {
            Write-Output "Altering $ModelName.deploymenttargets"
            [xml]$deploymentTargets = [xml](Get-Content $deploymentTargetsPath);
            $deploymentTargets.DeploymentTarget.Database = $TargetDatabaseName;
            $deploymentTargets.DeploymentTarget.Server = $TargetServerName;
            $deploymentTargets.DeploymentTarget.ConnectionString="DataSource=$TargetServerName;Timeout=0"
            $deploymentTargets.Save($deploymentTargetsPath);
        } else {
            throw "Update-AnalysisServicesConfig: $ModelName.deploymenttargets file does not exist in $configFolder";
        }

        # Deployment Options
        $deploymentOptionsPath = Join-Path $configFolder "$ModelName.deploymentoptions";
        if (Test-Path($deploymentOptionsPath))
        {
            Write-Output "Altering $ModelName.deploymentoptions"

            if ([string]::IsNullOrEmpty($ProcessingOption)) {
                $ProcessingOption = 'DoNotProcess';
            }

            [xml]$deploymentOptions = [xml](Get-Content $deploymentOptionsPath);
            $deploymentOptions.DeploymentOptions.ProcessingOption = $ProcessingOption;
            $deploymentOptions.Save($deploymentOptionsPath);
        } else {
            throw "Update-AnalysisServicesConfig: $ModelName.deploymentoptions file does not exist in $configFolder";
        }

        # Config Settings File - only present when we are deploying multidimensional cubes - so do not error if missing
        $configSettingsPath = Join-Path $configFolder "$ModelName.configsettings"
        if (Test-Path($configSettingsPath))
        {
            Write-Output "Altering $ModelName.configsettings"
            [xml]$configSettings = [xml](Get-Content $configSettingsPath);

            $dataSourceNode = $configSettings.ConfigurationSettings.Database.DataSources.DataSource;
            $dataSourceNode.ConnectionString = Get-SsasSourceConnectionString -DatabaseName $DatabaseName -ConnectionString $dataSourceNode.ConnectionString;
            $configSettings.Save($configSettingsPath);
        }
    } else {
        throw "Update-AnalysisServicesConfig: AsDatabase file does not exist in $configFolder";
    }
}
