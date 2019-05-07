---
external help file: DeployCube-help.xml
Module Name: DeployCube
online version: https://github.com/DrJohnT/DeployCube
schema: 2.0.0
---

# Get-CubeDatabaseCompatibilityLevel

## SYNOPSIS
Gets the compatibility level of a deployed cube.

## SYNTAX

```
Get-CubeDatabaseCompatibilityLevel [-Server] <String> [-CubeDatabase] <String> [<CommonParameters>]
```

## DESCRIPTION
Returns the compatibility level of a deployed cube as an integer.

## EXAMPLES

### EXAMPLE 1
```
Get-CubeDatabaseCompatibilityLevel -Server localhost -CubeDatabase MyTabularCube;
```

Finds MyTabularCube on localhost and returns 1400

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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### System.Int32
## NOTES
Written by (c) Dr.
John Tunnicliffe, 2019 https://github.com/DrJohnT/DeployCube
This PowerShell script is released under the MIT license http://www.opensource.org/licenses/MIT

## RELATED LINKS

[https://github.com/DrJohnT/DeployCube](https://github.com/DrJohnT/DeployCube)

