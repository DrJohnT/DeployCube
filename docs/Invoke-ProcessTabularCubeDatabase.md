---
external help file: DeployCube-help.xml
Module Name: DeployCube
online version: https://github.com/DrJohnT/DeployCube
schema: 2.0.0
---

# Invoke-ProcessTabularCubeDatabase

## SYNOPSIS
Processes an SSAS database on a SQL Server SSAS instance

## SYNTAX

```
Invoke-ProcessTabularCubeDatabase [-Server] <String> [-CubeDatabase] <String> [[-RefreshType] <String>]
 [<CommonParameters>]
```

## DESCRIPTION
Processes an SSAS database on a SQL Server SSAS instance

## EXAMPLES

### Example 1
```powershell
PS C:\> {{ Add example code here }}
```

{{ Add example description here }}

## PARAMETERS

### -Server
Name of the target SSAS server, including instance and port if required.

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
The name of the tabular cube database on the SSAS server.

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

### -RefreshType
Valid options are: 'Full', 'Automatic', 'ClearValues', 'Calculate'.
Default value: 'Full'.
'Full': processes all the objects in the cube database.
When Full processing is executed against an object that has already been processed, Analysis Services drops all data in the object and then processes the object.
'Automatic': detects the process state of cube database objects, and performs the processing necessary to deliver unprocessed or partially processed objects to a fully processed state.
'ClearValues': Clear values in this object and all its dependents.
'Calculate': Recalculate this object and all its dependents, but only if needed.
This value does not force recalculation, except for volatile formulas.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: Full
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES
Written by (c) Dr.
John Tunnicliffe, 2019 https://github.com/DrJohnT/DeployCube
This PowerShell script is released under the MIT license http://www.opensource.org/licenses/MIT

## RELATED LINKS

[https://github.com/DrJohnT/DeployCube](https://github.com/DrJohnT/DeployCube)

