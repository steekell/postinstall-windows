Describe 'Encodage des scripts PowerShell distribués' {
    It 'utilise UTF-8 avec BOM pour Windows PowerShell 5.1' {
        $rootPath = Split-Path -Parent $PSScriptRoot
        $scriptFiles = @(Get-ChildItem -LiteralPath $rootPath -File -Recurse -Include '*.ps1', '*.psm1)

        $scriptFiles.Count | Should -BeGreaterThan 0
        foreach ($scriptFile in $scriptFiles) {
            $bytes = [IO.File]::ReadAllBytes($scriptFile.FullName)
            $bytes.Count | Should -BeGreaterThan 2 -Because $scriptFile.FullName
            $bytes[0..2] | Should -Be @(0xEF, 0xBB, 0xBF) -Because $scriptFile.FullName
        }
    }
}
