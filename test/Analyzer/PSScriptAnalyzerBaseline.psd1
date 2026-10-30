# Known PSScriptAnalyzer findings in DeployCube/ at the time the CI gate was introduced.
# The gate fails when a file has MORE findings for a rule than listed here (or a finding for an unlisted rule/file).
# Fixing existing findings never fails the gate; lower or remove the entry in the same PR so it cannot regress.
# Keys are '<file name>|<rule name>'; values are the allowed finding count.
@{
    'Find-AnalysisServicesDeploymentExeLocations.ps1|PSAvoidTrailingWhitespace'  = 3
    'Get-AnalysisServicesDeploymentExePath.ps1|PSAvoidTrailingWhitespace'        = 11
    'Get-CubeDatabaseCompatibilityLevel.ps1|PSAvoidTrailingWhitespace'           = 3
    'Get-SqlConnectionString.ps1|PSAvoidTrailingWhitespace'                      = 7
    'Invoke-ExternalCommand.ps1|PSAvoidTrailingWhitespace'                       = 1
    'Invoke-ProcessTabularCubeDatabase.ps1|PSAvoidTrailingWhitespace'            = 2
    'Ping-SsasDatabase.ps1|PSAvoidTrailingWhitespace'                            = 1
    'Publish-Cube.ps1|PSAvoidTrailingWhitespace'                                 = 2
    'Publish-Cube.ps1|PSAvoidUsingUsernameAndPasswordParams'                     = 1
    'Publish-Cube.ps1|PSAvoidUsingWriteHost'                                     = 1
    'Select-AnalysisServicesDeploymentExeVersion.ps1|PSAvoidTrailingWhitespace'  = 1
    'Unpublish-Cube.ps1|PSAvoidTrailingWhitespace'                               = 1
    'Update-AnalysisServicesConfig.ps1|PSAvoidTrailingWhitespace'                = 4
    'Update-AnalysisServicesConfig.ps1|PSAvoidUsingUsernameAndPasswordParams'    = 1
    'Update-TabularCubeDataSource.ps1|PSAvoidTrailingWhitespace'                 = 13
    'Update-TabularCubeDataSource.ps1|PSUseOutputTypeCorrectly'                  = 1
}
