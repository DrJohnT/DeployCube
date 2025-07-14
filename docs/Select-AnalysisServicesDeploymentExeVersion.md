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
Select-AnalysisServicesDeploymentExeVersion -PreferredVersion latest;
```

Returns the latest version of Microsoft.AnalysisServices.Deployment.exe found on the machine.

### EXAMPLE 2
```
Select-AnalysisServicesDeploymentExeVersion -PreferredVersion 14;
```

Returns the SQL Server 2017 version of Microsoft.AnalysisServices.Deployment.exe (if present on the machine).

## PARAMETERS

### -PreferredVersion
The preferred version of Microsoft.AnalysisServices.Deployment.exe to attempt to find.
Valid values for -PreferredVersion are: ('20', '16', '15', '14', '13', '12', '11', 'latest') which translate as follows:

* latest: Latest SQL Server version found on agent
* 16: SQL Server 2022
* 15: SQL Server 2019
* 14: SQL Server 2017
* 13: SQL Server 2016
* 12: SQL Server 2014
* 11: SQL Server 2012

If you are unsure which version(s) of Microsoft.AnalysisServices.Deployment.exe you have installed, use the function \[Find-AnalysisServicesDeploymentExeLocations\](https://github.com/DrJohnT/DeployCube/blob/master/docs/Find-AnalysisServicesDeploymentExeLocations.md) to obtain a full list.

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
John Tunnicliffe, 2019-2021 https://github.com/DrJohnT/DeployCube
This PowerShell script is released under the MIT license http://www.opensource.org/licenses/MIT

## RELATED LINKS

[https://github.com/DrJohnT/DeployCube](https://github.com/DrJohnT/DeployCube)

