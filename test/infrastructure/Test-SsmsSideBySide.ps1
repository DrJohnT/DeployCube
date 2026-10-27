BeforeAll {
    $repositoryRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
    Import-Module -Name (Join-Path $repositoryRoot 'DeployCube\DeployCube.psd1') -Force -ErrorAction Stop
    $script:ssmsInstances = @(& (Join-Path $PSScriptRoot 'Get-InstalledSsmsInstances.ps1'))
    $script:utilities = @(& (Join-Path $PSScriptRoot 'Get-DeploymentToolInventory.ps1'))
    $script:versionPriority = @('22', '20', '16', '15', '14', '13', '12', '11')
}

Describe 'SSMS 20 and 22 side-by-side deployment utility selection' {
    It 'keeps both SSMS installations present' {
        @($script:ssmsInstances | Where-Object { $_.MajorVersion -eq 20 }).Count | Should -BeGreaterThan 0
        @($script:ssmsInstances | Where-Object { $_.MajorVersion -eq 22 }).Count | Should -BeGreaterThan 0
    }

    It 'discovers installed utility paths with actual file versions' {
        $script:utilities.Count | Should -BeGreaterThan 0
        foreach ($utility in $script:utilities) {
            Test-Path -LiteralPath $utility.Path -PathType Leaf | Should -BeTrue
            [System.Diagnostics.FileVersionInfo]::GetVersionInfo($utility.Path).FileVersion |
                Should -Be $utility.FileVersion
        }
    }

    It 'selects every installed utility version explicitly when its product major is supported' {
        foreach ($version in ($script:utilities.ProductMajorVersion | Where-Object { $null -ne $_ } | Sort-Object -Unique)) {
            $versionString = [string]$version
            $selectedPath = Get-AnalysisServicesDeploymentExePath -Version $versionString
            $selectedPath | Should -Not -BeNullOrEmpty
            [System.IO.Path]::GetFullPath($selectedPath) |
                Should -BeIn @($script:utilities | ForEach-Object { [System.IO.Path]::GetFullPath($_.Path) })
            Select-AnalysisServicesDeploymentExeVersion -PreferredVersion $versionString |
                Should -Be $versionString
        }
    }

    It 'uses the module version priority for latest across both installations' {
        $expected = $null
        foreach ($version in $script:versionPriority) {
            if ($script:utilities.ProductMajorVersion -contains [int]$version) {
                $expected = $version
                break
            }
        }

        Select-AnalysisServicesDeploymentExeVersion -PreferredVersion latest | Should -Be $expected
    }

    It 'returns stable latest selection across repeated discovery after the recorded install order' {
        $selectedBeforeRepeat = Select-AnalysisServicesDeploymentExeVersion -PreferredVersion latest
        $selectedAfterRepeat = Select-AnalysisServicesDeploymentExeVersion -PreferredVersion latest
        $selectedAfterRepeat | Should -Be $selectedBeforeRepeat
    }

    It 'handles overlapping CustomAsDwInstallLocation roots without breaking selection' {
        $utility = $script:utilities | Select-Object -First 1
        $version = [string]$utility.ProductMajorVersion
        $previousCustomRoot = [Environment]::GetEnvironmentVariable('CustomAsDwInstallLocation')
        $latestBeforeCustomRoot = Select-AnalysisServicesDeploymentExeVersion -PreferredVersion latest

        try {
            [Environment]::SetEnvironmentVariable(
                'CustomAsDwInstallLocation',
                (Split-Path -Parent $utility.Path),
                'Process'
            )
            $discoveryOutput = @(Find-AnalysisServicesDeploymentExeLocations)
            $matchingOutput = @(
                $discoveryOutput | Where-Object {
                    $_ -like "*$($utility.Path)"
                }
            )

            $env:COMPAT_OVERLAPPING_PATH_OCCURRENCES = [string]$matchingOutput.Count
            $matchingOutput.Count | Should -BeGreaterThan 0
            Get-AnalysisServicesDeploymentExePath -Version $version | Should -Not -BeNullOrEmpty
            Select-AnalysisServicesDeploymentExeVersion -PreferredVersion $version | Should -Be $version
            Select-AnalysisServicesDeploymentExeVersion -PreferredVersion latest |
                Should -Be $latestBeforeCustomRoot
        }
        finally {
            [Environment]::SetEnvironmentVariable('CustomAsDwInstallLocation', $previousCustomRoot, 'Process')
        }
    }
}

AfterAll {
    Remove-Module -Name DeployCube -ErrorAction SilentlyContinue
}
