[CmdletBinding()]
param([switch]$NonInteractive)

$ErrorActionPreference = 'Stop'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$desktop = [Environment]::GetFolderPath('Desktop')
$logPath = Join-Path $desktop "Recover-Official-Codex-$stamp.log"

function Write-RecoveryLog([string]$Message) {
  $line = "[$(Get-Date -Format o)] $Message"
  Add-Content -LiteralPath $logPath -Encoding utf8 -Value $line
  Write-Host $line
}

try {
  Write-RecoveryLog 'Recovery started.'
  $stateRoot = Join-Path $env:LOCALAPPDATA 'CodexDreamSkin'
  foreach ($stateName in @('watcher-state.json', 'state.json')) {
    $statePath = Join-Path $stateRoot $stateName
    if (Test-Path -LiteralPath $statePath) {
      try {
        $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
        foreach ($property in @('watcherPid', 'injectorPid')) {
          if ($state.$property) {
            Stop-Process -Id ([int]$state.$property) -Force -ErrorAction SilentlyContinue
          }
        }
      } catch {}
      Remove-Item -LiteralPath $statePath -Force -ErrorAction SilentlyContinue
    }
  }

  $startupShortcut = Join-Path ([Environment]::GetFolderPath('Startup')) 'Codex Dream Skin Watcher.lnk'
  Remove-Item -LiteralPath $startupShortcut -Force -ErrorAction SilentlyContinue

  Get-Process -Name ChatGPT, codex -ErrorAction SilentlyContinue |
    Stop-Process -Force -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 2
  Get-Process -Name ChatGPT, codex -ErrorAction SilentlyContinue |
    Stop-Process -Force -ErrorAction SilentlyContinue
  Write-RecoveryLog 'Stopped all Codex processes.'

  $config = Join-Path $HOME '.codex\config.toml'
  $original = Join-Path $stateRoot 'config.before-dream-skin.toml'
  if (Test-Path -LiteralPath $original) {
    if (Test-Path -LiteralPath $config) {
      Copy-Item -LiteralPath $config -Destination "$config.before-recovery-$stamp.bak" -Force
    }
    Copy-Item -LiteralPath $original -Destination $config -Force
    Write-RecoveryLog 'Restored the exact pre-skin config.toml backup.'
  } else {
    Write-RecoveryLog 'Pre-skin config backup was not found; current config.toml was left unchanged.'
  }

  $webState = Join-Path $env:APPDATA 'Codex\web\Codex'
  if (Test-Path -LiteralPath $webState) {
    $webBackup = Join-Path (Split-Path -Parent $webState) "Codex.before-klee-$stamp-$PID"
    Move-Item -LiteralPath $webState -Destination $webBackup
    Write-RecoveryLog "Moved renderer cache to: $webBackup"
  }

  $package = Get-AppxPackage OpenAI.Codex -ErrorAction Stop |
    Sort-Object Version -Descending | Select-Object -First 1
  $manifest = Get-AppxPackageManifest -Package $package.PackageFullName
  $application = @($manifest.Package.Applications.Application) | Select-Object -First 1
  $appId = [string]$application.Id
  if (-not $appId) { throw 'Could not resolve the official Codex application ID.' }
  $aumid = "$($package.PackageFamilyName)!$appId"
  Start-Process -FilePath (Join-Path $env:WINDIR 'explorer.exe') -ArgumentList "shell:AppsFolder\$aumid"
  Write-RecoveryLog "Launched official Codex entry: $aumid"
  Write-RecoveryLog 'Recovery completed. auth.json, projects, and conversations were not deleted.'

  if (-not $NonInteractive) {
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show(
      "官方Codex恢复已完成。`n`n如果仍停在Logo，请把桌面的恢复日志发给我。`n没有删除登录文件、项目或聊天记录。",
      'Codex恢复完成', 'OK', 'Information'
    ) | Out-Null
  }
} catch {
  $message = $_.Exception.Message
  try { Write-RecoveryLog "Recovery failed: $message" } catch {}
  if (-not $NonInteractive) {
    try {
      Add-Type -AssemblyName System.Windows.Forms
      [System.Windows.Forms.MessageBox]::Show(
        "恢复过程中出现错误：$message`n`n请把桌面的恢复日志发给我。",
        'Codex恢复失败', 'OK', 'Error'
      ) | Out-Null
    } catch {}
    exit 1
  }
  throw
}
