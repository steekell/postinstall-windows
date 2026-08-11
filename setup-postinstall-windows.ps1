[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repository = 'steekell/postinstall-windows'
$version = 'v0.1.0'
$archiveUrl = "https://github.com/$repository/archive/refs/tags/$version.zip"
$temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) "postinstall-windows-$version-$([guid]::NewGuid().ToString('N'))"
$archivePath = Join-Path ([IO.Path]::GetTempPath()) "postinstall-windows-$version-$([guid]::NewGuid().ToString('N')).zip"

try {
    New-Item -ItemType Directory -Path $temporaryRoot -Force | Out-Null
    Write-Host "Téléchargement de Postinstall Windows $version..."
    Invoke-WebRequest -Uri $archiveUrl -OutFile $archivePath -UseBasicParsing
    Expand-Archive -LiteralPath $archivePath -DestinationPath $temporaryRoot -Force

    $projectRoot = @(Get-ChildItem -LiteralPath $temporaryRoot -Directory)[0].FullName
    $entryPoint = Join-Path $projectRoot 'setup-postinstall.ps1'
    if (-not (Test-Path -LiteralPath $entryPoint -PathType Leaf)) {
        throw "Point d'entrée absent dans l'archive $version."
    }

    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
    & $entryPoint
    if (-not $?) { throw "L'installation Postinstall Windows $version a échoué." }
}
finally {
    if (Test-Path -LiteralPath $archivePath) { Remove-Item -LiteralPath $archivePath -Force -ErrorAction SilentlyContinue }
    if (Test-Path -LiteralPath $temporaryRoot) { Remove-Item -LiteralPath $temporaryRoot -Recurse -Force -ErrorAction SilentlyContinue }
}
