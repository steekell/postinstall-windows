BeforeAll {
    $manifestModulePath = Join-Path $PSScriptRoot '..\src\modules\manifest.psm1'
    $catalogModulePath = Join-Path $PSScriptRoot '..\src\modules\catalog.psm1'
    $engineModulePath = Join-Path $PSScriptRoot '..\src\modules\engine.psm1'
    Import-Module $manifestModulePath -Force
    Import-Module $catalogModulePath -Force
    Import-Module $engineModulePath -Force
}

Describe 'Moteur postinstallation' {
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
}
