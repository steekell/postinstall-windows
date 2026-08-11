BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..\src\modules\catalog.psm1'
    Import-Module $modulePath -Force
}

Describe 'Catalogue Postinstall Windows' {
    It 'charge les applications et les configurations versionnées' {
        $catalog = Import-PostinstallCatalog -RootPath (Join-Path $PSScriptRoot '..')

        @($catalog.Applications).Count | Should -BeGreaterThan 0
        @($catalog.Configurations).Count | Should -BeGreaterThan 0
        @($catalog.Configurations | Where-Object { [string]::IsNullOrWhiteSpace($_.'config-version') }).Count | Should -Be 0
    }
}
