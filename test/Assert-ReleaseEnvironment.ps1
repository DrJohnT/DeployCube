function Assert-ReleaseEnvironment {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)]$Environment)
    $reviewRules = @($Environment.protection_rules | Where-Object {
        $_.type -eq 'required_reviewers' -and $null -ne $_.reviewers -and @($_.reviewers).Count -gt 0
    })
    if ($Environment.name -cne 'psgallery' -or $reviewRules.Count -eq 0) {
        throw 'The psgallery environment must exist and require reviewer approval before publication.'
    }
    if (-not $Environment.deployment_branch_policy.custom_branch_policies) {
        throw 'The psgallery environment requires custom deployment tag rules; configure intended v* tags.'
    }
}
