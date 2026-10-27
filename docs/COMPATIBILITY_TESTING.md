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

`test/DeploymentToolSelection.Tests.ps1` creates dummy files under realistic SSMS 18/19/20 x86 `Common7\IDE` and SSMS 21/22 x64 `Release\Common7\IDE` layouts. Pester mocks only the executable file-version metadata returned by filesystem discovery. The real DeployCube `Find-AnalysisServicesDeploymentExeLocations`, `Get-AnalysisServicesDeploymentExePath`, and `Select-AnalysisServicesDeploymentExeVersion` logic executes against those files.

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
- SSAS setup requires large SQL Server media and installation space. SSMS single-install jobs require 8 GB free; SSAS setup currently requires 12 GB free after installing SSMS. Runner diagnostics capture available disk and physical memory before installation. Installation durations are recorded per SSMS release; actual disk consumption is not certified.
- The SSAS workflow requires externally supplied direct Microsoft ISO URLs; it does not automate download-center registration. This avoids credentials and avoids inventing stable links for releases whose direct media URLs aren't verified.
- The Tabular fixture build depends on Analysis Services Projects build targets already being available to MSBuild on the hosted image. A missing target is recorded as a build failure; automatic extension acquisition is not implemented.
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
