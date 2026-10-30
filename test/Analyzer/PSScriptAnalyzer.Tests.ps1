# PSScriptAnalyzer gate for the DeployCube module and maintained validation scripts.
# Every analyzer rule (except the excluded ones in PSScriptAnalyzerSettings.psd1) is checked for every module script.
# Existing findings are tolerated up to the counts recorded in PSScriptAnalyzerBaseline.psd1, so the gate blocks new
# findings without requiring changes to module code.

BeforeDiscovery {
    $testRoot = Split-Path -Parent $PSScriptRoot
    $moduleRoot = Join-Path -Path (Split-Path -Parent $testRoot) -ChildPath 'DeployCube'
    $validationFiles = @(
        'bootstrap.ps1', 'RequiredModules.psd1', 'TestHelpers.ps1', 'TestSelection.psd1',
        'Assert-ValidationResult.ps1', 'Assert-ReleaseEnvironment.ps1', 'Invoke-DeployCubeTests.ps1', 'Test-PowerShellSyntax.ps1',
        'Build-ReleasePackage.ps1', 'RunPesterCodeCoverage.ps1', 'RunSpecificTests.ps1'
    ) | ForEach-Object { Get-Item (Join-Path $testRoot $_) }
    $scripts = @(@(Get-ChildItem -Path $moduleRoot -Recurse -Include '*.ps1', '*.psm1', '*.psd1') + $validationFiles |
        Where-Object { $_.Name -notlike '*.Tests.ps1' } |
        ForEach-Object { @{
            Name = $_.Name
            FullName = $_.FullName
            IsModule = $_.FullName.StartsWith("$moduleRoot$([IO.Path]::DirectorySeparatorChar)")
        } })

    $settings = Import-PowerShellDataFile -Path (Join-Path -Path $PSScriptRoot -ChildPath 'PSScriptAnalyzerSettings.psd1')
    $rules = @(Get-ScriptAnalyzerRule |
        Where-Object { $settings.ExcludeRules -notcontains $_.RuleName } |
        Sort-Object -Property RuleName |
        ForEach-Object { @{ Rule = $_.RuleName } })
}

Describe 'PSScriptAnalyzer: <Name>' -Tag 'Analyzer' -ForEach $scripts {
    BeforeAll {
        $settingsPath = Join-Path -Path $PSScriptRoot -ChildPath 'PSScriptAnalyzerSettings.psd1'
        $baseline = Import-PowerShellDataFile -Path (Join-Path -Path $PSScriptRoot -ChildPath 'PSScriptAnalyzerBaseline.psd1')
    }

    It 'Should not add findings for <Rule>' -ForEach $rules {
        # One rule per call on purpose: PSScriptAnalyzer runs rules in parallel, and on files that call
        # Export-ModuleMember (DeployCube.psm1) PSProvideCommentHelp races with other rules on a shared CommandInfo
        # and intermittently throws NullReferenceException. A single rule per invocation removes that race.
        $found = @(Invoke-ScriptAnalyzer -Path $FullName -Settings $settingsPath -IncludeRule $Rule -ErrorAction Stop)
        # Validation scripts have no baseline allowance, even if a module filename is reused.
        $key = if ($IsModule) { "$Name|$Rule" } else { "validation/$Name|$Rule" }
        $allowed = if ($baseline.ContainsKey($key)) { [int]$baseline[$key] } else { 0 }

        $details = ($found | ForEach-Object { "line $($_.Line): $($_.Message)" }) -join [Environment]::NewLine
        $found.Count | Should -BeLessOrEqual $allowed -Because "baseline allows $allowed finding(s) for $key. Findings:$([Environment]::NewLine)$details"
    }
}

Describe 'PSScriptAnalyzer baseline' -Tag 'Analyzer' {
    It 'Only references module files that exist' {
        $baseline = Import-PowerShellDataFile -Path (Join-Path -Path $PSScriptRoot -ChildPath 'PSScriptAnalyzerBaseline.psd1')
        $moduleRoot = Join-Path -Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) -ChildPath 'DeployCube'
        $names = @(Get-ChildItem -Path $moduleRoot -Recurse -File | Select-Object -ExpandProperty Name)
        $missing = @($baseline.Keys | ForEach-Object { ($_ -split '\|')[0] } | Where-Object { $names -notcontains $_ })
        $missing | Should -BeNullOrEmpty
    }
}
