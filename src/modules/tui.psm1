Set-StrictMode -Version Latest

$script:CategoryNames = @{
    system = 'Système'
    web = 'Web'
    'artificial-intelligence' = 'Intelligence artificielle'
    editor = 'Éditeur'
    communication = 'Communication'
}

function Read-PostinstallMenu {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][array]$Items,
        [string]$Footer = '↑/↓ ou j/k : naviguer | Entrée : valider | q/Échap : quitter'
    )

    $index = 0
    while ($true) {
        Clear-Host
        Write-Host $Title -ForegroundColor Cyan
        Write-Host ''
        for ($itemIndex = 0; $itemIndex -lt $Items.Count; $itemIndex++) {
            $prefix = if ($itemIndex -eq $index) { '>' } else { ' ' }
            Write-Host "$prefix $($Items[$itemIndex].name)"
        }
        Write-Host ''
        Write-Host $Footer -ForegroundColor DarkGray

        $key = [Console]::ReadKey($true)
        switch ($key.Key) {
            'UpArrow' { $index = if ($index -eq 0) { $Items.Count - 1 } else { $index - 1 } }
            'DownArrow' { $index = if ($index -eq ($Items.Count - 1)) { 0 } else { $index + 1 } }
            'Enter' { return $Items[$index] }
            'Escape' { return $null }
            default {
                if ($key.KeyChar -eq 'q') { return $null }
                if ($key.KeyChar -eq 'k') { $index = if ($index -eq 0) { $Items.Count - 1 } else { $index - 1 } }
                if ($key.KeyChar -eq 'j') { $index = if ($index -eq ($Items.Count - 1)) { 0 } else { $index + 1 } }
            }
        }
    }
}

function Show-PostinstallApplicationSelection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][array]$Applications,
        [Parameter(Mandatory)]$Profile,
        [Parameter(Mandatory)][string]$Operation,
        [Parameter(Mandatory)]$Catalog
    )

    $states = @{}
    foreach ($application in $Applications) {
        $states[$application.id] = [pscustomobject]@{
            Application = $application
            Selected = $false
            ConfigSelected = $false
            ConfigId = if (@($application.configurations).Count -gt 0) { @($application.configurations)[0] } else { $null }
        }
    }

    foreach ($profileApplication in @($Profile.applications)) {
        if ($states.ContainsKey($profileApplication.id)) {
            $states[$profileApplication.id].Selected = $true
            $states[$profileApplication.id].ConfigSelected = -not [string]::IsNullOrWhiteSpace($profileApplication.config)
            if ($states[$profileApplication.id].ConfigSelected) { $states[$profileApplication.id].ConfigId = $profileApplication.config }
        }
    }

    $orderedApplications = @()
    foreach ($category in @('system', 'web', 'artificial-intelligence', 'editor', 'communication')) {
        $orderedApplications += @($Applications | Where-Object { $_.category -eq $category })
    }

    $index = 0
    while ($true) {
        Clear-Host
        Write-Host "Applications - $Operation - profil $($Profile.name)" -ForegroundColor Cyan
        Write-Host 'Espace : application | c : configuration par défaut | Entrée : valider' -ForegroundColor DarkGray
        Write-Host '↑/↓ ou j/k : naviguer | q/Échap : quitter' -ForegroundColor DarkGray
        Write-Host ''

        for ($itemIndex = 0; $itemIndex -lt $orderedApplications.Count; $itemIndex++) {
            $application = $orderedApplications[$itemIndex]
            $state = $states[$application.id]
            $cursor = if ($itemIndex -eq $index) { '>' } else { ' ' }
            $applicationMark = if ($state.Selected) { 'x' } else { ' ' }
            $configurationMark = if ($state.ConfigSelected) { 'c' } else { ' ' }
            $categoryName = $script:CategoryNames[$application.category]
            Write-Host "$cursor [$applicationMark] [$configurationMark] $categoryName / $($application.name)"
        }

        $key = [Console]::ReadKey($true)
        switch ($key.Key) {
            'UpArrow' { $index = if ($index -eq 0) { $orderedApplications.Count - 1 } else { $index - 1 } }
            'DownArrow' { $index = if ($index -eq ($orderedApplications.Count - 1)) { 0 } else { $index + 1 } }
            'Enter' {
                $plan = @()
                foreach ($application in $orderedApplications) {
                    $state = $states[$application.id]
                    if ($state.Selected) {
                        $plan += [pscustomobject]@{
                            Application = $application
                            ConfigId = if ($state.ConfigSelected) { $state.ConfigId } else { $null }
                            Operation = $Operation
                        }
                    }
                }
                return $plan
            }
            'Escape' { return $null }
            default {
                if ($key.KeyChar -eq 'q') { return $null }
                if ($key.KeyChar -eq 'j') { $index = if ($index -eq ($orderedApplications.Count - 1)) { 0 } else { $index + 1 } }
                if ($key.KeyChar -eq 'k') { $index = if ($index -eq 0) { $orderedApplications.Count - 1 } else { $index - 1 } }
                if ($key.KeyChar -eq ' ') { $states[$orderedApplications[$index].id].Selected = -not $states[$orderedApplications[$index].id].Selected; if (-not $states[$orderedApplications[$index].id].Selected) { $states[$orderedApplications[$index].id].ConfigSelected = $false } }
                if ($key.KeyChar -eq 'c' -and @($orderedApplications[$index].configurations).Count -gt 0) { $states[$orderedApplications[$index].id].ConfigSelected = -not $states[$orderedApplications[$index].id].ConfigSelected; if ($states[$orderedApplications[$index].id].ConfigSelected) { $states[$orderedApplications[$index].id].Selected = $true } }
            }
        }
    }
}

function Show-PostinstallSummary {
    [CmdletBinding()]
    param([Parameter(Mandatory)][array]$Plan, [Parameter(Mandatory)][string]$ProfileName)

    Clear-Host
    Write-Host 'Récapitulatif' -ForegroundColor Cyan
    Write-Host "Profil : $ProfileName"
    Write-Host ''
    foreach ($item in $Plan) {
        $configuration = if ($item.ConfigId) { $item.ConfigId } else { 'aucune configuration' }
        Write-Host "- $($item.Operation) : $($item.Application.name) [$configuration]"
    }
    Write-Host ''
    Write-Host 'Confirmer l’exécution ? [o/N]' -ForegroundColor Yellow
    $key = [Console]::ReadKey($true)
    return $key.KeyChar -in @('o', 'O', 'y', 'Y')
}

function Get-PostinstallPlanFromTui {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Catalog, [Parameter(Mandatory)][array]$Profiles)

    $operation = Read-PostinstallMenu -Title 'Postinstall Windows - opération' -Items @(
        [pscustomobject]@{ name = 'Installation'; value = 'install' }
        [pscustomobject]@{ name = 'Mise à jour'; value = 'update' }
        [pscustomobject]@{ name = 'Désinstallation'; value = 'uninstall' }
    )
    if ($null -eq $operation) { return $null }

    $profileItems = @(
        $Profiles | ForEach-Object {
            [pscustomobject]@{
                name = $_.name
                value = $_
            }
        }
    )
    $profile = Read-PostinstallMenu -Title 'Postinstall Windows - profil' -Items $profileItems
    if ($null -eq $profile) { return $null }
    $profileValue = $profile.value

    $plan = Show-PostinstallApplicationSelection -Applications $Catalog.Applications -Profile $profileValue -Operation $operation.value -Catalog $Catalog
    if ($null -eq $plan) { return $null }
    return [pscustomobject]@{
        Plan = @($plan)
        ProfileName = $profileValue.name
    }
}

Export-ModuleMember -Function Get-PostinstallPlanFromTui, Show-PostinstallSummary
