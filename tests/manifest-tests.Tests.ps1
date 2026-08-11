BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..\src\modules\manifest.psm1'
    Import-Module $modulePath -Force
}

Describe 'Configuration backups' {
    BeforeEach {
        $testDirectory = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $testDirectory -Force | Out-Null
        $configurationPath = Join-Path $testDirectory 'settings.json'
        Set-Content -LiteralPath $configurationPath -Value '{"theme":"light"}' -Encoding UTF8
    }

    AfterEach {
        Remove-Item -LiteralPath $testDirectory -Recurse -Force
    }

    It 'conserve le nom, l extension et l horodatage UTC a la seconde' {
        $backup = New-ConfigurationBackup -Path $configurationPath

        $backup.'backup-path' | Should -Match 'settings\.bak\.\d{8}T\d{6}Z\.json$'
        Test-Path -LiteralPath $backup.'backup-path' -PathType Leaf | Should -BeTrue
        $backup.'original-path' | Should -Be $configurationPath
        $backup.'original-hash' | Should -Not -BeNullOrEmpty
    }

    It 'ne remplace pas un backup existant' {
        $first = New-ConfigurationBackup -Path $configurationPath
        $second = New-ConfigurationBackup -Path $configurationPath

        $second.'backup-path' | Should -Not -Be $first.'backup-path'
        @($first.'backup-path', $second.'backup-path') | ForEach-Object { Test-Path -LiteralPath $_ -PathType Leaf | Should -BeTrue }
    }
}

Describe 'Manifest applications' {
    It 'ajoute une application absente sans erreur d index' {
        $manifest = [pscustomobject]@{
            applications = @()
            operations = @()
        }
        $operation = [pscustomobject]@{
            'application-id' = 'library-folders'
            operation = 'install'
            result = 'success'
            'configuration-id' = $null
            'config-version' = $null
            backups = @()
        }

        { Add-PostinstallOperation -Manifest $manifest -Operation $operation } | Should -Not -Throw
        @($manifest.applications).Count | Should -Be 1
        $manifest.applications[0].'application-id' | Should -Be 'library-folders'
    }
}
