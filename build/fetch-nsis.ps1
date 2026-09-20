<#
  Download the portable NSIS 3.11 zip and unpack it. SourceForge hands out a lot of bad
  mirrors, so the URLs are tried in order and each download is checked before it is unpacked.
  The unpacked tree lands in -TargetDir; makensis.exe ends up in a version subfolder.
#>
param(
  [string]$TargetDir = (Join-Path (Split-Path -Parent $PSScriptRoot) 'work\nsis')
)

$ErrorActionPreference = 'Stop'
$urls = @(
  'https://cfhcable.dl.sourceforge.net/project/nsis/NSIS%203/3.11/nsis-3.11.zip',
  'https://master.dl.sourceforge.net/project/nsis/NSIS%203/3.11/nsis-3.11.zip',
  'https://downloads.sourceforge.net/project/nsis/NSIS%203/3.11/nsis-3.11.zip',
  'https://cfhcable.dl.sourceforge.net/project/nsis/NSIS%203/3.10/nsis-3.10.zip'
)

New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null
$zip = Join-Path $TargetDir 'nsis.zip'
Add-Type -AssemblyName System.IO.Compression.FileSystem

foreach ($url in $urls) {
  Write-Host "trying $url"
  if (Test-Path $zip) { Remove-Item $zip -Force }
  try {
    Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing -TimeoutSec 300
  } catch {
    Write-Warning $_.Exception.Message
    continue
  }
  try {
    $archive = [System.IO.Compression.ZipFile]::OpenRead($zip)
    $hasMakensis = [bool]($archive.Entries | Where-Object { $_.FullName -match 'makensis\.exe$' })
    $archive.Dispose()
  } catch {
    Write-Warning "not a usable zip: $($_.Exception.Message)"
    continue
  }
  if (-not $hasMakensis) { Write-Warning 'zip has no makensis.exe'; continue }
  [System.IO.Compression.ZipFile]::ExtractToDirectory($zip, $TargetDir)
  Remove-Item $zip -Force
  Write-Host "NSIS unpacked into $TargetDir"
  exit 0
}

throw 'could not download NSIS. Install it manually, put makensis.exe on PATH (or in work\nsis) and rerun.'
