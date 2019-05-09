[![PowerShell Gallery Version](https://img.shields.io/powershellgallery/v/DeployCube.svg)](https://www.powershellgallery.com/packages/DeployCube)
[![Build Status](https://qatar-re.visualstudio.com/QatarRe.BI/_apis/build/status/Test%20and%20Publish%20Package%20DeployCube?branchName=master)](https://qatar-re.visualstudio.com/QatarRe.BI/_build/latest?definitionId=58&branchName=master)


### DeployCube

# Deploy a SSAS Tabular or Multidimensional cube using the Analysis Services Deployment Utility

## Overview

**Publish-Cube** allows you to deploy a tabular or multidimensional cube to a SQL Server Analysis Services instance.  Behind the scenes it uses the
[Analysis Services Deployment Utility](https://docs.microsoft.com/en-us/sql/analysis-services/multidimensional-models/deploy-model-solutions-with-the-deployment-utility?view=sql-server-2017)
in silent mode.
**Publish-Cube** simplifies the use of [Analysis Services Deployment Utility](https://docs.microsoft.com/en-us/sql/analysis-services/multidimensional-models/deploy-model-solutions-with-the-deployment-utility?view=sql-server-2017)
by automatically updating the various config files that the Deployment Utility uses to deploy the cube.

When you perform a **build** of a Visual Studio cube project, it creates an **AsDatabase** file which defines the entire model such as dimensions, attributes and measures associated with the cube.
**Publish-Cube** can be used in CI senarios as part of the pipeline so that you can populate the cube with data and run tests against the cube using DAX or MDX as part of the pipeline.

To automate the build and deployment of tabular cube in Azure DevOps, you can use MsBuild to create AsDatabase from your Visual Studio solution.  You can then add a PowerShell task which uses **Publish-Cube** to invoke [Analysis Services Deployment Utility](https://docs.microsoft.com/en-us/sql/analysis-services/multidimensional-models/deploy-model-solutions-with-the-deployment-utility?view=sql-server-2017) to deploy each AsDatabase.
For Multidimensional models you will have to use DevEnv.com (Visual Studio) to generate the AsDatabase file.

**Publish-Cube** can also be used to automate the deployment of cubes as part of a server deployment using [Octopus Deploy](https://octopus.com/) or Azure DevOps Release Manager.

## Installation

Install from PowerShell gallery using:

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ powershell
Install-Module -Name DeployCube
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

## Pre-requisites

The following pre-requisites need to be installed for **Publish-Cube** to work properly.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ powershell
Microsoft.AnalysisServices.Deployment.exe
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Microsoft.AnalysisServices.Deployment.exe is known as the [Analysis Services Deployment Utility](https://docs.microsoft.com/en-us/sql/analysis-services/multidimensional-models/deploy-model-solutions-with-the-deployment-utility?view=sql-server-2017) which is installed with [SQL Server Managment Studio](https://docs.microsoft.com/en-us/sql/ssms/download-sql-server-management-studio-ssms?view=sql-server-2017) (SSMS).

The module also requires the Microsoft SQL Server PowerShell module **SqlServer** which is installed automatically.

## Getting Started

Full documentation for all the functions in this module are provided below.  Here's a quick start guide.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ powershell
Publish-Cube -AsDatabasePath "C:\Dev\YourCube\bin\Debug\YourCube.asdatabase" -Server "YourCubeServer"
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Where -AsDatabasePath is the path to your tabular or multidimensional model, and -Server is the name of the target server (including instance and port if required).  The above is the minimum set of parameters that can be used with **Publish-Cube**.

Normally, the database will be named the same as your AsDatabase file (i.e. YourCube in the example above).  However, by adding the -CubeDatabase parameter, you can change the name of your deployed cube to be anything you like.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ powershell
Publish-Cube -AsDatabasePath "C:\Dev\YourCube\bin\Debug\YourCube.asdatabase" -Server "YourCubeServer" -CubeDatabase "YourNewCubeName"
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

As part of the deployment you can specify a processing option.  Valid processing options are: ProcessFull, ProcessDefault and DoNotProcess.  However, it is strongly recommended that you use default "DoNotProcess" option as the connection to your source database may not be correct and need adjustment post-deployment.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ powershell
Publish-Cube -AsDatabasePath "C:\Dev\YourCube\bin\Debug\YourCube.asdatabase" -Server "YourCubeServer" -ProcessingOption "DoNotProcess"
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Finnally, if there are multiple versions of the Analysis Services Deployment Utility (Microsoft.AnalysisServices.Deployment.exe) are installed on your build agent, you can specify which version should be used with the -PreferredVersion option.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ powershell
Publish-Cube -AsDatabasePath "C:\Dev\YourCube\bin\Debug\YourCube.asdatabase" -Server "YourCubeServer" -PreferredVersion latest
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

## List of commands

The following is a list of commands provided by this module once you have installed the package (see *Installation* above)

| **Function**             | **Description**                                                             |
|--------------------------|-----------------------------------------------------------------------------|
| [Find-AnalysisServicesDeploymentExeLocations](https://github.com/DrJohnT/DeployCube/blob/master/docs/Find-AnalysisServicesDeploymentExeLocations.md) | Lists all locations of Microsoft.AnalysisServices.Deployment.exe on the host |
| [Get-AnalysisServicesDeploymentExePath](https://github.com/DrJohnT/DeployCube/blob/master/docs/Get-AnalysisServicesDeploymentExePath.md) | Returns the path of a specific version of Microsoft.AnalysisServices.Deployment.exe |
| [Get-CubeDatabaseCompatibilityLevel](https://github.com/DrJohnT/DeployCube/blob/master/docs/Get-CubeDatabaseCompatibilityLevel.md) | Returns the CompatibilityLevel of a deployed cube database |
| [Get-ServerMode](https://github.com/DrJohnT/DeployCube/blob/master/docs/Get-ServerMode.md) | Returns the mode of the server: Tabular or Multidimensional |
| [Get-SqlAsPath](https://github.com/DrJohnT/DeployCube/blob/master/docs/Get-SqlAsPath.md) | Returns the path to a specific cube database SQLSERVER:\SQLAS\YourServer\DEFAULT\Databases\YourCubeDatabase |
| [Get-ModuleByName](https://github.com/DrJohnT/DeployCube/blob/master/docs/Get-ModuleByName.md) | Loads the named PowerShell module, installing it if required || Publish-Cube                                | Publishes a Tabular or Multidimensional cube to the specified server |
| [Get-SqlConnectionString](https://github.com/DrJohnT/DeployCube/blob/master/docs/Get-SqlConnectionString.md) | Helper function to create valid SQL Server database connection strings |
| [Get-SsasProcessingMessages](https://github.com/DrJohnT/DeployCube/blob/master/docs/Get-SqlConnectionString.md) | Examines the XML returned by the Invoke-AsCmd function to find errors.  Writes error message if errors are found |
| [Invoke-ProcessTabularCubeDatabase](https://github.com/DrJohnT/DeployCube/blob/master/docs/Invoke-ProcessTabularCubeDatabase.md) | Processes an SSAS database on a SQL Server SSAS instance |
| [Invoke-ExternalCommand](https://github.com/DrJohnT/DeployCube/blob/master/docs/Invoke-ExternalCommand.md) | Helper function to run command-line programs |
| [Ping-SsasDatabase](https://github.com/DrJohnT/DeployCube/blob/master/docs/Ping-SsasDatabase.md) | Returns true if the specified SSAS database exists on the server |
| [Ping-SsasServer](https://github.com/DrJohnT/DeployCube/blob/master/docs/Ping-SsasServer.md) | Returns true if the specified SSAS server exists |
| [Publish-Cube](https://github.com/DrJohnT/DeployCube/blob/master/docs/Publish-Cube.md) | Publish-Cube deploys a tabular or multidimentional cube to a SQL Server Analysis Services instance |
| [Select-AnalysisServicesDeploymentExeVersion](https://github.com/DrJohnT/DeployCube/blob/master/docs/Select-AnalysisServicesDeploymentExeVersion.md) | Finds a specific version of the Microsoft.AnalysisServices.Deployment.exe if more than one present on the host |
| [Unpublish-Cube](https://github.com/DrJohnT/DeployCube/blob/master/docs/Unpublish-Cube.md) | Drops a Tabular or Multidimensional cube from the specified server |
| [Update-AnalysisServicesConfig](https://github.com/DrJohnT/DeployCube/blob/master/docs/Update-AnalysisServicesConfig.md) | Updates the various config files (listed below) which are needed to deploy the cube |
| [Update-TabularCubeDataSource](https://github.com/DrJohnT/DeployCube/blob/master/docs/Update-TabularCubeDataSource.md) | Updates the cube's connection to the source SQL database. |

## Azure DevOps Agent

For CI senarios, **Publish-Cube** has been packaged as an extension for Azure DevOps Pipelines available from the marketplace here:
[Deployment tools for SSAS Tabular Cube Models](https://marketplace.visualstudio.com/items?itemName=DrJohnExtensions.DeployTabularModel)

## Example Tabular Model

An example tabular model is provided as a Visual Studio solution alongside a SQL database which acts as the cubes source.  Th
DACPAC is provided in the .\example folder.  You can use this to test that deployments work correctly.  Note that the SSDT Visual Studio solution is configured to deploy to SQL Server 2016.  Open the Visual Studio solution and change the target version and rebuild the solution if you have a different version of SQL Server installed.

## Issue Reporting

If you are facing problems in making this PowerShell module work, please report any
problems on [DeployCube GitHub Project
Page](https://github.com/DrJohnT/DeployCube/issues).
