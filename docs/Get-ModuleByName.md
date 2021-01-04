---
external help file: DeployCube-help.xml
Module Name: DeployCube
online version: https://github.com/DrJohnT/DeployCube
schema: 2.0.0
---

# Get-ModuleByName

## SYNOPSIS
Loads the named PowerShell module, installing it if needed

## SYNTAX

```
Get-ModuleByName [-Name] <String> [<CommonParameters>]
```

## DESCRIPTION
Loads the named PowerShell module, installing it if needed.

## EXAMPLES

### EXAMPLE 1
```
Get-ModuleByName -Name SqlServer;
```

Will load the SqlServer module, or install it if not present on the host machine.

## PARAMETERS

### -Name
Name of the PowerShell module to load.

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

## NOTES
Written by (c) Dr.
John Tunnicliffe, 2019-2021 https://github.com/DrJohnT/DeployCube
This PowerShell script is released under the MIT license http://www.opensource.org/licenses/MIT

## RELATED LINKS

[https://github.com/DrJohnT/DeployCube](https://github.com/DrJohnT/DeployCube)

