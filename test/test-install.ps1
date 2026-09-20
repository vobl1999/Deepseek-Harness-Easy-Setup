<#
  End-to-end check of a built installer.

  Silently installs into -TestDir, verifies files / shortcuts / registry, exercises the
  launcher and the stopper against a stand-in bin.js, boots the real dsh web from the
  installed copy on -Port, then uninstalls and verifies the cleanup.

  usage: powershell -ExecutionPolicy Bypass -File test\test-install.ps1
         powershell -ExecutionPolicy Bypass -File test\test-install.ps1 -Setup out\DeepSeekHarness-Setup-0.1.1.exe
#>
param(
  [string]$Setup = '',
  [string]$TestDir = '',
  [int]$Port = 3999
)

$ErrorActionPreference = 'Continue'
$projRoot = Split-Path -Parent $PSScriptRoot

if (-not $Setup) {
  $Setup = (Get-ChildItem (Join-Path $projRoot 'out') -Filter 'DeepSeekHarness-Setup-*.exe' -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
}
if (-not $TestDir) { $TestDir = Join-Path $projRoot 'testinstall' }
if (-not $Setup -or -not (Test-Path $Setup)) { throw 'installer not found; pass -Setup <path>' }

$dataDir   = Join-Path $env:LOCALAPPDATA 'DeepSeekHarness'
$startMenu = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\DeepSeek Harness'
$desktop   = [Environment]::GetFolderPath('Desktop')
$regKey    = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\DeepSeekHarness'
$fails = 0

function Say([string]$text) { Write-Host "### $text" }
function Check([string]$name, [bool]$ok) {
  if ($ok) { Say "ok   - $name" } else { $script:fails++; Say "FAIL - $name" }
}
function WaitUntil([scriptblock]$test, [int]$timeoutSec = 120) {
  for ($i = 0; $i -lt $timeoutSec * 2; $i++) {
    if (& $test) { return $true }
    Start-Sleep -Milliseconds 500
  }
  return $false
}
function Running([int]$processId) {
  return [bool](Get-CimInstance Win32_Process -Filter "ProcessId=$processId" -ErrorAction SilentlyContinue)
}
function DesktopLinks() {
  return @(Get-ChildItem $desktop -Filter *.lnk -ErrorAction SilentlyContinue |
           Where-Object { $_.Name -like '*DeepSeek Harness*.lnk' })
}

Say "installer: $Setup"

# ---------------------------------------------------------------- install
if (Test-Path $TestDir) { Remove-Item $TestDir -Recurse -Force }
$p = Start-Process $Setup -ArgumentList '/S', "/D=$TestDir" -PassThru -Wait
Check 'silent install exits 0' ($p.ExitCode -eq 0)
Check 'install directory appears' (WaitUntil { Test-Path (Join-Path $TestDir 'DeepSeekHarness.exe') } 180)

foreach ($rel in @('node.exe', 'DeepSeekHarness.exe', 'DeepSeekHarnessStop.exe', 'whale.ico', 'uninstall.exe',
                   'node_modules\@deepseek-ai\dsh\lib\bin.js')) {
  Check "installed: $rel" (Test-Path (Join-Path $TestDir $rel))
}

# ---------------------------------------------------------------- shortcuts + registry
$shell = New-Object -ComObject WScript.Shell
$smLinks = @(Get-ChildItem $startMenu -Filter *.lnk -ErrorAction SilentlyContinue)
Check 'start menu holds 3 shortcuts' ($smLinks.Count -eq 3)
if ($smLinks.Count -gt 0) {
  $targets = @($smLinks | ForEach-Object { $shell.CreateShortcut($_.FullName).TargetPath })
  $icons   = @($smLinks | ForEach-Object { $shell.CreateShortcut($_.FullName).IconLocation })
  Check 'start menu: launcher shortcut'     ([bool]( $targets -contains (Join-Path $TestDir 'DeepSeekHarness.exe')))
  Check 'start menu: stopper shortcut'      ([bool]( $targets -contains (Join-Path $TestDir 'DeepSeekHarnessStop.exe')))
  Check 'start menu: uninstaller shortcut'  ([bool]( $targets -contains (Join-Path $TestDir 'uninstall.exe')))
  Check 'start menu: shortcuts use whale.ico' (@($icons | Where-Object { $_ -like '*whale.ico*' }).Count -eq 3)
}
$deskLinks = DesktopLinks
Check 'desktop holds 2 shortcuts' ($deskLinks.Count -eq 2)

Check 'uninstall entry registered' (Test-Path $regKey)
if (Test-Path $regKey) {
  $props = Get-ItemProperty $regKey
  Check 'registry points at the install dir' ($props.InstallLocation -eq $TestDir)
  Check 'registry carries an uninstall string' ([bool]($props.UninstallString -like '*uninstall.exe*'))
}

# ---------------------------------------------------------------- launcher + stopper
$binPath = Join-Path $TestDir 'node_modules\@deepseek-ai\dsh\lib\bin.js'
$binBackup = "$binPath.real"
Copy-Item $binPath $binBackup -Force
Copy-Item (Join-Path $PSScriptRoot 'fake-bin.js') $binPath -Force
if (Test-Path $dataDir) { Remove-Item $dataDir -Recurse -Force }

$pidFile = Join-Path $dataDir 'pid.txt'
$logFile = Join-Path $dataDir 'run.log'

$host1 = Start-Process (Join-Path $TestDir 'DeepSeekHarness.exe') -PassThru
Check 'launcher writes a pid file' (WaitUntil { Test-Path $pidFile } 60)
$childPid = 0
if (Test-Path $pidFile) { $childPid = [int](Get-Content $pidFile).Trim() }
Check 'launched server process is alive' (Running $childPid)
Check 'launcher keeps running as the host process' (-not $host1.HasExited)
Check 'server stdout lands in run.log' (WaitUntil { (Test-Path $logFile) -and ((Get-Content $logFile -Raw) -match 'dsh web:') } 60)

$t0 = Get-Date
$host2 = Start-Process (Join-Path $TestDir 'DeepSeekHarness.exe') -PassThru
$host2.WaitForExit(20000) | Out-Null
$elapsed = [math]::Round(((Get-Date) - $t0).TotalMilliseconds)
Check 'second launch returns immediately' ($elapsed -lt 5000)
Check 'second launch starts nothing new' (Running $childPid)

& (Join-Path $TestDir 'DeepSeekHarnessStop.exe') /s | Out-Null
Check 'stopper kills the server process' (WaitUntil { -not (Running $childPid) } 60)
Check 'stopper removes the pid file' (WaitUntil { -not (Test-Path $pidFile) } 60)
$host1.WaitForExit(20000) | Out-Null
Check 'host process exits once the server is gone' $host1.HasExited
& (Join-Path $TestDir 'DeepSeekHarnessStop.exe') /s | Out-Null
Check 'stopper is a no-op when nothing runs' ($LASTEXITCODE -eq 0)

# ---------------------------------------------------------------- real dsh boot
Copy-Item $binBackup $binPath -Force
Remove-Item $binBackup -Force
Say "booting the real dsh web from the installed copy on port $Port"
& (Join-Path $TestDir 'node.exe') (Join-Path $PSScriptRoot 'boot-check.js') $TestDir $Port
Check 'dsh web serves HTTP 200' ($LASTEXITCODE -eq 0)

# ---------------------------------------------------------------- uninstall
Say 'uninstalling'
& (Join-Path $TestDir 'uninstall.exe') /S | Out-Null
# the NSIS uninstaller copies itself to %TEMP% and the original process exits at once,
# so poll instead of trusting the exit
Check 'uninstall removes the install directory' (WaitUntil { -not (Test-Path $TestDir) } 300)
Check 'uninstall removes the start menu folder' (WaitUntil { -not (Test-Path $startMenu) } 120)
Check 'uninstall removes the desktop shortcuts' (WaitUntil { (DesktopLinks).Count -eq 0 } 120)
Check 'uninstall removes the registry entry' (WaitUntil { -not (Test-Path $regKey) } 120)

Write-Host ''
if ($fails -eq 0) { Say 'ALL CHECKS PASSED' } else { Say "$fails CHECK(S) FAILED" }
exit $fails
