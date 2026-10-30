function Get-SsasProductMajor {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('2017', '2019', '2022', '2025')]
        [string]$SsasVersion
    )

    return @{ '2017' = 14; '2019' = 15; '2022' = 16; '2025' = 17 }[$SsasVersion]
}
