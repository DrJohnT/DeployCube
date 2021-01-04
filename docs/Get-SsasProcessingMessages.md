---
external help file: DeployCube-help.xml
Module Name: DeployCube
online version: https://github.com/DrJohnT/DeployCube
schema: 2.0.0
---

# Get-SsasProcessingMessages

## SYNOPSIS
Examines the XML returned by the Invoke-AsCmd function to find errors. 
Writes error message if errors are found.

## SYNTAX

```
Get-SsasProcessingMessages [-ASCmdReturnString] <String> [<CommonParameters>]
```

## DESCRIPTION
Examines the XML returned by the Invoke-AsCmd function to find errors. 
Writes error message if errors are found.

## EXAMPLES

### EXAMPLE 1
```
Get-SsasProcessingMessages -ASCmdReturnString $xmlMessages;
```

Analyses the messages within the $xmlMessages for errors.

## PARAMETERS

### -ASCmdReturnString
The XML returned by the Invoke-AsCmd function.

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

### No return parameters.  Writes to error stream only if an error is detected.
## NOTES
Written by (c) Dr.
John Tunnicliffe, 2019-2021 https://github.com/DrJohnT/DeployCube
This PowerShell script is released under the MIT license http://www.opensource.org/licenses/MIT

## RELATED LINKS

[https://github.com/DrJohnT/DeployCube](https://github.com/DrJohnT/DeployCube)

