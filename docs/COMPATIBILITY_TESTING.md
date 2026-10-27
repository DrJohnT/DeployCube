# Experimental SQL Server compatibility testing

These workflows are manual, experimental checks for the deployment utility that DeployCube discovers and executes. They run on disposable GitHub-hosted Windows Server 2022 runners, use Windows PowerShell 5.1, and make no production connections. They do not change the DeployCube public API or existing CI workflows.

No compatibility combination has been run or certified by this change. A successful result must come from a completed workflow run and its JSON/NUnit artifacts; installer download, setup completion, or an unexecuted matrix entry is not a compatibility result.

GitHub requires a `workflow_dispatch` workflow to exist on the repository's default branch before it can be dispatched. While this feature remains unmerged by design, Phase A and Phase B cannot be started from the feature branch alone. Do not treat this limitation as an installer result.

## SSMS deployment utility matrix

Run **Actions → SSMS compatibility → Run workflow** with `phase-a` to validate SSMS 20, 21, and 22. After all Phase A jobs pass, dispatch again with `phase-b` for side-by-side SSMS 20 + 22 installs. The workflow does not start Phase B automatically. The installer sources are Microsoft links:

| SSMS | Installer source | Installer family |
|---|---|---|
| 18 | [Microsoft fixed SSMS 18.12.1 bootstrapper](https://go.microsoft.com/fwlink/?linkid=2199013&clcid=0x409) | Standalone setup |
| 19 | [Microsoft fixed SSMS 19.3 bootstrapper](https://go.microsoft.com/fwlink/?linkid=2257624&clcid=0x409) | Standalone setup |
| 20 | [Microsoft fixed SSMS 20.2.1 bootstrapper](https://go.microsoft.com/fwlink/?linkid=2313753&clcid=0x409) | Standalone setup |
| 21 | [Microsoft SSMS 21 release bootstrapper](https://aka.ms/ssms/21/release/vs_SSMS.exe) | Visual Studio Installer |
| 22 | [Microsoft SSMS 22 release bootstrapper](https://aka.ms/ssms/22/release/vs_SSMS.exe) | Visual Studio Installer |

SSMS 18 and 19 installer mappings remain available in the installation script but are outside the current Phase A matrix. The 18–20 links are fixed builds, not a promise to test the newest servicing update. SSMS 21/22 release aliases move over time. The installer script uses the quiet switches for each installer family and verifies an installed `Ssms.exe` and its product major before continuing. It records elapsed installation time and does not infer a utility version from the SSMS major.

Each job inventories every `Microsoft.AnalysisServices.Deployment.exe` beneath the SQL Server/SSMS program directories and records the actual full path, file version, and product version. It then tests:

- `Find-AnalysisServicesDeploymentExeLocations` output against the filesystem inventory.
- `Get-AnalysisServicesDeploymentExePath` using each observed product major supported by the current module.
- `Select-AnalysisServicesDeploymentExeVersion` exact preference, fallback, and `latest` behavior.
- `CustomAsDwInstallLocation` with the standard install roots isolated.
- No-utility behavior with empty temporary search roots; no installed files are moved or faked.

The current selector prioritizes utility product versions in this order: `22`, `20`, `16`, `15`, `14`, `13`, `12`, `11`. This is not the SSMS-version order. An installed utility whose product major is not accepted by the current API is reported as an incompatibility; this infrastructure does not alter the public API to hide that result.

The Phase B SSMS 20 + 22 jobs install both products in both orders on separate runners. They check both product installations, record all utility locations, actual file versions, and individual installation durations, and test selector stability when paths overlap through `CustomAsDwInstallLocation`. The existing finder can emit repeated paths for overlapping search roots; the tests check selection and path identity rather than claiming that the finder deduplicates results.

The side-by-side job requires at least 14 GB free before it starts. When the side-by-side job fails, isolated SSMS 20 and SSMS 22 jobs run as a fallback and record individual discovery results. This fallback does **not** establish simultaneous installation or cross-version selection. Disk thresholds are preflight gates, not measured consumption.

## SSAS integration matrix

Run **Actions → SSAS compatibility → Run workflow**. The default scope is the Phase C cell (SSAS 2022 Tabular with SSMS 22). `full-matrix` enables the 16 combinations of SSAS 2017/2019/2022/2025, Tabular/Multidimensional, and SSMS 20/22. Each combination is a separate `windows-2022` runner with an independent timeout.

The manual `media_urls_json` input must map each SQL Server major to a **direct, public Microsoft Developer ISO URL**, for example `{"2017":"https://download.microsoft.com/...iso","2019":"...","2022":"...","2025":"..."}`. URLs with credentials or query tokens are rejected. The workflow does not place SQL setup media in the repository or rely on undocumented registration flows. If media for a requested release is unavailable, the job reports the missing input and makes no installation claim.

Before setup, the script checks the Windows Server release, URL host, downloaded ISO, signed Microsoft `setup.exe`, and setup executable product major (SQL Server 2017/2019/2022/2025 correspond to setup majors 14/15/16/17). It installs the Database Engine and a named `DCUBE` Analysis Services instance using the selected Tabular or Multidimensional mode, starts both services, and records setup logs. The Developer media is intended for non-production development/testing only. There are no production connections or embedded passwords.

For Tabular jobs, the integration script builds the repository's checked-in 1200 model for SSAS 2017 or 1500 model for SSAS 2019/2022/2025, creates a disposable local SQL source database, and runs Pester checks for connection, mode, DeployCube deployment, database existence, compatibility level, Full processing, and Automatic processing. Cleanup removes the deployed test model and source database. A missing Analysis Services Projects MSBuild target, missing fixture output, utility selection failure, or processing failure is a test failure, not a successful fallback.

**Multidimensional is currently reported as `Unsupported`.** The repository has no checked-in or buildable Multidimensional `.asdatabase` fixture. The workflow still verifies setup and server mode, but does not claim a model deployment or processing test for that mode.

## Cross-version results and support claims

The SSAS workflow records the exact SSAS version/mode, SSMS major, selected deployment utility major/path, model compatibility level, and test outcome in `compatibility-report.json`. Results apply only to that recorded tuple. A newer deployment utility is never assumed to work with an older SSAS server.

| SSAS target | SSMS deployment utility | Current status |
|---|---|---|
| 2019 | 20 | Not yet tested |
| 2019 | 22 | Not yet tested |
| 2022 | 20 | Not yet tested |
| 2022 | 22 | Not yet tested |
| 2025 | 22 | Not yet tested |
| 2017 | 20 or 22 | Not yet tested |

No combination is declared supported by this branch. Failures and explicit unsupported cells are reported separately from passes. Full-matrix artifacts are the source of truth for actual installed paths and file versions; the paths documented for one SSMS release are not used to predict paths for another.

## Runner limitations, resource use, and coverage gaps

- SSMS 22 lists Windows Server 2022 as a supported OS, but Microsoft also lists non-persistent VM environments as unsupported. GitHub-hosted runners are ephemeral; these results are experimental and are not a claim of Microsoft support for that runner arrangement.
- SSAS setup requires large SQL Server media and installation space. SSMS single-install jobs require 8 GB free; the two-version job requires 14 GB free; SSAS setup currently requires 12 GB free after installing SSMS. Runner diagnostics capture available disk and physical memory before installation. SSMS installation duration is captured per installation; actual runtime and disk consumption are not certified until the workflow runs produce artifacts.
- The SSAS workflow requires externally supplied direct Microsoft ISO URLs; it does not automate download-center registration. This avoids credentials and avoids inventing stable links for releases whose direct media URLs aren't verified.
- The Tabular fixture build depends on Analysis Services Projects build targets already being available to MSBuild on the hosted image. A missing target is recorded as a build failure; automatic extension acquisition is not implemented.
- Multidimensional model deployment and processing are uncovered until a real fixture is checked in and built.
- The current cross-version matrix samples SSMS 20 and 22. It does not certify every SSMS utility against every SSAS release, model compatibility level, deployment option, or service pack.
- No workflow was dispatched as part of this implementation. Runtime, disk usage, installer success, actual executable paths, file versions, and compatibility outcomes remain unmeasured.

## Reports and artifacts

Each job writes a machine-readable `compatibility-report.json`, runner diagnostics, and NUnit-format Pester results when tests execute. Upload steps run after failure so installer logs and failure reports remain available. The same outcome and observed utility inventory are appended to the GitHub Step Summary. SSAS multidimensional cells and installation/build failures are explicitly marked unsupported/failed; they are never reported as passing tests.

Official references:

- [SSMS release history](https://learn.microsoft.com/en-us/ssms/release-history)
- [SSMS command-line installation parameters](https://learn.microsoft.com/en-us/ssms/install/command-line-parameters)
- [SSMS system requirements](https://learn.microsoft.com/en-us/ssms/system-requirements)
- [Install Analysis Services](https://learn.microsoft.com/en-us/analysis-services/instances/install-windows/install-analysis-services)
- [SQL Server 2017 operating-system requirements](https://learn.microsoft.com/en-us/sql/sql-server/install/hardware-and-software-requirements-for-installing-sql-server-2017)
- [SQL Server 2019 operating-system requirements](https://learn.microsoft.com/en-us/sql/sql-server/install/hardware-and-software-requirements-for-installing-sql-server-2019)
- [SQL Server 2022 Developer download](https://go.microsoft.com/fwlink/?linkid=2215158&clcid=0x409)
- [SQL Server 2022 operating-system requirements](https://learn.microsoft.com/en-us/sql/sql-server/install/hardware-and-software-requirements-for-installing-sql-server-2022)
- [SQL Server 2025 operating-system requirements](https://learn.microsoft.com/en-us/sql/sql-server/install/hardware-and-software-requirements-for-installing-sql-server-2025)
