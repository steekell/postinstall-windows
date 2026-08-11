[CmdletBinding()]
param([string]$ManifestPath)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($env:OS -ne 'Windows_NT') {
    throw 'Ce script doit être exécuté sur Windows.'
}

$modulePath = Join-Path $PSScriptRoot 'src/modules'
Import-Module (Join-Path $modulePath 'catalog.psm1') -Force
Import-Module (Join-Path $modulePath 'manifest.psm1') -Force
Import-Module (Join-Path $modulePath 'package-managers.psm1') -Force
Import-Module (Join-Path $modulePath 'engine.psm1') -Force
Import-Module (Join-Path $modulePath 'tui.psm1') -Force

$catalog = Import-PostinstallCatalog -RootPath $PSScriptRoot
$profiles = Import-PostinstallProfiles -RootPath $PSScriptRoot
$selection = Get-PostinstallPlanFromTui -Catalog $catalog -Profiles $profiles
if ($null -eq $selection) {
    Write-Host 'Opération annulée.'
    exit 0
}
$plan = @($selection.Plan)
if ($plan.Count -eq 0) {
    Write-Host 'Aucune application sélectionnée.'
    exit 0
}

$confirmed = Show-PostinstallSummary -Plan $plan -ProfileName $selection.ProfileName
if (-not $confirmed) {
    Write-Host 'Opération annulée.'
    exit 0
}

$results = Invoke-PostinstallPlan -Plan $plan -Catalog $catalog -RootPath $PSScriptRoot -ManifestPath $ManifestPath
Write-Host ''
Write-Host 'Rapport final' -ForegroundColor Cyan
foreach ($result in $results) {
    $color = if ($result.result -eq 'success') { 'Green' } else { 'Red' }
    Write-Host "[$($result.result)] $($result.operation) $($result.'application-id')" -ForegroundColor $color
    if ($result.message) { Write-Host "  $($result.message)" }
}
