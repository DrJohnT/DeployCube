# SSMS compatibility testing

The SSMS workflow is a manual, experimental matrix of independent GitHub-hosted Windows Server 2022 runners. Each matrix job installs exactly one SSMS version (20, 21, or 22), uses Windows PowerShell 5.1, makes no production connections, and leaves existing CI unchanged. It inventories the actual deployment utility executable and records its file/product version and path; SSMS major numbers are never used as a substitute for the executable's metadata.

Run **Actions → SSMS compatibility → Run workflow**. The workflow is manual-only and has no phase input, push trigger, fallback job, or multi-install job. GitHub requires the workflow to exist on the repository's default branch for manual dispatch.

| SSMS | Installer source | Installer family |
|---|---|---|
| 20 | [Microsoft fixed SSMS 20.2.1 bootstrapper](https://go.microsoft.com/fwlink/?linkid=2313753&clcid=0x409) | Standalone setup |
| 21 | [Microsoft SSMS 21 release bootstrapper](https://aka.ms/ssms/21/release/vs_SSMS.exe) | Visual Studio Installer |
| 22 | [Microsoft SSMS 22 release bootstrapper](https://aka.ms/ssms/22/release/vs_SSMS.exe) | Visual Studio Installer |

Each runner records diagnostics, installs one SSMS release, verifies its `Ssms.exe`, inventories every installed `Microsoft.AnalysisServices.Deployment.exe`, and runs Pester tests for real discovery plus mocked multi-version selection. Installation failures also produce a machine-readable compatibility report; NUnit results are included when tests run. Installation logs, reports, and test results are uploaded as artifacts even when a step fails. A discovered executable or a passing selection test does not establish SSAS deployment compatibility.

## Deployment utility selection tests

`test/DeploymentToolSelection.Tests.ps1` creates dummy files under realistic SSMS 18/19/20 x86 `Common7\IDE` and SSMS 21/22 x64 `Release\Common7\IDE` layouts. Pester mocks filesystem enumeration and the executable product-major metadata accessor; the real DeployCube `Find-AnalysisServicesDeploymentExeLocations`, `Get-AnalysisServicesDeploymentExePath`, and `Select-AnalysisServicesDeploymentExeVersion` logic executes against those files.

The unit tests cover explicit selection and fallback, `latest` priority, missing versions, discovery order independence, duplicate paths from overlapping roots, invalid version metadata, and `CustomAsDwInstallLocation`. The tests include majors 18–22 and assert the actual selection APIs accept those majors. Older supported utility majors remain in the selector.

The current selector priority is `22`, `21`, `20`, `19`, `18`, `16`, `15`, `14`, `13`, `12`, `11`. These values are deployment-utility product majors, not claims about the SSAS server version or cross-version deployment support.

### GitHub-hosted installation evidence

The historical individual installation results are in [workflow run 40513688326](https://github.com/DrJohnT/DeployCube/actions/runs/40513688326) and the SSMS 21 focused rerun in [40515689408](https://github.com/DrJohnT/DeployCube/actions/runs/40515689408). SSMS 21 was also rerun after adding version 21 in [workflow run 40518000480](https://github.com/DrJohnT/DeployCube/actions/runs/40518000480); its independent Phase A job passed Pester 10/10 with deployment utility `21.0.52.0` at `C:\Program Files\Microsoft SQL Server Management Studio 21\Release\Common7\IDE\Microsoft.AnalysisServices.Deployment.exe` and installation duration 145.86 seconds. The overall experimental run was not a matrix pass because its then-present side-by-side jobs failed during SSMS 22 bootstrapper setup; those jobs have been removed from the workflow. No result from that run is evidence of side-by-side or SSAS deployment compatibility.

| SSMS | SSMS executable file version and path | Deployment utility file version and path | Historical individual result | Duration |
|---|---|---|---|---:|
| 20 | `20.2.37.0`; `C:\Program Files (x86)\Microsoft SQL Server Management Studio 20\Common7\IDE\Ssms.exe` | `20.0.3.0`; `C:\Program Files (x86)\Microsoft SQL Server Management Studio 20\Common7\IDE\Microsoft.AnalysisServices.Deployment.exe` | Discovery and explicit/latest selection passed (8/8 Pester) | 586.89 s |
| 21 | `21.6.36603.0`; `C:\Program Files\Microsoft SQL Server Management Studio 21\Release\Common7\IDE\SSMS.exe` | `21.0.52.0`; `C:\Program Files\Microsoft SQL Server Management Studio 21\Release\Common7\IDE\Microsoft.AnalysisServices.Deployment.exe` | Initial run marked unsupported; after selector fix, independent job passed (10/10 Pester) | 145.86 s on fixed-selector rerun |
| 22 | `22.11.12324.101`; `C:\Program Files\Microsoft SQL Server Management Studio 22\Release\Common7\IDE\SSMS.exe` | `22.1.17.0`; `C:\Program Files\Microsoft SQL Server Management Studio 22\Release\Common7\IDE\Microsoft.AnalysisServices.Deployment.exe` | Discovery and explicit/latest selection passed (8/8 Pester) | 633.44 s |

SSMS 18 and 19 are covered by mocked filesystem unit tests only; they have not been installed on a GitHub runner. The 20–22 runner results establish installation and discovery/selection behavior for the exact observed runner builds, not model/server compatibility.

## Independent deployment utility installation

The official Microsoft channels reviewed do not provide `Microsoft.AnalysisServices.Deployment.exe` as an independently installable package. For modern releases, the supported acquisition path is installing SSMS. SSMS 21/22 use the Visual Studio Installer bootstrapper and support unattended component selection, but an SSMS installation remains an SSMS product installation; no documented standalone Deployment Wizard component ID was found. The Analysis Services Projects Visual Studio extension provides project/design-time tooling, but its Microsoft Marketplace documentation does not offer this executable as a separate command-line package. Microsoft Analysis Services NuGet packages provide client libraries, not this deployment utility. Third-party packages are not treated as an official or supported source.

DeployCube also searches the legacy SQL Server `Tools\Binn` tree, which can contain the utility from older combined SQL Server setup installations. That legacy path is distinct from a modern standalone utility installer and is not the strategy for this SSMS compatibility matrix.

## SSAS integration matrix

The focused `phase-f` scope runs exactly three independent Multidimensional jobs: SSAS 2019, 2022 and 2025 Developer with SSMS 22. It does not start the full matrix or repeat the Tabular scopes. Microsoft's [Analysis Services features by edition](https://learn.microsoft.com/en-us/analysis-services/analysis-services-features-by-edition?view=sql-analysis-services-2025) explicitly covers these releases and lists Multidimensional features for Developer. SQL Server 2025 Enterprise Developer is equivalent to the previous Developer edition. The [Analysis Services installation documentation](https://learn.microsoft.com/en-us/analysis-services/instances/install-windows/install-analysis-services) documents the `MULTIDIMENSIONAL` server mode.

Phase F builds a genuine AMO multidimensional database, validates its bindings, serializes it to Deployment Utility `.asdatabase` XML, and checks the deserialized object graph. The fixture contains one local data source, one DSV, the `Item` key dimension, `FixtureCube`, the `Fact` measure group and partition, a Sum `Amount` measure, and a default `CALCULATE` MDX script. A dedicated runner-account LocalDB instance contains one actual `dbo.Fact` row `(ItemKey=1, Amount=10)`; setup queries and verifies its sum before deployment. Both direct utility and DeployCube deployments use `DoNotProcess` and distinct database names. Each deployment refreshes server-side AMO metadata and requires the expected objects before cleanup.

This is **metadata deployment compatibility, not processing compatibility**. The cube can remain unprocessed. The LocalDB instance belongs to the runner account; access from the SSAS service identity and data-source/provider connectivity during processing are deliberately not asserted. Phase G must establish service-accessible source connectivity and processing separately. No production or external source is used; the disposable runner owns all fixture data. The existing verified Tabular1500 fixture is unchanged.

Run **Actions → SSAS compatibility → Run workflow**. The default `media-only` scope downloads, validates, and mounts installation media on `windows-2022` without installing SSMS or SSAS. Run this scope first when troubleshooting downloads. After it passes, select `phase-c` for SSAS 2022 Tabular with SSMS 20. Select `phase-d` to test SSAS 2022 Tabular against SSMS **20, 21, and 22** on three independent runners, with exactly one SSMS installation per runner. It reuses Phase C's media, provisioning, verification, direct utility probe, compatibility-1500 fixture, Publish-Cube, database verification, and Unpublish-Cube stages. `full-matrix` remains a separate explicit opt-in for the 16 combinations of SSAS 2017/2019/2022/2025, Tabular/Multidimensional, and SSMS 20/22; Phase D does not start it. Each combination has an independent timeout and artifact bundle, and `fail-fast: false` preserves the other results when one job fails. The workflow is manual-only. An SSMS installer failure (including historical SSMS 22 HRESULT `0x8013153B`) blocks subsequent stages for that cell and is not classified as Deployment Utility incompatibility.

The `media_urls_json` input maps versions to direct, public Microsoft installation ISO URLs, not bootstrapper URLs. Media acquisition is independent of SQL Setup and always runs before installing SSMS. `Acquire-SqlServerMedia.ps1` uses the runner's curl with a 30-second connection timeout, a 60-second inactivity limit (less than one byte/second), and a 20-minute overall download deadline. Transferred bytes are logged every 30 seconds; curl progress, HTTP status, effective URL, duration, and errors are retained. The downloader rejects images smaller than 1 GiB and files without ISO9660/UDF volume descriptors, and records the image's SHA-256. For 2019/2022 this computed hash is an audit identifier, not an independently published Microsoft SHA-256; the pinned 2025 ISO additionally has a Microsoft manifest SHA-256 check.

### Phase E media and fixture selection

Select `phase-e` for exactly **SSAS 2019 Tabular + SSMS 22** and **SSAS 2025 Tabular + SSMS 22**, on independent GitHub-hosted `windows-2022` runners with `fail-fast: false` and one SSMS installation each. The 2022 baseline is not part of this scope; `media-only`, `phase-c`, `phase-d`, and the explicitly selected `full-matrix` remain available. Phase E reuses the successful Phase D short absolute installer TEMP/log path and all existing media/setup/probe/integration scripts.

Official media verified on 2026-10-28, before dispatch:

| Release | Official bootstrapper source | Direct x64 English Developer ISO from its embedded `Manifest_Media_Dev_en-US.xml` | Manifest bytes / HTTPS HEAD |
|---|---|---|---|
| 2019 Developer | [Microsoft 2019 Developer fwlink](https://go.microsoft.com/fwlink/?linkid=866662) | [SQLServer2019-x64-ENU-Dev.iso](https://download.microsoft.com/download/8/4/c/84c6c430-e0f5-476d-bf43-eaaa222a72e0/SQLServer2019-x64-ENU-Dev.iso) | 1,433,974,784 / HTTP 200, identical Content-Length |
| 2025 Enterprise Developer | [Microsoft Enterprise Developer fwlink](https://go.microsoft.com/fwlink/?linkid=2344711&clcid=0x409), linked by the [official downloads page](https://www.microsoft.com/en-us/sql-server/sql-server-downloads) | [SQLServer2025-x64-ENU-EntDev.iso](https://download.microsoft.com/download/dea8c210-c44a-4a9d-9d80-0c81578860c5/ENU/SQLServer2025-x64-ENU-EntDev.iso) | 1,265,688,576 / HTTP 200, identical Content-Length |

These are real manifest URLs, not guessed endpoints. The bootstrapper resources were read without executing the downloader. SQL Server 2025 offers Standard Developer and Enterprise Developer; **Enterprise Developer** is selected to remain comparable with the previous full-featured Developer editions. Evaluation media is not substituted. The existing downloader checks all three pinned ISO lengths and records SHA-256; for the 2025 ISO it additionally checks the SHA-256 published in Microsoft's embedded manifest: `f78f869d44e8c2cbf93be16ce6ea52dd811636f046ded29e7a74dd1352134851`. Media stays on each ephemeral runner, without caching or redistribution.

The [Microsoft compatibility-level documentation](https://learn.microsoft.com/en-us/analysis-services/tabular-models/compatibility-level-for-tabular-models-in-analysis-services) lists **1500** for SQL Server 2019 and **1700** as the latest level for 2025. Phase E reuses the existing **1500** calculated-table fixture on both engines to keep scenarios comparable. TOM validation, real direct deployment, and actual database compatibility verification passed on both releases; 2025's acceptance of 1500 is confirmed by execution, not inferred merely from its newer maximum level. No 2022 fixture changes or new fixture were necessary. All service and integration version gates now derive the expected product major from the requested release (2019=15, 2022=16, 2025=17) rather than hard-coding 2022; positive and wrong-release regression tests cover all three.

### Official SQL Server 2022 Developer media source

The default is the [direct Microsoft SQL Server 2022 Developer English ISO](https://download.microsoft.com/download/3/8/d/38de7036-2433-4207-8eae-06e247e17b25/SQLServer2022-x64-ENU-Dev.iso). This URL was obtained from Microsoft's own distribution metadata, not constructed from a guessed GUID or taken from a mirror:

1. The [official 2022 Developer link](https://go.microsoft.com/fwlink/?linkid=2215158&clcid=0x409) redirects through `https://aka.ms/sqlserver2022developer` to Microsoft's `SQL2022-SSEI-Dev.exe`.
2. Its embedded `Microsoft.Sql.Installer.UI.Externals.InstallerEngine.dll` contains `Manifest_Media_Dev_en-US.xml`. The ISO entry explicitly provides the `DownloadRoot` above, `FileName` `SQLServer2022-x64-ENU-Dev.iso`, and `FileSize` **1,163,053,056 bytes**. Reading these .NET resource streams does not execute the bootstrapper downloader.
3. On 2026-10-28, a direct HTTPS HEAD request returned HTTP 200, the identical `Content-Length`, and the Developer ISO filename in `Content-Disposition`. The downloader checks this exact size for the pinned URL. Mounted setup signature, version, and media structure must still pass before installation; HEAD alone is not a successful media test.

The same Microsoft manifest lists official `.exe` + `.box` self-extracting media. That is a verified distribution alternative, but this workflow uses the ISO to avoid an additional extraction subprocess. The bootstrapper's command-line download mechanism was tested and stalled; it is no longer invoked. The [Evaluation Center](https://www.microsoft.com/en-us/evalcenter/evaluate-sql-server-2022) is a different, registration-dependent offer and is not substituted for Developer. Private artifact/cache reuse remains a proposal requiring authorized storage, access controls, and review of the applicable license/distribution rights; no media cache or public artifact is created. Developer installation remains restricted to non-production development/testing under Microsoft's applicable terms.

The focused [media-only run 40680324226](https://github.com/DrJohnT/DeployCube/actions/runs/40680324226) **passed** on 2026-10-28 without installing SSMS or SSAS. The download took **26.43 seconds**, transferred **1,163,053,056 bytes**, and had observed SHA-256 `80D2CD75DD2B28098C0182F50AD86BD44F9B3A9F357C30FF617480A1497DAFFD`. ISO format/size, real stalled-download regression tests, mounting, x64 setup structure, Microsoft signature, and setup product version **16.0.1000.6** passed; mounting/structure/signature validation took **2.19 seconds**. The image was dismounted and deleted; only diagnostics were uploaded. This establishes media acquisition, not an installed SSAS version or compatibility.

Only after that success, [Phase C run 40680739031](https://github.com/DrJohnT/DeployCube/actions/runs/40680739031) was dispatched with the same direct ISO URL. Media acquisition passed again in **9.55 seconds**. SSMS **20.2.37.0** installed in **584.77 seconds** with Deployment Utility **20.0.3.0**. SSAS setup succeeded (exit 0; **100.53 seconds**) and AMO confirmed **16.0.42.209**, **Developer64**, **Tabular**, service **MSOLAP$DCUBE Running**. The utility log reported a completed deployment and exit 0, but the probe harness then failed because `DatabaseCollection.Refresh()` does not exist in AMO. Database verification and probe cleanup therefore did not pass, and the DeployCube step was correctly skipped. This was a test-harness verification failure, not a proven utility incompatibility. The harness now uses the verified AMO `Server.Refresh(Boolean)` method with a full child refresh; mocks no longer invent a collection method.

The corrected [end-to-end Phase C run 40682470858](https://github.com/DrJohnT/DeployCube/actions/runs/40682470858) **passed** on 2026-10-28:

| Evidence | Actual result |
|---|---|
| Media download | 11.06 s; 1,163,053,056 bytes; identical SHA-256 to the focused media test |
| Media validation | ISO/UDF descriptor, exact size, mounted x64 setup structure, Microsoft signature; setup version 16.0.1000.6 |
| SSMS installation | 20.2.37.0; 758.55 s |
| Deployment Utility | File/product version 20.0.3.0; direct probe exit 0; database exists at compatibility 1500; probe cleanup passed |
| SSAS installation | Setup exit 0; 131.59 s setup, 132.17 s including readiness |
| Running SSAS | Product 16.0.42.209, Developer64, Tabular; MSOLAP$DCUBE and SQLBrowser Running; AMO connection passed |
| DeployCube | Real Publish-Cube succeeded; database existence and compatibility 1500 verified |
| Cleanup | Unpublish-Cube succeeded; database absence verified; ISO dismounted and deleted |
| Integration tests | 3 passed, 0 failed, 0 skipped |

This is evidence for the exact recorded server/tool/fixture tuple only, not the full matrix or processing/external-data-source compatibility. The public module and separate SSMS compatibility workflow were unchanged.

`Mount-SqlServerMedia.ps1` mounts the validated image and checks the x64 setup structure, Microsoft's Authenticode signature, and setup executable product major (SQL Server 2017/2019/2022/2025 correspond to setup majors 14/15/16/17). `Install-Ssas.ps1` now takes an existing media root; it cannot invoke a downloader. Before setup it rechecks the media, Windows Server release, and disk space. It installs a named `DCUBE` Analysis Services instance in the selected mode and records SQL Setup and service-readiness durations, with independent 120- and 15-minute limits. A separate step verifies the running `MSOLAP$DCUBE` service and uses AMO to confirm product version, Developer edition, and requested mode. The direct Deployment Utility probe and real DeployCube integration are separate, ordered workflow steps; integration requires a successful probe including database verification and cleanup. Diagnostics and reports are uploaded with `if: always()` when the runner remains available. No installation media is uploaded, cached, or redistributed. The job limit is 240 minutes, leaving time for diagnostics after individual step deadlines. It does not install the Database Engine or use production credentials.

For SSAS 2022 Tabular, the integration uses the checked-in self-contained compatibility-1500 fixture under `test/infrastructure/fixtures/Tabular1500`. Its calculated table requires neither a local SQL source nor Analysis Services Projects build targets. Phase C reuses the unchanged `Install-Ssms.ps1` SSMS 20 installation path that passed the independent matrix in [run 40528965611](https://github.com/DrJohnT/DeployCube/actions/runs/40528965611) (14/14 discovery/selection tests; utility `20.0.3.0`). The separate SSMS compatibility workflow is unchanged.

Before calling `Publish-Cube`, the harness validates the fixture with TOM, invokes the selected Deployment Utility directly against a separate probe database, verifies database existence and compatibility level 1500 through AMO, and drops the probe. Discovery alone never passes this gate. The utility log, exit code, database verification, and cleanup are retained under `utility-probe`. A utility failure is not attributed to DeployCube; server-side model validation errors in that log must be distinguished from unsupported utility/server combinations.

The fixture explicitly declares a `calculatedTableColumn` bound to `[Value]`, the column returned by its DAX `ROW` expression. An omitted column type deserializes as a regular TOM `DataColumn`, which is not the column type for a calculated table. This is a test-fixture correction, not a DeployCube behavior change.

Pester then verifies the local SSAS connection, actual product version and Developer edition, Tabular mode, real `Publish-Cube` deployment using the selected SSMS 20 utility, `Ping-SsasDatabase`, compatibility level 1500, and removal through `Unpublish-Cube`. Deployment utility output and NUnit-format Pester results are retained as artifacts. SSMS installation, media acquisition, SSAS installation/connectivity, fixture validation, utility compatibility, and DeployCube outcomes are recorded separately. The test deliberately does not claim data-source or processing compatibility.

**Multidimensional is tested separately by Phase F.** Its AMO-built fixture and server-side object verification replace the former missing-fixture `Unsupported` gate. The three recorded Phase F combinations passed real deployment; building the fixture locally alone is not deployment evidence.

## Cross-version results and support claims

The SSAS workflow records the exact SSAS version/mode, SSMS major, selected deployment utility major/path, model compatibility level, and test outcome in `compatibility-report.json`. Results apply only to that recorded tuple. A newer deployment utility is never assumed to work with an older SSAS server.

### Phase G: focused processing and data validation

The manual `phase-g` scope runs **only SSAS 2022 Developer Multidimensional + SSMS 22** on one Windows Server 2022 runner. Other scopes retain their previous matrices. Phase G reuses the AMO cube fixture and one-row dataset but replaces runner-account LocalDB with a dedicated `DCUBESOURCE` SQL Server 2022 Developer Engine instance installed from the same validated Microsoft media. LocalDB is not assumed to be reachable from the separate SSAS service.

The source uses local shared memory (`lpc:.\DCUBESOURCE`), with TCP and named pipes disabled, integrated Windows authentication and no stored passwords. `NT Service\MSOLAP$DCUBE` receives only a Windows login, a database user and SELECT on `dbo.Fact`; the harness checks it is not sysadmin and cannot INSERT. The runner's administrative setup connection separately validates the table, integer columns, exactly one `(1,10)` row and sum 10. A successful dimension `ProcessFull` plus SQL Extended Events captured under the actual SSAS service principal proves service-side source access, rather than confusing an administrator's SQL connection with SSAS connectivity.

DeployCube already supports `Publish-Cube -ProcessingOption Full`. Phase G first deploys with `DoNotProcess` and verifies real metadata, processes the dimension for connectivity evidence, then exercises the existing `Full` publish option. It requires the cube, dimension and partition to be `Processed`, executes MDX `SELECT {[Measures].[Amount]} ON COLUMNS FROM [Fixture Cube]`, and validates exactly one numeric result equal to **10** from the deployed SSAS database. `Invoke-ProcessTabularCubeDatabase` emits Tabular TMSL and is deliberately not used for a Multidimensional cube; no production API is added.

Two independent SSAS databases test expected processing failures: a local-only nonexistent shared-memory instance and a partition query against `dbo.DeployCubePhaseGMissingTable`. Their errors must identify connectivity/provider failure and the missing object, respectively; an arbitrary exception is not accepted. Each starts from a fresh known-good model. All owned SSAS databases are removed using `Unpublish-Cube`, absence is verified, the SQL source database/login/event session are removed and its service is stopped. Separate `always()` cleanup steps provide fallback after child-process failure; disposable runner teardown removes installed binaries.

Artifacts include `phase-g-report.json`, source provisioning/permission/cleanup reports, processing outcome/duration and utility diagnostics, XMLA dimension/negative processing reports, actual SQL service-account read evidence, MDX XML/result, Publish/Unpublish output and installation logs. Processing has a ten-minute process-tree deadline, AMO/MDX operations have 120-second timeouts, source SQL queries have 30-second deadlines, and source setup has a 20-minute deadline. A complete pass requires all positive checks, both expected negative failures and verified cleanup. Phase F metadata-only passes do not certify processing.

**Passed:** [focused Phase G run 40840026414](https://github.com/DrJohnT/DeployCube/actions/runs/40840026414), on the single SSAS 2022 Multidimensional + SSMS 22 hosted Windows Server 2022 runner. The server was `16.0.42.209`, `Developer64`, mode `Multidimensional`; `MSOLAP$DCUBE` was Running with identity `NT Service\MSOLAP$DCUBE`. SSMS `22.11.12324.101` installed in 691.28 s; its actual `Microsoft.AnalysisServices.Deployment.exe` was `22.1.17.0`. Official SQL Server 2022 Developer media downloaded in 18.78 s (1,163,053,056 bytes; SHA-256 `80D2CD75DD2B28098C0182F50AD86BD44F9B3A9F357C30FF617480A1497DAFFD`) and passed mounted-media validation. SSAS setup took 138.07 s (138.67 s total provisioning). The isolated SQL Server 2022 Developer Engine reported `16.0.1000.6`; source setup took 99.17 s.

| Phase G check | Actual evidence | Classification |
|---|---|---|
| Source schema and data | `DeployCubeFixtureSource.dbo.Fact`; expected `int NOT NULL` columns `ItemKey`, `Amount`; table count 1; row count 1; key 1; sum 10 | **Passed** |
| Least-privilege SSAS login | `NT SERVICE\MSOLAP$DCUBE`; `IsSysadmin=0`, `CanSelect=1`, `CanInsert=0`; no saved credentials | **Passed** |
| SSAS-process source connectivity | Dimension `ProcessFull` succeeded; SQL Extended Events recorded a source read as the SSAS service principal (1 read) | **Passed** |
| DeployCube deployment | `Publish-Cube` first deployed the actual multidimensional fixture with `DoNotProcess`; later `Publish-Cube -ProcessingOption Full -PreferredVersion 22` completed successfully | **Passed** |
| Actual processing | `ProcessFull`; 2.40 s; cube, dimension and partition all `Processed`; no processing warnings recorded | **Passed** |
| MDX data result | `SELECT {[Measures].[Amount]} ON COLUMNS FROM [Fixture Cube]`; saved XML reports `xsi:type="xsd:int"` and value `10` | **Passed** |
| Invalid source negative test | Isolated nonexistent shared-memory instance failed with `HYT00` / shared-memory connection error; expected actionable connection failure | **Passed (expected failure)** |
| Missing source object negative test | Isolated `dbo.DeployCubePhaseGMissingTable` query failed with SQLSTATE `42S02`, `Invalid object name` | **Passed (expected failure)** |
| Cleanup | `Unpublish-Cube` removed all three owned SSAS databases; absence verified. SQL database and login removed, Extended Events session dropped, SQL Engine service stopped. | **Passed** |

Infrastructure guards passed **62/62** on the runner. The required pass chain was source validation → deployment/metadata → service-account read → full processing → numeric MDX result → both expected negative outcomes → complete cleanup. No production API or deployment logic was changed.

#### Phase G diagnostic retries

The first attempt, [40829423030](https://github.com/DrJohnT/DeployCube/actions/runs/40829423030), stopped during source validation because the harness used SQL's reserved `RowCount` as an unquoted alias; SQL Engine and SSAS provisioning had succeeded. The source cleanup report confirms the temporary database/login were removed and the service stopped.

The second attempt, [40837504852](https://github.com/DrJohnT/DeployCube/actions/runs/40837504852), installed SQL Engine and validated its version and data, then its permission check failed because `USE` changed database context inside `EXECUTE AS`, preventing `REVERT`. The always-run cleanup again removed the temporary source and stopped its service. The harness was corrected to use fully qualified object names without changing database context and the exact Phase G cell was rerun. These were test-harness errors, not SSAS deployment or processing compatibility failures; the passing evidence above is from the subsequent complete run.

#### Smallest next step

Extend only Phase G's focused matrix to SSAS 2019 Multidimensional + SSMS 22, reusing the same fixture, local SQL Engine provisioning, service-account permissions, `ProcessFull`, MDX/negative assertions and cleanup. Keep SSAS 2025 out until that single added cell passes.

### Phase G2: SSAS 2019 and 2025 processing extension

The manual `phase-g2` scope adds only SSAS 2019 and SSAS 2025 Multidimensional, both with SSMS 22. Its two jobs use independent hosted Windows runners, `fail-fast: false`, and `max-parallel: 1` with the 2019 cell listed first. This limits troubleshooting overlap while preserving one SSMS installation and one SSAS instance per runner. It does not dispatch the full matrix or rerun C–G.

G2 reuses the successful Phase G source provisioning and processing harness. Target-release SQL Server media provisions SSAS; a separately downloaded and validated official SQL Server 2022 Developer ISO provisions the same isolated database-engine source on both runners. The harness now explicitly checks the requested SSAS product major (2019→15, 2025→17), Developer edition and Multidimensional mode before deployment. Both use the same validated compatibility-1100 AMO fixture and SQL Engine connection; no release-specific fixture downgrade or production API change is expected or assumed.

| SSAS target | Source version | Processing / MDX | Negative tests | Cleanup | Classification | GitHub Actions |
|---|---|---|---|---|---|---|
| 2019 Multidimensional + SSMS 22 | SQL Server 2022 Developer | Not tested | Not tested | Not tested | **Not tested** | Pending |
| 2025 Multidimensional + SSMS 22 | SQL Server 2022 Developer | Not tested | Not tested | Not tested | **Not tested** | Pending |

Replace these pending classifications only with evidence from completed, real runner artifacts that satisfy the full Phase G pass criteria.

### Phase F: SSAS 2019, 2022 and 2025 Multidimensional with SSMS 22

**Passed:** [workflow run 40732695201](https://github.com/DrJohnT/DeployCube/actions/runs/40732695201), executing commit `5704468` on `feature/ssms-ssas-compatibility`. All three independent GitHub-hosted Windows Server 2022 jobs passed on the first attempt. Each installed exactly one SSMS product; no Tabular matrix or full matrix was dispatched. There were **9/9 real integration tests**, plus **50/50 infrastructure guards on each runner**. Local validation also passed 44 focused Pester tests, YAML/manual-trigger/matrix checks, embedded PowerShell parsing and actual AMO fixture validation/XML round-trip.

| SSAS release / actual server version / edition | Server mode | SSMS product version | Deployment Utility file version | Model level | Media download | SSMS install | SSAS setup / total provision | Direct utility + probe metadata + removal | `Publish-Cube` | Database + cube metadata | `Unpublish-Cube` + verified absence | Status | Run |
|---|---|---|---|---:|---:|---:|---:|---|---|---|---|---|---|
| 2019 / `15.0.32.50` / `Developer64` | Multidimensional | `22.11.12324.101` | `22.1.17.0` | 1100 | 21.43 s | 700.93 s | 148.73 / 149.64 s | Passed | Passed | Passed | Passed | **Passed** | [40732695201](https://github.com/DrJohnT/DeployCube/actions/runs/40732695201) |
| 2022 / `16.0.42.209` / `Developer64` | Multidimensional | `22.11.12324.101` | `22.1.17.0` | 1100 | 11.31 s | 876.42 s | 160.69 / 161.13 s | Passed | Passed | Passed | Passed | **Passed** | [40732695201](https://github.com/DrJohnT/DeployCube/actions/runs/40732695201) |
| 2025 / `17.0.25.218` / `Developer64` | Multidimensional | `22.11.12324.101` | `22.1.17.0` | 1100 | 12.80 s | 725.74 s | 97.37 / 97.77 s | Passed | Passed | Passed | Passed | **Passed** | [40732695201](https://github.com/DrJohnT/DeployCube/actions/runs/40732695201) |

All three runners reported service `MSOLAP$DCUBE` **Running** and AMO confirmed the requested release, `Developer64` edition and `Multidimensional` mode. SQL Server 2025 uses the official **Enterprise Developer** image. Every runner identified the utility at:

```text
C:\Program Files\Microsoft SQL Server Management Studio 22\Release\Common7\IDE\Microsoft.AnalysisServices.Deployment.exe
```

Its file and product versions were both `22.1.17.0`. SSMS `Ssms.exe` reported file version `22.11.12324.101 built by: stable`, product version `22.11.12324.101`.

The existing official Microsoft x64 English Developer ISO sources were reused without caching or redistribution. ISO size/format, mounted media structure, setup signature and requested product major passed; setup versions were `15.0.2000.5`, `16.0.1000.6` and `17.0.1000.7`, respectively. Recorded sizes and SHA-256 values:

| SQL Server media | Bytes | Recorded SHA-256 |
|---|---:|---|
| 2019 Developer | 1,433,974,784 | `53A7900C27B71D42A63EBCC89F8ADD2F2C6DB278153FC3FC3B2053BA547BCFD0` |
| 2022 Developer | 1,163,053,056 | `80D2CD75DD2B28098C0182F50AD86BD44F9B3A9F357C30FF617480A1497DAFFD` |
| 2025 Enterprise Developer | 1,265,688,576 | `F78F869D44E8C2CBF93BE16CE6EA52DD811636F046DED29E7A74DD1352134851` |

The 2025 SHA-256 was also compared with Microsoft's embedded manifest. The 2019/2022 values are recorded audit hashes, not claims of independently published Microsoft SHA-256 verification. Exact source URLs and provenance are documented above and retained in each `media-acquisition.json`.

The same bound AMO fixture worked unmodified on all three server releases: one database, `LocalFixture` data source, `FixtureView` DSV, `Item` dimension/key, `FixtureCube`, `Fact` measure group/partition, `Amount` Sum measure and default MDX calculation script. LocalDB `15.0.4382.1` created an actual isolated database with one row and verified `SUM(Amount)=10` on every runner. No version-specific project or deployment-option workaround was needed; the unchanged compatibility-1500 Tabular fixture was not reused as a Multidimensional model.

For each release, the direct utility created `DeployCubeUtilityCompatibilityProbe`; refreshed AMO metadata verified every expected object and compatibility 1100, then the probe was dropped and its absence verified. Next, the real `Publish-Cube -ProcessingOption DoNotProcess` created the distinct `DeployCubeCompatibilityTest` database. Server-side AMO verified the database, cube, dimension, key, measure group, measure, partition and bindings. `Unpublish-Cube` then removed that database and the final test verified absence. Utility exit code zero alone was not accepted as deployment success.

**This establishes metadata deployment compatibility only.** Both deployed cubes reported `Unprocessed`; processing was not requested or needed to validate deployment. SSAS-service access to runner-account LocalDB, provider connectivity, processing and measure-query results remain Phase G work. There were no failed, unsupported or infrastructure-blocked Phase F cells in this run. Other server/utility tuples remain `Not tested` unless separately recorded.

The three downloaded artifact bundles were checked against `compatibility-report.json`, `utility-probe/compatibility-probe.json`, `fixture-source.json`, `fixture-validation.json`, `published-metadata.json`, media reports and both NUnit reports. Installer/setup logs and deployment logs are preserved with the artifacts. No public API, production deployment logic or separate SSMS compatibility workflow changed.

### Phase E: SSAS 2019 and 2025 Tabular with SSMS 22

[Run 40718431659](https://github.com/DrJohnT/DeployCube/actions/runs/40718431659) **passed both independent Windows jobs** on 2026-10-28. Each runner inventoried one SSMS installation and one matching utility, verified **MSOLAP$DCUBE Running**, connected using AMO, and confirmed the requested engine release, **Developer64** edition, and **Tabular** mode. SQL Browser was also Running. The existing SSAS 2022 deployments were not repeated.

| SSAS release / actual server version | Edition (media / AMO) | Mode | SSMS product version | Utility file version | Model level | Media download | SSMS install | SSAS setup | Direct probe | Publish-Cube | Database verification | Unpublish-Cube | Classification / run |
|---|---|---|---|---|---:|---:|---:|---:|---|---|---|---|---|
| 2019 / 15.0.32.50 | Developer / Developer64 | Tabular | 22.11.12324.101 | 22.1.17.0 | 1500 | 8.54 s | 708.23 s | 146.73 s | Passed; exit 0; probe DB level 1500 and removal verified | Passed | Exists; level 1500 | Passed; absence verified | **Passed** — [2019 job](https://github.com/DrJohnT/DeployCube/actions/runs/40718431659/job/122922392315) |
| 2025 / 17.0.25.218 | Enterprise Developer / Developer64 | Tabular | 22.11.12324.101 | 22.1.17.0 | 1500 | 24.09 s | 661.63 s | 97.85 s | Passed; exit 0; probe DB level 1500 and removal verified | Passed | Exists; level 1500 | Passed; absence verified | **Passed** — [2025 job](https://github.com/DrJohnT/DeployCube/actions/runs/40718431659/job/122922391566) |

Both use the inventoried utility at `C:\Program Files\Microsoft SQL Server Management Studio 22\Release\Common7\IDE\Microsoft.AnalysisServices.Deployment.exe` (file and product version **22.1.17.0**). Each cell passed **37 infrastructure guard tests** and **3 real integration tests**, with no failures or skipped integration tests: **6/6 real integration tests total**. Guard coverage includes the previous 2022 version gate, rejection of substituted releases, media validation/inactivity, utility selection, probe verification, and cleanup.

| Media evidence | SQL Server 2019 Developer | SQL Server 2025 Enterprise Developer |
|---|---|---|
| Source | Official direct Microsoft ISO linked in the Phase E media table above | Official direct Microsoft ISO linked in the Phase E media table above |
| Actual bytes | 1,433,974,784 | 1,265,688,576 |
| Recorded SHA-256 | `53A7900C27B71D42A63EBCC89F8ADD2F2C6DB278153FC3FC3B2053BA547BCFD0` | `F78F869D44E8C2CBF93BE16CE6EA52DD811636F046DED29E7A74DD1352134851` (matches Microsoft manifest) |
| Mounted setup product version | 15.0.2000.5 | 17.0.1000.7 |
| Media validation | Passed ISO/UDF, exact size, x64 setup structure and Microsoft Authenticode signature | Passed ISO/UDF, exact size, x64 setup structure and Microsoft Authenticode signature |
| SSAS setup result | Exit 0; 147.41 s including service readiness | Exit 0; 98.44 s including service readiness |

In both jobs the direct probe's database and the real DeployCube database were separately created, queried, and removed. The checked-in 1500 model was not upgraded or altered. Media dismount/deletion and always-upload diagnostic steps passed; media was not included in artifacts. Reports include `media-acquisition.json`, `media-validation.json`, installation and service verification JSON, the direct probe JSON/log, `compatibility-report.json`, and NUnit test results.

The initial [run 40715625533](https://github.com/DrJohnT/DeployCube/actions/runs/40715625533) is classified **Blocked by infrastructure**, not incompatible: both official ISO downloads passed, but the new unit-test guard mocked `Get-Service` before Windows PowerShell had loaded `System.ServiceProcess`, so `[System.ServiceProcess.ServiceControllerStatus]` could not resolve. No SSMS/SSAS installation or deployment occurred in that attempt. The test now explicitly loads that assembly; all 37 Windows guards passed on both runners in the successful follow-up. Both cells were rerun because neither had reached deployment; no already-verified 2022 job was rerun.

#### Verified deployment matrix after Phase E

| SSAS / mode | SSMS utility | Classification | Real deployment evidence |
|---|---|---|---|
| 2019 Tabular | SSMS 22 / 22.1.17.0 | **Passed** | [Phase E 40718431659](https://github.com/DrJohnT/DeployCube/actions/runs/40718431659) |
| 2022 Tabular | SSMS 20 / 20.0.3.0 | **Passed** (previously verified) | [Phase D 40691182874](https://github.com/DrJohnT/DeployCube/actions/runs/40691182874) |
| 2022 Tabular | SSMS 21 / 21.0.52.0 | **Passed** (previously verified) | [Phase D 40691182874](https://github.com/DrJohnT/DeployCube/actions/runs/40691182874) |
| 2022 Tabular | SSMS 22 / 22.1.17.0 | **Passed** (previously verified) | [Phase D 40691182874](https://github.com/DrJohnT/DeployCube/actions/runs/40691182874) |
| 2025 Tabular | SSMS 22 / 22.1.17.0 | **Passed** | [Phase E 40718431659](https://github.com/DrJohnT/DeployCube/actions/runs/40718431659) |

All five passes apply to the observed Developer builds and compatibility-1500 fixture only. Other combinations are **Not tested** unless separately documented; an installer/runner/media blocker is **Blocked by infrastructure**, and a completed failing deployment/verification is **Failed**, never a pass based only on an installer or utility exit code.

### Phase D: SSMS 20 / 21 / 22 against SSAS 2022 Tabular

The focused [Phase D run 40691182874](https://github.com/DrJohnT/DeployCube/actions/runs/40691182874) **passed all three independent Windows runner jobs** on 2026-10-28. Each artifact bundle inventories exactly one matching SSMS installation and one Deployment Utility. All three servers reported **16.0.42.209**, **Developer64**, **Tabular**, and **MSOLAP$DCUBE Running**, with successful AMO connectivity.

| SSMS | Installed SSMS product version | Utility file/product version | SSMS installation | Media download | SSAS setup | Direct utility probe | Publish-Cube / database 1500 / Unpublish-Cube |
|---|---|---|---:|---:|---:|---|---|
| [20 job](https://github.com/DrJohnT/DeployCube/actions/runs/40691182874/job/122826097825) | 20.2.37.0 | 20.0.3.0 | 1120.67 s | 7.25 s | 104.82 s | Passed; exit 0; database 1500; cleanup passed | Passed / passed / passed; 3/3 tests |
| [21 job](https://github.com/DrJohnT/DeployCube/actions/runs/40691182874/job/122826097490) | 21.6.36603.0 | 21.0.52.0 | 153.46 s | 11.93 s | 124.03 s | Passed; exit 0; database 1500; cleanup passed | Passed / passed / passed; 3/3 tests |
| [22 job](https://github.com/DrJohnT/DeployCube/actions/runs/40691182874/job/122826097783) | 22.11.12324.101 | 22.1.17.0 | 883.34 s | 27.56 s | 134.28 s | Passed; exit 0; database 1500; cleanup passed | Passed / passed / passed; 3/3 tests |

Utility paths recorded by the real inventory:

- SSMS 20: `C:\Program Files (x86)\Microsoft SQL Server Management Studio 20\Common7\IDE\Microsoft.AnalysisServices.Deployment.exe`
- SSMS 21: `C:\Program Files\Microsoft SQL Server Management Studio 21\Release\Common7\IDE\Microsoft.AnalysisServices.Deployment.exe`
- SSMS 22: `C:\Program Files\Microsoft SQL Server Management Studio 22\Release\Common7\IDE\Microsoft.AnalysisServices.Deployment.exe`

Each cell passed **31 infrastructure guard tests** and **3 real integration tests** (9/9 real integration tests in total). The direct probe checked database existence and compatibility 1500 and removed its separate database. The DeployCube tests independently deployed the checked-in fixture, verified database existence and compatibility 1500, and verified database absence after real `Unpublish-Cube`. Media was dismounted/deleted, and diagnostics were uploaded in all cells. This does not certify external data sources, processing, other compatibility levels, or other SSAS versions/modes.

#### Installer investigation, separate from utility compatibility

[Run 40689319575](https://github.com/DrJohnT/DeployCube/actions/runs/40689319575) passed the SSMS 20 baseline but failed to install SSMS 21 and 22 with `-2146233029` (`0x8013153B`) after **38.20 s** and **63.15 s**, respectively. Their decompression logs showed successful extraction followed by failure in the extracted Visual Studio bootstrapper, before SSAS installation or utility execution. Both runners had 81 GB free. These are installer failures, not utility/server incompatibility.

For Phase D only, the workflow now passes a short, absolute log/TEMP path (`RUNNER_TEMP/ssms-<major>-logs`) to the unchanged shared installer, instead of the long relative artifact path. Logs are copied into each cell's artifact directory in `finally`; an additional always-eligible failure step captures .NET Runtime, Application Error, Windows Error Reporting, and MSI Application events. With this isolated change, all three installations and real deployments passed in run 40691182874. This is a verified working installer configuration; the earlier logs alone do not establish which path property caused the .NET failure or prove all intermittent installer faults are eliminated. Phase C's installation path and the separate SSMS workflow remain unchanged.

The first Phase D dispatch, [40688866364](https://github.com/DrJohnT/DeployCube/actions/runs/40688866364), stopped at guard configuration before installation because Pester's typed `Run.Path` option does not support `+=`. The workflow now assembles a string array before assigning it; all subsequent Windows guard suites passed. A pre-existing Windows-path assertion in the selector tests fails on Linux, so Windows runner results, not a Linux pass claim, validate that suite.

### Phase C runner attempt

Phase C **passed in run 40682470858** as recorded above. The following earlier attempts document the blockers resolved before that pass. The SSAS 2022 Tabular test did not reach SQL Server media download or setup in [run 40533721392](https://github.com/DrJohnT/DeployCube/actions/runs/40533721392) or [run 40572068520](https://github.com/DrJohnT/DeployCube/actions/runs/40572068520) because the SSMS 22 bootstrapper repeatedly exited with `-2146233029` (`0x8013153b`). The three observed installer durations were 40.14, 42.32, and 44.20 seconds. Runner diagnostics showed at least 16 GB physical memory and 78–81 GB free on C:. The installer extraction log recorded the launched Visual Studio bootstrapper's exit as `0x8013153b`; redirected stdout/stderr were empty.

The SSMS 20 replacement run, [40588588717](https://github.com/DrJohnT/DeployCube/actions/runs/40588588717), installed SSMS successfully in 12m 32s. Its SSAS installation step started at 2026-10-27 21:52:18 UTC and remained in progress when the job ended at 2026-10-28 00:44:31 UTC. The workflow at that revision had a 180-minute job timeout; the 180-minute deadline from the 21:39:31 UTC job start was 00:39:31 UTC, five minutes before the Actions job finished cancellation handling. GitHub recorded the conclusion as `cancelled`, not `timed_out`; logs and artifacts were unavailable, so the exact blocked sub-operation and any external cancellation actor cannot be proven. The timing strongly indicates the job timeout, and the old installer had no bounded child-process wait. No SSAS version, service status, media/setup completion, or deployment result can be inferred from that run.

The first instrumented rerun, [40660803981](https://github.com/DrJohnT/DeployCube/actions/runs/40660803981), installed SSMS 20 in 12m 34s and failed two seconds into SSAS media acquisition, before setup. Its artifact recorded curl finishing in 0.59 seconds but the original PowerShell `Start-Process` wrapper exposed a blank `ExitCode`; the script therefore stopped at bootstrapper-download validation. The empty curl stdout/stderr does not establish whether the HTTP download itself succeeded. Runner diagnostics confirmed neither SSAS service nor server executable had been installed. The wrapper now uses `System.Diagnostics.Process`, captures stdout/stderr asynchronously, and reports the real exit code; focused tests exercise exit codes, both output streams, and timeout termination.

[Run 40663060973](https://github.com/DrJohnT/DeployCube/actions/runs/40663060973) confirmed the next blocker: SSMS 20 installed in 12m 23s, but the Developer bootstrapper produced zero media files during 90 minutes. The media-acquisition deadline terminated its process tree with a `System.TimeoutException` after 5,400 seconds. Diagnostic collection and artifact upload succeeded. SQL Setup, service verification, the utility probe, and DeployCube integration were never reached. This is a media-download failure, not evidence against SSAS or DeployCube.

| SSAS target | SSMS deployment utility | Observed outcome |
|---|---|---|
| 2022 Tabular | SSMS 22 | Blocked before SSAS setup; deployment utility version/path not inventoried in these runs; no deployment attempted |
| 2022 Tabular | SSMS 20 | Earlier bootstrapper attempts blocked; direct-ISO run 40682470858 passed service verification, utility probe, real deployment, database verification, and cleanup |

The earlier individual SSMS 22 matrix did install and discover utility `22.1.17.0` at `C:\Program Files\Microsoft SQL Server Management Studio 22\Release\Common7\IDE\Microsoft.AnalysisServices.Deployment.exe`, but that is not evidence that the Phase C runner installed the utility or that a model deploys to SSAS 2022.

| SSAS target | SSMS deployment utility | Current status |
|---|---|---|
| 2019 | 20 | Not yet tested |
| 2019 Tabular | 22 | Passed in run 40718431659: server 15.0.32.50, utility 22.1.17.0, compatibility-1500 fixture, Publish-Cube, verification, and Unpublish-Cube |
| 2022 Tabular | 20 | Passed in run 40682470858: server 16.0.42.209, utility 20.0.3.0, compatibility-1500 fixture, Publish-Cube, verification, and Unpublish-Cube |
| 2022 Tabular | 21 | Passed in run 40691182874: server 16.0.42.209, utility 21.0.52.0, compatibility-1500 fixture, Publish-Cube, verification, and Unpublish-Cube |
| 2022 Tabular | 22 | Passed in run 40691182874: server 16.0.42.209, utility 22.1.17.0, compatibility-1500 fixture, Publish-Cube, verification, and Unpublish-Cube |
| 2025 Tabular | 22 | Passed in run 40718431659: server 17.0.25.218, utility 22.1.17.0, compatibility-1500 fixture, Publish-Cube, verification, and Unpublish-Cube |
| 2017 | 20 or 22 | Not yet tested |

Only the exact eight Phase C/D/E/F tuples recorded above have passed real deployment on this branch: five Tabular and three Multidimensional. Failures and explicit unsupported cells are reported separately from passes. Per-job artifacts are the source of truth for actual installed paths and file versions; the paths documented for one SSMS release are not used to predict paths for another.

## Runner limitations, resource use, and coverage gaps

- SSMS 22 lists Windows Server 2022 as a supported OS, but Microsoft also lists non-persistent VM environments as unsupported. GitHub-hosted runners are ephemeral; these results are experimental and are not a claim of Microsoft support for that runner arrangement.
- SSAS setup requires large SQL Server media and installation space. SSMS single-install jobs require 8 GB free; SSAS setup currently requires 20 GB free after installing SSMS. Runner diagnostics capture available disk and physical memory before installation. Media acquisition, SQL Setup, service readiness, and total SSAS installation durations are reported separately; actual disk consumption is not certified.
- The SSAS workflow requires direct official Microsoft installation media and does not automate download-center registration or silently substitute Evaluation edition. Media remains local to each ephemeral runner; private caching would require a separately authorized storage location, access controls, and confirmation of applicable license/distribution rights before implementation.
- The Phase C calculated-table fixture does not test relational data sources or processing. Those checks require a separate explicit fixture and additional local services.
- Multidimensional metadata deployment uses the Phase F fixture; processing remains outside this phase.
- The SSAS workflow does not certify every deployment utility against every SSAS release, model compatibility level, deployment option, or service pack. The selector unit tests are not server integration tests.
- SSMS 18/19 installations and SSAS combinations other than the recorded Phase C/D/E/F tuples remain untested. Individual install/discovery results do not establish deployment compatibility with an SSAS server or processing option.

## Reports and artifacts

Each job writes a machine-readable `compatibility-report.json`, runner diagnostics, and NUnit-format Pester results when tests execute. Upload steps run after failure so installer logs and failure reports remain available, including cancellation where the runner survives. Windows service/event diagnostics are also captured for downstream fixture/deployment failures, not just provisioning failures. The same outcome and observed utility inventory are appended to the GitHub Step Summary. Installation/build failures are never reported as passing tests.

Official references:

- [SSMS release history](https://learn.microsoft.com/en-us/ssms/release-history)
- [Install SSMS](https://learn.microsoft.com/en-us/ssms/install/install)
- [SSMS command-line installation parameters](https://learn.microsoft.com/en-us/ssms/install/command-line-parameters)
- [SSMS system requirements](https://learn.microsoft.com/en-us/ssms/system-requirements)
- [Analysis Services Projects Visual Studio extension](https://marketplace.visualstudio.com/items?itemName=ProBITools.MicrosoftAnalysisServicesModelingProjects)
- [Install Analysis Services](https://learn.microsoft.com/en-us/analysis-services/instances/install-windows/install-analysis-services)
- [SQL Server 2017 operating-system requirements](https://learn.microsoft.com/en-us/sql/sql-server/install/hardware-and-software-requirements-for-installing-sql-server-2017)
- [SQL Server 2019 operating-system requirements](https://learn.microsoft.com/en-us/sql/sql-server/install/hardware-and-software-requirements-for-installing-sql-server-2019)
- [SQL Server 2022 Developer download](https://go.microsoft.com/fwlink/?linkid=2215158&clcid=0x409)
- [SQL Server 2022 operating-system requirements](https://learn.microsoft.com/en-us/sql/sql-server/install/hardware-and-software-requirements-for-installing-sql-server-2022)
- [SQL Server 2025 operating-system requirements](https://learn.microsoft.com/en-us/sql/sql-server/install/hardware-and-software-requirements-for-installing-sql-server-2025)
