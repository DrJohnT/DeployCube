function Assert-ValidationResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]$Result,
        [switch]$CodeCoverage,
        [ValidateRange(0, 100)][double]$MinimumCoverage = 75
    )
    if ($Result.Result -ne 'Passed' -or $Result.PassedCount -le 0 -or
        $Result.FailedCount -ne 0 -or $Result.FailedBlocksCount -ne 0 -or $Result.FailedContainersCount -ne 0) {
        throw "Validation failed: result=$($Result.Result), passed=$($Result.PassedCount), failed=$($Result.FailedCount), blocks=$($Result.FailedBlocksCount), containers=$($Result.FailedContainersCount)."
    }
    if ($CodeCoverage) {
        $coverage = $Result.CodeCoverage
        if (-not $coverage -or $coverage.CommandsAnalyzedCount -le 0) {
            throw 'Coverage is missing or contains no analyzed commands.'
        }
        $percent = 100.0 * $coverage.CommandsExecutedCount / $coverage.CommandsAnalyzedCount
        Write-Information ("Unit command coverage: {0:N2}% ({1}/{2}); minimum {3}%" -f
            $percent, $coverage.CommandsExecutedCount, $coverage.CommandsAnalyzedCount, $MinimumCoverage) -InformationAction Continue
        if ($percent -lt $MinimumCoverage) {
            throw "Unit coverage $percent% is below $MinimumCoverage%."
        }
    }
}
