---
external help file: DeployCube-help.xml
Module Name: DeployCube
online version: https://github.com/DrJohnT/DeployCube
schema: 2.0.0
---

# Get-AnalysisServicesDeploymentExePath

## SYNOPSIS
Find path to specific version of Microsoft.AnalysisServices.Deployment.exe

## SYNTAX

```
Get-AnalysisServicesDeploymentExePath [-Version] <String> [<CommonParameters>]
```

## DESCRIPTION
Finds the path to specific version of Microsoft.AnalysisServices.Deployment.exe

## EXAMPLES

### EXAMPLE 1
```
Get-AnalysisServicesDeploymentExePath -Version latest
```

Returns the latest version of Microsoft.AnalysisServices.Deployment.exe

## PARAMETERS

### -Version
The version of Microsoft.AnalysisServices.Deployment.exe to find.
Valid values for -Version are: ('15', '14', '13', '12', '11') which translate as follows:
* 15: SQL Server 2019
* 14: SQL Server 2017
* 13: SQL Server 2016
* 12: SQL Server 2014
* 11: SQL Server 2012

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

### Returns a string containing the full path to the selected version of Microsoft.AnalysisServices.Deployment.exe
## NOTES
Written by (c) Dr.
John Tunnicliffe, 2019 https://github.com/DrJohnT/DeployCube
This PowerShell script is released under the MIT license http://www.opensource.org/licenses/MIT

## RELATED LINKS

[https://github.com/DrJohnT/DeployCube](https://github.com/DrJohnT/DeployCube)

