BeforeAll {
    . (Join-Path $PSScriptRoot 'infrastructure/Invoke-BoundedProcess.ps1')
    function Write-ProvisioningLog {
        param([string]$Stage, [string]$Message)
        Write-Host "[$Stage] $Message"
    }
}

Describe 'SQL Server media download inactivity limit' {
    It 'terminates curl promptly when the HTTP server sends no media bytes' {
        $serverPath = Join-Path $TestDrive 'stalled-server.ps1'
        $portPath = Join-Path $TestDrive 'port.txt'
        @'
param([string]$PortPath)
$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
$listener.Start()
[System.IO.File]::WriteAllText($PortPath, [string]$listener.LocalEndpoint.Port)
try {
    $client = $listener.AcceptTcpClient()
    try {
        $stream = $client.GetStream()
        $header = [System.Text.Encoding]::ASCII.GetBytes("HTTP/1.1 200 OK`r`nContent-Length: 2147483648`r`nConnection: close`r`n`r`n")
        $stream.Write($header, 0, $header.Length)
        $stream.Flush()
        Start-Sleep -Seconds 30
    }
    finally { $client.Dispose() }
}
finally { $listener.Stop() }
'@ | Set-Content -LiteralPath $serverPath
        $powershell = (Get-Process -Id $PID).Path
        $server = Start-Process -FilePath $powershell -ArgumentList @(
            '-NoLogo', '-NoProfile', '-File', "`"$serverPath`"", '-PortPath', "`"$portPath`""
        ) -PassThru
        try {
            $deadline = [DateTime]::UtcNow.AddSeconds(10)
            while (-not (Test-Path -LiteralPath $portPath) -and [DateTime]::UtcNow -lt $deadline) {
                Start-Sleep -Milliseconds 100
            }
            Test-Path -LiteralPath $portPath | Should -BeTrue
            $port = [System.IO.File]::ReadAllText($portPath)
            $curlName = if ($env:OS -eq 'Windows_NT') { 'curl.exe' } else { 'curl' }
            $result = Invoke-BoundedProcess -FilePath (Get-Command $curlName).Source `
                -ArgumentList @(
                    '--fail', '--show-error', '--connect-timeout', '3',
                    '--speed-limit', '1', '--speed-time', '2',
                    '--output', "`"$(Join-Path $TestDrive 'partial.iso')`"", "http://127.0.0.1:$port/"
                ) -TimeoutSeconds 10 -Stage 'Stalled download regression' `
                -StandardOutputPath (Join-Path $TestDrive 'curl.stdout.log') `
                -StandardErrorPath (Join-Path $TestDrive 'curl.stderr.log')
            $result.ExitCode | Should -Be 28
            $result.DurationSeconds | Should -BeLessThan 8
            $partialPath = Join-Path $TestDrive 'partial.iso'
            if (Test-Path -LiteralPath $partialPath) {
                (Get-Item -LiteralPath $partialPath -ErrorAction Stop).Length | Should -Be 0
            }
            Get-Content -LiteralPath (Join-Path $TestDrive 'curl.stderr.log') -Raw |
                Should -Match 'Operation too slow'
        }
        finally {
            if (-not $server.HasExited) { $server.Kill() }
            $server.WaitForExit(5000) | Out-Null
            $server.Dispose()
        }
    }
}
