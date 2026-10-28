BeforeAll {
    $script:verificationScript = Join-Path $PSScriptRoot 'infrastructure/Verify-SsasInstallation.ps1'
    function Get-Service {
        param([string]$Name)
        throw "Unexpected unmocked service query for '$Name'."
    }
}

Describe 'SSAS provisioning verification gate' {
    BeforeEach {
        $script:reportDirectory = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $script:reportPath = Join-Path $script:reportDirectory 'ssas-verification.json'
        $script:logPath = Join-Path $script:reportDirectory 'ssas-verification.log'
        $script:connection = [pscustomobject]@{
            Connected = $false
            ServerMode = 'Tabular'
            Version = [version]'16.0.1000.1'
            Edition = 'Developer Edition'
        }
        $script:connection | Add-Member ScriptMethod Connect { param($Name) $this.Connected = $true }
        $script:connection | Add-Member ScriptMethod Disconnect { $this.Connected = $false }

        Mock Get-Service {
            [pscustomobject]@{
                Name = $Name
                Status = [System.ServiceProcess.ServiceControllerStatus]::Running
            }
        } -ParameterFilter { $Name -eq 'MSOLAP$DCUBE' }
        Mock New-Object { $script:connection } -ParameterFilter {
            $TypeName -eq 'Microsoft.AnalysisServices.Server'
        }
    }

    It 'requires a running service and confirms product, edition and mode' {
        . $script:verificationScript -SsasVersion 2022 -Mode Tabular `
            -InstallationReportPath (Join-Path $script:reportDirectory 'ssas-install.json') `
            -ReportPath $script:reportPath -LogPath $script:logPath

        $report = Get-Content -LiteralPath $script:reportPath -Raw | ConvertFrom-Json
        $report.Outcome | Should -Be 'Passed'
        $report.ServiceStatus | Should -Be 'Running'
        $report.ProductVersion | Should -Be '16.0.1000.1'
        $report.ActualMode | Should -Be 'Tabular'
        $report.Edition | Should -Be 'Developer Edition'
        $script:connection.Connected | Should -BeFalse
    }

    It 'fails before the deployment gate when the server mode is wrong' {
        $script:connection.ServerMode = 'Multidimensional'
        {
            . $script:verificationScript -SsasVersion 2022 -Mode Tabular `
                -InstallationReportPath (Join-Path $script:reportDirectory 'ssas-install.json') `
                -ReportPath $script:reportPath -LogPath $script:logPath
        } | Should -Throw '*SSAS provisioning verification failed*'

        $report = Get-Content -LiteralPath $script:reportPath -Raw | ConvertFrom-Json
        $report.Outcome | Should -Be 'Failed'
        $report.ActualMode | Should -Be 'Multidimensional'
        $report.Error | Should -Match "Expected SSAS mode 'Tabular'; server reports 'Multidimensional'"
    }
}
