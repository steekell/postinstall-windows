BeforeAll {
    $manifestModulePath = Join-Path $PSScriptRoot '..\src\modules\manifest.psm1'
    $catalogModulePath = Join-Path $PSScriptRoot '..\src\modules\catalog.psm1'
    $packageManagersModulePath = Join-Path $PSScriptRoot '..\src\modules\package-managers.psm1'
    $engineModulePath = Join-Path $PSScriptRoot '..\src\modules\engine.psm1'
    Import-Module $manifestModulePath -Force
    Import-Module $catalogModulePath -Force
    Import-Module $packageManagersModulePath -Force
    Import-Module $engineModulePath -Force
}

Describe 'Moteur postinstallation' {
    It 'transmet les paramètres nommés au script applicatif' {
        InModuleScope engine {
            $scriptPath = Join-Path $TestDrive 'capture-parameters.ps1'
            $resultPath = Join-Path $TestDrive 'received-parameters.json'
            @'
param(
    [Parameter(Mandatory)][ValidateSet('install', 'update', 'uninstall')][string]$Action,
    [Parameter(Mandatory)][string]$ApplicationId,
    [Parameter(Mandatory)][string]$SettingId
)
[pscustomobject]@{
    Action = $Action
    ApplicationId = $ApplicationId
    SettingId = $SettingId
} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'received-parameters.json') -Encoding UTF8
'@ | Set-Content -LiteralPath $scriptPath -Encoding UTF8

            Invoke-PostinstallScript -RootPath $TestDrive -RelativePath 'capture-parameters.ps1' -Action install -ApplicationId 'test-application' -SettingId 'test-setting'

            $received = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
            $received.Action | Should -Be 'install'
            $received.ApplicationId | Should -Be 'test-application'
            $received.SettingId | Should -Be 'test-setting'
        }
    }

    It 'accepte une application absente du manifeste lors du premier passage' {
        $manifestPath = Join-Path ([IO.Path]::GetTempPath()) "postinstall-$([guid]::NewGuid().ToString('N')).json"
        $application = [pscustomobject]@{
            id = 'test-application'
            'install-method' = 'script'
            script = 'src/scripts/test.ps1'
            'script-action' = 'test'
        }
        $plan = @([pscustomobject]@{
            Application = $application
            ConfigId = $null
            Operation = 'install'
        })
        $catalog = [pscustomobject]@{ Applications = @($application); Configurations = @() }

        Mock -ModuleName engine Invoke-PostinstallScript {}
        try {
            { Invoke-PostinstallPlan -Plan $plan -Catalog $catalog -RootPath $PSScriptRoot -ManifestPath $manifestPath } |
                Should -Not -Throw
        }
        finally {
            if (Test-Path -LiteralPath $manifestPath) { Remove-Item -LiteralPath $manifestPath -Force }
        }
    }

    It 'ne mélange pas la sortie du script avec les résultats du plan' {
        $manifestPath = Join-Path ([IO.Path]::GetTempPath()) "postinstall-$([guid]::NewGuid().ToString('N')).json"
        $scriptPath = Join-Path $TestDrive 'writes-output.ps1'
        @'
param(
    [Parameter(Mandatory)][string]$Action,
    [Parameter(Mandatory)][string]$ApplicationId,
    [string]$SettingId
)
[pscustomobject]@{ output = 'diagnostic' }
'@ | Set-Content -LiteralPath $scriptPath -Encoding UTF8

        $application = [pscustomobject]@{
            id = 'test-application'
            'install-method' = 'script'
            script = 'writes-output.ps1'
            'script-action' = 'test'
        }
        $plan = @([pscustomobject]@{
            Application = $application
            ConfigId = $null
            Operation = 'install'
        })
        $catalog = [pscustomobject]@{ Applications = @($application); Configurations = @() }

        try {
            $results = Invoke-PostinstallPlan -Plan $plan -Catalog $catalog -RootPath $TestDrive -ManifestPath $manifestPath
            @($results).Count | Should -Be 1
            $results[0].result | Should -Be 'success'
        }
        finally {
            if (Test-Path -LiteralPath $manifestPath) { Remove-Item -LiteralPath $manifestPath -Force }
        }
    }

    It 'utilise winget par défaut et respecte une source explicite' {
        $manifestPath = Join-Path ([IO.Path]::GetTempPath()) "postinstall-$([guid]::NewGuid().ToString('N')).json"
        $defaultApplication = [pscustomobject]@{
            id = 'test-application'
            'install-method' = 'winget'
            'package-id' = 'Publisher.Application'
        }
        $storeApplication = [pscustomobject]@{
            id = 'store-application'
            'install-method' = 'winget'
            'package-id' = '9STOREPACKAGE'
            'package-source' = 'msstore'
        }
        $plan = @(
            [pscustomobject]@{ Application = $defaultApplication; ConfigId = $null; Operation = 'install' }
            [pscustomobject]@{ Application = $storeApplication; ConfigId = $null; Operation = 'install' }
        )
        $catalog = [pscustomobject]@{ Applications = @($defaultApplication, $storeApplication); Configurations = @() }

        Mock -ModuleName engine Test-WingetPackageInstalled { $false }
        Mock -ModuleName engine Invoke-WingetAction {}
        try {
            $results = Invoke-PostinstallPlan -Plan $plan -Catalog $catalog -RootPath $TestDrive -ManifestPath $manifestPath

            @($results).result | Should -Not -Contain 'failed'
            Should -Invoke -ModuleName engine Test-WingetPackageInstalled -Times 1 -ParameterFilter {
                $PackageId -eq 'Publisher.Application' -and $Source -eq 'winget'
            }
            Should -Invoke -ModuleName engine Test-WingetPackageInstalled -Times 1 -ParameterFilter {
                $PackageId -eq '9STOREPACKAGE' -and $Source -eq 'msstore'
            }
            Should -Invoke -ModuleName engine Invoke-WingetAction -Times 1 -ParameterFilter {
                $Action -eq 'install' -and $PackageId -eq 'Publisher.Application' -and $Source -eq 'winget'
            }
            Should -Invoke -ModuleName engine Invoke-WingetAction -Times 1 -ParameterFilter {
                $Action -eq 'install' -and $PackageId -eq '9STOREPACKAGE' -and $Source -eq 'msstore'
            }
        }
        finally {
            if (Test-Path -LiteralPath $manifestPath) { Remove-Item -LiteralPath $manifestPath -Force }
        }
    }
}
