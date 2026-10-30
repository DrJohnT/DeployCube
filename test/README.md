# Contributor validation

## Local commands

Use **Windows PowerShell 5.1** (`powershell.exe -NoProfile`), not `pwsh`, for the
certified CI target. From the repository root:

```powershell
./test/bootstrap.ps1
./test/Test-PowerShellSyntax.ps1
./test/Invoke-DeployCubeTests.ps1 -Type Analyzer
./test/Invoke-DeployCubeTests.ps1 -Type Unit -CodeCoverage
./test/Build-ReleasePackage.ps1 -OutputPath ./TestResults/local-package
```

Dependencies are pinned in [RequiredModules.psd1](RequiredModules.psd1): Pester
5.7.1 and PSScriptAnalyzer 1.24.0. Bootstrap installs only missing versions,
restores the Gallery trust policy, and fails explicitly on installation errors.
It never installs SqlServer or deployment utilities. Network access is needed
for dependency installation, not for the tests.

The existing [RunSpecificTests.ps1](RunSpecificTests.ps1) and
[RunPesterCodeCoverage.ps1](RunPesterCodeCoverage.ps1) now call the safe unit runner.
For focused work, import pinned Pester and run a specific safe test file with
`Invoke-Pester -Path ./test/Unit/ValidationGates.Tests.ps1`.
Use the full runner before submitting changes.

PowerShell 7/Linux can provide an early local check, but is not a substitute for
Windows CI: OLE DB cases are Windows-only. One known-defect Multidimensional
`.configsettings` test remains skipped (assessment F01); this change does not
repair production deployment behavior.

## Unit versus integration tests

[TestSelection.psd1](TestSelection.psd1) is the explicit automatic test selection:

- `test/Unit`: mocked command behavior, XMLA/TMSL responses, fixture copies,
  external-command exit codes, and non-publishing release-gate tests.
- Existing root-level Phase C-H2 guard tests listed in `UnitPaths`: mocked
  utility discovery/deployment, provisioning verification, metadata, processing
  evidence, ISO validation, and bounded subprocess/download handling.

These need no SQL Server, SSAS, SSMS installation, production credentials, or
deployment infrastructure. The download regression starts a temporary loopback
HTTP listener and uses Windows' built-in `curl.exe`; it does not download SQL
Server media. The committed executable fixture supplies version metadata only;
tests never execute that deployment utility.

**Do not run `Invoke-Pester ./test` recursively.** Unselected legacy root tests
contain real deployment, processing, deletion, and Azure operations. They remain
in place for historical/manual use, not mandatory validation; the old root
analyzer test is also superseded by `test/Analyzer`. The isolated suite replaces
their infrastructure-free assertions without relocating the legacy tests.

For real integration testing, use the existing manual
[SSMS](../.github/workflows/ssms-compatibility.yml) and
[SSAS](../.github/workflows/ssas-compatibility.yml) workflows. Both remain
`workflow_dispatch`-only, use GitHub-hosted Windows runners, and retain the
Phase C-H2 infrastructure. See [compatibility testing](../docs/COMPATIBILITY_TESTING.md)
for supported phases, fixtures, cost, and reports. No self-hosted runner or
second integration framework is introduced.

## Static analysis

Run `./test/Invoke-DeployCubeTests.ps1 -Type Analyzer`, not a broad direct
multi-rule `Invoke-ScriptAnalyzer` invocation. The gate uses documented
[settings](Analyzer/PSScriptAnalyzerSettings.psd1) and a reviewed
[baseline](Analyzer/PSScriptAnalyzerBaseline.psd1).

Each file/rule pair is invoked separately with terminating analyzer errors.
This preserves PR #17's workaround for the reproduced PSScriptAnalyzer
multi-rule `PSProvideCommentHelp`/`Export-ModuleMember` shared-command race.
There are **no analyzer retries**.

All module scripts/manifests and the maintained validation scripts are checked.
The five historical rule exclusions remain explicit in the settings.
Existing module debt is capped by file/rule count; unlisted findings and any
findings in the new validation scripts fail. Counts cannot distinguish replacement
findings at the same count, so reviewers must inspect the reported findings.
When fixing debt, lower the corresponding allowance in the same PR.
Do not regenerate the baseline just to turn CI green.

The recovered baseline was compared against merged PR #18: executable discovery
has four existing trailing-whitespace findings, not the three in PR #17. No
production code was rewritten to satisfy the analyzer.

## Coverage

Pester instruments **every `DeployCube/public/*.ps1` file** (17 files), including
external-boundary commands tested with mocks and the new discovery helper.
Coverage is `100 * executed commands / analyzed commands`, not line coverage
or evidence of a successful real deployment. The gate compares the unrounded
value with 75% and rejects missing/empty coverage.

Excluded from this denominator: the module loader/manifest (validated separately),
tests, fixtures, and the installer/provisioning/live integration harness under
`test/infrastructure`. There are no per-function exclusions in public module
code, including poorly covered infrastructure-bound branches.

Outputs in ignored `TestResults/`:

- `TestResults-Unit.xml`, `TestResults-Analyzer.xml`: NUnit reports.
- `Coverage-Unit.xml`: JaCoCo coverage report.
- `CoverageSummary.json`: analyzed/executed counts, scope, and missed commands.
- In CI, runtime and dependency-version diagnostics.

PR #17's 92.33% is historical, not the current result. The verified Phase J
[Windows 5.1 run](https://github.com/DrJohnT/DeployCube/actions/runs/41047961303)
measured **393/428 commands (91.82%)**; Linux measured 377/428 (88.08%) because
the OLE DB cases require Windows. Windows CI is authoritative. Compare runs
using the same scope and engine. Coverage changes with module code; do not
copy old reports into CI.

## Automatic CI and releases

[CI](../.github/workflows/ci.yml) runs on every pull request and push to `master`.
It verifies **Desktop 5.1**, parses PowerShell syntax, runs analyzer and unit
gates, and builds/inspects a package using `Publish-Module` against a temporary
**local filesystem repository**, never the Gallery. NUnit, JaCoCo, coverage
summary and diagnostics are uploaded even when validation fails. A successful
run also uploads the validated module source and local `.nupkg`.

[Release](../.github/workflows/release.yml) preserves the `v*` tag strategy:

1. Re-run the exact shared CI workflow on the tagged commit, without secrets.
2. Require the exact case-sensitive tag `v<manifest version>`, successful tests,
   analyzer, coverage and local package build. A separate read-only policy job
   verifies that `psgallery` already has required reviewers and custom deployment
   rules; missing/unprotected environments fail closed before publication.
3. Only after success, enter the protected `psgallery` environment, download
   that run's validated module artifact, recheck its version, and publish.
4. Create the GitHub release only after Gallery publication succeeds.

The publication job has read-only repository permission. Only the final
GitHub-release job receives `contents: write`. Checkout credentials are not
persisted. Actions are SHA-pinned; jobs have timeouts and concurrency controls.
No live SSAS gate, test tag, or test Gallery publication is needed.

### Administrator setup (required before publishing)

Repository environment settings are **not** created by this change:

- Create **`psgallery`**, configure required reviewers and tag deployment rules
  permitting only intended `v*` release tags. Do not rely on an automatically
  created, unprotected environment. Restrict who may create release tags.
- Store **`PSGALLERY_API_KEY` only as a `psgallery` environment secret**, not as a
  repository/organization secret. It is passed only to the publication step;
  CI, build and GitHub-release jobs do not receive it.
  An existing repository-level key must be moved by an administrator; this
  change intentionally does not alter repository secrets or environment settings.
- Require the CI **Windows PowerShell 5.1 validation** check in `master` branch
  protection/rulesets. Environment protection and branch protection are GitHub
  settings, not enforced by a YAML declaration alone.

No secrets or environments are required for ordinary CI. The compatibility
workflows keep their existing configuration documented separately.

## Troubleshooting

- **Dependencies:** confirm the exact versions in `dependencies.txt`; rerun
  bootstrap after resolving Gallery/network errors. Do not change versions or
  hide analyzer failures behind retries.
- **Analyzer:** open `TestResults-Analyzer.xml` and the job log to locate the
  file, rule, line, and allowed count. Existing allowances are not a blanket
  suppression for new validation code.
- **Tests/coverage:** inspect NUnit failures, `CoverageSummary.json` missed
  commands, and the JaCoCo report in the `validation-windows-powershell-5.1`
  artifact. A discovery failure or zero passing tests fails validation.
- **Package:** use a fresh `-OutputPath` for each local build. Build failures,
  incorrect/missing packages, and tag mismatches block publication.
- **Release pending:** inspect shared validation first, then environment approval
  and the environment-scoped key. Never bypass failed validation to publish.
- **Missing artifacts:** a cancelled job or dependency failure can prevent test
  report creation; runtime diagnostics and Actions logs remain the first check.
