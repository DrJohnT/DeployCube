[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('1500')]
    [string]$CompatibilityLevel,

    [Parameter(Mandatory = $true)]
    [string]$LogDirectory
)

$ErrorActionPreference = 'Stop'
$fixtureDirectory = Join-Path $PSScriptRoot "fixtures\Tabular$CompatibilityLevel"
$outputDirectory = Join-Path $LogDirectory "fixture-tabular-$CompatibilityLevel"
$fixtureFiles = @(
    'Model.asdatabase',
    'Model.deploymentoptions',
    'Model.deploymenttargets'
)

New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
foreach ($fixtureFile in $fixtureFiles) {
    $sourcePath = Join-Path $fixtureDirectory $fixtureFile
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "The checked-in Tabular compatibility fixture is missing '$sourcePath'."
    }

    Copy-Item -LiteralPath $sourcePath -Destination $outputDirectory -Force
}

$modelPath = Join-Path $outputDirectory 'Model.asdatabase'
$model = Get-Content -LiteralPath $modelPath -Raw | ConvertFrom-Json -ErrorAction Stop
if ([int]$model.compatibilityLevel -ne [int]$CompatibilityLevel) {
    throw "Fixture compatibility level '$($model.compatibilityLevel)' does not match requested level '$CompatibilityLevel'."
}

return $modelPath
