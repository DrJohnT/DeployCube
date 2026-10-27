[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('1200', '1500')]
    [string]$CompatibilityLevel,

    [Parameter(Mandatory = $true)]
    [string]$LogDirectory
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$projectDirectory = Join-Path $repositoryRoot "examples\CubeAtCompatibility$CompatibilityLevel"
$projectPath = Join-Path $projectDirectory "CubeAtCompatibility$CompatibilityLevel.smproj"
$outputPath = Join-Path $projectDirectory 'bin\Model.asdatabase'
$logPath = Join-Path $LogDirectory "build-tabular-$CompatibilityLevel.log"
$vswherePath = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'

if (-not (Test-Path -LiteralPath $vswherePath)) {
    throw "Visual Studio locator was not found at '$vswherePath'; cannot build the checked-in Tabular compatibility fixture."
}

$msbuildPath = & $vswherePath -latest -products '*' -requires Microsoft.Component.MSBuild -find 'MSBuild\Current\Bin\MSBuild.exe' |
    Select-Object -First 1
if (-not $msbuildPath -or -not (Test-Path -LiteralPath $msbuildPath)) {
    throw 'MSBuild.exe was not found on the GitHub-hosted Windows runner.'
}
if (-not (Test-Path -LiteralPath $projectPath)) {
    throw "The checked-in Tabular project fixture is missing: '$projectPath'."
}

New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
$buildArguments = @(
    $projectPath,
    '/t:Build',
    '/p:Configuration=Development',
    '/p:VisualStudioVersion=17.0',
    '/nologo',
    '/verbosity:minimal'
)
& $msbuildPath @buildArguments *> $logPath
if ($LASTEXITCODE -ne 0) {
    throw "Tabular model build failed with exit code $LASTEXITCODE. See '$logPath'; this runner may not have the Analysis Services Projects build targets."
}
if (-not (Test-Path -LiteralPath $outputPath -PathType Leaf)) {
    throw "MSBuild succeeded but did not produce '$outputPath'. No model deployment is claimed; inspect '$logPath'."
}

$outputPath
