function Invoke-ExternalCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command,

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,

        [Parameter(Mandatory = $false)]
        [boolean]$PipeOutNull

    )
    # Reset $LASTEXITCODE in case it was tripped somewhere else
    $Global:LASTEXITCODE = 0;

    # We want the command will write to standard output so we can trace progress
    if ($PipeOutNull) {
        & $Command $Arguments | Out-Null;
    } else {
        & $Command $Arguments;
    }
    if ($LASTEXITCODE -ne 0) {
        Throw "Error executing $Command";
    }
}