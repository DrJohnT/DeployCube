BeforeAll {
    . (Join-Path $PSScriptRoot 'infrastructure/SqlServerMedia.ps1')
    if (-not (Get-Command Get-AuthenticodeSignature -ErrorAction SilentlyContinue)) {
        function global:Get-AuthenticodeSignature {
            throw 'The Windows Authenticode cmdlet is unavailable outside Windows.'
        }
        $script:removeAuthenticodeTestShim = $true
    }
}

Describe 'SQL Server installation media validation' {
    It 'accepts a valid Microsoft Authenticode signature' {
        $path = Join-Path $TestDrive 'microsoft-setup.exe'
        [System.IO.File]::WriteAllText($path, 'test')
        Mock Get-AuthenticodeSignature {
            [pscustomobject]@{
                Status = 'Valid'
                SignerCertificate = [pscustomobject]@{
                    Subject = 'CN=Microsoft Corporation, O=Microsoft Corporation'
                    Thumbprint = '0123456789ABCDEF'
                }
            }
        }

        $signature = Assert-MicrosoftAuthenticodeSignature -Path $path
        $signature.Status | Should -Be 'Valid'
        $signature.Thumbprint | Should -Be '0123456789ABCDEF'
    }

    It 'rejects invalid or non-Microsoft Authenticode signatures' -ForEach @(
        @{ Status = 'NotSigned'; Subject = '' }
        @{ Status = 'Valid'; Subject = 'CN=Other Publisher, O=Other Publisher' }
    ) {
        $path = Join-Path $TestDrive 'untrusted-setup.exe'
        [System.IO.File]::WriteAllText($path, 'test')
        Mock Get-AuthenticodeSignature {
            [pscustomobject]@{
                Status = $Status
                SignerCertificate = [pscustomobject]@{ Subject = $Subject; Thumbprint = '' }
            }
        }

        AfterAll {
            if ($script:removeAuthenticodeTestShim) {
                Remove-Item Function:\Get-AuthenticodeSignature -ErrorAction SilentlyContinue
            }
        }

        { Assert-MicrosoftAuthenticodeSignature -Path $path } | Should -Throw '*valid Microsoft Authenticode signature*'
    }

    It 'rejects bootstrappers, mirrors, credentials, query tokens and HTTP' -ForEach @(
        @{ Uri = 'https://go.microsoft.com/fwlink/?linkid=2215158&clcid=0x409' }
        @{ Uri = 'https://example.com/sql.iso' }
        @{ Uri = 'https://download.microsoft.com.example.com/sql.iso' }
        @{ Uri = 'https://user:pass@download.microsoft.com/sql.iso' }
        @{ Uri = 'https://download.microsoft.com/sql.iso?token=secret' }
        @{ Uri = 'http://download.microsoft.com/sql.iso' }
    ) {
        { Assert-MicrosoftMediaUri -Uri $Uri } | Should -Throw '*direct*'
    }

    It 'accepts a direct Microsoft HTTPS media URL' {
        { Assert-MicrosoftMediaUri -Uri 'https://download.microsoft.com/download/sql.iso' } | Should -Not -Throw
    }

    It 'rejects small files even if they contain an ISO descriptor' {
        $path = Join-Path $TestDrive 'small.iso'
        [System.IO.File]::WriteAllBytes($path, (New-Object byte[] 65536))
        { Assert-SqlServerIso -Path $path } | Should -Throw '*too small*'
    }

    It 'rejects a response without an ISO or UDF volume descriptor' {
        $path = Join-Path $TestDrive 'html.iso'
        [System.IO.File]::WriteAllText($path, '<html>not installation media</html>')
        { Assert-SqlServerIso -Path $path -MinimumBytes 1 } | Should -Throw '*not an ISO9660/UDF*'
    }

    It 'recognizes ISO9660 and UDF descriptors' -ForEach @(
        @{ Identifier = 'CD001' }
        @{ Identifier = 'NSR02' }
        @{ Identifier = 'NSR03' }
    ) {
        $path = Join-Path $TestDrive "$Identifier.iso"
        $bytes = New-Object byte[] 65536
        [System.Text.Encoding]::ASCII.GetBytes($Identifier).CopyTo($bytes, 32769)
        [System.IO.File]::WriteAllBytes($path, $bytes)
        { Assert-SqlServerIso -Path $path -MinimumBytes 65536 } | Should -Not -Throw
    }

    It 'rejects extracted media missing its setup payload' {
        { Assert-SqlServerMediaRoot -MediaRoot $TestDrive -ExpectedMajor 16 } |
            Should -Throw '*Incomplete SQL Server*'
    }

    It 'preserves a diagnostic report when source validation fails' {
        $directory = Join-Path $TestDrive 'failed-source'
        {
            & (Join-Path $PSScriptRoot 'infrastructure/Acquire-SqlServerMedia.ps1') `
                -MediaUri 'https://example.com/not-official.iso' `
                -MediaDirectory (Join-Path $directory 'download') -LogDirectory $directory
        } | Should -Throw '*direct*'
        $report = Get-Content -LiteralPath (Join-Path $directory 'media-acquisition.json') -Raw | ConvertFrom-Json
        $report.Outcome | Should -Be 'Failed'
        $report.Stage | Should -Be 'Source validation'
        $report.Bytes | Should -Be 0
        $report.Error | Should -Match 'Bootstrapper URLs are not installation media'
    }
}
