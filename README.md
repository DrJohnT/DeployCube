[![Build Status](https://qatar-re.visualstudio.com/QatarRe.BI/_apis/build/status/Test%20and%20Publish%20Package%20DeployCube?branchName=master)](https://qatar-re.visualstudio.com/QatarRe.BI/_build/latest?definitionId=58&branchName=master)

### DeployCube

# Deploy a SSAS Tabular or Multidimensional cube using the Analysis Services Deployment Utility

## Overview

**Publish-Cube** allows you to deploy a tabular or multidimensional cube to a SQL Server Analysis Services instance.  Behind the scenes it uses the Analysis Services Deployment Utility in silent mode.
**Publish-Cube** simplifies the use of [Analysis Services Deployment Utility](https://docs.microsoft.com/en-us/sql/analysis-services/multidimensional-models/deploy-model-solutions-with-the-deployment-utility?view=sql-server-2017).
The key advantage being that it takes care of updating the various config files that the Deployment Utility uses to understand where to deploy the cube.  This is done for you automatically and makes the entire deployment process simpler.

When you perform a **build** of a Visual Studio tabular or multidimensional project, it creates an **AsDatabase** file which defines the entire model such as dimensions, attributes and measures associated with the cube.
**Publish-Cube** can therefore be used in CI senarios as part of the build so that you can populate the cube with data and run tests against the cube using DAX or MDX as part of the pipeline.

To automate build and deployment of tabular cube in Azure DevOps, you can use MsBuild to create AsDatabase from your Visual Studio solution.  You can then add a PowerShell task which uses **Publish-Cube** to invoke [Analysis Services Deployment Utility](https://docs.microsoft.com/en-us/sql/analysis-services/multidimensional-models/deploy-model-solutions-with-the-deployment-utility?view=sql-server-2017) to deploy each AsDatabase.
For Multidimensional models you will have to use DevEnv.com (Visual Studio) to generate the AsDatabase file.

**Publish-Cube** can also be used to automate the deployment of cubes as part of a server deployment using [Octopus Deploy](https://octopus.com/) or Azure DevOps Release Manager.

## Installation

Install from PowerShell gallery using:

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ powershell
Install-Module -Name DeployCube
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

## Usage

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ powershell
Publish-Cube -AsDatabasePath "C:\Dev\YourCube\bin\Debug\YourCube.asdatabase" -TargetServerName "YourCubeServer"
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Where -AsDatabasePath is the path to your tabular or multidimensional model, and -TargetServerName is the name of the target server (including instance and port if required).  The above is the minimum set of parameters that can be used with **Publish-Cube**.

Normally, the database will be named the same as your AsDatabase file (i.e. YourCube in the example above).  However, by adding the -TargetDatabaseName parameter, you can change the name of your deployed cube to be anything you like.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ powershell
Publish-Cube -AsDatabasePath "C:\Dev\YourCube\bin\Debug\YourCube.asdatabase" -TargetServerName "YourCubeServer" -TargetDatabaseName "YourNewCubeName"
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Finnally, if there are multiple versions of the Analysis Services Deployment Utility (Microsoft.AnalysisServices.Deployment.exe) are installed on your build agent, you can specify which version should be used with the -PreferredVersion option.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ powershell
Publish-Cube -AsDatabasePath "C:\Dev\YourCube\bin\Debug\YourCube.asdatabase" -TargetServerName "YourCubeServer" -PreferredVersion latest
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Valid values for -PreferredVersion are:

|**Version**|**SQL Server Release**|
|-------|------------------|
|latest|Latest SQL Server version found on agent|
|150|SQL Server 2019|
|140|SQL Server 2017|
|130|SQL Server 2016|
|120|SQL Server 2014|

## List of commands

The following is a list of commands provided by this module once you have installed the package (see *Installation* above)

| **Function**             | **Description**                                                             |
|--------------------------|-----------------------------------------------------------------------------|
| Publish-Cube                  | Publishes a Tabular or Multidimensional cube to the specified server        |
| Unpublish-Cube                | Drops a Tabular or Multidimensional cube from the specified server          |
| Select-AnalysisServicesDeploymentExeVersion | Finds a specific version of the Microsoft.AnalysisServices.Deployment.exe if more than one present on the host |
| Get-AnalysisServicesDeploymentExePath       | Returns the path of a specific version of Microsoft.AnalysisServices.Deployment.exe |
| Ping-SsasServer               | Returns true if the specified SSAS server exists                            |
| Ping-SsasDatabase             | Returns true if the specified SSAS database exists on the server            |
| Find-AnalysisServicesDeploymentExeLocations | Lists all locations of Microsoft.AnalysisServices.Deployment.exe on the host |
| Invoke-ExternalCommand        | Helper function to run command-line programs                                        |
| Get-SsasSourceConnectionString | Helper function to create valid connection strings                                 |
| Update-AnalysisServicesConfig | Updates the various config files (listed below) which are needed to deploy the cube |


## Pre-requisites

The following pre-requisites need to be installed for **Publish-Cube** to work properly.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ powershell
Microsoft.AnalysisServices.Deployment.exe
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Microsoft.AnalysisServices.Deployment.exe is known as the [Analysis Services Deployment Utility](https://docs.microsoft.com/en-us/sql/analysis-services/multidimensional-models/deploy-model-solutions-with-the-deployment-utility?view=sql-server-2017) which is installed with [SQL Server Managment Studio](https://docs.microsoft.com/en-us/sql/ssms/download-sql-server-management-studio-ssms?view=sql-server-2017) (SSMS).

## Azure DevOps Agent

**Publish-Cube** can be run on an in-house hosted Azure DevOps agent when once [Analysis Services Deployment Utility](https://docs.microsoft.com/en-us/sql/analysis-services/multidimensional-models/deploy-model-solutions-with-the-deployment-utility?view=sql-server-2017) is installed:

* By installing SQL Server 2012 or later

* By installing [SQL Server Managment Studio](https://docs.microsoft.com/en-us/sql/ssms/download-sql-server-management-studio-ssms?view=sql-server-2017) (SSMS).

Be aware that it is best to install the latest version of Analysis Services Deployment Utility
as this provides support for all previous versions of SQL Server Analysis Services as well as current versions.

## Example Tabular Model

An example tabular model is provided as a Visual Studio solution alongside a SQL database which acts as the cubes source.  Th
DACPAC is provided in the .\example folder.  You can use this to test that deployments work correctly.  Note that the SSDT Visual Studio solution is configured to deploy to SQL Server 2016.  Open the Visual Studio solution and change the target version and rebuild the solution if you have a different version of SQL Server installed.

 ## Update-AnalysisServicesConfig
 This PowerShell function updates the various config files (listed below) which are needed to deploy the cube:

|XMLA File|Description|
|-------|------------------|
|[project name].asdatabase|Contains the declarative definitions for all SSAS objects|
|[project name].deploymenttargets|Contains the name of the target SSAS instance and database|
|[project name].deploymentoptions|Contains options such as whether deployment is transactional and whether objects should be processed.|
|[project name].configsettings|(Multidimensional only) Contains environment specific settings such as data source connections and object storage locations.  These settings override whats in [project name].asdatabase.|


## Issue Reporting

If you are facing problems in making this PowerShell module work, please report any
problems on [DeployCube GitHub Project
Page](https://github.com/DrJohnT/DeployCube/issues).
