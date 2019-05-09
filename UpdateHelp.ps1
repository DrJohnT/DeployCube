if (Get-Module -Name DeployCube) {
    Remove-Module DeployCube
}
Import-Module .\DeployCube -Force
New-MarkdownHelp -Module DeployCube -OutputFolder .\docs -Force -FwLink https://github.com/DrJohnT/DeployCube/docs
#-WithModulePage -ConvertDoubleDashLists
New-ExternalHelp .\docs -OutputPath .\DeployCube\en-US\ -Force;
