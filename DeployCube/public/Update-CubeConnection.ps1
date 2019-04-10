<#
# change the connection string on the newly deployed tabular instance
$scriptFile = "DeploymentScripts\ReplaceConnectionString.xmla";
$scriptFilePath = Join-Path $TmslScripts $scriptFile;
if (Test-Path $scriptFilePath) {
    $TMSL = Get-Content $scriptFilePath | ConvertFrom-Json;
    $TMSL.createOrReplace.object.database = $MappedDatabaseName;
    $TMSL.createOrReplace.dataSource.description = "BuildNumber $BuildNumber Deployed by $UserName";
    $DataSourcesNode = $TMSL.createOrReplace.dataSource;
    $ConnectionString = Get-SsasSourceConnectionString -DatabaseName $TargetDatabaseName -ConnectionString $DataSourcesNode.connectionString;
    $DataSourcesNode.connectionString = $ConnectionString;
    $DataSourcesNode.impersonationMode = "impersonateAccount";
    $SsasAccount = Get-SQLCmdVariable -name "SsasAccount";
    $SsasPassword = Get-SQLCmdVariable -name "SsasPassword";
    $DataSourcesNode.account = $SsasAccount;
    $DataSourcesNode.password = $SsasPassword;
    $TMSLPath = Join-Path $TempPath "$DatabaseName.xmla";

    $TMSL | ConvertTo-Json | set-content "$TMSLPath";
    Write-Host "Running $TMSLPath against $ServerName.$MappedDatabaseName";
    [xml]$result = Invoke-ASCmd �InputFile "$TMSLPath" -Server "$ServerName" -Database "$MappedDatabaseName";
    ProcessAsCmdXmlResult($result);
} catch {
    throw "Cannot find $scriptFile";
}
#>