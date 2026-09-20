<#
  Build the DeepSeek Harness Windows installer (single-file setup exe).

  Usage:
    powershell -ExecutionPolicy Bypass -File build\build.ps1
    powershell -ExecutionPolicy Bypass -File build\build.ps1 -DshSource C:\path\to\dsh -AppVersion 0.1.1

  Needs: Windows x64, PowerShell 5.1, .NET Framework 4.x (csc.exe), Node.js on the build machine,
  network access for the portable Node.js runtime and NSIS. Keep the project path free of spaces.
#>
[CmdletBinding()]
param(
  [string]$DshSource = '',
  [string]$NodeExe = '',
  [string]$AppVersion = '',
  [string]$WorkDir = '',
  [string]$OutDir = ''
)

$ErrorActionPreference = 'Stop'
$projRoot = Split-Path -Parent $PSScriptRoot
if (-not $WorkDir) { $WorkDir = Join-Path $projRoot 'work' }
if (-not $OutDir) { $OutDir = Join-Path $projRoot 'out' }
$srcDir = Join-Path $projRoot 'src'
$staging = Join-Path $WorkDir 'staging'
$nsisRoot = Join-Path $WorkDir 'nsis'

function Step([string]$text) { Write-Host ''; Write-Host "== $text" }
function Need([string]$p, [string]$what) { if (-not (Test-Path $p)) { throw "$what not found: $p" } }

# ------------------------------------------------------------------ node + dsh
Step 'locate node.exe'
if (-not $NodeExe) {
  $cmd = Get-Command node.exe -ErrorAction SilentlyContinue
  if (-not $cmd) { throw 'node.exe not on PATH. Install Node.js, or pass -NodeExe.' }
  $NodeExe = $cmd.Source
}
Need $NodeExe 'node.exe'
$nodeVersion = (& $NodeExe -v).Trim()
Write-Host "node $nodeVersion  ($NodeExe)"

Step 'locate the dsh package'
if (-not $DshSource) {
  $guess = Join-Path $env:APPDATA 'npm\node_modules\@deepseek-ai\dsh'
  if (Test-Path $guess) { $DshSource = $guess }
}
if (-not $DshSource) { throw 'pass -DshSource <dir>; install one with: npm i -g @deepseek-ai/dsh' }
Need (Join-Path $DshSource 'lib\bin.js') 'dsh package'
$manifest = Get-Content (Join-Path $DshSource 'package.json') -Raw | ConvertFrom-Json
if (-not $AppVersion) { $AppVersion = ($manifest.version -split '-')[0] }
Write-Host "dsh $($manifest.version)  ->  installer version $AppVersion"

# ------------------------------------------------------------------ NSIS
Step 'locate NSIS'
$makensis = $null
if (Test-Path $nsisRoot) {
  $makensis = Get-ChildItem $nsisRoot -Recurse -Filter makensis.exe -ErrorAction SilentlyContinue |
              Select-Object -First 1
}
if (-not $makensis) {
  $cmd = Get-Command makensis.exe -ErrorAction SilentlyContinue
  if ($cmd) { $makensis = $cmd }
}
if (-not $makensis) {
  Write-Host 'no local copy, downloading NSIS 3.11'
  & (Join-Path $PSScriptRoot 'fetch-nsis.ps1') -TargetDir $nsisRoot
  $makensis = Get-ChildItem $nsisRoot -Recurse -Filter makensis.exe | Select-Object -First 1
}
if (-not $makensis) { throw 'makensis.exe not found' }
Write-Host $makensis.FullName

# ------------------------------------------------------------------ staging
Step "stage the runtime into $staging"
if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }
New-Item -ItemType Directory -Force -Path $staging | Out-Null
$dshTarget = Join-Path $staging 'node_modules\@deepseek-ai\dsh'
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dshTarget) | Out-Null
robocopy $DshSource $dshTarget /E /NFL /NDL /NJH /NJS /NP | Out-Null
Write-Host 'dsh package copied'

# the shipped runtime is Windows x64 only, so other platforms' prebuilt binaries are dead weight
$prune = @(
  'node-pty\prebuilds\darwin-arm64',
  'node-pty\prebuilds\darwin-x64',
  'node-pty\prebuilds\linux-arm64',
  'node-pty\prebuilds\linux-x64',
  'node-pty\prebuilds\win32-arm64',
  '@img\sharp-wasm32'
)
$deps = Join-Path $dshTarget 'node_modules'
foreach ($rel in $prune) {
  $p = Join-Path $deps $rel
  if (Test-Path $p) { Remove-Item $p -Recurse -Force; Write-Host "pruned $rel" }
}

Step 'portable node runtime'
$nodeZip = Join-Path $WorkDir "node-$nodeVersion-win-x64.zip"
if (-not (Test-Path $nodeZip)) {
  $url = "https://nodejs.org/dist/$nodeVersion/node-$nodeVersion-win-x64.zip"
  Write-Host "downloading $url"
  Invoke-WebRequest -Uri $url -OutFile $nodeZip -UseBasicParsing -TimeoutSec 900
}
$nodeExtract = Join-Path $WorkDir 'node'
if (Test-Path $nodeExtract) { Remove-Item $nodeExtract -Recurse -Force }
Expand-Archive -Path $nodeZip -DestinationPath $nodeExtract -Force
$nodeDir = Get-ChildItem $nodeExtract -Directory | Select-Object -First 1
Copy-Item (Join-Path $nodeDir.FullName 'node.exe') (Join-Path $staging 'node.exe') -Force
Copy-Item (Join-Path $nodeDir.FullName 'LICENSE')  (Join-Path $staging 'node-license.txt') -Force

# ------------------------------------------------------------------ icon
Step 'build the icon'
& $NodeExe (Join-Path $srcDir 'icon\build-icon.js') $deps (Join-Path $srcDir 'icon\whale.svg') $staging
$icon = Join-Path $staging 'whale.ico'
Need $icon 'whale.ico'

# ------------------------------------------------------------------ launcher + stopper
Step 'compile the launcher and the stopper'
$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
Need $csc 'csc.exe (.NET Framework 4.x)'
& $csc /nologo /target:winexe /platform:anycpu /optimize "/win32icon:$icon" "/out:$staging\DeepSeekHarness.exe" (Join-Path $srcDir 'Launcher.cs')
if ($LASTEXITCODE -ne 0) { throw 'csc failed on Launcher.cs' }
& $csc /nologo /target:winexe /platform:anycpu /optimize "/win32icon:$icon" "/out:$staging\DeepSeekHarnessStop.exe" (Join-Path $srcDir 'Stopper.cs')
if ($LASTEXITCODE -ne 0) { throw 'csc failed on Stopper.cs' }

# ------------------------------------------------------------------ installer
Step 'compile the installer'
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$outFile = Join-Path $OutDir "DeepSeekHarness-Setup-$AppVersion.exe"
$utf16 = Join-Path $WorkDir 'installer.utf16.nsi'
$text = [System.IO.File]::ReadAllText((Join-Path $srcDir 'installer.nsi'), [System.Text.Encoding]::UTF8)
[System.IO.File]::WriteAllText($utf16, $text, (New-Object System.Text.UnicodeEncoding($false, $true)))
& $makensis.FullName /V2 "/DSTAGING_DIR=$staging" "/DOUT_FILE=$outFile" "/DICON_FILE=$icon" "/DAPP_VER=$AppVersion" $utf16
if ($LASTEXITCODE -ne 0) { throw 'makensis failed' }

Step 'done'
Write-Host ("{0}  ({1} MB)" -f $outFile, [math]::Round((Get-Item $outFile).Length / 1MB, 1))
