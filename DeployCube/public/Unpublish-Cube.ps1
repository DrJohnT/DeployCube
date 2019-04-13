function Unpublish-Cube {
    <#
		.SYNOPSIS
        Unpublish-Cube drops a tabular or multidimenstional cube from a SQL Server Analysis Services instance.
    #>
    [CmdletBinding()]
	param
	(
        [String] [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $ServerName,

        [String] [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $DatabaseName
    )

    $asCmd = "<Delete xmlns='http://schemas.microsoft.com/analysisservices/2003/engine'><Object><DatabaseID>$DatabaseName</DatabaseID></Object></Delete>";
    Invoke-ASCmd -Server $ServerName -Query $asCmd;
}

New-Alias -Name Drop-Cube -Value Unpublish-Cube;