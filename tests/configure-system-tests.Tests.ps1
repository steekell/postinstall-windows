BeforeAll {
    $scriptPath = Join-Path $PSScriptRoot '..\src\scripts\configure-system.ps1'
    $advancedPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
}

Describe 'Configuration système' {
    BeforeEach {
        Mock Test-Path { $true }
        Mock Get-ItemProperty { [pscustomobject]@{ TaskbarAl = 1; ShowTaskViewButton = 1 } }
        Mock New-Item {}
        Mock New-ItemProperty {}
    }

    It 'aligne les icônes de la barre des tâches à gauche' {
        & $scriptPath -Action install -ApplicationId 'align-taskbar-icons-left' -SettingId 'align-taskbar-icons-left'

        Should -Invoke New-Item -Times 0
        Should -Invoke New-ItemProperty -Times 1 -ParameterFilter {
            $LiteralPath -eq $advancedPath -and $Name -eq 'TaskbarAl' -and
                $PropertyType -eq 'DWord' -and $Value -eq 0 -and $Force
        }
    }

    It 'masque la vue des tâches sans recréer la clé existante' {
        & $scriptPath -Action install -ApplicationId 'hide-task-view' -SettingId 'hide-task-view'

        Should -Invoke New-Item -Times 0
        Should -Invoke New-ItemProperty -Times 1 -ParameterFilter {
            $LiteralPath -eq $advancedPath -and $Name -eq 'ShowTaskViewButton' -and
                $PropertyType -eq 'DWord' -and $Value -eq 0 -and $Force
        }
    }

    It 'crée les valeurs de barre des tâches lorsqu’elles sont absentes' {
        Mock Get-ItemProperty { [pscustomobject]@{} }

        & $scriptPath -Action install -ApplicationId 'align-taskbar-icons-left' -SettingId 'align-taskbar-icons-left'
        & $scriptPath -Action install -ApplicationId 'hide-task-view' -SettingId 'hide-task-view'

        Should -Invoke New-ItemProperty -Times 1 -ParameterFilter {
            $LiteralPath -eq $advancedPath -and $Name -eq 'TaskbarAl' -and $Value -eq 0 -and $Force
        }
        Should -Invoke New-ItemProperty -Times 1 -ParameterFilter {
            $LiteralPath -eq $advancedPath -and $Name -eq 'ShowTaskViewButton' -and $Value -eq 0 -and $Force
        }
    }

    It 'ne réécrit pas une valeur déjà conforme' {
        Mock Get-ItemProperty { [pscustomobject]@{ ShowTaskViewButton = 0 } }

        & $scriptPath -Action install -ApplicationId 'hide-task-view' -SettingId 'hide-task-view'

        Should -Invoke New-ItemProperty -Times 0
    }
}
