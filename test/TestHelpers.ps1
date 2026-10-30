# Shared helpers for the DeployCube Pester suites. Must stay compatible with Windows PowerShell 5.1
# (for example, Join-Path only accepts a single -ChildPath there, so paths are built with nested calls).

function Get-DeployCubeRepositoryRoot {
    return (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..')).ProviderPath
}

function Get-DeployCubeManifestPath {
    $root = Get-DeployCubeRepositoryRoot
    return (Join-Path -Path (Join-Path -Path $root -ChildPath 'DeployCube') -ChildPath 'DeployCube.psd1')
}

function Import-DeployCubeForTest {
    Get-Module -Name DeployCube | Remove-Module -Force
    Import-Module -Name (Get-DeployCubeManifestPath) -Force -ErrorAction Stop
}

function Get-DeployCubeFixturePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )
    $root = Get-DeployCubeRepositoryRoot
    $forTests = Join-Path -Path (Join-Path -Path $root -ChildPath 'examples') -ChildPath 'ForTests'
    return (Join-Path -Path $forTests -ChildPath $Name)
}

function Copy-DeployCubeFixture {
    <#
        Copies a fixture folder from examples/ForTests to a destination (normally TestDrive) so tests never
        modify tracked repository files. Returns the path of the copied Model.asdatabase file.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [string]$Destination
    )
    $source = Get-DeployCubeFixturePath -Name $Name
    $target = Join-Path -Path $Destination -ChildPath $Name
    if (Test-Path -Path $target) {
        Remove-Item -Path $target -Recurse -Force
    }
    Copy-Item -Path $source -Destination $target -Recurse -Force
    return (Join-Path -Path $target -ChildPath 'Model.asdatabase')
}

function Test-DeployCubeFlag {
    param([string]$Value)
    return @('1', 'true', 'yes') -contains "$Value".Trim().ToLowerInvariant()
}

function Test-DeployCubeIntegrationEnabled {
    return (Test-DeployCubeFlag -Value $env:DEPLOYCUBE_RUN_INTEGRATION)
}

function Test-DeployCubeAzureIntegrationEnabled {
    return (Test-DeployCubeFlag -Value $env:DEPLOYCUBE_RUN_AZURE_INTEGRATION)
}

function Test-DeployCubeLocalServer {
    <#
        True when an SSAS server name refers to this machine, e.g. localhost, ., (local), 127.0.0.1, ::1 or the
        computer name, with or without an instance name (localhost\TABULAR) or port (localhost:2383).
    #>
    param([string]$Server)
    # Anything not recognised is treated as remote, which is the safe direction.
    $hostName = ("$Server".Trim() -split '\\')[0].ToLowerInvariant()
    if ($hostName -ne '::1') {
        $hostName = ($hostName -split '[:,]')[0]
    }
    $localNames = @('localhost', '.', '(local)', '127.0.0.1', '::1', [Environment]::MachineName.ToLowerInvariant())
    return ($localNames -contains $hostName)
}

function Assert-DeployCubeDisposableServer {
    <#
        Integration tests deploy, process, rewrite and drop databases. Refuse any server that is not on this machine
        unless it has been explicitly declared disposable by setting DEPLOYCUBE_DISPOSABLE_SSAS_SERVER to exactly the
        same name, so a mistyped or leftover DEPLOYCUBE_SSAS_SERVER can never point the suite at a shared server.
    #>
    param([Parameter(Mandatory)][string]$Server)
    if ($Server -like 'asazure://*') {
        throw "Refusing to run SSAS integration tests against Azure Analysis Services server '$Server'. Use -Type Azure for Azure tests."
    }
    if (Test-DeployCubeLocalServer -Server $Server) {
        return
    }
    if ("$env:DEPLOYCUBE_DISPOSABLE_SSAS_SERVER".Trim() -ne $Server.Trim()) {
        throw ("Refusing to run SSAS integration tests against remote server '$Server'. Integration tests create, overwrite, " +
            "process and drop databases. If '$Server' is a dedicated, disposable test instance, set " +
            "DEPLOYCUBE_DISPOSABLE_SSAS_SERVER to the same value to confirm.")
    }
}

function Get-DeployCubeIntegrationSettings {
    <#
        Integration test settings. Defaults reproduce the original suite (a local default SSAS Tabular instance
        with the example models built in Visual Studio/SSDT). Override with environment variables to target a
        dedicated SSAS test instance.
    #>
    $root = Get-DeployCubeRepositoryRoot
    $examples = Join-Path -Path $root -ChildPath 'examples'

    $default1200 = Join-Path -Path (Join-Path -Path (Join-Path -Path $examples -ChildPath 'CubeAtCompatibility1200') -ChildPath 'bin') -ChildPath 'Model.asdatabase'
    $default1500 = Join-Path -Path (Join-Path -Path (Join-Path -Path $examples -ChildPath 'CubeAtCompatibility1500') -ChildPath 'bin') -ChildPath 'Model.asdatabase'

    $server = if ($env:DEPLOYCUBE_SSAS_SERVER) { $env:DEPLOYCUBE_SSAS_SERVER } else { 'localhost' }
    if (Test-DeployCubeIntegrationEnabled) {
        # Every integration test file loads its settings in BeforeAll, so an unsafe target fails the file before any test runs.
        Assert-DeployCubeDisposableServer -Server $server
    }

    return [pscustomobject]@{
        Server                       = $server
        SourceSqlServer              = if ($env:DEPLOYCUBE_SOURCE_SQL_SERVER) { $env:DEPLOYCUBE_SOURCE_SQL_SERVER } else { $server }
        SourceSqlDatabase            = if ($env:DEPLOYCUBE_SOURCE_SQL_DATABASE) { $env:DEPLOYCUBE_SOURCE_SQL_DATABASE } else { 'DatabaseToPublish' }
        AsDatabasePath1200           = if ($env:DEPLOYCUBE_ASDATABASE_1200) { $env:DEPLOYCUBE_ASDATABASE_1200 } else { $default1200 }
        AsDatabasePath1500           = if ($env:DEPLOYCUBE_ASDATABASE_1500) { $env:DEPLOYCUBE_ASDATABASE_1500 } else { $default1500 }
        ExpectedDeploymentExeVersion = if ($env:DEPLOYCUBE_EXPECTED_DEPLOYMENT_EXE_VERSION) { $env:DEPLOYCUBE_EXPECTED_DEPLOYMENT_EXE_VERSION } else { '15' }
    }
}

function Get-DeployCubeIntegrationPrerequisiteIssues {
    <#
        Returns a list of human-readable problems that would prevent the SSAS integration suite from running.
        An empty result means the environment looks usable. Requires the DeployCube module to be imported.
    #>
    $issues = New-Object System.Collections.Generic.List[string]
    try {
        $settings = Get-DeployCubeIntegrationSettings
    }
    catch {
        $issues.Add($_.Exception.Message)
        return $issues
    }

    $onWindows = ($PSVersionTable.PSEdition -ne 'Core') -or $IsWindows
    if (-not $onWindows) {
        $issues.Add('SSAS integration tests require Windows.')
        return $issues
    }

    $version = Select-AnalysisServicesDeploymentExeVersion -PreferredVersion latest -WarningAction SilentlyContinue
    if (-not $version) {
        $issues.Add('Microsoft.AnalysisServices.Deployment.exe was not found (install SSMS or set CustomAsDwInstallLocation).')
    }

    foreach ($path in @($settings.AsDatabasePath1200, $settings.AsDatabasePath1500)) {
        if (-not (Test-Path -Path $path)) {
            $issues.Add("Built model not found: $path (build the example Tabular projects or set DEPLOYCUBE_ASDATABASE_1200/1500).")
        }
    }

    if (-not (Get-Module -ListAvailable -Name SqlServer)) {
        $issues.Add('The SqlServer PowerShell module is not installed (Install-Module SqlServer -Scope CurrentUser).')
    }

    if (-not (Ping-SsasServer -Server $settings.Server)) {
        $issues.Add("SSAS server '$($settings.Server)' is not reachable (set DEPLOYCUBE_SSAS_SERVER).")
    }

    return $issues
}

function Register-DeployCubeAsCmdStub {
    <#
        Invoke-ASCmd ships in the SqlServer module, which unit tests must not require. Pester can only mock a
        command that exists, so define a stand-in that unit tests then mock with -ModuleName DeployCube.
        The stub throws if it is ever called un-mocked, so no test can accidentally reach a real server.
    #>
    function global:Invoke-ASCmd {
        [CmdletBinding()]
        param($Server, $Query, $Credential, $ConnectionTimeout)
        throw 'Invoke-ASCmd stub called without a mock.'
    }
}

function Unregister-DeployCubeAsCmdStub {
    Remove-Item -Path Function:\global:Invoke-ASCmd -ErrorAction SilentlyContinue
}

function New-DeployCubeXmlaRowset {
    <# Builds an XMLA DiscoverResponse rowset like the one returned by Invoke-ASCmd. Each row is a hashtable. #>
    param([hashtable[]]$Rows = @())

    $rowXml = foreach ($row in $Rows) {
        $cells = foreach ($key in $row.Keys) {
            $value = [System.Security.SecurityElement]::Escape([string]$row[$key])
            "<$key>$value</$key>"
        }
        "<row>$($cells -join '')</row>"
    }
    return '<DiscoverResponse xmlns="urn:schemas-microsoft-com:xml-analysis"><return><root xmlns="urn:schemas-microsoft-com:xml-analysis:rowset">' +
        ($rowXml -join '') +
        '</root></return></DiscoverResponse>'
}

function New-DeployCubeXmlaEmptyResult {
    <# Builds an XMLA "empty" result as returned by TMSL commands, optionally containing an error message. #>
    param([string]$ErrorDescription)

    $messages = ''
    if ($ErrorDescription) {
        $description = [System.Security.SecurityElement]::Escape($ErrorDescription)
        $messages = "<Messages xmlns=`"urn:schemas-microsoft-com:xml-analysis:exception`"><Error ErrorCode=`"-1`" Description=`"$description`" Source=`"Unit test`" HelpFile=`"`" /></Messages>"
    }
    return "<return xmlns=`"urn:schemas-microsoft-com:xml-analysis`"><root xmlns=`"urn:schemas-microsoft-com:xml-analysis:empty`">$messages</root></return>"
}

function Initialize-DeployCubeIntegrationBaseline {
    <#
        Several integration tests expect the example cubes CubeAtCompatibility1200 and CubeAtCompatibility1500 to
        exist on the SSAS test server (the original suite relied on them being deployed by hand). Deploy them only
        when missing so the suite is repeatable against a fresh dedicated instance.
    #>
    $settings = Get-DeployCubeIntegrationSettings
    $baseline = @(
        @{ Name = 'CubeAtCompatibility1200'; Path = $settings.AsDatabasePath1200 },
        @{ Name = 'CubeAtCompatibility1500'; Path = $settings.AsDatabasePath1500 }
    )
    $savedPreference = $global:ErrorActionPreference
    try {
        foreach ($cube in $baseline) {
            if (-not (Ping-SsasDatabase -Server $settings.Server -CubeDatabase $cube.Name)) {
                Publish-Cube -AsDatabasePath $cube.Path -Server $settings.Server -CubeDatabase $cube.Name | Out-Null
            }
        }
    } finally {
        # Publish-Cube changes the global ErrorActionPreference (assessment F03).
        $global:ErrorActionPreference = $savedPreference
    }
}
