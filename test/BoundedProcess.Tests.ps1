BeforeAll {
    $script:boundedProcessPath = Join-Path $PSScriptRoot 'infrastructure/Invoke-BoundedProcess.ps1'
    . $script:boundedProcessPath
    function Write-ProvisioningLog {
        param([string]$Stage, [string]$Message)
        $script:provisioningMessages += "[$Stage] $Message"
    }
}

Describe 'Bounded provisioning subprocess' {
    BeforeEach {
        $script:processDirectory = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:processDirectory -Force | Out-Null
        $script:childPath = Join-Path $script:processDirectory 'child process.ps1'
        $script:stdoutPath = Join-Path $script:processDirectory 'stdout.log'
        $script:stderrPath = Join-Path $script:processDirectory 'stderr.log'
        $script:provisioningMessages = @()
        $script:powershellPath = if ($PSVersionTable.PSEdition -eq 'Desktop') {
            Join-Path $PSHOME 'powershell.exe'
        }
        else {
            (Get-Process -Id $PID).Path
        }
    }

    It 'returns the real exit code and captures both output streams' {
        @(
            "[Console]::Out.WriteLine('child standard output')"
            "[Console]::Error.WriteLine('child standard error')"
            'exit 7'
        ) | Set-Content -LiteralPath $script:childPath -Encoding UTF8

        $result = Invoke-BoundedProcess -FilePath $script:powershellPath `
            -ArgumentList @('-NoLogo', '-NoProfile', '-File', "`"$script:childPath`"") `
            -TimeoutSeconds 10 -Stage 'Test subprocess' `
            -StandardOutputPath $script:stdoutPath -StandardErrorPath $script:stderrPath

        $result.ExitCode | Should -Be 7
        Get-Content -LiteralPath $script:stdoutPath -Raw | Should -Match 'child standard output'
        Get-Content -LiteralPath $script:stderrPath -Raw | Should -Match 'child standard error'
        @($script:provisioningMessages | Where-Object { $_ -match 'exited with code 7 after' }).Count |
            Should -BeGreaterThan 0
    }

    It 'terminates a process when its execution deadline expires' {
        'Start-Sleep -Seconds 30' | Set-Content -LiteralPath $script:childPath -Encoding UTF8
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

        {
            Invoke-BoundedProcess -FilePath $script:powershellPath `
                -ArgumentList @('-NoLogo', '-NoProfile', '-File', "`"$script:childPath`"") `
                -TimeoutSeconds 2 -Stage 'Test timeout' `
                -StandardOutputPath $script:stdoutPath -StandardErrorPath $script:stderrPath
        } | Should -Throw "*exceeded the 2-second timeout in stage 'Test timeout'*"

        $stopwatch.Stop()
        $stopwatch.Elapsed.TotalSeconds | Should -BeLessThan 15
        @($script:provisioningMessages | Where-Object { $_ -match 'exceeded its timeout; terminating its process tree' }).Count |
            Should -BeGreaterThan 0
    }
}
