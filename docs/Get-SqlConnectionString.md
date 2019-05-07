---
external help file: DeployCube-help.xml
Module Name: DeployCube
online version: https://github.com/DrJohnT/DeployCube
schema: 2.0.0
---

# Get-SqlConnectionString

## SYNOPSIS
Updates a connection strings to source SQL databases with new server and database names.

## SYNTAX

```
Get-SqlConnectionString [-SourceSqlServer] <String> [-SourceSqlDatabase] <String>
 [-ExistingConnectionString] <String> [<CommonParameters>]
```

## DESCRIPTION
Helper function to help create valid connection strings to source SQL databases.

## EXAMPLES

### EXAMPLE 1
```
Get-SqlConnectionString -SourceSqlServer myserver -SourceSqlDatabase mydatabase -ExistingConnectionString 'Provider=SQLNCLI11;Data Source=localhost;Initial Catalog=DatabaseToPublish;Integrated Security=SSPI;Persist Security Info=false';
```

Returns
'Provider=SQLNCLI11;Data Source=myserver;Persist Security Info=False;Integrated Security=SSPI;Initial Catalog=mydatabase'

## PARAMETERS

### -SourceSqlServer
Name of the SQL server, including instance and port if required.

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

### -SourceSqlDatabase
Name of the source SQL database.

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

### -ExistingConnectionString
The existing SQL connection string obtained from the cube definition or config file.

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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### System.String
## NOTES
Written by (c) Dr.
John Tunnicliffe, 2019 https://github.com/DrJohnT/DeployCube
This PowerShell script is released under the MIT license http://www.opensource.org/licenses/MIT

## RELATED LINKS

[https://github.com/DrJohnT/DeployCube](https://github.com/DrJohnT/DeployCube)

