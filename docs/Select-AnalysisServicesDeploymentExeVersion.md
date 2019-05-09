---
external help file: DeployCube-help.xml
Module Name: DeployCube
online version: https://github.com/DrJohnT/DeployCube
schema: 2.0.0
---

# Select-AnalysisServicesDeploymentExeVersion

## SYNOPSIS
Selects a version of Microsoft.AnalysisServices.Deployment.exe to use

## SYNTAX

```
Select-AnalysisServicesDeploymentExeVersion [-PreferredVersion] <String> [<CommonParameters>]
```

## DESCRIPTION
Selects a version of Microsoft.AnalysisServices.Deployment.exe to use

## EXAMPLES

### EXAMPLE 1
```
Select-AnalysisServicesDeploymentExeVersion -PreferredVersion 140;
```

## PARAMETERS

### -PreferredVersion
The preferred version of Microsoft.AnalysisServices.Deployment.exe to attempte to find.
Valid values for -PreferredVersion are:
* latest: Latest SQL Server version found on agent
* 150: SQL Server 2019
* 140: SQL Server 2017
* 130: SQL Server 2016
* 120: SQL Server 2014

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

### Returns a string containing the version found, if the preferred version could not be found.
## NOTES
Written by (c) Dr.
John Tunnicliffe, 2019 https://github.com/DrJohnT/DeployCube
This PowerShell script is released under the MIT license http://www.opensource.org/licenses/MIT

## RELATED LINKS

[https://github.com/DrJohnT/DeployCube](https://github.com/DrJohnT/DeployCube)

