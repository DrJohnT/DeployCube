BeforeAll {
    $repositoryRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
    $modulePath = Join-Path $repositoryRoot 'DeployCube\DeployCube.psd1'
    Import-Module -Name $modulePath -Force -ErrorAction Stop

    $script:knownVersions = @('22', '20', '16', '15', '14', '13', '12', '11')
}

Describe "DeployCube deployment utility discovery on SSMS $env:COMPAT_SSMS_MAJOR" {
    BeforeAll {
        $script:inventory = @(& (Join-Path $PSScriptRoot 'Get-DeploymentToolInventory.ps1'))
        $script:actualPaths = @($script:inventory | ForEach-Object { $_.Path })
        $script:discoveryOutput = @(Find-AnalysisServicesDeploymentExeLocations)
    }

    It 'finds and records at least one installed deployment utility' {
        $script:inventory.Count | Should -BeGreaterThan 0 -Because "SSMS $env:COMPAT_SSMS_MAJOR is expected to provide a deployment utility; absence is reported as an installation failure"
    }

    It 'uses a utility product version supported by DeployCube selection' {
        foreach ($utility in $script:inventory) {
            [string]$utility.ProductMajorVersion | Should -BeIn $script:knownVersions
        }
    }

    It 'returns every installed utility path through DeployCube discovery' {
        $reportedPaths = @(
            $script:discoveryOutput | ForEach-Object {
                if ($_ -match '^\s*\S+\s+(?<Path>.+Microsoft\.AnalysisServices\.Deployment\.exe)$') {
                    [System.IO.Path]::GetFullPath($matches.Path.Trim())
                }
            }
        )

        foreach ($path in $script:actualPaths) {
            $reportedPaths | Should -Contain ([System.IO.Path]::GetFullPath($path))
        }
    }

    It 'returns each installed utility for its actual supported product major version' {
        foreach ($utility in $script:inventory) {
            $version = [string]$utility.ProductMajorVersion
            if ($script:knownVersions -contains $version) {
                $selectedPath = Get-AnalysisServicesDeploymentExePath -Version $version
                $selectedPath | Should -Not -BeNullOrEmpty
                [System.IO.Path]::GetFullPath($selectedPath) | Should -BeIn $script:actualPaths
            }
        }
    }

    It 'selects latest according to DeployCube version priority, not the SSMS major' {
        $expected = $null
        foreach ($version in $script:knownVersions) {
            if ($script:inventory.ProductMajorVersion -contains [int]$version) {
                $expected = $version
                break
            }
        }

        Select-AnalysisServicesDeploymentExeVersion -PreferredVersion latest | Should -Be $expected
    }

    It 'honors an installed PreferredVersion and falls back when it is absent' {
        $installedVersions = @(
            $script:inventory |
                Where-Object { $script:knownVersions -contains [string]$_.ProductMajorVersion } |
                ForEach-Object { [string]$_.ProductMajorVersion } |
                Sort-Object -Unique
        )
        foreach ($version in $installedVersions) {
            Select-AnalysisServicesDeploymentExeVersion -PreferredVersion $version | Should -Be $version
        }

        $preferred = '22'
        if ($script:inventory.ProductMajorVersion -contains [int]$preferred) {
            Select-AnalysisServicesDeploymentExeVersion -PreferredVersion $preferred | Should -Be $preferred
        }
        else {
            $fallback = $null
            foreach ($version in ($script:knownVersions | Where-Object { $_ -ne $preferred })) {
                if ($script:inventory.ProductMajorVersion -contains [int]$version) {
                    $fallback = $version
                    break
                }
            }

            Select-AnalysisServicesDeploymentExeVersion -PreferredVersion $preferred | Should -Be $fallback
        }
    }

    It 'discovers utilities through CustomAsDwInstallLocation with standard roots isolated' {
        $utility = $script:inventory |
            Where-Object { $script:knownVersions -contains [string]$_.ProductMajorVersion } |
            Select-Object -First 1
        $utility | Should -Not -BeNullOrEmpty
        $previousProgramFiles = $env:ProgramFiles
        $previousProgramFilesX86 = ${env:ProgramFiles(x86)}
        $previousCustomRoot = [Environment]::GetEnvironmentVariable('CustomAsDwInstallLocation')
        $isolatedRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString('N'))

        try {
            New-Item -ItemType Directory -Path $isolatedRoot -Force | Out-Null
            $env:ProgramFiles = $isolatedRoot
            ${env:ProgramFiles(x86)} = $isolatedRoot
            [Environment]::SetEnvironmentVariable('CustomAsDwInstallLocation', (Split-Path -Parent $utility.Path), 'Process')

            Get-AnalysisServicesDeploymentExePath -Version ([string]$utility.ProductMajorVersion) |
                Should -Be $utility.Path
        }
        finally {
            $env:ProgramFiles = $previousProgramFiles
            ${env:ProgramFiles(x86)} = $previousProgramFilesX86
            [Environment]::SetEnvironmentVariable('CustomAsDwInstallLocation', $previousCustomRoot, 'Process')
            Remove-Item -LiteralPath $isolatedRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'handles a machine with no deployment utility without returning a false path or version' {
        $previousProgramFiles = $env:ProgramFiles
        $previousProgramFilesX86 = ${env:ProgramFiles(x86)}
        $previousCustomRoot = [Environment]::GetEnvironmentVariable('CustomAsDwInstallLocation')
        $isolatedRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString('N'))

        try {
            New-Item -ItemType Directory -Path $isolatedRoot -Force | Out-Null
            $env:ProgramFiles = $isolatedRoot
            ${env:ProgramFiles(x86)} = $isolatedRoot
            [Environment]::SetEnvironmentVariable('CustomAsDwInstallLocation', $null, 'Process')

            foreach ($version in $script:knownVersions) {
                Get-AnalysisServicesDeploymentExePath -Version $version | Should -BeNullOrEmpty
            }

            $noUtilityDiscovery = @(Find-AnalysisServicesDeploymentExeLocations)
            $noUtilityDiscovery.Count | Should -Be 0
            Select-AnalysisServicesDeploymentExeVersion -PreferredVersion latest -WarningAction SilentlyContinue |
                Should -BeNullOrEmpty
        }
        finally {
            $env:ProgramFiles = $previousProgramFiles
            ${env:ProgramFiles(x86)} = $previousProgramFilesX86
            [Environment]::SetEnvironmentVariable('CustomAsDwInstallLocation', $previousCustomRoot, 'Process')
            Remove-Item -LiteralPath $isolatedRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

AfterAll {
    Remove-Module -Name DeployCube -ErrorAction SilentlyContinue
}
