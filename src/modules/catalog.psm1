Set-StrictMode -Version Latest

function Read-PostinstallJson {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Fichier JSON introuvable : $Path"
    }

    try {
        return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    catch {
        throw "JSON invalide dans '$Path' : $($_.Exception.Message)"
    }
}

function Import-PostinstallCatalog {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$RootPath)

    $applicationsFile = Join-Path $RootPath 'catalog/applications.json'
    $configurationsFile = Join-Path $RootPath 'catalog/config/configurations.json'
    $applicationsDocument = Read-PostinstallJson -Path $applicationsFile
    $configurationsDocument = Read-PostinstallJson -Path $configurationsFile

    $applications = @($applicationsDocument.applications)
    $configurations = @($configurationsDocument.configurations)
    $applicationIds = @{}
    $configurationIds = @{}

    foreach ($application in $applications) {
        if ([string]::IsNullOrWhiteSpace($application.id) -or $applicationIds.ContainsKey($application.id)) {
            throw "Identifiant d'application absent ou dupliqué."
        }
        $applicationIds[$application.id] = $true
    }

    foreach ($configuration in $configurations) {
        if ([string]::IsNullOrWhiteSpace($configuration.id) -or $configurationIds.ContainsKey($configuration.id)) {
            throw "Identifiant de configuration absent ou dupliqué."
        }
        if ([string]::IsNullOrWhiteSpace($configuration.'config-version')) {
            throw "La configuration '$($configuration.id)' doit déclarer config-version."
        }
        if (-not $applicationIds.ContainsKey($configuration.'application-id')) {
            throw "La configuration '$($configuration.id)' référence une application inconnue."
        }
        $configurationIds[$configuration.id] = $true
    }

    foreach ($application in $applications) {
        foreach ($configurationId in @($application.configurations)) {
            if (-not $configurationIds.ContainsKey($configurationId)) {
                throw "L'application '$($application.id)' référence une configuration inconnue : $configurationId"
            }
        }
    }

    return [pscustomobject]@{
        Applications = $applications
        Configurations = $configurations
    }
}

function Import-PostinstallProfiles {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$RootPath)

    $profilesPath = Join-Path $RootPath 'catalog/profiles'
    $profiles = @(
        [pscustomobject]@{ id = 'manual'; name = 'Manuel'; applications = @() }
    )

    foreach ($path in @(Get-ChildItem -LiteralPath $profilesPath -Filter '*.json' -File -ErrorAction Stop)) {
        $profiles += Read-PostinstallJson -Path $path.FullName
    }

    return $profiles
}

function Get-PostinstallApplication {
    param([Parameter(Mandatory)]$Catalog, [Parameter(Mandatory)][string]$Id)
    return $Catalog.Applications |
        Where-Object { $_.id -eq $Id } |
        Select-Object -First 1
}

function Get-PostinstallConfiguration {
    param([Parameter(Mandatory)]$Catalog, [Parameter(Mandatory)][string]$Id)
    return $Catalog.Configurations |
        Where-Object { $_.id -eq $Id } |
        Select-Object -First 1
}

Export-ModuleMember -Function Import-PostinstallCatalog, Import-PostinstallProfiles, Get-PostinstallApplication, Get-PostinstallConfiguration
