BeforeAll {
    $repositoryRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
    Import-Module -Name (Join-Path $repositoryRoot 'DeployCube\DeployCube.psd1') -Force -ErrorAction Stop
    $script:originalProgramFiles = $env:ProgramFiles
    $script:originalProgramFilesX86 = ${env:ProgramFiles(x86)}
    $script:originalCustomLocation = [Environment]::GetEnvironmentVariable('CustomAsDwInstallLocation')
    $script:testDrive = $TestDrive

    function New-MockedDeploymentUtility {
        param(
            [Parameter(Mandatory = $true)]
            [string]$SsmsMajor,

            [Parameter(Mandatory = $true)]
            [string]$ProductMajor,

            [ValidateSet('x86', 'x64', 'custom')]
            [string]$Layout = 'x86'
        )

        switch ($Layout) {
            'x86' {
                $root = $script:programFilesX86
                $relativePath = "Microsoft SQL Server Management Studio $SsmsMajor\Common7\IDE"
            }
            'x64' {
                $root = $script:programFiles
                $relativePath = "Microsoft SQL Server Management Studio $SsmsMajor\Release\Common7\IDE"
            }
            'custom' {
                $root = Join-Path $script:testDrive 'Custom install'
                $relativePath = "Microsoft SQL Server Management Studio $SsmsMajor\Release\Common7\IDE"
            }
        }

        $directory = Join-Path $root $relativePath
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
        $file = Join-Path $directory 'Microsoft.AnalysisServices.Deployment.exe'
        New-Item -ItemType File -Path $file -Force | Out-Null
        Set-Content -LiteralPath "$file.version" -Value $ProductMajor -NoNewline
        return $file
    }
}

Describe 'Deployment utility version selection with mocked filesystem metadata' {
    BeforeEach {
        $script:programFiles = Join-Path $TestDrive 'Program Files'
        $script:programFilesX86 = Join-Path $TestDrive 'Program Files (x86)'
        New-Item -ItemType Directory -Path $script:programFiles, $script:programFilesX86 -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:programFilesX86 'Microsoft SQL Server') -Force | Out-Null
        $env:ProgramFiles = $script:programFiles
        ${env:ProgramFiles(x86)} = $script:programFilesX86
        [Environment]::SetEnvironmentVariable('CustomAsDwInstallLocation', $null, 'Process')
        [Environment]::SetEnvironmentVariable('DEPLOY_CUBE_TEST_DISCOVERY_ORDER', $null, 'Process')

        Mock -ModuleName DeployCube Get-ChildItem {
            param($Path, [switch]$Recurse, [string[]]$Include)

            $arguments = @{
                Path = $Path
                ErrorAction = 'SilentlyContinue'
            }
            if ($Recurse) {
                $arguments.Recurse = $true
            }
            if ($Include) {
                $arguments.Include = $Include
            }

            $files = @(Microsoft.PowerShell.Management\Get-ChildItem @arguments)
            if ([Environment]::GetEnvironmentVariable('DEPLOY_CUBE_TEST_DISCOVERY_ORDER') -eq 'reverse') {
                $files = @($files | Sort-Object -Property FullName -Descending)
            }

            $files
        }

        Mock -ModuleName DeployCube Get-AnalysisServicesDeploymentExeProductMajorVersion {
            param($DeploymentExe)

            $productMajor = Get-Content -LiteralPath "$($DeploymentExe.FullName).version" -Raw -ErrorAction SilentlyContinue
            if ($productMajor -match '^\s*(\d+)') {
                return $matches[1]
            }

            Write-Warning "Skipping '$($DeploymentExe.FullName)' because it has no readable product major version."
            return $null
        }
    }

    AfterEach {
        [Environment]::SetEnvironmentVariable('CustomAsDwInstallLocation', $null, 'Process')
        [Environment]::SetEnvironmentVariable('DEPLOY_CUBE_TEST_DISCOVERY_ORDER', $null, 'Process')
    }

    It 'discovers utility majors 18 through 22 in their SSMS installation layouts' {
        $expectedPaths = @{}
        $fixtures = @(
            @{ SsmsMajor = '18'; ProductMajor = '22'; Layout = 'x86' },
            @{ SsmsMajor = '19'; ProductMajor = '21'; Layout = 'x86' },
            @{ SsmsMajor = '20'; ProductMajor = '20'; Layout = 'x86' },
            @{ SsmsMajor = '21'; ProductMajor = '19'; Layout = 'x64' },
            @{ SsmsMajor = '22'; ProductMajor = '18'; Layout = 'x64' }
        )
        foreach ($fixture in $fixtures) {
            $expectedPaths[$fixture.ProductMajor] = New-MockedDeploymentUtility `
                -SsmsMajor $fixture.SsmsMajor `
                -ProductMajor $fixture.ProductMajor `
                -Layout $fixture.Layout
        }

        $discovery = @(Find-AnalysisServicesDeploymentExeLocations)
        $discovery.Count | Should -Be 5
        foreach ($major in @('18', '19', '20', '21', '22')) {
            $discovery | Should -Contain "$major  $($expectedPaths[$major])"
            Get-AnalysisServicesDeploymentExePath -Version $major |
                Should -Be $expectedPaths[$major]
            Select-AnalysisServicesDeploymentExeVersion -PreferredVersion $major |
                Should -Be $major
        }

        foreach ($commandName in @(
            'Get-AnalysisServicesDeploymentExePath',
            'Select-AnalysisServicesDeploymentExeVersion',
            'Publish-Cube'
        )) {
            $parameterName = if ($commandName -eq 'Get-AnalysisServicesDeploymentExePath') { 'Version' } else { 'PreferredVersion' }
            $validateSet = (Get-Command $commandName).Parameters[$parameterName].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            foreach ($major in @('18', '19', '20', '21', '22')) {
                $validateSet.ValidValues | Should -Contain $major
            }
        }

        Get-AnalysisServicesDeploymentExePath -Version 22 |
            Should -Match 'Management Studio 18\\Common7\\IDE\\Microsoft\.AnalysisServices\.Deployment\.exe$'
        { Get-AnalysisServicesDeploymentExePath -Version 17 } | Should -Throw
    }

    It 'selects the highest supported utility major regardless of filesystem discovery order' {
        foreach ($fixture in @(
            @{ SsmsMajor = '18'; ProductMajor = '22'; Layout = 'x86' },
            @{ SsmsMajor = '19'; ProductMajor = '21'; Layout = 'x86' },
            @{ SsmsMajor = '20'; ProductMajor = '20'; Layout = 'x86' },
            @{ SsmsMajor = '21'; ProductMajor = '19'; Layout = 'x64' },
            @{ SsmsMajor = '22'; ProductMajor = '18'; Layout = 'x64' }
        )) {
            New-MockedDeploymentUtility @fixture | Out-Null
        }

        Select-AnalysisServicesDeploymentExeVersion -PreferredVersion latest | Should -Be '22'
        Select-AnalysisServicesDeploymentExeVersion -PreferredVersion 21 | Should -Be '21'

        [Environment]::SetEnvironmentVariable('DEPLOY_CUBE_TEST_DISCOVERY_ORDER', 'reverse', 'Process')
        Select-AnalysisServicesDeploymentExeVersion -PreferredVersion latest | Should -Be '22'
        Select-AnalysisServicesDeploymentExeVersion -PreferredVersion 21 | Should -Be '21'
    }

    It 'falls back to the highest installed supported major when the requested major is missing' {
        New-MockedDeploymentUtility -SsmsMajor 22 -ProductMajor 19 -Layout x64 | Out-Null
        New-MockedDeploymentUtility -SsmsMajor 21 -ProductMajor 18 -Layout x64 | Out-Null
        New-MockedDeploymentUtility -SsmsMajor 20 -ProductMajor 20 -Layout x86 | Out-Null

        Get-AnalysisServicesDeploymentExePath -Version 21 | Should -BeNullOrEmpty
        Select-AnalysisServicesDeploymentExeVersion -PreferredVersion 21 | Should -Be '20'
        Select-AnalysisServicesDeploymentExeVersion -PreferredVersion 22 | Should -Be '20'
        Select-AnalysisServicesDeploymentExeVersion -PreferredVersion latest | Should -Be '20'
    }

    It 'deduplicates overlapping standard and custom search roots without changing selection' {
        $expectedPath = New-MockedDeploymentUtility -SsmsMajor 19 -ProductMajor 21 -Layout x86
        [Environment]::SetEnvironmentVariable(
            'CustomAsDwInstallLocation',
            $script:programFilesX86,
            'Process'
        )

        $discovery = @(Find-AnalysisServicesDeploymentExeLocations)
        @($discovery | Where-Object { $_ -like "*$expectedPath" }).Count | Should -Be 1
        Get-AnalysisServicesDeploymentExePath -Version 21 | Should -Be $expectedPath
        Select-AnalysisServicesDeploymentExeVersion -PreferredVersion latest | Should -Be '21'
    }

    It 'discovers a utility from CustomAsDwInstallLocation when standard roots are empty' {
        $expectedPath = New-MockedDeploymentUtility -SsmsMajor 18 -ProductMajor 22 -Layout custom
        $customRoot = Join-Path $script:testDrive 'Custom install'
        [Environment]::SetEnvironmentVariable('CustomAsDwInstallLocation', $customRoot, 'Process')

        Find-AnalysisServicesDeploymentExeLocations | Should -Contain "22  $expectedPath"
        Get-AnalysisServicesDeploymentExePath -Version 22 | Should -Be $expectedPath
        Select-AnalysisServicesDeploymentExeVersion -PreferredVersion latest | Should -Be '22'
    }

    It 'ignores executable paths with invalid version metadata and rejects a missing custom root' {
        $invalidDirectory = Join-Path $script:programFilesX86 'Microsoft SQL Server Management Studio 22 Invalid executable\Common7\IDE'
        New-Item -ItemType Directory -Path $invalidDirectory -Force | Out-Null
        $invalidPath = Join-Path $invalidDirectory 'Microsoft.AnalysisServices.Deployment.exe'
        New-Item -ItemType File -Path $invalidPath -Force | Out-Null
        Set-Content -LiteralPath "$invalidPath.version" -Value 'not-a-version' -NoNewline

        Get-AnalysisServicesDeploymentExePath -Version 22 -WarningAction SilentlyContinue |
            Should -BeNullOrEmpty
        Find-AnalysisServicesDeploymentExeLocations -WarningAction SilentlyContinue |
            Should -BeNullOrEmpty

        [Environment]::SetEnvironmentVariable(
            'CustomAsDwInstallLocation',
            (Join-Path $script:testDrive 'missing custom root'),
            'Process'
        )
        { Get-AnalysisServicesDeploymentExePath -Version 22 } | Should -Throw
    }
}

AfterAll {
    $env:ProgramFiles = $script:originalProgramFiles
    ${env:ProgramFiles(x86)} = $script:originalProgramFilesX86
    [Environment]::SetEnvironmentVariable('CustomAsDwInstallLocation', $script:originalCustomLocation, 'Process')
    Remove-Module -Name DeployCube -ErrorAction SilentlyContinue
}
