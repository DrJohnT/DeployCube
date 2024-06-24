function Update-TabularCubeDataSource
{
<#
    .SYNOPSIS
    Updates the tabular cube's connection to the source SQL database.

    .DESCRIPTION
    Connects to the deployed tabular cube and updates the connection to the source SQL database.
    Supports the newer PowerQuery style tabular cubes with CompatibilityLevel = 1400.

    .PARAMETER Server
    SSAS Server Name or IP address.  Include the instance name and port if necessary (e.g. myserver\\myinstance,myport)

    .PARAMETER CubeDatabase
    The name of the deployed tabular cube database.

    .PARAMETER Credential
    A PSCredential object containing the credentials to connect to the AAS server.

    .PARAMETER SourceSqlServer
    The name of the source SQL Server server or its IP address.  Include the instance name and port if necessary.

    .PARAMETER SourceSqlDatabase
    The name of the database which will act as a source of data for the tabular cube database.

    .PARAMETER ImpersonationMode
    Defines how the cube will connect to the data source. Possible options are 'ImpersonateServiceAccount' which connects to the SQL Server database using ,
    or 'ImpersonateAccount' which uses a specific username/password.  When using 'ImpersonateAccount' it is best to use a domain based service account with a static password.

    .PARAMETER ImpersonationAccount
    The username of the account that will be used to connect to the SQL Server database.  Required for ImpersonationMode='ImpersonateAccount'.

    .PARAMETER ImpersonationPwd
    The password of the account that will be used to connect to the SQL Server database.  Required for ImpersonationMode='ImpersonateAccount'.

    .PARAMETER DataSource
    The name of the data source that will be updated.  Optional, use when there are multiple data sources in the deployed tabular cube database.

    .PARAMETER CommandTimeout
    Command timeout in minutes. Use a decimal number to set seconds. The fractional part defines a fraction of a minute e.g. 0.5 is 30 seconds and 0.334 is 20 seconds.

    .EXAMPLE
    Update-TabularCubeDataSource -Server localhost -CubeDatabase MyCube -SourceSqlServer localhost -SourceSqlDatabase MyDB -ImpersonationMode ImpersonateServiceAccount;

    .EXAMPLE
    Update-TabularCubeDataSource -Server localhost -CubeDatabase MyCube -SourceSqlServer localhost -SourceSqlDatabase MyDB -ImpersonationMode ImpersonateAccount -ImpersonationAccount "DOMAIN\user" -ImpersonationPwd "Password" -DataSource DataSource2;

    .OUTPUTS
    Returns true if the cube's data source was updated successfully.

    .LINK
    https://github.com/DrJohnT/DeployCube

    .NOTES
    Written by (c) Dr. John Tunnicliffe, 2019-2021 https://github.com/DrJohnT/DeployCube
    This PowerShell script is released under the MIT license http://www.opensource.org/licenses/MIT
#>
    [OutputType([bool])]
    [CmdletBinding()]
    param
    (
        [String] [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $Server,

        [String] [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $CubeDatabase,

        [PSCredential] [Parameter(Mandatory = $false)]
        $Credential = $null,

        [String] [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $SourceSqlServer,

        [String] [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $SourceSqlDatabase,

        [Alias("AuthenticationKind")]
        [String] [Parameter(Mandatory = $true)]
        [ValidateSet('ImpersonateServiceAccount', 'ImpersonateAccount', 'UsernamePassword')]
        [ValidateNotNullOrEmpty()]
        $ImpersonationMode,

        [String] [Parameter(Mandatory = $false)]
        $ImpersonationAccount,

        [Alias("ImpersonationPassword")]
        [String] [Parameter(Mandatory = $false)]
        $ImpersonationPwd,

        [String] [Parameter(Mandatory = $false)]
        $DataSource,

        #[Decimal] 
        [AllowNull()][System.Nullable[decimal]]
        [Parameter(Mandatory = $false)]
        $CommandTimeout
    )

    # validate inputs
    if ($ImpersonationMode -eq 'ImpersonateAccount') {
        if ([string]::IsNullOrEmpty($ImpersonationAccount)) {
            throw "ImpersonationAccount not set but ImpersonationMode=ImpersonateAccount";
        }
        if ([string]::IsNullOrEmpty($ImpersonationPwd)) {
            throw "ImpersonationPassword not set but ImpersonationMode=ImpersonateAccount";
        }
    }    

    $CommandTimeoutFormatted = $null
    $CommandTimeoutFormatted_cl1200 = $null
    if ($CommandTimeout -gt 0) {
        # convert command timeout from minutes to a formatted string.

        # formatted for compatibility level >= 1400
        # split the timeout in minutes into days, hours, minutes and seconds
        $CommandTimeoutDays = [Math]::Truncate($CommandTimeout / 1440)
        $CommandTimeoutHours = [Math]::Truncate(($CommandTimeout % 1440) / 60)
        $CommandTimeoutMinutes = [Math]::Truncate(($CommandTimeout % 1440) % 60)
        $CommandTimeoutSeconds = [Math]::Truncate(($CommandTimeout - [Math]::Truncate($CommandTimeout)) * 60)

        # convert the splitted time parts to proper format
        $CommandTimeoutFormatted = "P"
        
        if ($CommandTimeoutDays -gt 0) {
            $CommandTimeoutFormatted += "$($CommandTimeoutDays)D"
        }

        if ($CommandTimeoutHours -gt 0 -or $CommandTimeoutMinutes -gt 0 -or $CommandTimeoutSeconds -gt 0) {
            $CommandTimeoutFormatted += "T"
        
            if ($CommandTimeoutHours -gt 0) {
                $CommandTimeoutFormatted += "$($CommandTimeoutHours)H"
            }
        
            if ($CommandTimeoutMinutes -gt 0) {
                $CommandTimeoutFormatted += "$($CommandTimeoutMinutes)M"
            }
        
            if ($CommandTimeoutSeconds -gt 0) {
                $CommandTimeoutFormatted += "$($CommandTimeoutSeconds)S"
            }
        }

        # formatted for compatibility level < 1400
        # convert into seconds
        $CommandTimeoutInSeconds = ([Math]::Truncate($CommandTimeout) * 60) + $CommandTimeoutSeconds
        $CommandTimeoutFormatted_cl1200 = $CommandTimeoutInSeconds
    } elseif ($null -ne $CommandTimeout) {
        throw "CommandTimeout cannot be zero or a negative number.";
    }
    

    #  note that Get-CubeDatabaseCompatibilityLevel will throw and error if the cube or server do not exist, which is exactly what we want!
    [int]$CompatibilityLevel;
    if ($null -eq $Credential) {
        $CompatibilityLevel = Get-CubeDatabaseCompatibilityLevel -Server $Server -CubeDatabase $CubeDatabase;
        $returnResult = Invoke-ASCmd -Server $Server -ConnectionTimeout 1 -Query "<Discover xmlns='urn:schemas-microsoft-com:xml-analysis'><RequestType>TMSCHEMA_DATA_SOURCES</RequestType><Restrictions><RestrictionList><DatabaseName>$CubeDatabase</DatabaseName></RestrictionList></Restrictions><Properties/></Discover>";
    } else {
        $CompatibilityLevel = Get-CubeDatabaseCompatibilityLevel -Server $Server -CubeDatabase $CubeDatabase -Credential $Credential;
        $returnResult = Invoke-ASCmd -Server $Server -Credential $Credential -ConnectionTimeout 1 -Query "<Discover xmlns='urn:schemas-microsoft-com:xml-analysis'><RequestType>TMSCHEMA_DATA_SOURCES</RequestType><Restrictions><RestrictionList><DatabaseName>$CubeDatabase</DatabaseName></RestrictionList></Restrictions><Properties/></Discover>";
    }

    $returnXml = New-Object -TypeName System.Xml.XmlDocument;
    $returnXml.LoadXml($returnResult);

    [System.Xml.XmlNamespaceManager] $nsmgr = $returnXml.NameTable;
    $nsmgr.AddNamespace('xmlAnalysis', 	'urn:schemas-microsoft-com:xml-analysis');
    $nsmgr.AddNamespace('rootNS', 		'urn:schemas-microsoft-com:xml-analysis:rowset');

    $rows = $returnXML.SelectNodes("//xmlAnalysis:return/rootNS:root/rootNS:row", $nsmgr);

    If (![string]::IsNullOrEmpty($DataSource)) {
        $rows = @($rows | Where-Object { $_.name -eq $DataSource })
    }

    if ($rows.Count -ge 1) {
        [string]$DataSourceName = $rows[0].name;
        $type = $rows[0].type;
        $description = "${rows[0].description}";

        [int]$MaxConnections = $rows[0].MaxConnections;

        if ($CompatibilityLevel -ge 1400 -and $type -eq '2') {
            # New style structured (Power Query) connectors
            $type = "structured"
            $connObj = ConvertFrom-Json -InputObject $rows[0].ConnectionDetails;
            $protocol = $connObj.protocol;
            $authentication = $connObj.authentication;
            $query = $connObj.query;

            $CredentialDetails = ConvertFrom-Json -InputObject $rows[0].Credential;
            $EncryptConnection = $CredentialDetails.EncryptConnection;

            switch ($ImpersonationMode) {
                'ImpersonateServiceAccount' {
                    $credentialNode = [pscustomobject]@{
                        AuthenticationKind = 'ServiceAccount'
                        path = "$SourceSqlServer;$SourceSqlDatabase"
                        EncryptConnection = $EncryptConnection
                    }
                 }
                'ImpersonateAccount' {
                    $credentialNode = [pscustomobject]@{
                        AuthenticationKind = 'Windows'
                        path = "$SourceSqlServer;$SourceSqlDatabase"
                        Username =  $ImpersonationAccount
                        Password = $ImpersonationPwd
                        EncryptConnection = $EncryptConnection
                    }
                 }
                 'UsernamePassword' {
                    $credentialNode = [pscustomobject]@{
                        AuthenticationKind = 'UsernamePassword'
                        kind = "SQL"
                        path = "$SourceSqlServer;$SourceSqlDatabase"
                        Username =  $ImpersonationAccount
                        Password = $ImpersonationPwd
                        EncryptConnection = $EncryptConnection
                    }
                 }
            }

            $dataSourceObject = [pscustomobject]@{
                type = $type
                name = $DataSourceName
                description = $description
                connectionDetails = [pscustomobject]@{
                    protocol = $protocol
                    address = [pscustomobject]@{
                        server = $SourceSqlServer
                        database = $SourceSqlDatabase
                    }
                    authentication = $authentication
                    query = $query
                }
                credential = $credentialNode
            }
            
            # Add command timeout if specified
            If (![string]::IsNullOrEmpty($CommandTimeoutFormatted)) {
                $dataSourceObject | Add-Member -NotePropertyName options -NotePropertyValue @{commandTimeout=$CommandTimeoutFormatted}
            }

        } else {
            # $CompatibilityLevel -lt 1400
            $type = 'model < 1200';  # only used in the message below
            $ExistingConnectionString = $rows[0].ConnectionString;
            $ConnectionString  = Get-SqlConnectionString -SourceSqlServer $SourceSqlServer -SourceSqlDatabase $SourceSqlDatabase -ExistingConnectionString $ExistingConnectionString 

            if ($ImpersonationMode -eq 'ImpersonateAccount') {
                $dataSourceObject = [pscustomobject]@{
                    name = $DataSourceName
                    connectionString = $ConnectionString
                    maxConnections = $MaxConnections
                    impersonationMode = $ImpersonationMode
                    account =  $ImpersonationAccount
                    password = $ImpersonationPwd
                }
            } else {
                $dataSourceObject = [pscustomobject]@{
                    name = $DataSourceName
                    connectionString = $ConnectionString
                    maxConnections = $MaxConnections
                    impersonationMode = $ImpersonationMode
                }
            }
            
            # Add command timeout if specified
            If (![string]::IsNullOrEmpty($CommandTimeoutFormatted_cl1200)) {
                $dataSourceObject | Add-Member -NotePropertyName timeout -NotePropertyValue $CommandTimeoutFormatted_cl1200
            }
           
        }

        $tmslStructure = [pscustomobject]@{
            createOrReplace = [pscustomobject]@{
                object = [pscustomobject]@{
                    database = $CubeDatabase
                    dataSource = $DataSourceName
                }
                dataSource = $dataSourceObject
            }
        }

        $tmsl = $tmslStructure | ConvertTo-Json -Depth 5;

        #Write-Host $tmsl

        # now send the createOrReplace command to the cube
        Write-Verbose "Updating cube data source $DataSourceName with a connection to $SourceSqlServer.$SourceSqlDatabase using a $type createOrReplace TMSL statement";

        if ($null -eq $Credential) {
            $returnResult = Invoke-ASCmd -Server $Server -ConnectionTimeout 10 -Query $tmsl;
        } else {
            $returnResult = Invoke-ASCmd -Server $Server -Credential $Credential -ConnectionTimeout 10 -Query $tmsl;
        }
        
        try {
            $returnXml.LoadXml($returnResult);
            $nsmgr = $returnXml.NameTable;        
            $nsmgr.AddNamespace('xmlAnalysis', 	'urn:schemas-microsoft-com:xml-analysis');
            $nsmgr.AddNamespace('rootNS', 		'urn:schemas-microsoft-com:xml-analysis:empty');
            $resultNodes = $returnXML.SelectNodes("//xmlAnalysis:return/rootNS:root", $nsmgr);

            $ErrorMsg = $resultNodes[0].Messages.Error.Description;
            if ("$ErrorMsg" -eq "") {
                return $true;
            } else {
                Write-Error $ErrorMsg;
                return $false;
            }
        }
        catch
        {
            throw "Executing createOrReplace TMSL returned incorrectly formatted XML";
        }
    } else {
        throw "CubeDatabase $CubeDatabase not found or does not have a data source";
    }
}