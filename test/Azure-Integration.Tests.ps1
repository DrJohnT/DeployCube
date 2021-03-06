<#
Add a service principal to the server administrator role
    https://docs.microsoft.com/en-us/azure/analysis-services/analysis-services-addservprinc-admins
How to: Use Azure PowerShell to create a service principal with a certificate
    https://docs.microsoft.com/en-us/azure/active-directory/develop/howto-authenticate-service-principal-powershell
#>

BeforeAll { 
    $CurrentFolder = Split-Path -Parent $PSScriptRoot;
    $ModulePath = Resolve-Path "$CurrentFolder\DeployCube\DeployCube.psd1";
    import-Module -Name $ModulePath; 

    function Get-AzureAsServer {
        
        $data = @{};

        if ("" -eq "$Env:AzureAsServer")
        {
            throw "AzureAsServer environment variable is not set!";
            return $data;
        }
        
        $CurrentFolder = Split-Path -Parent $PSScriptRoot;
        $data.PathToCubeProject = "$CurrentFolder\examples\CubeAtCompatibility1500\bin\Model.asdatabase";
        
        $data.AzureAsServer = $Env:AzureAsServer;
        $data.CubeDatabase = $Env:AzureAsCube;  

        $data.UserID = $Env:AzureAsUserID;
        $data.Password = $Env:AzureAsPassword;
        [SecureString] $SecurePassword = ConvertTo-SecureString $data.Password -AsPlainText -Force;
        [PsCredential] $data.Credential = New-Object System.Management.Automation.PSCredential($data.UserID, $SecurePassword);

        return $data;
    }


    function Get-AzureSqlServer {

        $data = @{};

        if ("" -eq "$Env:AzureSqlServer")
        {
            throw "AzureSqlServer environment variable is not set!";
            return $data;
        }
        $data.AzureSqlServer = $Env:AzureSqlServer;
        $data.SqlServerDatabase = 'DatabaseToPublish';
        $data.SqlUserID = $Env:AzureSqlUserID;
        $data.SqlUserPwd = $Env:AzureSqlPassword;

        return  $data;
    }
}

Describe "Azure AS Integration Tests" -Tag "Azure" {
    Context "Deploy Cube, update connection and process" {
        
        It "Deploy cube should not throw" {
            $aasData = Get-AzureAsServer;
            # Unable to obtain authentication token using the credentials provided. If your Active Directory tenant administrator has configured Multi-Factor Authentication 
            # or if your account is a Microsoft Account, please remove the user name and password from the connection string, and then retry. You should then be prompted to enter your credentials.
            { Publish-Cube -AsDatabasePath $aasData.PathToCubeProject -Server $aasData.AzureAsServer -CubeDatabase $aasData.CubeDatabase -UserID $aasData.UserID -Password $aasData.Password } | Should -Not -Throw
        }

        It "Check the cube is deployed" {
            $aasData = Get-AzureAsServer;
            ( Ping-SsasDatabase -Server $aasData.AzureAsServer -CubeDatabase $aasData.CubeDatabase -Credential $aasData.Credential ) | Should -BeTrue;
        }

        It "Update cube data source connection string" {
            $aasData = Get-AzureAsServer
            $sqlData = Get-AzureSqlServer;            
            ( Update-TabularCubeDataSource -Server $aasData.AzureAsServer -CubeDatabase $aasData.CubeDatabase -Credential $aasData.Credential -SourceSqlServer $sqlData.AzureSqlServer -SourceSqlDatabase $sqlData.SqlServerDatabase -ImpersonationMode 'UsernamePassword' -ImpersonationAccount $sqlData.SqlUserID -ImpersonationPassword $sqlData.SqlUserPwd )[1] | Should -BeTrue;
        }

        It "Process cube should not throw" {
            $aasData = Get-AzureAsServer
            { Invoke-ProcessTabularCubeDatabase -Server $aasData.AzureAsServer -CubeDatabase $aasData.CubeDatabase -Credential $aasData.Credential -RefreshType Full }  | Should -Not -Throw;
        }

        It "Drop cube should not throw" {
            $aasData = Get-AzureAsServer
            { Unpublish-Cube -Server $aasData.AzureAsServer -CubeDatabase $aasData.CubeDatabase -Credential $aasData.Credential } | Should -Not -Throw;
        }

        It "Check the cube dropped" {
            $aasData = Get-AzureAsServer
            ( Ping-SsasDatabase -Server $aasData.AzureAsServer -CubeDatabase $aasData.CubeDatabase -Credential $aasData.Credential ) | Should -BeFalse;
        }
        

    }
}

AfterAll {
    Remove-Module -Name DeployCube;
}