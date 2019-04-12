function Ping-SsasServer {
	<#
		.SYNOPSIS
		Checks that the SQL Server SSAS instance exists

        .DESCRIPTION
        Checks that the SQL Server SSAS instance exists

		Written by (c) Dr. John Tunnicliffe, 2019 https://github.com/DrJohnT/PublishDacPac
		This PowerShell script is released under the MIT license http://www.opensource.org/licenses/MIT

	#>
	[OutputType([Boolean])]
    [CmdletBinding()]
	param
	(
			[String] [Parameter(Mandatory = $true)]
			[ValidateNotNullOrEmpty()]
        	$ServerName
	)

	try {
		# simply request a list of databases on the SSAS server.  If the server does not exist, it will return an empty string
		$returnResult = Invoke-ASCmd -Server $ServerName -ConnectionTimeout 1 -Query "<Discover xmlns='urn:schemas-microsoft-com:xml-analysis'><RequestType>DBSCHEMA_CATALOGS</RequestType><Restrictions /><Properties /></Discover>";

		#  Invoke-ASCmd does not return a string if the server does not exist
		if ([string]::IsNullOrEmpty($returnResult)) {
			return $false;
		}
		return $true;
	} catch {
		return $false;
	}
}