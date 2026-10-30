# PSScriptAnalyzer settings for the module and maintained validation scripts.
# Use ./test/Invoke-DeployCubeTests.ps1 -Type Analyzer for the per-rule, baseline-aware gate.
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
