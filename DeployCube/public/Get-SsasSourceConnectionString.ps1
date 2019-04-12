function Get-SsasSourceConnectionString {
    [OutputType([string])]
    [CmdletBinding()]
	param
	(
        [String] [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $SourceServerName,

        [String] [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $SourceDatabaseName,

        [String] [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $ExistingConnectionString
	)

    $ConnBuilder = New-Object System.Data.OleDb.OleDbConnectionStringBuilder($ExistingConnectionString);
    $ConnBuilder["Data Source"] = $SourceServerName;
    $ConnBuilder["Initial Catalog"] = $SourceDatabaseName;
    return $ConnBuilder.ConnectionString;
}