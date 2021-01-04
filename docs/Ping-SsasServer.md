---
external help file: DeployCube-help.xml
Module Name: DeployCube
online version: https://github.com/DrJohnT/DeployCube
schema: 2.0.0
---

# Ping-SsasServer

## SYNOPSIS
For on-premise SSAS instances only!
Checks that the SQL Server SSAS instance exists.

## SYNTAX

```
Ping-SsasServer [-Server] <String> [<CommonParameters>]
```

## DESCRIPTION
For on-premise SSAS instances only!
Checks that the SQL Server SSAS instance exists.

## EXAMPLES

### EXAMPLE 1
```
Ping-SsasServer -Server build02;
```

Returns true if server build02 exists and has SSAS installed.

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

