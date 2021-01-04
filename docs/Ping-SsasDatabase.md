---
external help file: DeployCube-help.xml
Module Name: DeployCube
online version: https://github.com/DrJohnT/DeployCube
schema: 2.0.0
---

# Ping-SsasDatabase

## SYNOPSIS
Checks that the database exists on the specified SQL Server SSAS instance

## SYNTAX

```
Ping-SsasDatabase [-Server] <String> [-CubeDatabase] <String> [[-Credential] <PSCredential>]
 [<CommonParameters>]
```

## DESCRIPTION
Checks that the database exists on the specified SQL Server SSAS instance

## EXAMPLES

### EXAMPLE 1
```
Ping-SsasDatabase -Server build02 -CubeDatabase 'MyTabularCube'
```

Returns true of the SSAS instance on build02 has a cube called 'MyTabularCube'

## PARAMETERS

### -Server
Name of the SSAS server, including instance and port if required.

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
The name of the cube database to be deployed.

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
\[Optional\] A PSCredential object containing the credentials to connect to the AAS server.

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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### System.Boolean
## NOTES
Written by (c) Dr.
John Tunnicliffe, 2019-2021 https://github.com/DrJohnT/DeployCube
This PowerShell script is released under the MIT license http://www.opensource.org/licenses/MIT

## RELATED LINKS

[https://github.com/DrJohnT/DeployCube](https://github.com/DrJohnT/DeployCube)

