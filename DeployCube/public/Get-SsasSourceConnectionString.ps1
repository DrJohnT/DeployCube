function Get-SsasSourceConnectionString {
    [OutputType([string])]
    [CmdletBinding()]
	param
	(
        [String] [Parameter(Mandatory = $true)]
        $SourceServerName,

        [String] [Parameter(Mandatory = $true)]
        $SourceDatabaseName,

        [String] [Parameter(Mandatory = $true)]
        $ExistingConnectionString
	)

    $ConnBuilder = New-Object System.Data.OleDb.OleDbConnectionStringBuilder($ExistingConnectionString);
    $ConnBuilder["Data Source"] = $SourceServerName;
    $ConnBuilder["Initial Catalog"] = $SourceDatabaseName;
    return $ConnBuilder.ConnectionString;
}