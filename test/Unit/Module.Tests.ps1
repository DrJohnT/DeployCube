BeforeDiscovery {
    $expectedFunctions = @(
        'Find-AnalysisServicesDeploymentExeLocations',
        'Get-AnalysisServicesDeploymentExePath',
        'Get-CubeDatabaseCompatibilityLevel',
        'Get-ModuleByName',
        'Get-ServerMode',
        'Get-SqlAsPath',
        'Get-SqlConnectionString',
        'Get-SsasProcessingMessages',
        'Invoke-ExternalCommand',
        'Invoke-ProcessTabularCubeDatabase',
        'Ping-SsasDatabase',
        'Ping-SsasServer',
        'Publish-Cube',
        'Select-AnalysisServicesDeploymentExeVersion',
        'Unpublish-Cube',
        'Update-AnalysisServicesConfig',
        'Update-TabularCubeDataSource'
    ) | ForEach-Object { @{ Name = $_ } }
}

BeforeAll {
    . (Join-Path -Path (Split-Path -Parent $PSScriptRoot) -ChildPath 'TestHelpers.ps1')
    Import-DeployCubeForTest
    $ManifestPath = Get-DeployCubeManifestPath
}

Describe "DeployCube module" -Tag 'Unit' {
    Context "Manifest" {
        It "Is a valid module manifest" {
            { Test-ModuleManifest -Path $ManifestPath -ErrorAction Stop } | Should -Not -Throw
        }

        It "Supports Windows PowerShell 5.x" {
            (Test-ModuleManifest -Path $ManifestPath).PowerShellVersion | Should -BeLessOrEqual ([version]'5.1')
        }

        It "Has a semantic module version" {
            (Test-ModuleManifest -Path $ManifestPath).Version | Should -BeOfType [version]
        }
    }

    Context "Public API" {
        It "Exports <Name>" -ForEach $expectedFunctions {
            Get-Command -Module DeployCube -Name $Name -CommandType Function | Should -Not -BeNullOrEmpty
        }

        It "Exports exactly the documented functions" {
            (Get-Command -Module DeployCube -CommandType Function).Count | Should -Be 17
        }

        It "Exports alias Deploy-Cube for Publish-Cube" {
            (Get-Alias -Name Deploy-Cube).ResolvedCommandName | Should -Be 'Publish-Cube'
        }

        It "Exports alias Drop-Cube for Unpublish-Cube" {
            (Get-Alias -Name Drop-Cube).ResolvedCommandName | Should -Be 'Unpublish-Cube'
        }
    }
}
