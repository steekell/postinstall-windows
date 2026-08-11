[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('install', 'update', 'uninstall')][string]$Action,
    [Parameter(Mandatory)][string]$ApplicationId,
    [Parameter(Mandatory)][string]$SettingId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$enabled = $Action -ne 'uninstall'

function Set-RegistryDword {
    param([string]$Path, [string]$Name, [int]$Value)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }

    $registryItem = Get-ItemProperty -LiteralPath $Path
    $property = $registryItem.PSObject.Properties[$Name]
    $currentValue = if ($null -eq $property) { $null } else { $property.Value }
    if ($null -ne $currentValue -and [int]$currentValue -eq $Value) { return }

    New-ItemProperty -LiteralPath $Path -Name $Name -PropertyType DWord -Value $Value -Force | Out-Null
}

switch ($SettingId) {
    'create-library-folders' {
        $folders = @('Y:\library', 'Y:\library\downloads', 'Y:\library\documents', 'Y:\library\pictures', 'Y:\library\videos')
        if ($enabled) { $folders | ForEach-Object { New-Item -ItemType Directory -Path $_ -Force | Out-Null } }
        else { Write-Verbose 'Les dossiers de bibliothèque sont conservés lors de la désinstallation.' }
    }
    'hide-desktop-recycle-bin' {
        $path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel'
        Set-RegistryDword -Path $path -Name '{645FF040-5081-101B-9F08-00AA002F954E}' -Value ([int]$enabled)
    }
    'align-taskbar-icons-left' {
        Set-RegistryDword -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'TaskbarAl' -Value $(if ($enabled) { 0 } else { 1 })
    }
    'hide-search-box' {
        Set-RegistryDword -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' -Name 'SearchboxTaskbarMode' -Value $(if ($enabled) { 0 } else { 2 })
    }
    'hide-task-view' {
        Set-RegistryDword -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'ShowTaskViewButton' -Value ([int](-not $enabled))
    }
    'context-menu' {
        $path = 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32'
        if ($enabled) { New-Item -Path $path -Force | Out-Null; Set-Item -Path $path -Value '' }
        elseif (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Recurse -Force }
    }
    'dark-theme' {
        $path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
        Set-RegistryDword -Path $path -Name 'AppsUseLightTheme' -Value ([int](-not $enabled))
        Set-RegistryDword -Path $path -Name 'SystemUsesLightTheme' -Value ([int](-not $enabled))
    }
    default { throw "Configuration système inconnue : $SettingId" }
}
