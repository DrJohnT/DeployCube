# Exact versions used by ./bootstrap.ps1, ./Invoke-DeployCubeTests.ps1 and the GitHub Actions workflows.
# Update deliberately (for example via a Dependabot-style PR) and re-baseline the analyzer if rules change.
@(
    @{ ModuleName = "Pester"; RequiredVersion = "5.7.1"}
    @{ ModuleName = "PSScriptAnalyzer"; RequiredVersion = "1.24.0"}
)
