Set-StrictMode -Version Latest

function Test-WingetAvailable {
    return $null -ne (Get-Command winget -ErrorAction SilentlyContinue)
}

function Test-WingetPackageInstalled {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$PackageId)

    if (-not (Test-WingetAvailable)) { return $false }
    $output = & winget list --id $PackageId --exact --accept-source-agreements --disable-interactivity 2>&1
    return ($LASTEXITCODE -eq 0 -and (@($output) -join "`n") -match [regex]::Escape($PackageId))
}

function Invoke-WingetAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('install', 'update', 'uninstall')][string]$Action,
        [Parameter(Mandatory)][string]$PackageId,
        [string]$Source
    )

    if (-not (Test-WingetAvailable)) { throw 'WinGet est introuvable dans le PATH.' }
    $arguments = @($Action, '--id', $PackageId, '--exact', '--accept-source-agreements', '--disable-interactivity')
    if ($Action -ne 'uninstall') { $arguments += '--accept-package-agreements' }
    if (-not [string]::IsNullOrWhiteSpace($Source)) { $arguments += @('--source', $Source) }
    # Ne pas laisser la sortie native remonter dans Invoke-PostinstallPlan :
    # cette fonction doit émettre uniquement son résultat logique (ou une
    # exception), sinon le rapport final reçoit des chaînes WinGet.
    $wingetOutput = & winget @arguments 2>&1
    $wingetExitCode = $LASTEXITCODE
    $wingetOutput | ForEach-Object { Write-Host $_ }
    if ($wingetExitCode -ne 0) { throw "WinGet a échoué ($wingetExitCode) pour '$PackageId'." }
}

Export-ModuleMember -Function Test-WingetAvailable, Test-WingetPackageInstalled, Invoke-WingetAction
