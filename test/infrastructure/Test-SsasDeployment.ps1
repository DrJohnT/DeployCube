BeforeAll {
    $repositoryRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
    Import-Module -Name (Join-Path $repositoryRoot 'DeployCube\DeployCube.psd1') -Force -ErrorAction Stop
    Import-Module SqlServer -ErrorAction Stop
    $script:ssasServer = 'localhost\DCUBE'
    $script:databaseName = 'DeployCubeCompatibilityTest'
    $script:modelPath = $env:COMPAT_MODEL_PATH
    $script:expectedMode = $env:COMPAT_SSAS_MODE
    $script:expectedCompatibilityLevel = [int]$env:COMPAT_MODEL_COMPATIBILITY
    $script:deploymentLogPath = $env:COMPAT_DEPLOYMENT_LOG_PATH
    $env:COMPAT_ACTUAL_SSAS_MODE = ''
    $env:COMPAT_ACTUAL_MODEL_COMPATIBILITY = ''
}

Describe "DeployCube integration with SQL Server Analysis Services $env:COMPAT_SSAS_VERSION $env:COMPAT_SSAS_MODE using SSMS $env:COMPAT_SSMS_MAJOR" {
    It 'connects to the configured Analysis Services instance in the expected mode' {
        Ping-SsasServer -Server $script:ssasServer | Should -BeTrue
        $actualMode = Get-ServerMode -Server $script:ssasServer
        $actualMode | Should -Be $script:expectedMode
        $env:COMPAT_ACTUAL_SSAS_MODE = $actualMode

        $server = New-Object Microsoft.AnalysisServices.Server
        $server.Connect($script:ssasServer)
        try {
            $server.Version.ToString() | Should -Match '^16\.'
            [string]$server.Edition | Should -Match 'Developer'
        }
        finally {
            if ($server.Connected) {
                $server.Disconnect()
            }
        }
    }

    It 'deploys the model and reports its compatibility level' {
        {
            Publish-Cube `
                -AsDatabasePath $script:modelPath `
                -Server $script:ssasServer `
                -CubeDatabase $script:databaseName `
                -PreferredVersion latest `
                -ProcessingOption DoNotProcess *>&1 |
                Tee-Object -FilePath $script:deploymentLogPath -Append
        } | Should -Not -Throw

        Ping-SsasDatabase -Server $script:ssasServer -CubeDatabase $script:databaseName |
            Should -BeTrue
        $actualCompatibilityLevel = Get-CubeDatabaseCompatibilityLevel -Server $script:ssasServer -CubeDatabase $script:databaseName
        $env:COMPAT_ACTUAL_MODEL_COMPATIBILITY = [string]$actualCompatibilityLevel
        $actualCompatibilityLevel | Should -Be $script:expectedCompatibilityLevel
    }

    It 'removes the test database with Unpublish-Cube' {
        {
            Unpublish-Cube `
                -Server $script:ssasServer `
                -CubeDatabase $script:databaseName
        } | Should -Not -Throw

        Ping-SsasDatabase -Server $script:ssasServer -CubeDatabase $script:databaseName |
            Should -BeFalse
    }
}

AfterAll {
    try {
        if (Ping-SsasDatabase -Server $script:ssasServer -CubeDatabase $script:databaseName) {
            Unpublish-Cube -Server $script:ssasServer -CubeDatabase $script:databaseName
        }
    }
    finally {
        Remove-Module -Name DeployCube -ErrorAction SilentlyContinue
    }
}
