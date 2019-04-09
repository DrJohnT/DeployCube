
function Update-AnalysisServicesConfig {
    [CmdletBinding()]
	param
	(
        [String] [Parameter(Mandatory = $true)]
        $AsDatabasePath,

        [String] [Parameter(Mandatory = $true)]
        $ModelName,

        [String] [Parameter(Mandatory = $true)]
        $TargetServerName,

        [String] [Parameter(Mandatory = $false)]
        $TargetDatabaseName,

        [String] [Parameter(Mandatory = $false)]
        $PreferredVersion
    )

    if (Test-Path $AsDatabasePath) {
        $configFolder = Split-Path $AsDatabasePath;
        $MappedDatabaseName = Get-MappedDatabaseNameFromConfig -DatabaseName $DatabaseName;

        # DeploymentTargets Config File
        $deploymentTargetsPath = Join-Path $configFolder "$ModelName.deploymenttargets";
        [xml]$deploymentTargets = [xml](Get-Content $deploymentTargetsPath);
        $deploymentTargets.DeploymentTarget.Database = "$MappedDatabaseName";
        $deploymentTargets.DeploymentTarget.Server = $ServerName;
        $deploymentTargets.DeploymentTarget.ConnectionString="DataSource=$ServerName;Timeout=0"
        $deploymentTargets.Save($deploymentTargetsPath);

        # Config Settings File
        $configSettingsPath = Join-Path $configFolder "$ModelName.configsettings"
        if (Test-Path($configSettingsPath))
        {
            [xml]$configSettings = [xml](Get-Content $configSettingsPath);

            $dataSourceNode = $configSettings.ConfigurationSettings.Database.DataSources.DataSource;
            $dataSourceNode.ConnectionString = Get-SsasSourceConnectionString -DatabaseName $DatabaseName -ConnectionString $dataSourceNode.ConnectionString;
            $configSettings.Save($configSettingsPath);
        }

        # Deployment Options
        $deploymentOptionsPath = Join-Path $configFolder "$ModelName.deploymentoptions";
        [xml]$deploymentOptions = [xml](Get-Content $deploymentOptionsPath);
        $deploymentOptions.DeploymentOptions.ProcessingOption = "DoNotProcess";
        $deploymentOptions.Save($deploymentOptionsPath);
    } else {
        logError -Message "Update-AnalysisServicesConfig: AsDatabase file does not exist in $AsDatabasePath";
    }
}
