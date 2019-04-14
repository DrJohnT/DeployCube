function Update-CubeDataSource {
    <#
        .SYNOPSIS
        Updates the cube's connection to the source SQL database

		Written by (c) Dr. John Tunnicliffe, 2019 https://github.com/DrJohnT/DeployCube
		This PowerShell script is released under the MIT license http://www.opensource.org/licenses/MIT
    #>
    [CmdletBinding()]
    param
    (
        [String] [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $Server,

        [String] [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $CubeDatabase,

        [String] [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $SourceSqlServer,

        [String] [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $SourceSqlDatabase,

        [String] [Parameter(Mandatory = $true)]
        [ValidateSet('ImpersonateServiceAccount', 'ImpersonateAccount')]
        [ValidateNotNullOrEmpty()]
        $ImpersonationMode,

        [String] [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        $ImpersonationAccount,

        [SecureString] [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        $ImpersonationPassword
    )

    Import-Module -Name SqlServer;
    $path = Get-SqlAsPath -Server $Server -Database $CubeDatabase;
    $DataSources = Get-ChildItem -Path "$path\DataSources";

    foreach ($DataSource in $DataSources) {
        [string]$DataSourceName = $DataSource.Name;
        [string]$Isolation = $DataSource.isolation;
        [int]$MaxConnections = $DataSource.MaxConnections
        $ExistingConnectionString = $DataSource.ConnectionString;
        $ConnectionString  = Get-SqlConnectionString -SourceSqlServer $SourceSqlServer -SourceSqlDatabase $SourceSqlDatabase -ExistingConnectionString  $ExistingConnectionString;

        if ($ImpersonationMode -eq 'ImpersonateAccount') {
            $tmslStructure = [pscustomobject]@{
                createOrReplace = [pscustomobject]@{
                    object = [pscustomobject]@{
                        database = $DatabaseName
                        dataSource = $DataSourceName
                    }
                    dataSource = [pscustomobject]@{
                        name = $DataSourceName
                        connectionString = $ConnectionString
                        isolation = $Isolation
                        maxConnections = $MaxConnections
                        impersonationMode = $ImpersonationMode
                        account =  $ImpersonationAccount
                        password = $ImpersonationPassword
                    }
                }
            }
        } else {
            $tmslStructure = [pscustomobject]@{
                createOrReplace = [pscustomobject]@{
                    object = [pscustomobject]@{
                        database = $DatabaseName
                        dataSource = $DataSourceName
                    }
                    dataSource = [pscustomobject]@{
                        name = $DataSourceName
                        connectionString = $ConnectionString
                        isolation = $Isolation
                        maxConnections = $MaxConnections
                        impersonationMode = $ImpersonationMode
                    }
                }
            }
        }

        $tmsl = $tmslStructure | ConvertTo-Json;
        # now send the createOrReplace command to the cube

        Invoke-ASCmd -Server $Server -ConnectionTimeout 1 -Query $tmsl; 2>&1;

    }
}