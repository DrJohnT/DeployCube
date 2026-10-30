BeforeAll {
    $script:testRoot = Split-Path $PSScriptRoot -Parent
    . (Join-Path $script:testRoot 'Assert-ValidationResult.ps1')
    . (Join-Path $script:testRoot 'Assert-ReleaseEnvironment.ps1')
    $script:buildScript = Join-Path $script:testRoot 'Build-ReleasePackage.ps1'
}

Describe 'Mandatory validation result gate' {
    BeforeEach {
        $script:result = [pscustomobject]@{
            Result = 'Passed'
            PassedCount = 1
            FailedCount = 0
            FailedBlocksCount = 0
            FailedContainersCount = 0
            CodeCoverage = [pscustomobject]@{ CommandsAnalyzedCount = 400; CommandsExecutedCount = 300 }
        }
    }

    It 'accepts exactly 75 percent command coverage' {
        { Assert-ValidationResult $script:result -CodeCoverage } | Should -Not -Throw
    }

    It 'rejects coverage just below 75 percent without rounding up' {
        $script:result.CodeCoverage.CommandsExecutedCount = 299
        { Assert-ValidationResult $script:result -CodeCoverage } | Should -Throw '*below 75%*'
    }

    It 'rejects missing coverage' {
        $script:result.CodeCoverage = $null
        { Assert-ValidationResult $script:result -CodeCoverage } | Should -Throw '*Coverage is missing*'
    }

    It 'rejects an empty coverage denominator' {
        $script:result.CodeCoverage.CommandsAnalyzedCount = 0
        { Assert-ValidationResult $script:result -CodeCoverage } | Should -Throw '*no analyzed commands*'
    }

    It 'rejects failed, undiscovered, and broken tests: <Property>' -ForEach @(
        @{ Property = 'Result'; Value = 'Failed' }
        @{ Property = 'PassedCount'; Value = 0 }
        @{ Property = 'FailedCount'; Value = 1 }
        @{ Property = 'FailedBlocksCount'; Value = 1 }
        @{ Property = 'FailedContainersCount'; Value = 1 }
    ) {
        $script:result.$Property = $Value
        { Assert-ValidationResult $script:result } | Should -Throw '*Validation failed*'
    }
}

Describe 'Protected release environment gate' {
    BeforeEach {
        $script:environment = [pscustomobject]@{
            name = 'psgallery'
            protection_rules = @([pscustomobject]@{
                type = 'required_reviewers'
                reviewers = @([pscustomobject]@{ type = 'User' })
            })
            deployment_branch_policy = [pscustomobject]@{ custom_branch_policies = $true }
        }
    }

    It 'accepts an explicitly protected environment' {
        { Assert-ReleaseEnvironment $script:environment } | Should -Not -Throw
    }

    It 'rejects an unprotected or automatically created environment' {
        $script:environment.protection_rules = @()
        { Assert-ReleaseEnvironment $script:environment } | Should -Throw '*require reviewer approval*'
    }

    It 'rejects a reviewer rule with no reviewers' {
        $script:environment.protection_rules[0].reviewers = @()
        { Assert-ReleaseEnvironment $script:environment } | Should -Throw '*require reviewer approval*'
    }

    It 'rejects a reviewer rule with missing reviewers' {
        $script:environment.protection_rules[0].reviewers = $null
        { Assert-ReleaseEnvironment $script:environment } | Should -Throw '*require reviewer approval*'
    }

    It 'rejects the wrong environment' {
        $script:environment.name = 'other'
        { Assert-ReleaseEnvironment $script:environment } | Should -Throw '*psgallery environment*'
    }

    It 'rejects an unrestricted deployment policy' {
        $script:environment.deployment_branch_policy = $null
        { Assert-ReleaseEnvironment $script:environment } | Should -Throw '*custom deployment tag rules*'
    }
}

Describe 'Non-publishing release package validation' {
    BeforeEach {
        $script:outputPath = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $script:version = (Import-PowerShellDataFile (Join-Path (Split-Path $script:testRoot -Parent) 'DeployCube/DeployCube.psd1')).ModuleVersion
        Mock Register-PSRepository {}
        Mock Get-PSRepository { [pscustomobject]@{ Name = $Name } }
        Mock Unregister-PSRepository {}
        Mock Publish-Module { throw 'Simulated packaging failure' }
    }

    It 'rejects mismatched and malformed release tags before building: <Tag>' -ForEach @(
        @{ Tag = 'v0.0.0' }
        @{ Tag = '1.2.6' }
        @{ Tag = 'vv1.2.6' }
        @{ Tag = 'V1.2.6' }
        @{ Tag = 'v1.2.6-extra' }
    ) {
        { & $script:buildScript -Tag $Tag -OutputPath $script:outputPath } | Should -Throw '*must exactly match*'
        Should -Invoke Publish-Module -Times 0 -Exactly
    }

    It 'surfaces packaging failures and unregisters the temporary repository' {
        { & $script:buildScript -Tag "v$script:version" -OutputPath $script:outputPath } |
            Should -Throw '*Simulated packaging failure*'
        Should -Invoke Unregister-PSRepository -Times 1 -Exactly
        Should -Invoke Publish-Module -Times 1 -Exactly -ParameterFilter {
            $Repository -like 'DeployCubeBuild-*' -and -not $NuGetApiKey
        }
    }

    It 'rejects a successful command that did not produce a package' {
        Mock Publish-Module {}
        { & $script:buildScript -OutputPath $script:outputPath } | Should -Throw '*expected versioned NuGet package*'
    }

    It 'builds only against the temporary filesystem repository and checks package contents' {
        Mock Publish-Module {
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            $version = (Import-PowerShellDataFile (Join-Path $Path 'DeployCube.psd1')).ModuleVersion
            [IO.Compression.ZipFile]::CreateFromDirectory($Path, (Join-Path (Split-Path $Path -Parent) "feed/DeployCube.$version.nupkg"))
        }
        { & $script:buildScript -Tag "v$script:version" -OutputPath $script:outputPath } | Should -Not -Throw
        Should -Invoke Register-PSRepository -Times 1 -Exactly -ParameterFilter {
            $SourceLocation -eq (Join-Path $script:outputPath 'feed') -and $PublishLocation -eq $SourceLocation
        }
        Test-Path (Join-Path $script:outputPath 'DeployCube/DeployCube.psd1') | Should -BeTrue
    }

    It 'rejects missing module files in a package' {
        Mock Publish-Module {
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            $empty = Join-Path $TestDrive 'empty'
            New-Item -ItemType Directory -Path $empty -Force | Out-Null
            $version = (Import-PowerShellDataFile (Join-Path $Path 'DeployCube.psd1')).ModuleVersion
            [IO.Compression.ZipFile]::CreateFromDirectory($empty, (Join-Path (Split-Path $Path -Parent) "feed/DeployCube.$version.nupkg"))
        }
        { & $script:buildScript -OutputPath $script:outputPath } | Should -Throw '*Package is missing*'
    }
}

Describe 'Workflow release and integration boundaries' {
    BeforeAll {
        $workflows = Join-Path (Split-Path $script:testRoot -Parent) '.github/workflows'
        $script:ci = Get-Content (Join-Path $workflows 'ci.yml') -Raw
        $script:release = Get-Content (Join-Path $workflows 'release.yml') -Raw
        $script:workflows = $workflows
    }

    It 'keeps live compatibility workflows manual-only' -ForEach @(
        @{ Workflow = 'ssas-compatibility.yml' }
        @{ Workflow = 'ssms-compatibility.yml' }
    ) {
        $content = Get-Content (Join-Path $script:workflows $Workflow) -Raw
        $content | Should -Match '(?m)^  workflow_dispatch:'
        $content | Should -Not -Match '(?m)^  (push|pull_request|schedule|workflow_call|workflow_run):'
    }

    It 'uses the shared mandatory CI gate before publication' {
        $script:release | Should -Match 'uses: \./\.github/workflows/ci.yml'
        $script:release | Should -Match 'release_tag: \$\{\{ github.ref_name \}\}'
        $script:release | Should -Match '(?s)publish:\s+needs: \[validate, release-policy\]\s+if: \$\{\{ success\(\)'
        $script:release | Should -Match 'Assert-ReleaseEnvironment -Environment'
        $script:release | Should -Match 'environment: psgallery'
        $script:release | Should -Match 'name: release-package'
        $script:release | Should -Not -Match 'secrets: inherit|continue-on-error:'
    }

    It 'exposes publication credentials only in the publishing step' {
        $script:ci | Should -Not -Match 'secrets\.|PSGALLERY_API_KEY'
        $script:release | Should -Match '(?s)name: Publish module to PSGallery\s+env:\s+PSGALLERY_API_KEY:'
        @([regex]::Matches($script:release, 'secrets\.PSGALLERY_API_KEY')).Count | Should -Be 1
    }

    It 'does not schedule infrastructure or bypass failing validation' {
        $script:ci | Should -Not -Match 'self-hosted|Install-Ssas|Install-Ssms|Invoke-SsasCompatibility|continue-on-error:'
        $script:ci | Should -Match 'shell: powershell'
        $script:ci | Should -Match 'PSVersion.Minor -ne 1'
        $script:ci | Should -Match 'Invoke-DeployCubeTests.ps1 -Type Analyzer -CI'
        $script:ci | Should -Match 'Invoke-DeployCubeTests.ps1 -Type Unit -CodeCoverage -CI'
    }
}
