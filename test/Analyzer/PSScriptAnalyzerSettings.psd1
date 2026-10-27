# PSScriptAnalyzer settings for the DeployCube module (DeployCube/).
# Use locally with: Invoke-ScriptAnalyzer -Path ./DeployCube -Recurse -Settings ./test/Analyzer/PSScriptAnalyzerSettings.psd1
@{
    # Rules excluded by the original AnalyzePSScripts.Tests.ps1. Changing them is out of scope for the test/CI work;
    # see docs/MODERNIZATION_ASSESSMENT.md before re-enabling any of them.
    ExcludeRules = @(
        'PSAlignAssignmentStatement',
        'PSUseSingularNouns',
        'PSUseApprovedVerbs',
        'PSUseShouldProcessForStateChangingFunctions',
        'PSAvoidUsingPlainTextForPassword'
    )
}
