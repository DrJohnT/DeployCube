# DeployCube tests

The suite is split by what it needs to run:

| Suite | Folder | Needs | Runs in CI |
|-------|--------|-------|------------|
| **Analyzer** | `test/Analyzer` | PSScriptAnalyzer only | Every pull request and push to `master` |
| **Unit** | `test/Unit` | Pester only. No SQL Server, SSAS, SqlServer module or deployment utility. All external calls (`Invoke-ASCmd`, `Microsoft.AnalysisServices.Deployment.exe`, module installs) are mocked | Every pull request and push to `master` |
| **Integration** | `test/Integration` (tag `SSAS`) | Windows, a live SSAS Tabular instance, the deployment utility, the SqlServer module and the built example models | Only when explicitly requested, on a self-hosted runner |
| **Azure** | `test/Integration/Azure-Integration.Tests.ps1` (tag `Azure`) | An Azure Analysis Services server and service principal | Never automatically |

Integration and Azure tests are **skipped** (not failed) unless they are explicitly enabled, so running
`Invoke-Pester` on the whole `test` folder never touches a server by accident.

## Prerequisites

Test dependencies are pinned to exact versions in [`RequiredModules.psd1`](RequiredModules.psd1)
(Pester 5.7.1, PSScriptAnalyzer 1.24.0). Install them once per machine:

```powershell
./test/bootstrap.ps1            # CurrentUser scope; use -Scope AllUsers on a build agent
```

The supported test host is **Windows PowerShell 5.1**, which is what CI uses. Analyzer and Unit also run on
PowerShell 7 (including Linux/macOS), which is convenient for local development. Some OleDb connection-string
tests are skipped there because `System.Data.OleDb` is Windows-only.

## Running tests locally

`Invoke-DeployCubeTests.ps1` is the single entry point used both locally and by GitHub Actions:

```powershell
./test/Invoke-DeployCubeTests.ps1                                  # Unit (default)
./test/Invoke-DeployCubeTests.ps1 -Type Analyzer                   # PSScriptAnalyzer gate
./test/Invoke-DeployCubeTests.ps1 -Type Analyzer, Unit -CodeCoverage   # what CI runs
./test/Invoke-DeployCubeTests.ps1 -Type Integration -Tag Round1     # extra Pester tag filters
```

Results go to `TestResults/` (git-ignored): `TestResults-<suite>.xml` (NUnit XML) and, with `-CodeCoverage`,
`Coverage-<suite>.xml` (JaCoCo, `DeployCube/public` only). The script throws (non-zero exit code) if any
test fails, so it can be used directly from any CI system, including Azure Pipelines.

To run a single file while developing, Pester can be used directly:

```powershell
Invoke-Pester ./test/Unit/Publish-Cube.Tests.ps1 -Output Detailed
```

### Analyzer baseline

`Analyzer/PSScriptAnalyzer.Tests.ps1` runs every PSScriptAnalyzer rule (except those excluded in
`Analyzer/PSScriptAnalyzerSettings.psd1`) against every file in `DeployCube/`. The module has pre-existing
findings, so `Analyzer/PSScriptAnalyzerBaseline.psd1` records the tolerated count per `file|rule`. The gate
fails on any **new** finding. When you fix existing findings, lower (or remove) the matching baseline entry so
they cannot come back. Do not raise a baseline count to make a build pass without a reviewed reason.

Rules are invoked one at a time because PSScriptAnalyzer 1.24 runs rules in parallel, and on files that call
`Export-ModuleMember` (`DeployCube.psm1`) that intermittently fails inside PowerShell with a
`NullReferenceException` or "cannot have more than one dynamic module in each dynamic assembly". Invoking one
rule per call avoids the race at the cost of a longer run (about 30 seconds).

## Running SSAS integration tests

Integration tests deploy, process and drop real databases, so they need a dedicated, disposable SSAS
instance. Do not point them at a shared or production server.

As a safeguard, the suite refuses to run (before any test connects) unless the target is on the local machine
(`localhost`, `.`, `(local)`, `127.0.0.1`, `::1` or the computer name, with any instance name or port), or
`DEPLOYCUBE_DISPOSABLE_SSAS_SERVER` is set to exactly the same value as `DEPLOYCUBE_SSAS_SERVER`. Azure Analysis
Services is always refused here; use `-Type Azure`. The databases the tests touch are fixed, test-owned names:
`CubeAtCompatibility1200`, `CubeAtCompatibility1500`, `IntegrationTestCube1200`, `IntegrationTestCube1500`,
`CubeWithInvalidDataSource`, `CubeToProcess`, `TestProcessing` and GUID-named temporary databases.

Requirements on the machine running the tests:

1. Windows with Windows PowerShell 5.1.
2. SQL Server Analysis Services in **Tabular** mode, compatibility level 1500 or higher (for example SSAS
   2019/2022 Developer Edition, which is free for non-production use), reachable from the test machine.
   The account running the tests must be an SSAS server administrator.
3. `Microsoft.AnalysisServices.Deployment.exe`, installed with SQL Server Management Studio. Alternatively,
   set `CustomAsDwInstallLocation` to the folder that contains it.
4. The `SqlServer` PowerShell module (`Install-Module SqlServer -Scope CurrentUser`).
5. The built example models: build `examples/CubeAtCompatibility1200` and `examples/CubeAtCompatibility1500`
   with Visual Studio + Analysis Services projects so that `bin/Model.asdatabase` exists, or point the
   settings below at prebuilt copies.
6. A SQL Server database that the cubes can use as their data source. Deploy
   `examples/DatabaseToPublish` (DACPAC) for this purpose; processing tests need it.

Configuration is read from environment variables; all are optional:

| Variable | Default | Purpose |
|----------|---------|---------|
| `DEPLOYCUBE_SSAS_SERVER` | `localhost` | SSAS Tabular instance to deploy to |
| `DEPLOYCUBE_DISPOSABLE_SSAS_SERVER` | *(none)* | Must equal `DEPLOYCUBE_SSAS_SERVER` to allow a remote server |
| `DEPLOYCUBE_SOURCE_SQL_SERVER` | value of `DEPLOYCUBE_SSAS_SERVER` | SQL Server hosting the cube source database |
| `DEPLOYCUBE_SOURCE_SQL_DATABASE` | `DatabaseToPublish` | Cube source database |
| `DEPLOYCUBE_ASDATABASE_1200` | `examples/CubeAtCompatibility1200/bin/Model.asdatabase` | Built 1200 model |
| `DEPLOYCUBE_ASDATABASE_1500` | `examples/CubeAtCompatibility1500/bin/Model.asdatabase` | Built 1500 model |
| `DEPLOYCUBE_EXPECTED_DEPLOYMENT_EXE_VERSION` | `15` | Deployment utility version the discovery tests expect |

Run them with:

```powershell
$env:DEPLOYCUBE_SSAS_SERVER = 'ssas-test01'
$env:DEPLOYCUBE_DISPOSABLE_SSAS_SERVER = 'ssas-test01'   # confirms the remote server is disposable
./test/Invoke-DeployCubeTests.ps1 -Type Integration
```

`-Type Integration` enables the suite for that process only (`DEPLOYCUBE_RUN_INTEGRATION=1`) and first runs a
prerequisite check, failing fast with a list of what is missing. `-SkipPrerequisiteCheck` bypasses it.

Integration tests are tagged `Round1` to `Round4`. Round1 is read-only discovery and ping checks; later
rounds deploy and process databases. Use `-Tag Round1` for a quick connectivity smoke test. The baseline
databases `CubeAtCompatibility1200` and `CubeAtCompatibility1500` are deployed automatically when missing and
left in place. Every other database a test creates is dropped again in `AfterAll`/`finally`.

### Azure Analysis Services

```powershell
$env:AzureAsServer = 'asazure://<region>.asazure.windows.net/<server>'
$env:AzureAsUserID = 'app:<appId>@<tenantId>'
$env:AzureAsPassword = '<secret>'
# plus AzureSqlServer / AzureSqlUserID / AzureSqlPassword for the source database
./test/Invoke-DeployCubeTests.ps1 -Type Azure
```

The Azure tests deploy and then drop a uniquely named `DeployCubeTest_<guid>` database (with best-effort
cleanup in `AfterAll`), so they never overwrite an existing database; the old `AzureAsCube` setting is ignored.
Keep these values out of the repository. `Azure-RunTests.ps1` is git-ignored for exactly this purpose.

## GitHub Actions

[`.github/workflows/ci.yml`](../.github/workflows/ci.yml)

* **validate** runs on every pull request, every push to `master` and on manual dispatch. It uses a GitHub-hosted
  `windows-latest` runner with Windows PowerShell 5.1. Steps: assert PowerShell 5.1, `bootstrap.ps1`,
  `Test-ModuleManifest`, Analyzer, then Unit with code coverage. NUnit and JaCoCo results are uploaded as the
  `test-results-windows-powershell-5.1` artifact. No secrets and only `contents: read` are used, so it is safe
  for pull requests from forks. To make it a required check, add **Analyzer and unit tests (Windows
  PowerShell 5.1)** to the `master` branch protection rule.
* **integration** runs only when the workflow is started manually (*Actions → CI → Run workflow*) with
  **run_integration** ticked, in `DrJohnT/DeployCube` itself, after `validate` has passed. It never runs
  for pull requests.

[`.github/workflows/release.yml`](../.github/workflows/release.yml)

On a `v*` tag it runs the same `ci.yml` validation (as a reusable workflow) and checks that the tag matches
`ModuleVersion` in `DeployCube.psd1`. Only if both pass does the `publish` job publish to the PowerShell
Gallery and create the GitHub release. That job runs in the `psgallery` environment, so the API key is only
exposed there. Add required reviewers to that environment for a manual approval step.

### Providing a dedicated SSAS runner

GitHub-hosted runners cannot run SSAS, and a SQL Server container is not a substitute: it has no Analysis
Services engine. To run integration tests from GitHub Actions:

1. Provision a Windows machine or VM that meets the requirements above. Any existing test server works;
   nothing is provisioned by the workflow, so there is no cost unless you choose to run one.
2. Register it as a [self-hosted runner](https://docs.github.com/actions/hosting-your-own-runners) for this
   repository with the extra labels `windows` and `ssas`. Run the runner service as an account that is an
   SSAS administrator. The runner must be version 2.327.1 or later (the pinned actions run on Node.js 24).
   If the SSAS instance is not on the runner itself, set `DEPLOYCUBE_DISPOSABLE_SSAS_SERVER` as well (see above).
3. Create an environment named `ssas-integration` (*Settings → Environments*). Optionally add required
   reviewers, and define the `DEPLOYCUBE_*` settings above as environment **variables**.
4. Start *CI* manually with **run_integration** ticked.

Because self-hosted runners execute workflow code, keep the runner restricted to this repository. The job
is only reachable through manual dispatch, never from pull requests, which prevents untrusted code from
running on it.

If no runner with those labels is online, the integration job stays queued until GitHub times it out. Cancel
the run if that happens.
