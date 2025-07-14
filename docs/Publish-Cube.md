---
external help file: DeployCube-help.xml
Module Name: DeployCube
online version: https://github.com/DrJohnT/DeployCube
schema: 2.0.0
---

# Publish-Cube

## SYNOPSIS
Publish-Cube deploys a tabular or multidimentional cube to a SQL Server Analysis Services instance.

## SYNTAX

```
Publish-Cube [-AsDatabasePath] <String> [-Server] <String> [-CubeDatabase] <String>
 [[-PreferredVersion] <String>] [[-ProcessingOption] <String>] [[-TransactionalDeployment] <Boolean>]
 [[-PartitionDeployment] <String>] [[-RoleDeployment] <String>] [[-ConfigurationSettingsDeployment] <String>]
 [[-OptimizationSettingsDeployment] <String>] [[-WriteBackTableCreation] <String>] [[-UserID] <String>]
 [[-Password] <String>] [<CommonParameters>]
```

## DESCRIPTION
Publish-Cube deploys a tabular or multidimentional cube to a SQL Server Analysis Services instance.

## EXAMPLES

### EXAMPLE 1
```
Publish-Cube -AsDatabasePath 'C:\Dev\YourDB\bin\Debug\YourDB.asdatabase' -Server YourDBServer -CubeDatabase MyTabularCube
```

## PARAMETERS

### -AsDatabasePath
Full path to your database XMLA or TMSL file which has a .asdatabase file extension.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Server
Name of the target SSAS server, including instance and port if required.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -CubeDatabase
The name of the cube database to be deployed.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -PreferredVersion
Defines the preferred version of Microsoft.AnalysisServices.Deployment.exe you wish to use. 
Use 'latest' for the latest version, or do not provide the parameter as the default is 'latest'.
Valid values for -PreferredVersion are: ('20', '16', '15', '14', '13', '12', '11') which translate as follows:
* latest: Latest SQL Server version found on agent
* 16: SQL Server 2022
* 15: SQL Server 2019
* 14: SQL Server 2017
* 13: SQL Server 2016
* 12: SQL Server 2014
* 11: SQL Server 2012

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: Latest
Accept pipeline input: False
Accept wildcard characters: False
```

### -ProcessingOption
Determines how the newely deployed cube is processed after deployment.
Strongly recommend using the default "DoNotProcess" option as the connection to your source database may not be correct and need adjustment post-deployment.
* Valid options are: Full, Default and DoNotProcess.
* Default value: 'DoNotProcess'.
* 'Full': processes all the objects in the cube database.
When Full processing is executed against an object that has already been processed, Analysis Services drops all data in the object and then processes the object.
* 'Default': detects the process state of cube database objects, and performs the processing necessary to deliver unprocessed or partially processed objects to a fully processed state.
* 'DoNotProcess': means no processing is performed.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
Default value: DoNotProcess
Accept pipeline input: False
Accept wildcard characters: False
```

### -TransactionalDeployment
Determines if the cube is deployed within one transaction for both metadata changes and processing commands.
* If this option is True, Analysis Services deploys all metadata changes and all process commands within a single transaction.
* If this option is False (default), Analysis Services deploys the metadata changes in a single transaction, and deploys each processing command in its own transaction.

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 6
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -PartitionDeployment
Determines if partitions are deployed.
* Valid options are: 'DeployPartitions' and 'RetainPartitions'.
* Default value: 'DeployPartitions'.
* 'DeployPartitions': New partitions are deployed. 
Existing partitions are removed.
* 'RetainPartitions': Existing partitions are retained. 
New partitions are not deployed.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 7
Default value: DeployPartitions
Accept pipeline input: False
Accept wildcard characters: False
```

### -RoleDeployment
Determines if the roles and members are deployed.
* Valid options are: 'DeployRolesAndMembers', 'DeployRolesRetainMembers' and 'RetainRoles'.
* Default value: 'DeployRolesRetainMembers'.
* 'DeployRolesRetainMembers': Existing roles and role members in the destination database are retained, and only new roles and role members are deployed.
* 'DeployRolesAndMembers': All existing roles and members in the destination database are replaced by the roles and members being deployed.
* 'RetainRoles': Existing roles and role members in the destination database are retained, and no new roles are deployed.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 8
Default value: DeployRolesRetainMembers
Accept pipeline input: False
Accept wildcard characters: False
```

### -ConfigurationSettingsDeployment
* Valid options are: 'Retain' and 'Deploy'.
* Default value: 'Deploy'.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 9
Default value: Deploy
Accept pipeline input: False
Accept wildcard characters: False
```

### -OptimizationSettingsDeployment
* Valid options are: 'Retain' and 'Deploy'.
* Default value: 'Deploy'.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 10
Default value: Deploy
Accept pipeline input: False
Accept wildcard characters: False
```

### -WriteBackTableCreation
Determines if a write back table is created
* Valid only for multidimensional cubes. 
Determines if the deployment should create the writeback table.
* Valid options are: 'Create', 'CreateAlways' and 'UseExisting'.
* Default value: 'UseExisting'.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 11
Default value: UseExisting
Accept pipeline input: False
Accept wildcard characters: False
```

### -UserID
\[Optional\] The user name used to connect to the AAS server.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 12
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Password
\[Optional\] The password of the above user (in plain text unfortunately).

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 13
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES
Written by (c) Dr.
John Tunnicliffe, 2019-2021 https://github.com/DrJohnT/DeployCube
This PowerShell script is released under the MIT license http://www.opensource.org/licenses/MIT

## RELATED LINKS

[https://github.com/DrJohnT/DeployCube](https://github.com/DrJohnT/DeployCube)

