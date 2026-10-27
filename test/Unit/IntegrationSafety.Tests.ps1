# Guards that keep the live integration suites from touching anything other than an explicitly chosen, disposable
# SSAS instance. These run with the unit tests so a regression is caught on every pull request.

BeforeDiscovery {
    $integrationFolder = Join-Path -Path (Split-Path -Parent $PSScriptRoot) -ChildPath 'Integration'
    $integrationFiles = @(Get-ChildItem -Path $integrationFolder -Filter '*.Tests.ps1' | ForEach-Object { @{ Name = $_.Name; FullName = $_.FullName } })
}

BeforeAll {
    . (Join-Path -Path (Split-Path -Parent $PSScriptRoot) -ChildPath 'TestHelpers.ps1')

    $script:SavedEnvironment = @{}
    foreach ($name in 'DEPLOYCUBE_RUN_INTEGRATION', 'DEPLOYCUBE_SSAS_SERVER', 'DEPLOYCUBE_DISPOSABLE_SSAS_SERVER') {
        $script:SavedEnvironment[$name] = [Environment]::GetEnvironmentVariable($name)
    }
}

AfterAll {
    foreach ($name in $script:SavedEnvironment.Keys) {
        [Environment]::SetEnvironmentVariable($name, $script:SavedEnvironment[$name])
    }
}

Describe "Integration target safety guard" -Tag 'Unit' {
    BeforeEach {
        $env:DEPLOYCUBE_RUN_INTEGRATION = $null
        $env:DEPLOYCUBE_SSAS_SERVER = $null
        $env:DEPLOYCUBE_DISPOSABLE_SSAS_SERVER = $null
    }

    It "Treats '<_>' as this machine" -ForEach @('localhost', 'LOCALHOST', 'localhost\TABULAR', 'localhost:2383', '.', '.\TABULAR', '(local)', '127.0.0.1', '::1') {
        Test-DeployCubeLocalServer -Server $_ | Should -BeTrue
    }

    It "Treats the computer name as this machine" {
        Test-DeployCubeLocalServer -Server "$([Environment]::MachineName)\TABULAR" | Should -BeTrue
    }

    It "Treats '<_>' as remote" -ForEach @('prod-ssas01', 'prod-ssas01\TABULAR', 'ssas.contoso.com:2383', 'localhost.contoso.com', 'asazure://westeurope.asazure.windows.net/prod', '') {
        Test-DeployCubeLocalServer -Server $_ | Should -BeFalse
    }

    It "Allows a local server without confirmation" {
        { Assert-DeployCubeDisposableServer -Server 'localhost\TABULAR' } | Should -Not -Throw
    }

    It "Refuses a remote server that has not been declared disposable" {
        { Assert-DeployCubeDisposableServer -Server 'prod-ssas01' } | Should -Throw -ExpectedMessage "*Refusing*remote server 'prod-ssas01'*DEPLOYCUBE_DISPOSABLE_SSAS_SERVER*"
    }

    It "Refuses a remote server when a different server was declared disposable" {
        $env:DEPLOYCUBE_DISPOSABLE_SSAS_SERVER = 'ssas-test01'
        { Assert-DeployCubeDisposableServer -Server 'prod-ssas01' } | Should -Throw -ExpectedMessage "*Refusing*prod-ssas01*"
    }

    It "Allows a remote server declared disposable by exact name" {
        $env:DEPLOYCUBE_DISPOSABLE_SSAS_SERVER = 'ssas-test01\TABULAR'
        { Assert-DeployCubeDisposableServer -Server 'ssas-test01\TABULAR' } | Should -Not -Throw
    }

    It "Always refuses Azure Analysis Services for the SSAS suite" {
        $env:DEPLOYCUBE_DISPOSABLE_SSAS_SERVER = 'asazure://westeurope.asazure.windows.net/prod'
        { Assert-DeployCubeDisposableServer -Server 'asazure://westeurope.asazure.windows.net/prod' } | Should -Throw -ExpectedMessage '*Azure Analysis Services*'
    }

    It "Settings refuse an unconfirmed remote server when integration is enabled" {
        $env:DEPLOYCUBE_RUN_INTEGRATION = '1'
        $env:DEPLOYCUBE_SSAS_SERVER = 'prod-ssas01'
        { Get-DeployCubeIntegrationSettings } | Should -Throw -ExpectedMessage '*Refusing*'
    }

    It "Settings default to localhost when integration is enabled" {
        $env:DEPLOYCUBE_RUN_INTEGRATION = '1'
        (Get-DeployCubeIntegrationSettings).Server | Should -Be 'localhost'
    }

    It "Settings do not enforce the guard while integration is disabled" {
        $env:DEPLOYCUBE_SSAS_SERVER = 'prod-ssas01'
        (Get-DeployCubeIntegrationSettings).Server | Should -Be 'prod-ssas01'
    }

    It "The prerequisite check reports an unconfirmed remote server instead of contacting it" {
        $env:DEPLOYCUBE_RUN_INTEGRATION = '1'
        $env:DEPLOYCUBE_SSAS_SERVER = 'prod-ssas01'
        $issues = @(Get-DeployCubeIntegrationPrerequisiteIssues)
        $issues.Count | Should -Be 1
        $issues[0] | Should -BeLike '*Refusing*prod-ssas01*'
    }
}

Describe "Integration test file <Name>" -Tag 'Unit' -ForEach $integrationFiles {
    BeforeAll {
        $tokens = $null
        $parseErrors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($FullName, [ref]$tokens, [ref]$parseErrors)
        $rootCommands = @($ast.EndBlock.Statements |
            ForEach-Object { $_.PipelineElements } |
            Where-Object { $_ -is [System.Management.Automation.Language.CommandAst] })
    }

    It "Parses without errors" {
        $parseErrors | Should -BeNullOrEmpty
    }

    It "Loads integration settings (and therefore the target guard) in a root BeforeAll" {
        $beforeAll = @($rootCommands | Where-Object { $_.GetCommandName() -eq 'BeforeAll' })
        $beforeAll.Count | Should -Be 1
        $beforeAll[0].Extent.Text | Should -Match 'Get-DeployCubeIntegrationSettings'
    }

    It "Only declares Describe blocks that are tagged Integration and skipped unless opted in" {
        $describes = @($rootCommands | Where-Object { $_.GetCommandName() -eq 'Describe' })
        $describes.Count | Should -BeGreaterThan 0
        foreach ($describe in $describes) {
            $text = $describe.Extent.Text.Split("`n")[0]
            $text | Should -Match "-Tag\s+'Integration'"
            $text | Should -Match '-Skip:\$skip'
        }
    }

    It "Decides whether to skip from the explicit opt-in flags" {
        $discovery = @($rootCommands | Where-Object { $_.GetCommandName() -eq 'BeforeDiscovery' })
        $discovery.Count | Should -Be 1
        $discovery[0].Extent.Text | Should -Match 'Test-DeployCube(Azure)?IntegrationEnabled'
    }
}
