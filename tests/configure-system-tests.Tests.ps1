BeforeAll {
    $scriptPath = Join-Path $PSScriptRoot '..\src\scripts\configure-system.ps1'
    $advancedPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
}

Describe 'Configuration système' {
    BeforeEach {
        Mock Test-Path { $true }
        Mock Get-ItemPropertyValue { 1 }
        Mock New-Item {}
        Mock New-ItemProperty {}
        Mock Set-ItemProperty {}
    }

    It 'aligne les icônes de la barre des tâches à gauche' {
        & $scriptPath -Action install -ApplicationId 'align-taskbar-icons-left' -SettingId 'align-taskbar-icons-left'

        Should -Invoke New-Item -Times 0
        Should -Invoke Set-ItemProperty -Times 1 -ParameterFilter {
            $LiteralPath -eq $advancedPath -and $Name -eq 'TaskbarAl' -and $Value -eq 0
        }
    }

    It 'masque la vue des tâches sans recréer la clé existante' {
        & $scriptPath -Action install -ApplicationId 'hide-task-view' -SettingId 'hide-task-view'

        Should -Invoke New-Item -Times 0
        Should -Invoke Set-ItemProperty -Times 1 -ParameterFilter {
            $LiteralPath -eq $advancedPath -and $Name -eq 'ShowTaskViewButton' -and $Value -eq 0
        }
    }

    It 'ne réécrit pas une valeur déjà conforme' {
        Mock Get-ItemPropertyValue { 0 }

        & $scriptPath -Action install -ApplicationId 'hide-task-view' -SettingId 'hide-task-view'

        Should -Invoke New-ItemProperty -Times 0
        Should -Invoke Set-ItemProperty -Times 0
    }
}
