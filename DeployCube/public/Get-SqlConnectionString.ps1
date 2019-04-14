function Get-SqlConnectionString {
    [OutputType([string])]
    [CmdletBinding()]
	param
	(
        [String] [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $SourceSqlServer,

        [String] [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $SourceSqlDatabase,

        [String] [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $ExistingConnectionString
	)

    $ConnBuilder = New-Object System.Data.OleDb.OleDbConnectionStringBuilder($ExistingConnectionString);
    $ConnBuilder["Data Source"] = $SourceServer;
    $ConnBuilder["Initial Catalog"] = $SourceDatabase;
    return $ConnBuilder.ConnectionString;
}