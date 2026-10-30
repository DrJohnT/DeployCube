function Get-DeployCubeRepositoryRoot {
    return (Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath
}

function Get-DeployCubeManifestPath {
    return Join-Path (Join-Path (Get-DeployCubeRepositoryRoot) 'DeployCube') 'DeployCube.psd1'
}

function Import-DeployCubeForTest {
    Get-Module DeployCube | Remove-Module -Force
    Import-Module (Get-DeployCubeManifestPath) -Force -ErrorAction Stop
}

function Get-DeployCubeFixturePath {
    param([Parameter(Mandatory = $true)][string]$Name)
    return Join-Path (Join-Path (Get-DeployCubeRepositoryRoot) 'examples/ForTests') $Name
}

function Copy-DeployCubeFixture {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Destination
    )
    $target = Join-Path $Destination $Name
    if (Test-Path $target) {
        Remove-Item $target -Recurse -Force
    }
    Copy-Item (Get-DeployCubeFixturePath $Name) $target -Recurse -Force
    return Join-Path $target 'Model.asdatabase'
}

function Register-DeployCubeAsCmdStub {
    # Pester needs an existing command to mock, but SqlServer must not be installed or contacted.
    function global:Invoke-ASCmd {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'Matches the external cmdlet signature so Pester can bind mock parameters.')]
        [CmdletBinding()]
        param($Server, $Query, [PSCredential]$Credential, $ConnectionTimeout)
        throw 'Invoke-ASCmd stub called without a mock.'
    }
}

function Unregister-DeployCubeAsCmdStub {
    Remove-Item Function:\global:Invoke-ASCmd -ErrorAction SilentlyContinue
}

function New-DeployCubeXmlaRowset {
    param([hashtable[]]$Rows = @())
    $rowXml = foreach ($row in $Rows) {
        $cells = foreach ($key in $row.Keys) {
            $value = [System.Security.SecurityElement]::Escape([string]$row[$key])
            "<$key>$value</$key>"
        }
        "<row>$($cells -join '')</row>"
    }
    return '<DiscoverResponse xmlns="urn:schemas-microsoft-com:xml-analysis"><return><root xmlns="urn:schemas-microsoft-com:xml-analysis:rowset">' +
        ($rowXml -join '') + '</root></return></DiscoverResponse>'
}

function New-DeployCubeXmlaEmptyResult {
    param([string]$ErrorDescription)
    $messages = ''
    if ($ErrorDescription) {
        $description = [System.Security.SecurityElement]::Escape($ErrorDescription)
        $messages = "<Messages xmlns=`"urn:schemas-microsoft-com:xml-analysis:exception`"><Error ErrorCode=`"-1`" Description=`"$description`" Source=`"Unit test`" HelpFile=`"`" /></Messages>"
    }
    return "<return xmlns=`"urn:schemas-microsoft-com:xml-analysis`"><root xmlns=`"urn:schemas-microsoft-com:xml-analysis:empty`">$messages</root></return>"
}
