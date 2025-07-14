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
Checks the following locations: 

    ${env:ProgramFiles(x86)}\Microsoft SQL Server\*\Tools\Binn
    ${env:ProgramFiles(x86)}\Microsoft SQL Server Management Studio *\Common7\IDE
    $env:CustomAsDwInstallLocation

The environment variable $env:CustomAsDwInstallLocation allows you to specify your own custom install directory.

## EXAMPLES

### EXAMPLE 1
```
Get-AnalysisServicesDeploymentExePath -Version 15
```

Returns the SQL Server 2019 version of Microsoft.AnalysisServices.Deployment.exe (if present on the machine).

### EXAMPLE 2
```
Get-AnalysisServicesDeploymentExePath -Version 14
```

Returns the SQL Server 2017 version of Microsoft.AnalysisServices.Deployment.exe (if present on the machine).

## PARAMETERS

### -Version
The version of Microsoft.AnalysisServices.Deployment.exe to find.
Valid values for -Version are: ('20', '16', '15', '14', '13', '12', '11') which translate as follows:

* 16: SQL Server 2022
* 15: SQL Server 2019
* 14: SQL Server 2017
* 13: SQL Server 2016
* 12: SQL Server 2014
* 11: SQL Server 2012

If you are unsure which version(s) of Microsoft.AnalysisServices.Deployment.exe you have installed, use the function **Find-AnalysisServicesDeploymentExeLocations** to obtain a full list.

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
John Tunnicliffe, 2019-2021 https://github.com/DrJohnT/DeployCube
This PowerShell script is released under the MIT license http://www.opensource.org/licenses/MIT

## RELATED LINKS

[https://github.com/DrJohnT/DeployCube](https://github.com/DrJohnT/DeployCube)

