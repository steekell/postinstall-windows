Describe 'Encodage des scripts PowerShell distribués' {
    It 'utilise UTF-8 avec BOM pour les scripts charges depuis un fichier' {
        $rootPath = Split-Path -Parent $PSScriptRoot
        $scriptFiles = @(Get-ChildItem -LiteralPath $rootPath -File -Recurse -Include '*.ps1', '*.psm1' |
            Where-Object { $_.Name -ne 'setup-postinstall-windows.ps1' })

        $scriptFiles.Count | Should -BeGreaterThan 0
        foreach ($scriptFile in $scriptFiles) {
            $bytes = [IO.File]::ReadAllBytes($scriptFile.FullName)
            $bytes.Count | Should -BeGreaterThan 2 -Because $scriptFile.FullName
            $bytes[0..2] | Should -Be @(0xEF, 0xBB, 0xBF) -Because $scriptFile.FullName
        }
    }

    It 'garde le bootstrap irm-iex sans BOM et en ASCII' {
        $bootstrapPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'setup-postinstall-windows.ps1'
        $bytes = [IO.File]::ReadAllBytes($bootstrapPath)

        $bytes[0..2] | Should -Not -Be @(0xEF, 0xBB, 0xBF)
        ($bytes | Where-Object { $_ -gt 0x7F }).Count | Should -Be 0
    }
}
