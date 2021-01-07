---
external help file: DeployCube-help.xml
Module Name: DeployCube
online version: https://github.com/DrJohnT/DeployCube
schema: 2.0.0
---

# Update-TabularCubeDataSource

## SYNOPSIS
Updates the tabular cube's connection to the source SQL database.

## SYNTAX

```
Update-TabularCubeDataSource [-Server] <String> [-CubeDatabase] <String> [[-Credential] <PSCredential>]
 [-SourceSqlServer] <String> [-SourceSqlDatabase] <String> [-ImpersonationMode] <String>
 [[-ImpersonationAccount] <String>] [[-ImpersonationPwd] <String>] [<CommonParameters>]
```

## DESCRIPTION
Connects to the deployed tabular cube and updates the connection to the source SQL database.
Supports the newer PowerQuery style tabular cubes with CompatibilityLevel = 1400.

## EXAMPLES

### EXAMPLE 1
```
Update-TabularCubeDataSource -Server localhost -CubeDatabase MyCube -SourceSqlServer localhost -SourceSqlDatabase MyDB -ImpersonationMode ImpersonateServiceAccount;
```

## PARAMETERS

### -Server
SSAS Server Name or IP address. 
Include the instance name and port if necessary (e.g.
myserver\\\\myinstance,myport)

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

### -CubeDatabase
The name of the deployed tabular cube database.

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

### -Credential
A PSCredential object containing the credentials to connect to the AAS server.

```yaml
Type: PSCredential
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -SourceSqlServer
The name of the source SQL Server server or its IP address. 
Include the instance name and port if necessary.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 4
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -SourceSqlDatabase
The name of the database which will act as a source of data for the tabular cube database.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 5
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ImpersonationMode
Defines how the cube will connect to the data source.
Possible options are 'ImpersonateServiceAccount' which connects to the SQL Server database using ,
or 'ImpersonateAccount' which uses a specific username/password. 
When using 'ImpersonateAccount' it is best to use a domain based service account with a static password.

```yaml
Type: String
Parameter Sets: (All)
Aliases: AuthenticationKind

Required: True
Position: 6
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ImpersonationAccount
The username of the account that will be used to connect to the SQL Server database. 
Required for ImpersonationMode='ImpersonateAccount'.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 7
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ImpersonationPwd
The password of the account that will be used to connect to the SQL Server database. 
Required for ImpersonationMode='ImpersonateAccount'.

```yaml
Type: String
Parameter Sets: (All)
Aliases: ImpersonationPassword

Required: False
Position: 8
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### Returns true if the cube's data source was updated successfully.
## NOTES
Written by (c) Dr.
John Tunnicliffe, 2019-2021 https://github.com/DrJohnT/DeployCube
This PowerShell script is released under the MIT license http://www.opensource.org/licenses/MIT

## RELATED LINKS

[https://github.com/DrJohnT/DeployCube](https://github.com/DrJohnT/DeployCube)

