Describe 'Bootstrap versionné' {
    It 'utilise la version publiée dans le script, le manifeste et le README' {
        $rootPath = Join-Path $PSScriptRoot '..'
        $bootstrap = Get-Content -LiteralPath (Join-Path $rootPath 'setup-postinstall-windows.ps1') -Raw
        $manifestModule = Get-Content -LiteralPath (Join-Path $rootPath 'src/modules/manifest.psm1') -Raw
        $readme = Get-Content -LiteralPath (Join-Path $rootPath 'README.md') -Raw

        $bootstrap | Should -Match '\$version = ''v0\.1\.5'''
        $manifestModule | Should -Match "'tool-version' = '0\.1\.5'"
        $readme | Should -Match '/v0\.1\.5/setup-postinstall-windows\.ps1'
        $readme | Should -Not -Match '/v0\.1\.0/setup-postinstall-windows\.ps1'
    }
}
