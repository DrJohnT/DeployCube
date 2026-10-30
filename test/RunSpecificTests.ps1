[CmdletBinding()]
param()
& (Join-Path $PSScriptRoot 'Invoke-DeployCubeTests.ps1') -Type Unit
