BeforeAll {
    $script:probeScript = Join-Path $PSScriptRoot 'infrastructure/Test-DeploymentUtilityCompatibility.ps1'
    $script:fixturePath = Join-Path $PSScriptRoot 'infrastructure/fixtures/Tabular1500/Model.asdatabase'
}

Describe 'Direct Deployment Utility compatibility gate' {
    It 'accepts all Phase D SSMS majors in the integration harness' {
        $command = Get-Command (Join-Path $PSScriptRoot 'infrastructure/Invoke-SsasCompatibility.ps1')
        $validation = $command.Parameters['SsmsMajor'].Attributes |
            Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
        @($validation.ValidValues) -join ',' | Should -Be '20,21,22'
    }

    BeforeEach {
        $script:logDirectory = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $script:exitCode = 0
        $script:createDatabase = $true
        $script:compatibilityLevel = 1500
        $script:dropFails = $false
        $script:databases = [pscustomobject]@{ Database = $null }
        $script:databases | Add-Member ScriptMethod FindByName { param($Name) return $this.Database }
        $script:mockConnection = [pscustomobject]@{ Connected = $false; Databases = $script:databases }
        $script:mockConnection | Add-Member ScriptMethod Connect { param($Server) $this.Connected = $true }
        $script:mockConnection | Add-Member ScriptMethod Disconnect { $this.Connected = $false }
        $script:mockConnection | Add-Member ScriptMethod Refresh {
            param([bool]$Full)
            if (-not $Full) { throw 'Expected a full server refresh including database children' }
        }

        Mock New-Object { return $script:mockConnection } -ParameterFilter {
            $TypeName -eq 'Microsoft.AnalysisServices.Server'
        }

        Mock Start-Process {
            if ($script:createDatabase) {
                $database = [pscustomobject]@{
                    CompatibilityLevel = $script:compatibilityLevel
                    Owner = $script:databases
                }
                $database | Add-Member ScriptMethod Drop {
                    if ($script:dropFails) { throw 'Simulated cleanup failure' }
                    $this.Owner.Database = $null
                }
                $script:databases.Database = $database
            }
            return [pscustomobject]@{ ExitCode = $script:exitCode }
        }
    }

    It 'declares calculated table columns bound to the DAX ROW result' {
        $fixture = Get-Content -LiteralPath $script:fixturePath -Raw | ConvertFrom-Json
        $fixture.compatibilityLevel | Should -Be 1500
        $fixture.model.tables[0].partitions[0].source.type | Should -Be 'calculated'
        $fixture.model.tables[0].columns[0].type | Should -Be 'calculatedTableColumn'
        $fixture.model.tables[0].columns[0].sourceColumn | Should -Be '[Value]'
    }

    It 'requires an actual database at compatibility 1500 and cleans up the probe' {
        . $script:probeScript -DeploymentUtilityPath 'utility.exe' -ModelPath $script:fixturePath `
            -Server 'localhost\DCUBE' -LogDirectory $script:logDirectory

        $report = Get-Content (Join-Path $script:logDirectory 'utility-probe/compatibility-probe.json') -Raw | ConvertFrom-Json
        $report.Outcome | Should -Be 'Passed'
        $report.DatabaseExists | Should -BeTrue
        $report.CompatibilityLevel | Should -Be 1500
        $report.Cleanup | Should -Be 'Passed'
        $script:databases.Database | Should -BeNullOrEmpty
        $script:mockConnection.Connected | Should -BeFalse
        Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter {
            $FilePath -eq 'utility.exe' -and $ArgumentList[1] -like '/s:*'
        }
    }

    It 'rejects a successful exit code without a deployed database' {
        $script:createDatabase = $false
        { . $script:probeScript -DeploymentUtilityPath 'utility.exe' -ModelPath $script:fixturePath `
            -Server 'localhost\DCUBE' -LogDirectory $script:logDirectory } |
            Should -Throw '*probe database does not exist*'
    }

    It 'rejects a nonzero utility exit and still removes a partially created database' {
        $script:exitCode = 1
        { . $script:probeScript -DeploymentUtilityPath 'utility.exe' -ModelPath $script:fixturePath `
            -Server 'localhost\DCUBE' -LogDirectory $script:logDirectory } |
            Should -Throw '*exit code 1*'
        $script:databases.Database | Should -BeNullOrEmpty
    }

    It 'rejects an incorrect database compatibility level' {
        $script:compatibilityLevel = 1600
        { . $script:probeScript -DeploymentUtilityPath 'utility.exe' -ModelPath $script:fixturePath `
            -Server 'localhost\DCUBE' -LogDirectory $script:logDirectory } |
            Should -Throw '*expected 1500*'
        $script:databases.Database | Should -BeNullOrEmpty
    }

    It 'fails explicitly if probe cleanup fails' {
        $script:dropFails = $true
        { . $script:probeScript -DeploymentUtilityPath 'utility.exe' -ModelPath $script:fixturePath `
            -Server 'localhost\DCUBE' -LogDirectory $script:logDirectory } |
            Should -Throw '*Simulated cleanup failure*'
        $report = Get-Content (Join-Path $script:logDirectory 'utility-probe/compatibility-probe.json') -Raw | ConvertFrom-Json
        $report.Outcome | Should -Be 'Failed'
        $report.Cleanup | Should -Be 'Failed'
        $script:mockConnection.Connected | Should -BeFalse
    }

    It 'does not deploy over or delete an existing database' {
        $existingDatabase = [pscustomobject]@{ CompatibilityLevel = 1500 }
        $script:databases.Database = $existingDatabase
        { . $script:probeScript -DeploymentUtilityPath 'utility.exe' -ModelPath $script:fixturePath `
            -Server 'localhost\DCUBE' -LogDirectory $script:logDirectory } |
            Should -Throw '*refusing to overwrite*'
        $script:databases.Database | Should -Be $existingDatabase
        Should -Invoke Start-Process -Times 0 -Exactly
    }
}
