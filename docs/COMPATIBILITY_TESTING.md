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

Run **Actions → SSAS compatibility → Run workflow**. The default `media-only` scope downloads, validates, and mounts installation media on `windows-2022` without installing SSMS or SSAS. Run this scope first when troubleshooting downloads. After it passes, select `phase-c` for SSAS 2022 Tabular with SSMS 20. `full-matrix` enables the 16 combinations of SSAS 2017/2019/2022/2025, Tabular/Multidimensional, and SSMS 20/22. Each combination is a separate runner with an independent timeout. The workflow is manual-only.

The `media_urls_json` input maps versions to direct, public Microsoft installation ISO URLs, not bootstrapper URLs. Media acquisition is independent of SQL Setup and always runs before installing SSMS. `Acquire-SqlServerMedia.ps1` uses the runner's curl with a 30-second connection timeout, a 60-second inactivity limit (less than one byte/second), and a 20-minute overall download deadline. Transferred bytes are logged every 30 seconds; curl progress, HTTP status, effective URL, duration, and errors are retained. The downloader rejects images smaller than 1 GiB and files without ISO9660/UDF volume descriptors, and records the image's SHA-256. This computed hash is an audit identifier, not an independently published Microsoft checksum.

### Official SQL Server 2022 Developer media source

The default is the [direct Microsoft SQL Server 2022 Developer English ISO](https://download.microsoft.com/download/3/8/d/38de7036-2433-4207-8eae-06e247e17b25/SQLServer2022-x64-ENU-Dev.iso). This URL was obtained from Microsoft's own distribution metadata, not constructed from a guessed GUID or taken from a mirror:

1. The [official 2022 Developer link](https://go.microsoft.com/fwlink/?linkid=2215158&clcid=0x409) redirects through `https://aka.ms/sqlserver2022developer` to Microsoft's `SQL2022-SSEI-Dev.exe`.
2. Its embedded `Microsoft.Sql.Installer.UI.Externals.InstallerEngine.dll` contains `Manifest_Media_Dev_en-US.xml`. The ISO entry explicitly provides the `DownloadRoot` above, `FileName` `SQLServer2022-x64-ENU-Dev.iso`, and `FileSize` **1,163,053,056 bytes**. Reading these .NET resource streams does not execute the bootstrapper downloader.
3. On 2026-10-28, a direct HTTPS HEAD request returned HTTP 200, the identical `Content-Length`, and the Developer ISO filename in `Content-Disposition`. The downloader checks this exact size for the pinned URL. Mounted setup signature, version, and media structure must still pass before installation; HEAD alone is not a successful media test.

The same Microsoft manifest lists official `.exe` + `.box` self-extracting media. That is a verified distribution alternative, but this workflow uses the ISO to avoid an additional extraction subprocess. The bootstrapper's command-line download mechanism was tested and stalled; it is no longer invoked. The [Evaluation Center](https://www.microsoft.com/en-us/evalcenter/evaluate-sql-server-2022) is a different, registration-dependent offer and is not substituted for Developer. Private artifact/cache reuse remains a proposal requiring authorized storage, access controls, and review of the applicable license/distribution rights; no media cache or public artifact is created. Developer installation remains restricted to non-production development/testing under Microsoft's applicable terms.

`Mount-SqlServerMedia.ps1` mounts the validated image and checks the x64 setup structure, Microsoft's Authenticode signature, and setup executable product major (SQL Server 2017/2019/2022/2025 correspond to setup majors 14/15/16/17). `Install-Ssas.ps1` now takes an existing media root; it cannot invoke a downloader. Before setup it rechecks the media, Windows Server release, and disk space. It installs a named `DCUBE` Analysis Services instance in the selected mode and records SQL Setup and service-readiness durations, with independent 120- and 15-minute limits. A separate step verifies the running `MSOLAP$DCUBE` service and uses AMO to confirm product version, Developer edition, and requested mode. The direct Deployment Utility probe and real DeployCube integration are separate, ordered workflow steps; integration requires a successful probe including database verification and cleanup. Diagnostics and reports are uploaded with `if: always()` when the runner remains available. No installation media is uploaded, cached, or redistributed. The job limit is 240 minutes, leaving time for diagnostics after individual step deadlines. It does not install the Database Engine or use production credentials.

For SSAS 2022 Tabular, the integration uses the checked-in self-contained compatibility-1500 fixture under `test/infrastructure/fixtures/Tabular1500`. Its calculated table requires neither a local SQL source nor Analysis Services Projects build targets. Phase C reuses the unchanged `Install-Ssms.ps1` SSMS 20 installation path that passed the independent matrix in [run 40528965611](https://github.com/DrJohnT/DeployCube/actions/runs/40528965611) (14/14 discovery/selection tests; utility `20.0.3.0`). The separate SSMS compatibility workflow is unchanged.

Before calling `Publish-Cube`, the harness validates the fixture with TOM, invokes the selected Deployment Utility directly against a separate probe database, verifies database existence and compatibility level 1500 through AMO, and drops the probe. Discovery alone never passes this gate. The utility log, exit code, database verification, and cleanup are retained under `utility-probe`. A utility failure is not attributed to DeployCube; server-side model validation errors in that log must be distinguished from unsupported utility/server combinations.

The fixture explicitly declares a `calculatedTableColumn` bound to `[Value]`, the column returned by its DAX `ROW` expression. An omitted column type deserializes as a regular TOM `DataColumn`, which is not the column type for a calculated table. This is a test-fixture correction, not a DeployCube behavior change.

Pester then verifies the local SSAS connection, actual product version and Developer edition, Tabular mode, real `Publish-Cube` deployment using the selected SSMS 20 utility, `Ping-SsasDatabase`, compatibility level 1500, and removal through `Unpublish-Cube`. Deployment utility output and NUnit-format Pester results are retained as artifacts. SSMS installation, media acquisition, SSAS installation/connectivity, fixture validation, utility compatibility, and DeployCube outcomes are recorded separately. The test deliberately does not claim data-source or processing compatibility.

**Multidimensional is currently reported as `Unsupported`.** The repository has no checked-in or buildable Multidimensional `.asdatabase` fixture. The workflow still verifies setup and server mode, but does not claim a model deployment or processing test for that mode.

## Cross-version results and support claims

The SSAS workflow records the exact SSAS version/mode, SSMS major, selected deployment utility major/path, model compatibility level, and test outcome in `compatibility-report.json`. Results apply only to that recorded tuple. A newer deployment utility is never assumed to work with an older SSAS server.

### Phase C runner attempt

Phase C has **not passed**. The SSAS 2022 Tabular test did not reach SQL Server media download or setup in [run 40533721392](https://github.com/DrJohnT/DeployCube/actions/runs/40533721392) or [run 40572068520](https://github.com/DrJohnT/DeployCube/actions/runs/40572068520) because the SSMS 22 bootstrapper repeatedly exited with `-2146233029` (`0x8013153b`). The three observed installer durations were 40.14, 42.32, and 44.20 seconds. Runner diagnostics showed at least 16 GB physical memory and 78–81 GB free on C:. The installer extraction log recorded the launched Visual Studio bootstrapper's exit as `0x8013153b`; redirected stdout/stderr were empty.

The SSMS 20 replacement run, [40588588717](https://github.com/DrJohnT/DeployCube/actions/runs/40588588717), installed SSMS successfully in 12m 32s. Its SSAS installation step started at 2026-10-27 21:52:18 UTC and remained in progress when the job ended at 2026-10-28 00:44:31 UTC. The workflow at that revision had a 180-minute job timeout; the 180-minute deadline from the 21:39:31 UTC job start was 00:39:31 UTC, five minutes before the Actions job finished cancellation handling. GitHub recorded the conclusion as `cancelled`, not `timed_out`; logs and artifacts were unavailable, so the exact blocked sub-operation and any external cancellation actor cannot be proven. The timing strongly indicates the job timeout, and the old installer had no bounded child-process wait. No SSAS version, service status, media/setup completion, or deployment result can be inferred from that run.

The first instrumented rerun, [40660803981](https://github.com/DrJohnT/DeployCube/actions/runs/40660803981), installed SSMS 20 in 12m 34s and failed two seconds into SSAS media acquisition, before setup. Its artifact recorded curl finishing in 0.59 seconds but the original PowerShell `Start-Process` wrapper exposed a blank `ExitCode`; the script therefore stopped at bootstrapper-download validation. The empty curl stdout/stderr does not establish whether the HTTP download itself succeeded. Runner diagnostics confirmed neither SSAS service nor server executable had been installed. The wrapper now uses `System.Diagnostics.Process`, captures stdout/stderr asynchronously, and reports the real exit code; focused tests exercise exit codes, both output streams, and timeout termination.

[Run 40663060973](https://github.com/DrJohnT/DeployCube/actions/runs/40663060973) confirmed the next blocker: SSMS 20 installed in 12m 23s, but the Developer bootstrapper produced zero media files during 90 minutes. The media-acquisition deadline terminated its process tree with a `System.TimeoutException` after 5,400 seconds. Diagnostic collection and artifact upload succeeded. SQL Setup, service verification, the utility probe, and DeployCube integration were never reached. This is a media-download failure, not evidence against SSAS or DeployCube.

| SSAS target | SSMS deployment utility | Observed outcome |
|---|---|---|
| 2022 Tabular | SSMS 22 | Blocked before SSAS setup; deployment utility version/path not inventoried in these runs; no deployment attempted |
| 2022 Tabular | SSMS 20 | SSMS installation passed; SSAS step remained active until the 180-minute job-timeout window; installer logs/artifacts unavailable; SSAS version, service, and deployment not verified |

The earlier individual SSMS 22 matrix did install and discover utility `22.1.17.0` at `C:\Program Files\Microsoft SQL Server Management Studio 22\Release\Common7\IDE\Microsoft.AnalysisServices.Deployment.exe`, but that is not evidence that the Phase C runner installed the utility or that a model deploys to SSAS 2022.

| SSAS target | SSMS deployment utility | Current status |
|---|---|---|
| 2019 | 20 | Not yet tested |
| 2019 | 22 | Not yet tested |
| 2022 | 20 | Provisioning timed out/cancelled before verification; no Deployment Utility probe or DeployCube deployment |
| 2022 Tabular | 22 | Blocked before SSAS setup by SSMS installer failure; deployment not tested |
| 2025 | 22 | Not yet tested |
| 2017 | 20 or 22 | Not yet tested |

No combination is declared supported by this branch. Failures and explicit unsupported cells are reported separately from passes. Full-matrix artifacts are the source of truth for actual installed paths and file versions; the paths documented for one SSMS release are not used to predict paths for another.

## Runner limitations, resource use, and coverage gaps

- SSMS 22 lists Windows Server 2022 as a supported OS, but Microsoft also lists non-persistent VM environments as unsupported. GitHub-hosted runners are ephemeral; these results are experimental and are not a claim of Microsoft support for that runner arrangement.
- SSAS setup requires large SQL Server media and installation space. SSMS single-install jobs require 8 GB free; SSAS setup currently requires 20 GB free after installing SSMS. Runner diagnostics capture available disk and physical memory before installation. Media acquisition, SQL Setup, service readiness, and total SSAS installation durations are reported separately; actual disk consumption is not certified.
- The SSAS workflow requires direct official Microsoft installation media and does not automate download-center registration or silently substitute Evaluation edition. Media remains local to each ephemeral runner; private caching would require a separately authorized storage location, access controls, and confirmation of applicable license/distribution rights before implementation.
- The Phase C calculated-table fixture does not test relational data sources or processing. Those checks require a separate explicit fixture and additional local services.
- Multidimensional model deployment and processing are uncovered until a real fixture is checked in and built.
- The SSAS workflow does not certify every deployment utility against every SSAS release, model compatibility level, deployment option, or service pack. The selector unit tests are not server integration tests.
- SSMS 18/19 installations and all SSAS scenarios remain untested. Individual install/discovery results do not establish deployment compatibility with an SSAS server or processing option.

## Reports and artifacts

Each job writes a machine-readable `compatibility-report.json`, runner diagnostics, and NUnit-format Pester results when tests execute. Upload steps run after failure so installer logs and failure reports remain available. The same outcome and observed utility inventory are appended to the GitHub Step Summary. SSAS multidimensional cells and installation/build failures are explicitly marked unsupported/failed; they are never reported as passing tests.

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
