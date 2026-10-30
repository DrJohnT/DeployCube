[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$files = Get-ChildItem $root -Recurse -File -Include '*.ps1', '*.psm1', '*.psd1' |
    Where-Object { $_.FullName -notmatch '[/\\](\.git|TestResults)[/\\]' }
$failures = foreach ($file in $files) {
    $tokens = $null
    $parseErrors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors)
    foreach ($parseError in $parseErrors) {
        '{0}:{1}: {2}' -f $file.FullName, $parseError.Extent.StartLineNumber, $parseError.Message
    }
}
if ($failures) { throw ($failures -join [Environment]::NewLine) }
Test-ModuleManifest (Join-Path $root 'DeployCube/DeployCube.psd1') -ErrorAction Stop | Out-Null
Write-Information "Parsed $(@($files).Count) PowerShell files and validated the module manifest." -InformationAction Continue
