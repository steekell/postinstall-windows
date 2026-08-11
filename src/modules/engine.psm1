Set-StrictMode -Version Latest

function Get-ManifestApplication {
    param([Parameter(Mandatory)]$Manifest, [Parameter(Mandatory)][string]$ApplicationId)
    # Une application absente du manifeste est normale lors de la première
    # exécution. Ne jamais indexer directement un tableau vide sous
    # StrictMode : cela provoque une IndexOutOfRangeException.
    return $Manifest.applications |
        Where-Object { $_.'application-id' -eq $ApplicationId } |
        Select-Object -First 1
}

function Invoke-PostinstallScript {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RootPath,
        [Parameter(Mandatory)][string]$RelativePath,
        [Parameter(Mandatory)][ValidateSet('install', 'update', 'uninstall')][string]$Action,
        [Parameter(Mandatory)][string]$ApplicationId,
        [string]$SettingId
    )

    $scriptPath = Join-Path $RootPath $RelativePath
    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) { throw "Script introuvable : $scriptPath" }
    $arguments = @('-Action', $Action, '-ApplicationId', $ApplicationId)
    if (-not [string]::IsNullOrWhiteSpace($SettingId)) { $arguments += @('-SettingId', $SettingId) }
    & $scriptPath @arguments
    if (-not $?) { throw "Le script '$RelativePath' a échoué." }
}

function Invoke-ConfigurationBackups {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Configuration, [string]$ManifestPath)

    $backups = @()
    foreach ($path in @($Configuration.'managed-paths')) {
        if (-not [string]::IsNullOrWhiteSpace($path)) {
            $backup = New-ConfigurationBackup -Path $path
            if ($null -ne $backup) { $backups += $backup }
        }
    }
    if ($Configuration.PSObject.Properties.Name -contains 'managed-registry') {
        foreach ($registryPath in @($Configuration.'managed-registry')) {
            if (-not [string]::IsNullOrWhiteSpace($registryPath)) {
                $backup = New-RegistryConfigurationBackup -RegistryPath $registryPath -ManifestPath $ManifestPath
                if ($null -ne $backup) { $backups += $backup }
            }
        }
    }
    return $backups
}

function Invoke-PostinstallPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Plan,
        [Parameter(Mandatory)]$Catalog,
        [Parameter(Mandatory)][string]$RootPath,
        [string]$ManifestPath
    )

    $manifest = Get-PostinstallManifest -Path $ManifestPath
    $results = @()

    foreach ($selection in @($Plan)) {
        $application = $selection.Application
        $configuration = $null
        if (-not [string]::IsNullOrWhiteSpace($selection.ConfigId)) {
            $configuration = Get-PostinstallConfiguration -Catalog $Catalog -Id $selection.ConfigId
        }
        $previous = Get-ManifestApplication -Manifest $manifest -ApplicationId $application.id
        $backups = @()
        $result = 'success'
        $message = $null

        try {
            $configScript = $null
            $configScriptAction = $null
            $applicationScript = $null
            if ($application.PSObject.Properties.Name -contains 'script') { $applicationScript = $application.script }
            if ($null -ne $configuration -and $configuration.PSObject.Properties.Name -contains 'configuration-script') {
                $configScript = $configuration.'configuration-script'
                $configScriptAction = $configuration.'script-action'
            }
            $configChanged = $null -ne $configuration -and (
                $null -eq $previous -or
                $previous.'config-version' -ne $configuration.'config-version' -or
                $previous.'configuration-id' -ne $configuration.id
            )

            if ($selection.Operation -in @('install', 'update') -and $configChanged) {
                $backups = @(Invoke-ConfigurationBackups -Configuration $configuration -ManifestPath $ManifestPath)
            }

            if ($application.'install-method' -eq 'winget') {
                $packageSource = $null
                if ($application.PSObject.Properties.Name -contains 'package-source') { $packageSource = $application.'package-source' }
                $installed = Test-WingetPackageInstalled -PackageId $application.'package-id'
                if ($selection.Operation -eq 'install' -and -not $installed) {
                    Invoke-WingetAction -Action install -PackageId $application.'package-id' -Source $packageSource
                }
                elseif ($selection.Operation -eq 'update' -and $installed) {
                    Invoke-WingetAction -Action update -PackageId $application.'package-id' -Source $packageSource
                }
                elseif ($selection.Operation -eq 'uninstall' -and $installed) {
                    Invoke-WingetAction -Action uninstall -PackageId $application.'package-id' -Source $packageSource
                }
            }
            elseif ($application.'install-method' -eq 'script') {
                Invoke-PostinstallScript -RootPath $RootPath -RelativePath $applicationScript -Action $selection.Operation -ApplicationId $application.id -SettingId $application.'script-action'
            }
            else {
                throw "Méthode d'installation inconnue pour '$($application.id)'."
            }

            if ($null -ne $configScript -and $applicationScript -ne $configScript -and (($selection.Operation -ne 'uninstall' -and $configChanged) -or $selection.Operation -eq 'uninstall')) {
                Invoke-PostinstallScript -RootPath $RootPath -RelativePath $configScript -Action $selection.Operation -ApplicationId $application.id -SettingId $configScriptAction
            }
        }
        catch {
            $result = 'failed'
            $message = $_.Exception.Message
        }

        $operation = [pscustomobject]@{
            'timestamp-utc' = (Get-Date).ToUniversalTime().ToString('o')
            operation = $selection.Operation
            'application-id' = $application.id
            'configuration-id' = if ($null -eq $configuration) { $null } else { $configuration.id }
            'config-version' = if ($null -eq $configuration) { $null } else { $configuration.'config-version' }
            result = $result
            message = $message
            backups = @($backups)
        }
        Add-PostinstallOperation -Manifest $manifest -Operation $operation
        $results += $operation
    }

    Save-PostinstallManifest -Manifest $manifest -Path $ManifestPath
    return $results
}

Export-ModuleMember -Function Invoke-PostinstallPlan
