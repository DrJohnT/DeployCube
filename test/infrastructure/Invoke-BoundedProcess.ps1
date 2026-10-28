function Invoke-BoundedProcess {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $true)]
        [string[]]$ArgumentList,

        [Parameter(Mandatory = $true)]
        [int]$TimeoutSeconds,

        [Parameter(Mandatory = $true)]
        [string]$Stage,

        [Parameter(Mandatory = $true)]
        [string]$StandardOutputPath,

        [Parameter(Mandatory = $true)]
        [string]$StandardErrorPath,

        [string]$ObservedDirectory
    )

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $FilePath
    $startInfo.Arguments = $ArgumentList -join ' '
    $startInfo.WorkingDirectory = Split-Path -Parent $FilePath
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    if (-not $process.Start()) {
        throw "Failed to start process '$FilePath' in stage '$Stage'."
    }
    $standardOutputTask = $process.StandardOutput.ReadToEndAsync()
    $standardErrorTask = $process.StandardError.ReadToEndAsync()
    $processStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    Write-ProvisioningLog -Stage $Stage -Message "Started process '$FilePath' (PID $($process.Id)); timeout ${TimeoutSeconds}s."

    try {
        while (-not $process.WaitForExit([int][math]::Min(30000, [math]::Max(1, ($TimeoutSeconds - $processStopwatch.Elapsed.TotalSeconds) * 1000)))) {
            if ($processStopwatch.Elapsed.TotalSeconds -ge $TimeoutSeconds) {
                Write-ProvisioningLog -Stage $Stage -Message "Process PID $($process.Id) exceeded its timeout; terminating its process tree."
                $taskkillPath = if ($env:SystemRoot) {
                    Join-Path $env:SystemRoot 'System32\taskkill.exe'
                }
                if ($taskkillPath -and (Test-Path -LiteralPath $taskkillPath -PathType Leaf)) {
                    $killer = Start-Process -FilePath $taskkillPath `
                        -ArgumentList @('/PID', [string]$process.Id, '/T', '/F') `
                        -PassThru -WindowStyle Hidden -ErrorAction Stop
                    if (-not $killer.WaitForExit(30000)) {
                        $killer.Kill()
                        $process.Kill()
                        $process.WaitForExit(15000) | Out-Null
                        throw "Unable to terminate timed-out process tree for PID $($process.Id) using taskkill."
                    }
                }
                else {
                    $process.Kill()
                }
                if (-not $process.WaitForExit(15000)) {
                    $process.Kill()
                    if (-not $process.WaitForExit(15000)) {
                        throw "Timed-out process PID $($process.Id) did not exit after process-tree termination."
                    }
                }
                $process.WaitForExit()
                throw [System.TimeoutException]::new(
                    "Process '$FilePath' exceeded the $TimeoutSeconds-second timeout in stage '$Stage'."
                )
            }

            $progressMessage = "Process PID $($process.Id) is still running after $([math]::Round($processStopwatch.Elapsed.TotalMinutes, 1)) minutes."
            if ($ObservedDirectory -and (Test-Path -LiteralPath $ObservedDirectory -PathType Container)) {
                $files = @(Get-ChildItem -LiteralPath $ObservedDirectory -File -Recurse -ErrorAction SilentlyContinue)
                $totalBytes = ($files | Measure-Object -Property Length -Sum).Sum
                $latestFile = $files | Sort-Object -Property LastWriteTime -Descending | Select-Object -First 1
                $progressMessage += " Media files: $($files.Count); bytes: $totalBytes; latest file: $($latestFile.FullName)."
            }
            Write-ProvisioningLog -Stage $Stage -Message $progressMessage
        }

        $process.WaitForExit()
        if (-not $standardOutputTask.Wait(30000) -or -not $standardErrorTask.Wait(30000)) {
            throw "Process output pipes for '$FilePath' remained open after process exit."
        }
        [System.IO.File]::WriteAllText($StandardOutputPath, $standardOutputTask.Result)
        [System.IO.File]::WriteAllText($StandardErrorPath, $standardErrorTask.Result)

        $process.Refresh()
        $durationSeconds = [math]::Round($processStopwatch.Elapsed.TotalSeconds, 2)
        $exitCode = $process.ExitCode
        Write-ProvisioningLog -Stage $Stage -Message (
            "Process PID $($process.Id) exited with code $exitCode after $durationSeconds seconds."
        )
        return [pscustomobject]@{
            ExitCode = $exitCode
            DurationSeconds = $durationSeconds
            ProcessId = $process.Id
        }
    }
    finally {
        if (-not $standardOutputTask.IsCompleted) {
            $standardOutputTask.Wait(30000) | Out-Null
        }
        if (-not $standardErrorTask.IsCompleted) {
            $standardErrorTask.Wait(30000) | Out-Null
        }
        if ($standardOutputTask.IsCompleted) {
            [System.IO.File]::WriteAllText($StandardOutputPath, $standardOutputTask.Result)
        }
        if ($standardErrorTask.IsCompleted) {
            [System.IO.File]::WriteAllText($StandardErrorPath, $standardErrorTask.Result)
        }
        $process.Dispose()
    }
}
