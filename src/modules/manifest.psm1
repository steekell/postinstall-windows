Set-StrictMode -Version Latest

function Get-PostinstallManifestPath {
    [CmdletBinding()]
    param([string]$Path)

    if (-not [string]::IsNullOrWhiteSpace($Path)) { return $Path }
    if (-not [string]::IsNullOrWhiteSpace($env:POSTINSTALL_MANIFEST_PATH)) { return $env:POSTINSTALL_MANIFEST_PATH }
    return Join-Path $env:ProgramData 'Postinstall-Windows/manifest.json'
}

function Get-PostinstallManifest {
    [CmdletBinding()]
    param([string]$Path)

    $manifestPath = Get-PostinstallManifestPath -Path $Path
    if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
        return Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    }

    return [pscustomobject]@{
        'schema-version' = 1
        'tool-version' = '0.1.4'
        applications = @()
        operations = @()
    }
}

function Save-PostinstallManifest {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Manifest, [string]$Path)

    $manifestPath = Get-PostinstallManifestPath -Path $Path
    $directory = Split-Path -Parent $manifestPath
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
    $temporaryPath = "$manifestPath.$([guid]::NewGuid().ToString('N')).tmp"
    $Manifest | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $temporaryPath -Encoding UTF8
    Move-Item -LiteralPath $temporaryPath -Destination $manifestPath -Force
}

function New-ConfigurationBackup {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }

    $directory = Split-Path -Parent $Path
    $extension = [IO.Path]::GetExtension($Path)
    $name = [IO.Path]::GetFileNameWithoutExtension($Path)
    $timestamp = (Get-Date).ToUniversalTime()
    do {
        $stamp = $timestamp.ToString('yyyyMMddTHHmmssZ', [Globalization.CultureInfo]::InvariantCulture)
        $backupName = if ([string]::IsNullOrEmpty($extension)) { "$name.bak.$stamp" } else { "$name.bak.$stamp$extension" }
        $backupPath = Join-Path $directory $backupName
        $timestamp = $timestamp.AddSeconds(1)
    } while (Test-Path -LiteralPath $backupPath)

    Copy-Item -LiteralPath $Path -Destination $backupPath -Force -ErrorAction Stop
    return [pscustomobject]@{
        'original-path' = $Path
        'backup-path' = $backupPath
        'timestamp-utc' = $stamp
        'original-hash' = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    }
}

function New-RegistryConfigurationBackup {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$RegistryPath, [string]$ManifestPath)

    $providerPath = $RegistryPath
    $nativePath = $RegistryPath -replace '^HKCU:\\', 'HKEY_CURRENT_USER\' -replace '^HKLM:\\', 'HKEY_LOCAL_MACHINE\'
    if (-not (Test-Path -LiteralPath $providerPath)) { return $null }

    $backupDirectory = Join-Path (Split-Path -Parent (Get-PostinstallManifestPath -Path $ManifestPath)) 'backups'
    New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null
    $name = (($nativePath -split '\\')[-1] -replace '[^a-zA-Z0-9_-]', '-')
    $timestamp = (Get-Date).ToUniversalTime()
    do {
        $stamp = $timestamp.ToString('yyyyMMddTHHmmssZ', [Globalization.CultureInfo]::InvariantCulture)
        $backupPath = Join-Path $backupDirectory "$name.bak.$stamp.reg"
        $timestamp = $timestamp.AddSeconds(1)
    } while (Test-Path -LiteralPath $backupPath)

    & reg.exe export $nativePath $backupPath /y | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Impossible de sauvegarder la clé registre '$RegistryPath'." }
    return [pscustomobject]@{
        'original-path' = "registry:$RegistryPath"
        'backup-path' = $backupPath
        'timestamp-utc' = $stamp
        'original-hash' = (Get-FileHash -LiteralPath $backupPath -Algorithm SHA256).Hash
    }
}

function Add-PostinstallOperation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Manifest,
        [Parameter(Mandatory)]$Operation
    )

    $Manifest.operations = @($Manifest.operations) + $Operation
    $current = $Manifest.applications |
        Where-Object { $_.'application-id' -eq $Operation.'application-id' } |
        Select-Object -First 1
    if ($null -eq $current) {
        $current = [pscustomobject]@{
            'application-id' = $Operation.'application-id'
            'installed' = $false
            'package-version' = $null
            'configuration-id' = $null
            'config-version' = $null
            'backups' = @()
        }
        $Manifest.applications = @($Manifest.applications) + $current
    }

    if ($Operation.result -eq 'success') {
        $current.installed = $Operation.operation -ne 'uninstall'
        if ($Operation.operation -eq 'uninstall') {
            $current.'config-version' = $null
            $current.'configuration-id' = $null
        }
        else {
            if ($Operation.PSObject.Properties.Name -contains 'config-version') { $current.'config-version' = $Operation.'config-version' }
            if ($Operation.PSObject.Properties.Name -contains 'configuration-id') { $current.'configuration-id' = $Operation.'configuration-id' }
        }
        if ($Operation.PSObject.Properties.Name -contains 'backups') { $current.backups = @($current.backups) + @($Operation.backups) }
    }
}

Export-ModuleMember -Function Get-PostinstallManifestPath, Get-PostinstallManifest, Save-PostinstallManifest, New-ConfigurationBackup, New-RegistryConfigurationBackup, Add-PostinstallOperation
