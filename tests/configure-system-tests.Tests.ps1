BeforeAll {
    $scriptPath = Join-Path $PSScriptRoot '..\src\scripts\configure-system.ps1'
}

Describe 'Dossiers de bibliothèque' {
    It 'crée les dossiers Pictures, Music et Videos' {
        Mock -CommandName New-Item

        & $scriptPath -Action install -ApplicationId 'create-library-folders' -SettingId 'create-library-folders'

        Should -Invoke -CommandName New-Item -Times 1 -Exactly -ParameterFilter { $Path -eq 'Y:\library\pictures' -and $ItemType -eq 'Directory' -and $Force }
        Should -Invoke -CommandName New-Item -Times 1 -Exactly -ParameterFilter { $Path -eq 'Y:\library\music' -and $ItemType -eq 'Directory' -and $Force }
        Should -Invoke -CommandName New-Item -Times 1 -Exactly -ParameterFilter { $Path -eq 'Y:\library\videos' -and $ItemType -eq 'Directory' -and $Force }
    }
}
