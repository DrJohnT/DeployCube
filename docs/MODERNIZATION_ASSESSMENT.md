# DeployCube: Technical Assessment and Modernization Roadmap

Assessment date: 26 October 2026.

## Executive summary

DeployCube is a small, understandable PowerShell orchestration module built around Microsoft's Analysis Services Deployment Utility. Its core architecture remains appropriate: use SSDT-generated model artifacts, configure deployment sidecars, deploy metadata, update environment-specific data sources, and process separately. A rewrite or migration away from the utility is not justified by this review.

The highest-value work is stabilization rather than new functionality:

1. The Multidimensional `.configsettings` branch calls a function absent from the repository and references an undeclared database variable. This is a **code-confirmed functional defect** in an advertised deployment path.
2. Authenticated deployment persists a plaintext password in the original `.deploymenttargets` file. There is no isolation or cleanup lifecycle. Actual unauthorized access is not demonstrated, but the credential persistence is confirmed.
3. Deployment changes the caller's global error preference, loses error-record detail, and can mask the original failure when its expected utility log is unavailable.
4. SSAS response checks are inconsistent. Database deletion checks only for a namespace substring; data-source replacement can treat a missing expected result node as success.
5. Most tests depend on a particular Windows machine, installed utility version, built examples, and live SSAS. The repository does not currently provide a clean, infrastructure-independent regression gate.
6. A **remote-only** GitHub release workflow exists, although it is absent from this checkout. It runs all tests with PowerShell 7 on `windows-latest`, without visible provisioning for their SSAS, SQL Server, SSDT, or analyzer requirements.

Preserve all 17 exported functions, the two deployment/deletion aliases, existing parameter names, and deployment defaults during stabilization. Treat Windows PowerShell 5.1 on Windows as the first certification target, not an already verified compatibility claim. Evaluate PowerShell 7 per function and dependency before declaring support.

### Scope, provenance, and evidence limits

- Local baseline: commit `42669636471d82d57d9c2b3315c3a6edc19c8110`, branch `master`.
- The local worktree already contained a manifest version change from `1.2.5` to `1.2.6` and a whitespace change in executable discovery. Both were included in the review and left untouched.
- Reviewed every public script, the module loader and manifest, all 18 Pester test files, test runners/bootstrap, publishing/help scripts, all 17 function Markdown help pages, external-help metadata, READMEs, ignore rules, example projects/models/profiles, seed-script structure, and test fixtures.
- Large generated seed data was inspected structurally, not audited value by value. Identical SQL table/seed fixtures and identical missing-sidecar model fixtures were identified by hashes. The committed Windows binary was identified by file format, not decompiled, executed, or certified as authentic.
- Local inventory contains no `.github` directory, GitHub workflow YAML, or Azure Pipelines YAML. Read-only GitHub API inspection found one active workflow, `Release`, at `.github/workflows/release.yml`.
- Remote `master` at inspection was `8becb836cdec7ff998416399aea747e3e0448e8c`; the release workflow blob was `ce80a582f0d4f9ebe428ccb5c0d8704554b68d13`. Remote-workflow findings below cite that revision, **not a local file**. This is not a claim that every other file on remote `master` matches the assessed checkout.
- The GitHub Actions runs endpoint returned an empty run list. That does not prove the workflow has never run or that external CI does not exist.
- No implementation changes, dependency installations, deployment executions, commits, or pull requests were made. This report is the sole assessment deliverable.

**Evidence labels:** **Confirmed** means directly established by code/configuration or read-only inventory, not necessarily reproduced at runtime. **Risk** means a concrete exposure or plausible failure mode with an identified trigger, requiring runtime/environment verification. **Idea** means an incremental improvement, not a defect.

**Validation performed:** Git/worktree inventory; targeted symbol searches; comparison of manifest/API/help definitions; XML parsing of external help, SQL publish profiles, and data-generator metadata; fixture hash comparisons; Windows executable format identification; read-only GitHub workflow/run inspection; consultation of Microsoft compatibility documentation.

**Tests not run:** Neither `pwsh` nor `powershell` is installed on this Linux host, so Pester, PowerShell parsing/import tests, and PSScriptAnalyzer could not run. Windows SSAS/AMO/OLE DB prerequisites are unavailable here; example `bin/Model.asdatabase` outputs are absent; Windows SSDT/MSBuild/Visual Studio tooling and isolated SSAS/SQL test targets were not available for integration validation. Azure integration also requires configured test endpoints and credentials. Existing tests can create, modify, process, truncate, and delete objects; they must not run against an unapproved/shared target. No test-pass or current module-wide coverage claim is made.

## A. Architecture Overview

### A1. Module composition and public API

[DeployCube.psm1](../DeployCube/DeployCube.psm1#L3) enumerates scripts beneath `public`, dot-sources them, and exports their basenames. Import exceptions are converted into `Write-Error` calls rather than an explicit fail-fast module initialization policy. The explicit [manifest export list](../DeployCube/DeployCube.psd1#L36) lists the same 17 functions. There is no private implementation directory.

| Component | Exported functions | Responsibility and current contract |
|---|---|---|
| Utility discovery | `Find-AnalysisServicesDeploymentExeLocations`, `Get-AnalysisServicesDeploymentExePath`, `Select-AnalysisServicesDeploymentExeVersion` | Enumerate installations, resolve a path, and select a preferred/fallback version. Discovery emits formatted strings; resolution and selection return strings. |
| Deployment and sidecars | `Publish-Cube`, `Update-AnalysisServicesConfig` | Modify adjacent deployment files, invoke the utility in silent mode, and print progress. `Deploy-Cube` aliases `Publish-Cube`. |
| Native execution | `Invoke-ExternalCommand` | Call a command with a string argument array, optionally discard stdout, and throw on a nonzero native exit code. |
| SSAS inspection | `Get-CubeDatabaseCompatibilityLevel`, `Get-ServerMode`, `Ping-SsasDatabase`, `Ping-SsasServer` | Discover database compatibility or server mode and test availability. Return integer, mode value, or booleans; network and dependency failures are handled differently. |
| Tabular update/processing | `Update-TabularCubeDataSource`, `Invoke-ProcessTabularCubeDatabase`, `Get-SsasProcessingMessages` | Discover a data source, generate TMSL replacement/refresh requests, execute them, and inspect XMLA messages. |
| Deletion | `Unpublish-Cube` | Submit XMLA `Delete`. `Drop-Cube` is its alias. |
| Helpers | `Get-ModuleByName`, `Get-SqlAsPath`, `Get-SqlConnectionString` | Install/import a module if missing; construct a SQLAS provider path; build OLE DB connection strings. These helpers are already public API. |

The exported aliases are defined in [Publish-Cube](../DeployCube/public/Publish-Cube.ps1#L212) and [Unpublish-Cube](../DeployCube/public/Unpublish-Cube.ps1#L55), and exported by the loader/manifest. Do not remove helper exports merely because their names suggest implementation details.

Most functions have `CmdletBinding`, parameter types, and useful validation. `Find-AnalysisServicesDeploymentExeLocations` lacks an advanced-function declaration. Public parameters are not configured for pipeline input; this is a current API choice, not a confirmed defect. Scalar output contracts are less dependable when transitive helpers also print status to the success stream.

### A2. Deployment execution flow

```text
Build model with SSDT / Visual Studio tooling
  -> model.asdatabase plus matching deployment sidecars
  -> Publish-Cube
       -> Select-AnalysisServicesDeploymentExeVersion
            -> Get-AnalysisServicesDeploymentExePath, repeatedly
       -> validate selected utility and model path existence
       -> Update-AnalysisServicesConfig
            -> write deploymenttargets
            -> write deploymentoptions
            -> optionally update Multidimensional configsettings
       -> print deployment settings
       -> invoke utility with model path and /s:<log path>
       -> native exit-code check; display utility log on recognized failure
  -> optional Update-TabularCubeDataSource
  -> optional Invoke-ProcessTabularCubeDatabase
  -> callers/tests may query existence or data after deployment
```

In [Publish-Cube](../DeployCube/public/Publish-Cube.ps1#L140):

- The function first sets global `ErrorActionPreference` to `Stop`.
- Version selection accepts `22`, `21`, `20`, `16`, `15`, `14`, `13`, `12`, `11`, or `latest`. `latest` follows this descending utility-major priority; an unavailable preferred version falls back to the next available supported utility.
- It checks utility/model existence, reads the utility's `ProductVersion`, and takes its first two characters. It does not parse the model or compare its compatibility level with the target/server/tool.
- It updates files **in their original build directory**, then invokes the utility with the model path and `/s:<folder>\AnalysisServicesDeploymentExeLog.txt`.
- It deletes an existing shared log before invoking the process. Successful exit is the wrapper's success criterion; it performs no independent post-deployment model/data validation.

The native wrapper uses the call operator, **not** `Invoke-Expression` or `cmd /c`. Passing an argument array is a good starting point; shell injection through ordinary argument text is not established. Native argument serialization, utility-specific parsing, executable identity, and process-start errors still need focused tests.

### A3. Configuration and deployment semantics

[Update-AnalysisServicesConfig](../DeployCube/public/Update-AnalysisServicesConfig.ps1#L129) derives sidecar names from the model basename:

- `.deploymenttargets`: changes database/server and replaces the connection string with `Data Source=<server>;Timeout=0;`. With a user ID, it appends plaintext credentials, `Persist Security Info=True`, and impersonation settings.
- `.deploymentoptions`: writes processing, transaction, partition, role, configuration, optimization, and writeback options.
- `.configsettings`: when present, attempts to rewrite a Multidimensional data-source connection. That branch is defective; see F01.
- `.asdatabase`: despite its mention in the documentation's list, this function **does not rewrite the model file**.

Existing defaults should be preserved unless explicitly approved:

| Option | Default | Operational significance |
|---|---|---|
| Processing | `DoNotProcess` | Useful safety boundary: allows environment-specific connections to be fixed before processing. |
| Transactional deployment | `$false` | Metadata and processing are not guaranteed to succeed/roll back as one combined operation. |
| Partitions | `DeployPartitions` | Existing partition definitions/data arrangements may be replaced according to utility semantics. Incrementally managed production partitions need deliberate `RetainPartitions` selection. |
| Roles | `DeployRolesRetainMembers` | Retention is intended; regression tests must verify real utility semantics, not just the sidecar string. |
| Configuration/optimization | `Deploy` | Environment settings can be replaced rather than retained. |
| Writeback | `UseExisting` | Relevant to Multidimensional deployments, not Tabular refresh. |

There is no wrapper-level transaction spanning file writes, utility deployment, data-source updates, and subsequent processing. Repeat invocation is possible, but this does not establish idempotent preservation of partitions, roles, provider settings, or processed state.

### A4. Data-source updates, processing, and deletion

[Update-TabularCubeDataSource](../DeployCube/public/Update-TabularCubeDataSource.ps1#L157) discovers compatibility and `TMSCHEMA_DATA_SOURCES`. It optionally filters by data-source name but then updates **only the first matching/discovered row**.

- For compatibility level >=1400 and source type `2`, it builds a structured SQL/Power Query data source with connection address and credentials.
- Otherwise it builds a provider-style replacement using `Get-SqlConnectionString`, max connections, impersonation settings, and optional timeout.
- It submits a `createOrReplace` TMSL object using `ConvertTo-Json`, avoiding manual JSON quoting.
- Its `CommandTimeout` is a **source query timeout in minutes**, formatted as a duration for structured sources or seconds for provider sources. It is not a timeout for the deployment utility or for the overall SSAS operation.
- The replacement preserves selected fields, not an arbitrary complete source definition. Existing options/metadata require preservation tests.

[Invoke-ProcessTabularCubeDatabase](../DeployCube/public/Invoke-ProcessTabularCubeDatabase.ps1#L58) generates a TMSL refresh for `Full`, `Automatic`, `ClearValues`, or `Calculate`, defaulting to `Full`. It does not independently initialize `SqlServer`; command availability may depend on prior operations or autoload behavior. This is a Tabular/TMSL path; do not extend its promise to legacy Tabular XMLA processing or Multidimensional processing without implementation and certification.

[Get-SsasProcessingMessages](../DeployCube/public/Get-SsasProcessingMessages.ps1#L35) parses XML and throws on the first matching exception-description node. It is not used by all modifying operations.

[Unpublish-Cube](../DeployCube/public/Unpublish-Cube.ps1#L43) uses XMLA deletion, which is suitable in principle for both model types. Its current success detection only checks a namespace substring. Tests intentionally expect deleting a nonexistent database not to throw; preserve that behavior when tightening error detection.

### A5. Dependencies and build/release surfaces

| Dependency/surface | Evidence | Assessment |
|---|---|---|
| PowerShell | [Manifest](../DeployCube/DeployCube.psd1#L33) specifies minimum `5.0`; no edition declaration. | Syntax largely fits Windows PowerShell. Runtime compatibility is not certified by a manifest alone. |
| Deployment utility / SSMS | [Discovery](../DeployCube/public/Get-AnalysisServicesDeploymentExePath.ps1#L61) searches Windows Program Files/SSMS layouts and `CustomAsDwInstallLocation`. | Windows executable installed outside this module; version/path/signature not locked. |
| SqlServer module | [Get-ModuleByName](../DeployCube/public/Get-ModuleByName.ps1#L33); used explicitly by ping/compatibility functions. | Runtime install/import is unversioned. Manifest has no declared module dependency. Not every operation requires SqlServer, so adding unconditional `RequiredModules` would change import behavior. |
| AMO | [Get-ServerMode](../DeployCube/public/Get-ServerMode.ps1#L34), [Ping-SsasServer](../DeployCube/public/Ping-SsasServer.ps1#L39). | Uses deprecated `LoadWithPartialName` and environment-installed assemblies. Assembly source/runtime is not explicit. |
| OLE DB / SQLNCLI11 | [Get-SqlConnectionString](../DeployCube/public/Get-SqlConnectionString.ps1#L62), [1200 example](../examples/CubeAtCompatibility1200/Model.bim#L9). | Legacy provider remains part of existing model compatibility. Provider must be available on the processing SSAS host, not merely the CI agent. |
| Example build tools | [1200 project](../examples/CubeAtCompatibility1200/CubeAtCompatibility1200.smproj#L44), [SQL project](../examples/DatabaseToPublish/DatabaseToPublish.sqlproj#L57). | Traditional SSDT/VS targets, not a generic `dotnet build` solution. A .NET SDK alone does not establish these targets are available. |
| Tests | [RequiredModules](../test/RequiredModules.psd1#L1). | Pester `5.1.1` and PSScriptAnalyzer `1.19.1` pinned for bootstrap; runtime dependency/tools/infrastructure are not equivalently specified. |
| Help generation | [UpdateHelp.ps1](../UpdateHelp.ps1#L1). | Imports the module and installs unpinned PlatyPS through the same runtime helper; working-directory dependent; writes Markdown and external help. |
| Gallery publishing | [PublishToPSGallery.ps1](../PublishToPSGallery.ps1#L15). | Interactive local path plus a distinct remote automated release path; local script uses private PowerShellGet internals. |
| Azure DevOps | [README](../README.md#L2), [extension reference](../README.md#L103). | Build badge and marketplace integration are documented, but pipeline/extension implementation and live configuration are outside this checkout. No claims about their secret storage, approvals, or current health are justified. |

The [MIT license](../LICENSE) is present at repository and module level with identical content. The binary test fixture's redistribution rights and provenance are separate questions; the module's MIT license does not establish rights over Microsoft binaries.

## B. Findings

Priorities: **P0** critical functional/security defects; **P1** high-impact reliability/maintenance; **P2** modernization/code quality; **P3** optional capabilities. Effort includes a focused regression test and directly related help, not a broad rewrite.

### B1. Prioritized findings table

| Priority | Category | Finding | File / Function | Impact | Recommended Improvement | Effort |
|---|---|---|---|---|---|---|
| P0 | Functional correctness | **F01 Confirmed:** Multidimensional sidecar handling calls absent `Get-SsasSourceConnectionString` and uses undeclared `$DatabaseName`. | [Update-AnalysisServicesConfig, line 183](../DeployCube/public/Update-AnalysisServicesConfig.ps1#L183) | A model with `.configsettings` reaches a command-not-found path in a normal module-only session, after earlier sidecars have already been written. Advertised Multidimensional support is incomplete. | First characterize one/multiple source sidecars. Replace the dangling call with a properly defined implementation based on existing helpers and intended configuration semantics; do not guess a new source database from the SSAS target name. | Medium |
| P1 | Credential security | **F02 Confirmed exposure:** authenticated deployment writes plaintext password into the original target sidecar, with `Persist Security Info=True`; no cleanup. | [Update-AnalysisServicesConfig, lines 140-147](../DeployCube/public/Update-AnalysisServicesConfig.ps1#L140); [Publish-Cube call, line 163](../DeployCube/public/Publish-Cube.ps1#L163) | Build artifacts, backups, shared workspaces, or overly broad artifact uploads can expose deployment credentials. No compromise is demonstrated. | Add an additive credential parameter set, validate credential pairs, stage a private per-run artifact bundle, restrict access, redact logs, and clean up in `finally`. Explain that credentials may still need transient plaintext serialization for this utility. | Medium |
| P1 | Error handling | **F03 Confirmed:** `Publish-Cube` permanently changes global `ErrorActionPreference`; catches stringify/reissue errors. | [Publish-Cube, lines 140 and 199-208](../DeployCube/public/Publish-Cube.ps1#L140) | Caller/test behavior changes after invocation, even on failure. Explicit `-ErrorAction` and existing local preferences can affect the catch's behavior; removing the global setting alone could weaken failure propagation. | Use operation-local terminating errors and preserve/rethrow the original error record. Add caller-preference preservation tests before changing the global assignment. | Small |
| P1 | Diagnostics | **F04 Confirmed:** native failure catch reads a presumed log without checking existence/readability; `$err` is undeclared in processing catch; other catches replace useful causes with “server not found.” | [Publish-Cube, line 202](../DeployCube/public/Publish-Cube.ps1#L202); [processing, line 80](../DeployCube/public/Invoke-ProcessTabularCubeDatabase.ps1#L80); [compatibility catch](../DeployCube/public/Get-CubeDatabaseCompatibilityLevel.ps1#L79); [mode catch](../DeployCube/public/Get-ServerMode.ps1#L43) | Missing logs can mask failures; authentication, assembly-load, malformed-response, or processing errors lose actionable detail. `$Error` may include unrelated earlier errors. | Preserve `$_`, add stage/target context without secret values, and make optional log retrieval subordinate to the original error. | Small |
| P1 | Native process reliability | **F05 Confirmed gap / risk:** exit codes are checked, but command-not-found/start failures, timeout, stderr context, and quoted/complex native arguments lack tests; global `LASTEXITCODE` is reset. | [Invoke-ExternalCommand, lines 42-53](../DeployCube/public/Invoke-ExternalCommand.ps1#L42) | A non-terminating process-start error can evade the exit-code-only check when called standalone; hung utility has no wrapper deadline; failure reports omit exit code. | Test a benign executable across supported shells. Resolve/validate an executable, distinguish launch failure from exit failure, capture exit code immediately, and add an optional bounded process timeout. Preserve the argument-array contract. | Medium |
| P1 | Repeatability / artifacts | **F06 Confirmed:** sidecars are saved sequentially in place, and every deployment in a folder shares a fixed log name. | [Config saves, lines 147-184](../DeployCube/public/Update-AnalysisServicesConfig.ps1#L147); [Publish-Cube, lines 188-197](../DeployCube/public/Publish-Cube.ps1#L188) | Missing/invalid later sidecars leave earlier files modified. Concurrent runs can overwrite targets/options, delete another run's log, or deploy to an unintended configured target. Concurrent misdeployment is a risk, not a reproduced event. | Preflight all required sidecars and XML before writing; stage the complete model/sidecar bundle with unique log identity. Test failures and concurrent isolation. Preserve the explicitly in-place public updater unless a new mode is approved. | Medium |
| P1 | SSAS result correctness | **F07 Confirmed:** deletion accepts a namespace substring; data-source replacement checks only the first expected root and treats absent error-description text as success. | [Unpublish-Cube, line 50](../DeployCube/public/Unpublish-Cube.ps1#L50); [Update-TabularCubeDataSource, lines 302-319](../DeployCube/public/Update-TabularCubeDataSource.ps1#L302) | A response can contain an error while retaining the “empty” namespace; an unexpected but well-formed XML document can take the success path in non-strict sessions. | Share a namespace-aware XMLA result validator that rejects malformed/missing expected envelopes and enumerates errors/warnings. Keep valid empty success and missing-database deletion semantics. | Medium |
| P1 | Data-source preservation | **F08 Confirmed behavior / risk:** source selection uses `$rows[0]`; `createOrReplace` reconstructs selected fields and does not retain existing `options` when timeout is omitted. | [Update-TabularCubeDataSource, lines 175-245](../DeployCube/public/Update-TabularCubeDataSource.ps1#L175); [replacement, line 279](../DeployCube/public/Update-TabularCubeDataSource.ps1#L279) | An omitted source name selects the first source, not all sources. Replacement may reset existing options/annotations/provider-specific metadata. Exact server effects require integration tests. | Characterize preservation first; preserve supported existing fields, clearly document first-source behavior, and optionally offer strict named selection rather than silently changing multi-source semantics. | Medium |
| P1 | Automated testing | **F09 Confirmed:** unit-like and destructive integration tests are mixed under `Round1`-`Round4`; many rely on live localhost SSAS, utility 15, and missing generated `bin` artifacts. | [RunSpecificTests](../test/RunSpecificTests.ps1#L3); [discovery expectations](../test/Get-AnalysisServicesDeploymentExePath.Tests.ps1#L27); [Publish-Cube fixture paths](../test/Publish-Cube.Tests.ps1#L6) | New contributors and hosted runners cannot obtain a deterministic unit gate from these tags. Parameter tests can pass for unrelated prerequisite failures. | Split/retag `Unit`, `Integration`, and `Azure`; use `TestDrive` XML/JSON fixtures and complete dependency mocks; make integration targets opt-in and explicit. | Medium |
| P1 | CI/release reliability | **F10 Confirmed remote configuration / risk:** tag release runs the entire suite in `pwsh` on `windows-latest`, installs only Pester, and has no visible SSAS/SSDT/SqlServer/analyzer provisioning. | [Remote release workflow, lines 19-37](https://github.com/DrJohnT/DeployCube/blob/8becb836cdec7ff998416399aea747e3e0448e8c/.github/workflows/release.yml#L19) | A reliable green gate is not supported by visible setup. Azure tests require secrets/endpoints not supplied there. Installing Pester does not install these other prerequisites. No failed run is claimed. | Establish Windows PowerShell 5.1 unit/analyzer CI on pull requests; run gated integration separately; release only from validated packages/tags. Add a PowerShell 7 compatibility leg only after its dependency surface is proven. | Medium |
| P1 | Dependency reliability/security | **F11 Confirmed:** runtime helper installs/imports unversioned modules with `-Force -AllowClobber -SkipPublisherCheck`; failures use non-terminating `Write-Error` by default. | [Get-ModuleByName, lines 33-47](../DeployCube/public/Get-ModuleByName.ps1#L33); [bootstrap trust change](../test/bootstrap.ps1#L8) | Deployment can mutate a user's machine or select an untested dependency version; offline jobs fail late. This is not evidence of a malicious dependency. | Provision tested versions outside deployment, verify required commands, and fail explicitly. Keep current auto-install behavior available during transition; provide an explicit no-install/CI path. Remove bypasses where unnecessary and scope bootstrap trust changes carefully. | Medium |
| P1 | Deployment validation | **F12 Confirmed gap:** preflight checks path existence, not file kind/extension, model validity, sidecar schemas, target mode/compatibility, or write access before mutation. | [Publish-Cube, lines 145-163](../DeployCube/public/Publish-Cube.ps1#L145); [config updater](../DeployCube/public/Update-AnalysisServicesConfig.ps1#L129) | Incompatible targets, directories supplied as files, or malformed inputs fail late. A successful native exit alone is not proof that desired model/data is usable. | Add offline bundle validation first, then opt-in/auth-compatible online mode/compatibility checks and post-deployment checks. Do not impose `Ping-SsasServer` on AAS. | Medium |
| P2 | Request construction/security | **F13 Confirmed:** database names are interpolated directly into XML; deployment connection strings are concatenated. | [Unpublish-Cube, line 43](../DeployCube/public/Unpublish-Cube.ps1#L43); [data-source discover, line 161](../DeployCube/public/Update-TabularCubeDataSource.ps1#L161); [deployment connection, line 140](../DeployCube/public/Update-AnalysisServicesConfig.ps1#L140) | XML metacharacters break otherwise valid identifiers; connection-string delimiters/quotes can alter parsing of server or credential values. Exploitable command injection is not demonstrated. | Use XML construction/escaping and an appropriate connection-string builder; test `&`, `<`, quotes, semicolons, and Unicode. JSON generation already uses object serialization. | Small |
| P2 | Data-source authentication | **F14 Confirmed:** required account/password checks cover `ImpersonateAccount` only; `UsernamePassword` reaches structured creation with missing values and is accepted for provider sources without a dedicated valid mapping. | [Update-TabularCubeDataSource, lines 105-112](../DeployCube/public/Update-TabularCubeDataSource.ps1#L105); [authentication branches](../DeployCube/public/Update-TabularCubeDataSource.ps1#L197) | Invalid credentials/mode combinations fail late at SSAS or create invalid requests. | Validate credentials for both credential-bearing modes and reject unsupported source-kind/mode combinations before replacement; preserve documented aliases. | Small |
| P2 | Metadata correctness | **F15 Confirmed:** `"${rows[0].description}"` references a braced variable name rather than evaluating the row's description property. | [Update-TabularCubeDataSource, line 183](../DeployCube/public/Update-TabularCubeDataSource.ps1#L183) | A structured replacement can lose the existing description in a normal session. | Read the property directly and assert preservation in serialized TMSL. | Small |
| P2 | Timeout correctness | **F16 Confirmed edge:** small positive fractional minutes can truncate to zero seconds, producing `P` for structured timeout and `0` for provider timeout. | [Update-TabularCubeDataSource, lines 118-149](../DeployCube/public/Update-TabularCubeDataSource.ps1#L118) | Accepted positive input need not yield a meaningful positive timeout; exact SSAS rejection/default behavior is untested. | Define minimum representable resolution and rounding; use a tested duration formatter. Retain the existing minutes unit and test boundary values. | Small |
| P2 | Discovery / reuse | **F17 Confirmed:** two discovery implementations search different depths (`Common7` versus `Common7\IDE`); selection repeats full scans; versions use a two-character substring and first-match selection. | [Find locations, lines 32-51](../DeployCube/public/Find-AnalysisServicesDeploymentExeLocations.ps1#L32); [Get path, lines 61-83](../DeployCube/public/Get-AnalysisServicesDeploymentExePath.ps1#L61); [selection](../DeployCube/public/Select-AnalysisServicesDeploymentExeVersion.ps1#L54) | Discovery can list a utility that resolution cannot find; missing/short version metadata can error; selection among identical major versions is not explicit. Future layouts/versions need updates. | Extract one private inventory helper returning path/full version; parse versions defensively; define deterministic ordering and retain public formatted/string contracts. Preserve existing fallback unless strict selection is explicitly requested. | Medium |
| P2 | PowerShell compatibility | **F18 Confirmed constraint:** module minimum is 5.0; AMO loading is partial-name based; OLE DB/utility/provider dependencies are Windows-centric; no tested edition/version matrix. | [Manifest, line 33](../DeployCube/DeployCube.psd1#L33); [AMO](../DeployCube/public/Get-ServerMode.ps1#L34); [OLE DB](../DeployCube/public/Get-SqlConnectionString.ps1#L62) | PowerShell 7 support, especially cross-platform deployment, cannot be inferred from syntax or an installed SqlServer module. Current SqlServer guidance requires >=5.1. | Certify 5.1 first; explicitly resolve compatible AMO dependencies; perform per-function Windows PS7 validation. Document Linux limitations instead of promising parity. Raising the manifest floor requires a deliberate compatibility decision. | Medium |
| P2 | Provider compatibility | **F19 Confirmed dependency / risk:** Azure branch hard-codes SQLNCLI11 and discards the existing connection string; on-prem branch ignores supplied SQL credential parameters. | [Get-SqlConnectionString, lines 59-81](../DeployCube/public/Get-SqlConnectionString.ps1#L59) | Hosts without SNAC cannot process legacy provider sources; Azure-specific settings can be lost; credential expectations differ by host-name branch. | Document/certify existing semantics, preserve provider/options where possible, and make any provider migration or authentication change explicit and tested on the SSAS processing host. | Medium |
| P2 | Connection lifecycle | **F20 Confirmed:** direct AMO connections disconnect only on the normal path; ping catches all errors as `false`. | [Get-ServerMode, lines 34-44](../DeployCube/public/Get-ServerMode.ps1#L34); [Ping-SsasServer, lines 38-50](../DeployCube/public/Ping-SsasServer.ps1#L38) | Failure paths can retain resources; dependency/authentication faults are indistinguishable from absence. Returning `false` is nevertheless an existing ping contract. | Disconnect/dispose safely in `finally`; retain ping boolean behavior with useful verbose diagnostics and offer a strict diagnostic/preflight path separately. | Small |
| P2 | Error stream / code reuse | **F21 Confirmed:** database ping/compatibility duplicate XMLA discovery and merge error stream into success output before XML parsing. | [Ping-SsasDatabase, lines 47-68](../DeployCube/public/Ping-SsasDatabase.ps1#L47); [compatibility, lines 48-76](../DeployCube/public/Get-CubeDatabaseCompatibilityLevel.ps1#L48) | Error records mixed with XML can become parse failures and obscure the actual connection problem. Duplicated namespace logic drifts. | Share a private discover/response helper with operation-local terminating errors, preserving ping/database-missing semantics separately from transport faults. | Medium |
| P2 | Public output contracts | **F22 Confirmed:** status is written to success output; data-source tests select result index `[1]` despite declared boolean output. | [Get-ModuleByName, line 36](../DeployCube/public/Get-ModuleByName.ps1#L36); [processing, line 60](../DeployCube/public/Invoke-ProcessTabularCubeDatabase.ps1#L60); [data-source tests, line 115](../test/Update-TabularCubeDataSource.Tests.ps1#L115) | Return cardinality depends on prior module/environment state. `[1]` is not a reliable correctness assertion. Existing scripts may depend on current status strings. | Characterize output shapes; route new diagnostics to information/verbose streams; introduce optional `PassThru` structured results rather than abruptly changing every legacy stream. Assert exact result shape in tests. | Medium |
| P2 | Test fidelity | **F23 Confirmed:** invalid-processing test uses stray `$ProcessingOption` instead of the named parameter; rollback test uses uninitialized `$InvalidDataSourceConnection`; credential guard tests also pass null mandatory source server; timeout metadata key contains a newline. | [Publish-Cube tests, line 97](../test/Publish-Cube.Tests.ps1#L97); [integration rollback, line 105](../test/DeployCubeIntegration.Tests.ps1#L105); [source tests, lines 35-72](../test/Update-TabularCubeDataSource.Tests.ps1#L35) | “Should throw” can pass before exercising the intended behavior. The rollback test does not establish transactional rollback. | Correct fixtures/arguments and assert the specific error identity and mock invocation/absence; use valid unrelated inputs when testing one validation rule. | Small |
| P2 | Test isolation | **F24 Confirmed:** discovery tests clear/change a caller environment variable without restoring its original value; shared artifacts and fixed database names are used; processing test lacks cube cleanup. | [Find tests, lines 6-33](../test/Find-AnalysisServicesDeploymentExeLocations.Tests.ps1#L6); [integration names](../test/DeployCubeIntegration.Tests.ps1#L24); [Process-Cube test](../test/Process-Cube.Tests.ps1#L14) | Tests depend on order and can leave modified files, environment state, or databases. Failed assertions may bypass cleanup in other tests. | Snapshot/restore environment in `AfterAll`, isolate filesystem state with `TestDrive`, use owned unique databases, and clean up in `finally`/test teardown. | Medium |
| P2 | Analyzer / coverage | **F25 Confirmed:** analyzer excludes plaintext-password and ShouldProcess rules globally; runners cover only a few discovery scripts and map one discovery test to a different source. | [Analyzer exclusions, line 11](../test/AnalyzePSScripts.Tests.ps1#L11); [coverage runner, lines 5-7](../test/RunPesterCodeCoverage.ps1#L5) | Safety debt is hidden and coverage is not a module-wide signal. Dynamic analyzer test creation also needs verification against pinned Pester 5 discovery/run lifecycles. | Use documented targeted suppressions/baselines; validate Pester 5 lifecycle; use a single configured coverage run over public/private implementation and explicit critical-branch tests. | Medium |
| P2 | Coverage evidence | **F26 Confirmed:** root coverage file is empty; test coverage is a 27 December 2020 report for one selection function (12 covered of 16 measured lines). | [Root coverage](../coverage.xml); [test coverage](../test/coverage.xml) | Historical 75% measured line coverage for one old function cannot establish current overall quality. | Generate coverage as CI artifacts with revision/tool metadata, not as a presumed up-to-date checked-in metric. Remove tracked stale reports only in an approved cleanup change. | Small |
| P2 | Local publishing | **F27 Confirmed:** gallery script prompts with `Read-Host`, calls help generation using a relative path, and invokes internal `Install-NuGetClientBinaries` through imported PowerShellGet. | [PublishToPSGallery, lines 20-29](../PublishToPSGallery.ps1#L20); [UpdateHelp](../UpdateHelp.ps1#L1) | Noninteractive use can block; execution from another directory fails; internal API changes can break releases. Help generation mutates sources while publishing. | Keep interactive convenience, add a supported noninteractive path, anchor paths to `PSScriptRoot`, pin tool versions, and publish a prevalidated staged package through supported commands. | Medium |
| P2 | Release supply chain | **F28 Confirmed remote choices / risk:** release grants workflow-wide contents-write permission, uses major action tags, unpinned Pester minimum, and publishes directly with a Gallery API key; no environment gate is declared. | [Remote release, lines 8-49](https://github.com/DrJohnT/DeployCube/blob/8becb836cdec7ff998416399aea747e3e0448e8c/.github/workflows/release.yml#L8) | Release inputs/tooling are not fully reproducible; privilege and publishing credentials are available to the release job. Repository-side protections might exist outside YAML and were not inspected. | Pin reviewed actions/tools, minimize permission scope, use protected tags/environment approval and narrowly scoped secrets, set explicit failure policy for native commands, and validate staged package contents before publish. | Medium |
| P2 | Documentation | **F29 Confirmed:** README calls required `CubeDatabase` optional/omits it, advertises `ProcessFull`/`ProcessDefault` instead of `Full`/`Default`, and overstates universal UserID/Password availability. Generated source-update help omits `CommandTimeout`. | [README, lines 47-77](../README.md#L47); [source-update syntax](./Update-TabularCubeDataSource.md#L15); [external help](../DeployCube/en-US/DeployCube-help.xml) | Copy/paste examples prompt/fail; users cannot discover supported timeout functionality or correct credentials. | Fix README examples without changing API; regenerate complete help using pinned tooling; document authentication per operation and mode/version prerequisites. | Small |
| P2 | Documentation / metadata | **F30 Confirmed:** generated help contains credential placeholders; manifest release notes point at 1.2.0 while local version is 1.2.6; command table has broken/incorrect links and example text points to an absent shipped DACPAC. | [Config help, line 225](./Update-AnalysisServicesConfig.md#L225); [connection help, line 96](./Get-SqlConnectionString.md#L96); [manifest, line 86](../DeployCube/DeployCube.psd1#L86); [README, lines 89-106](../README.md#L89) | Documentation/release metadata is not synchronized; onboarding relies on unexplained builds. | Fill source help, correct links/version metadata, and document the actual SSDT build/setup path rather than claiming generated artifacts are included. | Small |
| P2 | Example deployment safety | **F31 Confirmed example settings / risk:** sample profiles use `Encrypt=False`, some allow data loss/new database recreation, and postdeploy truncates the seed table. Structured sample keeps `EncryptConnection=false`. | [CI profile, lines 6-8](../examples/DatabaseToPublish/DatabaseToPublish.CI.publish.xml#L6); [Azure SQL profile, line 6](../examples/DatabaseToPublishToAzureSqlDB/DatabaseToPublishToAzure.Upgrade.publish.xml#L6); [seed script, line 3](../examples/DatabaseToPublish/Scripts/Post-Deploy/PostDeploy.sql#L3); [1500 model, line 22](../examples/CubeAtCompatibility1500/Model.bim#L22) | Unsafe if copied to production. These are example SQL/SSDT settings, not proof that DeployCube disables encryption globally or that a connection negotiated no encryption. | Clearly label disposable test-only profiles, parameterize machine/account identifiers, and provide safe production guidance with certificate/encryption checks. Do not silently change legacy processing encryption behavior. | Small |
| P2 | Test binary provenance | **F32 Confirmed artifact / open risk:** repository explicitly tracks a Windows Analysis Services-named PE/.NET binary as a discovery fixture without adjacent provenance/build documentation. | [Fixture folder](../examples/ForTests/DeploymentWizard/); [ignore exception, line 14](../.gitignore#L14); [discovery fixture test](../test/Get-AnalysisServicesDeploymentExePath.Tests.ps1#L77) | Authenticity/redistribution/update ownership is unclear; no malware or license violation is established. | Mock version/path metadata for unit tests; document fixture origin/hash/license if retained. Do not execute or treat this binary as a real deployment utility based on filename alone. | Small |
| P3 | Safe operation UX | **F33 Idea grounded in current API:** modifying/deleting functions have no `SupportsShouldProcess`; pipeline input and structured deployment results are absent. | [Publish-Cube declaration](../DeployCube/public/Publish-Cube.ps1#L88); [Unpublish-Cube declaration](../DeployCube/public/Unpublish-Cube.ps1#L28) | No wrapper `WhatIf`/`Confirm` planning surface; batch automation must build its own orchestration. | Add opt-in plan/`WhatIf` semantics after side effects are separated, with explicit confirmation-impact compatibility review. Add pipeline binding only if requested and tested. | Medium |

### B2. Security interpretation and boundaries

The important security boundary is **trusted artifacts + trusted executable + privileged deployment identity**. The module does not provide a sandbox for model files or arbitrary commands.

- **Credential persistence is established, credential theft is not.** Plaintext string parameters can also enter shell history/transcripts if callers embed literals. The code does not explicitly print the deployment password in its normal setting summary; it prints user ID. Unfiltered utility logs are displayed on errors, so their content needs redaction assessment. Do not assume pipeline secret masking protects files or transformed connection strings.
- **PSCredential is an additive usability/safety improvement, not encrypted utility input.** SSAS/data-source APIs may need a plaintext credential at the final serialization boundary. The objective is short lifetime, private storage, controlled logs, and no artifact retention, not an impossible promise to eliminate all plaintext from memory.
- **No shell-evaluation vulnerability was identified.** Native execution uses `& $Command $Arguments`. The exported helper intentionally executes the command chosen by its caller. Validate executable identity at the deployment boundary and characterize Windows argument handling rather than replacing the call operator with string evaluation.
- **XML and connection-string escaping need fixes.** Their construction defects are confirmed; unauthorized server-side operations through crafted values were not tested. Untrusted input must not be accepted as a production deployment specification merely because PowerShell parameter validation passed.
- **Dependency bypasses are risks, not proof of compromise.** `SkipPublisherCheck`, automatic installation, and custom recursive executable discovery reduce reproducibility/trust controls. Start with trusted, preprovisioned tools and an optional strict executable policy; avoid suddenly rejecting legitimate unsigned/custom installations.
- **No active secret was verified.** The tests contain literal fixture passwords, and profiles contain specific machine/account identifiers. Their validity was not tested. Do not call these “leaked production credentials” without evidence; replace with obviously synthetic fixture values and perform approved secret scanning later.
- **No CVE claim is made.** Installed SqlServer, AMO, provider, SSMS, and utility versions are unknown; the binary fixture was not authenticated. Inventory those exact versions before associating advisories with this module.

### B3. Testing assessment and proposed regression coverage

The existing suite has useful strengths: validation checks, negative paths, aliases, GUID-based deployment checks in some cases, end-to-end 1200/1500 model workflows, and an AAS scenario. Preserve those scenarios while repairing their isolation and assertions.

Missing or insufficiently isolated tests include:

| Surface | Required focused regression cases |
|---|---|
| Module import/API | Exact exports/aliases, repeat import, import failure, supported manifest minimum, no network installation during pure API tests. |
| Publish orchestration | Mock tool selection, inventory, filesystem/version data, configuration mutation, and process execution; verify exact arguments/options, call order, no invocation after preflight failure, and preserved caller preference. |
| Native helper | Native success/nonzero code, missing/not-executable command, stdout/stderr, empty/quoted arguments, spaces/Unicode in paths, optional deadline, no stale exit-code success. A benign executable fixture is needed; do not use the committed deployment-named fixture for this. |
| Config updater | Complete `TestDrive` model/sidecar bundles, every option's exact XML value, credential delimiters, missing/invalid/read-only later files, missing optional Multidimensional sidecar, and one/multiple Multidimensional sources. |
| XMLA response helper | Valid success, multiple errors, error-with-empty-namespace, unexpected envelope, empty response, malformed XML, namespace variations, and missing-database delete behavior. |
| Tabular source updates | Provider 1200 and structured 1400/1500 source types; named/omitted/missing source; multiple rows; preserve description/options/metadata; mode/source compatibility; missing credentials; exact JSON; timeout null/positive/tiny fraction/day boundary. |
| Processing and discovery | Specific transport/auth/server errors; all refresh types; missing dependency; compatibility parsing; first/error/warning responses; deterministic utility selection and existing fallback semantics. |
| Output behavior | Assert a single intended boolean/integer/string where promised. Never accept `[1]` as a substitute for verifying output cardinality. |

Recommended layers:

1. **Pure unit/API tests:** No live SSAS, no package installation, no real deployment utility. Run on Windows PowerShell 5.1; subsequently qualify on Windows PS7. Pure XML/JSON/path logic may be testable on Linux, but OLE DB/provider behavior is a separate Windows surface.
2. **Windows dependency tests:** Benign native argument tests, known SSMS utility inventory, actual compatible SqlServer imports, AMO resolution, and provider availability. Record versions; avoid machine-specific “exactly one installation” assertions.
3. **Isolated SSAS integration:** Explicit test targets and owned database prefixes, prebuilt/validated examples, SQL seed setup, cleanup even on failure, metadata/data assertions, redeployment, partition/role retention, and transactional versus nontransactional processing failure. Add a real Multidimensional fixture, including writeback/config settings where supported.
4. **AAS integration:** Explicit opt-in, protected credentials, unique test database ownership, noninteractive authentication validated against the chosen client/utility versions, and no production target.

For a fixed unit command, configure Pester 5 with an explicit path/tag selection, `Run.Exit`/CI failure behavior, result XML, and coverage source paths. Validate that runner against the chosen Pester version rather than copying older `-Script` compatibility examples blindly. Set coverage thresholds only after collecting a real baseline; initially make the critical success/failure branches above mandatory rather than inventing a percentage.

### B4. CI/CD and release assessment

The remote [Release workflow](https://github.com/DrJohnT/DeployCube/blob/8becb836cdec7ff998416399aea747e3e0448e8c/.github/workflows/release.yml) has useful controls: `v*` tag triggering, tag/manifest version matching, `Test-ModuleManifest`, test-before-publish ordering, environment-based Gallery key injection, and verified-tag GitHub release creation. These should be retained.

Visible gaps are concrete:

- Only release tags trigger it; there is no visible pull-request/push unit CI workflow in the API inventory.
- `windows-latest` and `pwsh` do not establish compatibility with Windows PowerShell 5.1 or the existing AMO/SSAS dependency chain.
- Installing Pester with `MinimumVersion 5.0.0` differs from the local bootstrap's exact version. Analyzer and live infrastructure are not provisioned.
- `Invoke-Pester -Path ./test -CI` selects the Azure and destructive localhost tests too.
- No visible lint/security-scan step, coverage artifact, generated-help drift check, package-content check, or protected environment is declared.
- Help regeneration is part of the local publishing script but not the remote release workflow.
- GitHub release creation invokes native `gh`; make nonzero native exit handling explicit rather than relying on runner/wrapper defaults.

Incremental target design:

1. PR CI runs manifest/import/API, isolated Pester unit tests, and PSScriptAnalyzer on Windows PowerShell 5.1 with exact tested tools. A separate experimental Windows PS7 leg reports per-function compatibility.
2. Integration is manual/scheduled or approved after unit CI, on a dedicated Windows agent with specified SSAS/SQL/SSDT prerequisites. Never expose privileged deployment secrets to untrusted pull-request code.
3. Build help/package once, validate exports/version/license/package contents, retain a versioned checksum, and publish that same staged package.
4. Release on protected version tags, match manifest/tag, use least job permissions and approved environment secrets, and fail explicitly on each publishing/native operation.
5. Do not auto-bump/release dependency updates. Regular dependency-update pull requests should run the compatibility matrix and document driver/client changes.

**Azure DevOps:** retain the existing marketplace-facing/public API. First recover or document the actual pipeline/extension source and hosted agent requirements. Then reuse the same PowerShell test/package commands in an Azure Pipeline, publish Pester results/coverage, use protected service connections or secret variables, explicit Windows shell choice, target ownership checks, and environment approvals. These are proposed capabilities; the external badge/extension alone does not prove which controls currently exist.

## C. Top 10 Recommended Improvements

Ranked by impact, risk reduction, effort, compatibility implications, and maintenance leverage.

| Rank | Improvement | Why it ranks here | Effort / compatibility |
|---|---|---|---|
| 1 | Repair and test Multidimensional `.configsettings` handling (F01). | Restores an advertised path that is broken by an absent command; prevents partial sidecar writes from a known defect. | Medium. Preserve target/source distinction and existing updater parameters. |
| 2 | Isolate deployment artifacts and minimize persisted credentials (F02, F06). | Reduces privileged credential retention and cross-run target/log contamination together. | Medium. Keep legacy credential parameters and explicitly in-place updater behavior; stage within the publish workflow. |
| 3 | Make failures terminating locally and preserve original diagnostics (F03, F04, F21). | Stops global side effects and makes CI failures actionable without accidental silent success. | Small to Medium. Characterize common-parameter/error behavior and preserve ping contracts. |
| 4 | Harden native execution and utility failure reporting (F05). | Reliably separates launch, exit, and timeout failure; enables safe Windows/PS7 certification. | Medium. Preserve `Command`, `Arguments`, and boolean `PipeOutNull`; do not blindly change argument escaping. |
| 5 | Centralize XMLA response validation and safe request construction (F07, F13). | Prevents false success and malformed identifier/credential requests across processing, deletion, and source updates. | Medium. Preserve valid success and nonexistent-delete behavior; no XMLA/TMSL rewrite needed. |
| 6 | Preserve data-source state and validate authentication/timeouts (F08, F14-F16, F19). | Reduces silent metadata/options loss and late SSAS failures across 1200 and structured sources. | Medium. Keep minutes units, aliases, and first-source compatibility; provider changes require opt-in. |
| 7 | Build a deterministic Pester unit suite and isolate integration (F09, F23-F26). | Supplies the safety net for every later change and enables contributors without SSAS. | Medium. Retain end-to-end scenarios but correct misleading assertions and teardown. |
| 8 | Establish 5.1-first CI and repair the release gate (F10, F27, F28). | Prevents releasing changes validated only by an inadequately provisioned PS7 hosted run. | Medium. Reuse supported commands and staged packages; do not require cloud infrastructure for PR unit tests. |
| 9 | Unify discovery and explicitly provision/certify dependencies (F11, F12, F17-F20). | Makes agent setup, version fallback, AMO loading, offline use, and modern SSMS support predictable. | Medium. Keep current fallback and custom locations; strict version selection is additive. |
| 10 | Correct help, publish onboarding, and document a tested compatibility matrix (F29-F32). | Eliminates immediate copy/paste failures and establishes maintainable support expectations. | Small to Medium. Documentation fixes are nonbreaking; no unverified PS7/SSAS promise. |

Dependencies matter: add regression tests alongside each stabilization fix, then consolidate the unit gate. Do not delay F01-F04 behind a comprehensive test-suite rewrite.

## D. Quick Wins

These can be separate, reviewable changes after approval:

- Correct README examples to include mandatory `CubeDatabase`; use `Full`/`Default`; describe per-operation credentials and the actual built-artifact prerequisites (F29).
- Replace `$err` with preserved processing error context; guard missing utility-log reads while keeping the original exception primary (F04).
- Correct the description property expression and add a serialized-payload assertion (F15).
- Correct the stray processing parameter, uninitialized rollback fixture, newline-bearing metadata key, and credential tests' unrelated invalid inputs (F23). A corrected rollback assertion still needs isolated SSAS.
- Restore `CustomAsDwInstallLocation` after discovery tests and ensure owned processing-test databases are cleaned up (F24).
- Anchor local help/publishing paths to `PSScriptRoot` without otherwise changing release behavior (part of F27).
- Fill credential help placeholders, expose `CommandTimeout` in generated help, synchronize release-note metadata, and fix the README command links (F29-F30).
- Clearly mark destructive/unencrypted example profiles and SQL seed scripts as disposable-test-only (F31).

**Not quick wins:** a blanket PowerShell 7 declaration, replacing SQLNCLI11 everywhere, changing deployment defaults, adding unconditional SqlServer manifest imports, rewriting all output streams, or changing first-source selection. Each needs compatibility evidence and behavior tests.

## E. Modernization Roadmap

### 1. Stabilization and security

Deliver as focused changes, with tests beside each fix:

1. **Multidimensional correctness:** define intended source-connection behavior; add XML fixtures for one/multiple sources; remove the dangling call; preflight relevant sidecars.
2. **Failure semantics:** local terminating errors, preserved caller preference and error identity, robust optional-log diagnostics, native start/exit tests.
3. **Credential/artifact lifecycle:** additive credential binding, pair validation, private per-run bundle/log, cleanup on success/failure, secret-safe diagnostics and artifact policy.
4. **XMLA correctness:** shared response parsing, safe XML/connection construction, explicit malformed/unexpected response failure, preserved absent-database delete semantics.

**Exit criteria:** F01 is covered without relying on caller-defined commands; caller preferences are unchanged; no original build sidecar acquires new deployment credentials through staged publishing; stage failures cannot launch the utility; all critical error/success response fixtures behave deterministically.

Deleting a local staging directory or timing out the utility is **not** server rollback. Diagnostics must state the last completed stage and whether the server may already have changed.

### 2. Code quality and automated testing

1. Retag/separate unit, Windows dependency, SSAS integration, and Azure integration; replace generated-output dependencies in unit tests with small `TestDrive` fixtures.
2. Repair false-positive assertions, machine-specific version/count expectations, and environment/database teardown.
3. Extract only the repeated seams: executable inventory, SSAS discover/response parsing, and tested source/timeout construction. Keep public wrappers and signatures intact.
4. Add dependency versions/setup documentation and no-install CI operation.
5. Establish analyzer baseline/targeted suppressions, current coverage artifacts, PR unit CI, and a prevalidated package release gate.

**Exit criteria:** a clean Windows PowerShell 5.1 host can run unit/API/analyzer checks without SSAS or network mutation during tests; critical failure branches are tested; integration cannot run accidentally; release validates and publishes the same package.

### 3. Modernization and developer experience

1. Unify utility inventory and deterministic version selection; test current/custom SSMS layouts and preserve fallback.
2. Resolve AMO from an explicit tested dependency source and clean up connections reliably; do not rely on GAC partial-name loading for PS7.
3. Validate Windows PowerShell 7 function-by-function with the exact chosen SqlServer, AMO, utility, and OLE DB versions. Keep the 5.1 gate.
4. Fix/automate help, publish a supported matrix and local development/test recipe, and record prerequisites on both deployment agents and processing servers.
5. Offer additive structured `PassThru` diagnostics and strict/offline preflight modes once legacy output/installation behaviors are characterized.

**Exit criteria:** support claims correspond to recorded test combinations; source-update help matches code; offline agent setup is reproducible; no public export/default is removed silently.

### 4. Optional future capabilities

- Deployment planning and `WhatIf`/confirmation semantics; utility `/o` output scripting can support a reviewable plan without replacing its deployment engine.
- Opt-in strict utility selection or explicit executable path for controlled agents.
- Explicit multi-source batch updates and partition/table-level processing, only if users need them.
- Approved AAS service-principal/token/certificate authentication adapters where actual utility/client support is established.
- Reusable Azure DevOps/GitHub integration examples, protected environments, and post-deployment DAX/MDX smoke tests.

These are P3/product decisions, not prerequisites for restoring reliability. Cross-platform full deployment, Power BI/Fabric support, and new SSAS model formats are not implied by this roadmap.

## F. Compatibility Risks

### F1. Current evidence and proposed certification matrix

| Runtime / target combination | Current evidence | Boundary / recommendation |
|---|---|---|
| Windows PowerShell 5.0 | Manifest declares minimum 5.0. | No run evidence here. Current SqlServer guidance requires >=5.1; preserve existing installed-version possibilities while deciding whether 5.0 should remain supported. Raising the floor is breaking. |
| Windows PowerShell 5.1 on Windows | Code predominantly uses compatible syntax; traditional Windows dependencies fit this environment. | First certification target. Test import, utility execution, SqlServer/AMO loading, OLE DB construction, authentication, and SSAS integration. “Fits” is not “verified.” |
| PowerShell 7 on Windows | Remote release chooses `pwsh`; modern AMO has .NET runtime options. | Feasible candidate, not proven end-to-end. Verify compatible SqlServer/AMO runtime assets, native argument/stderr behavior, OLE DB support/architecture, utility process boundary, and AAS auth independently. |
| PowerShell 7 on Linux/macOS | Pure model/XML/JSON helpers may be portable; modern AMO HTTP scenarios exist. | Current utility discovery/deployment and OLE DB source helper are Windows-centric. Microsoft documents native TCP AMO/ADOMD connectivity as Windows-only. Do not advertise full on-prem SSAS or deployment parity. |
| Tabular compatibility 1200 | Included model and many intended tests; provider source path. | Needs SQLNCLI11/selected provider on the SSAS processing host and supported target engine/tool. No actual integration result was collected. |
| Structured Tabular 1400/1500 | Code branches at >=1400/type `2`; included 1500 model/tests. | Validate source credentials, retained options, timeouts, partition references, and processing after replacement. >=1400 code does not certify every newer compatibility level. |
| Legacy Tabular 1100/1103 | Older utility majors are accepted; model update/refresh code uses TMSL/TMSCHEMA. | Utility-driven deployment may be viable with appropriate artifacts, but source update/refresh is not established for legacy models. Preserve utility support without claiming all commands work. |
| Multidimensional on Windows | Publish description and sidecar/writeback options advertise it; XMLA Delete is used. | F01 breaks present `.configsettings` handling. No Multidimensional model/project/integration fixture was found. Require a dedicated mode/sidecar/processing/writeback matrix before asserting repair is complete. |
| Azure Analysis Services | Credential-aware Invoke-ASCmd functions and opt-in Azure test scenario exist. | Username/password can conflict with MFA/tenant policies; utility/client-specific noninteractive auth needs certification. `Ping-SsasServer` explicitly rejects AAS and is unsuitable as universal preflight. |
| New SSMS/SQL Server releases | Accepted utility major strings include `20`/`22`; searches use historical Program Files layouts. | Utility `ProductVersion`, SSMS release number, SSAS engine version, and model compatibility are separate axes. Verify real metadata/layouts; do not equate accepted strings to proven server compatibility. |

Modern AMO/ADOMD multi-runtime packages make PS7 investigation reasonable. They **do not** make legacy `LoadWithPartialName`, OLE DB, the Windows deployment utility, or every SqlServer cmdlet automatically portable. Conversely, invoking a Windows utility out of process from Windows PS7 need not require that utility's framework to load in the PS7 process. Validate that boundary rather than declaring it impossible.

### F2. Changes that require explicit compatibility decisions

| Proposed change | Potential breakage | Safe rollout |
|---|---|---|
| Move helpers to private implementations | All 17 current exports are consumable. | Leave exported wrappers; only new helpers become private. |
| Add credential parameters | Replacing string parameters breaks scripts/extensions. | Add parameter sets, retain `UserID`, `Password`, `ImpersonationPwd`, and aliases; define ambiguity/pair-validation behavior. |
| Tighten error handling | Jobs that previously continued on `Write-Error`, or treated ping failure as absence, may now stop. | Treat modifying-operation failures as deliberate bug fixes; document; preserve ping booleans and explicit nonexistent-delete semantics. |
| Remove global preference mutation | Existing catch behavior may have depended on global `Stop`. | Add explicit local terminating behavior in the same change and prove failure/caller-state tests. |
| Stage artifacts | Callers may inspect changed original sidecars/logs after publishing. | Preserve the public in-place updater; document/add explicit artifact/log output for publishing, with a compatibility option if needed. |
| Strict utility version or signed-only policy | Current preference falls back; custom installs can be unsigned or have unusual metadata. | Preserve fallback and custom path support; introduce strict controls opt-in after inventory. |
| Change partition/role/transaction/processing defaults | Can replace/delete production state, change duration/resource use, or alter rollback expectations. | Do not change defaults in stabilization. Add warnings/plans/tests, not a silent “safer” semantic switch. |
| Preserve/change data-source reconstruction | First-source behavior and replacement semantics may be relied upon. | Characterize first; fix clear preservation defects; make strict multi-source selection additive. |
| Replace SQLNCLI11 | Provider availability, connection properties, certificates, encryption defaults, architecture, and older SSAS support differ. | Keep legacy provider compatibility; offer explicit migration with actual processing-host tests. |
| Move progress off success stream | Existing scripts parse text or positional outputs; tests currently use `[1]`. | Document/characterize; new structured results via opt-in `PassThru`, with staged legacy stream changes. |
| Add `SupportsShouldProcess` / high confirmation impact | `ConfirmPreference` can introduce unattended prompts. | Review impact/defaults, gate every side effect, support explicit CI confirmation control, and test `WhatIf` causes no installs/writes/process/server calls. |
| Raise PowerShell minimum / declare editions | 5.0 users may be blocked; `Core` metadata can overpromise unsupported dependencies. | Publish matrix first; justify version policy; avoid unconditional edition claims before certification. |
| Add unconditional manifest `RequiredModules` | Utility-only publishing/import may start requiring SqlServer/network/provisioning. | Prefer per-operation checks or document and approve the new dependency/import contract. |
| Update Pester/analyzer/PlatyPS/PowerShellGet | Test discovery, compatibility parameters, generated help, and publish internals can change. | One dependency family at a time, exact versions in CI, artifact/API diffs, supported publish APIs. |
| Modernize example SQL projects | Traditional SSDT targets/.NET framework requirements affect developer tooling, not the module's runtime target. | Keep example-build modernization separate; do not infer a module-wide .NET migration requirement. |

### F3. Operational rollout and partial failure

For production deployments, log a secret-safe stage summary: validated input, selected utility/full version, target/mode, configured options, metadata deployed, connections updated, processing completed, postchecks completed. Only claim stages actually confirmed.

If metadata succeeds but later connection update/processing fails, do not automatically delete the deployed database or retry `Full` blindly. Preserve diagnostics, stop the pipeline, identify the last successful stage, and allow deliberate remediation/retry against the same versioned artifacts. Transactional utility deployment does not encompass separate subsequent TMSL requests or local file writes.

Certification should include redeployment against existing roles/partitions, not just GUID-named fresh databases. It should also validate post-deployment data through DAX/MDX or targeted processing-state checks; `Ping-SsasDatabase` alone proves existence, not correctness.

## Supporting external compatibility references

Consulted on the assessment date. These explain dependency constraints, not test results for DeployCube:

- [Microsoft: Download SqlServer PowerShell module](https://learn.microsoft.com/en-us/powershell/sql-server/download-sql-server-ps-module?view=sqlserver-ps): current Gallery guidance requires PowerShell >=5.1; SSMS does not install this module; offline provisioning is documented.
- [Microsoft: Analysis Services Deployment Utility](https://learn.microsoft.com/en-us/analysis-services/deployment/deploy-model-solutions-with-the-deployment-utility?view=sql-analysis-services-2025): SSDT artifacts, silent/output modes, deployment sidecars, and SSMS installation.
- [Microsoft: Analysis Services client libraries](https://learn.microsoft.com/en-us/analysis-services/client-libraries?view=sql-analysis-services-2025): modern multi-runtime AMO/ADOMD packages, runtime changes, Windows-only native TCP connectivity, and authentication constraints.
- [Microsoft: SQL Server Native Client](https://learn.microsoft.com/en-us/sql/relational-databases/native-client/sql-server-native-client?view=sql-server-ver15): SNAC is not shipped with SQL Server 2022+ or SSMS 19+; newer drivers are recommended for new work. This does not justify an untested blanket provider substitution in existing SSAS models.

## Approval boundary

This is an assessment and proposed sequence only. No recommendation authorizes an implementation, public API change, dependency upgrade, live deployment, commit, or pull request. Begin incremental changes only after maintainer approval.
