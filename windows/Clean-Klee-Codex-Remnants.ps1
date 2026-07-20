[CmdletBinding()]
param(
  [switch]$Yes,
  [switch]$NoUi,
  [string]$HomePath = $HOME,
  [string]$LocalAppDataPath = $env:LOCALAPPDATA,
  [string]$RoamingAppDataPath = $env:APPDATA,
  [string]$DesktopPath = [Environment]::GetFolderPath('Desktop'),
  [string]$StartupPath = [Environment]::GetFolderPath('Startup')
)

$ErrorActionPreference = 'Stop'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$desktop = $DesktopPath
$backupRoot = Join-Path $desktop "KleeSkinCleanup-Backup-$stamp"
$logPath = Join-Path $desktop "KleeSkinCleanup-$stamp.log"
$script:Changed = 0
$script:Warnings = New-Object System.Collections.Generic.List[string]

if (-not $NoUi) { Add-Type -AssemblyName System.Windows.Forms }

function Write-CleanupLog([string]$Message) {
  $line = "[$(Get-Date -Format o)] $Message"
  Add-Content -LiteralPath $logPath -Encoding utf8 -Value $line
  Write-Host $line
}

function Add-CleanupWarning([string]$Message) {
  $script:Warnings.Add($Message)
  Write-CleanupLog "WARNING: $Message"
}

function Backup-File {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Name
  )
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return }
  New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null
  Copy-Item -LiteralPath $Path -Destination (Join-Path $backupRoot $Name) -Force
  Write-CleanupLog "Backed up: $Path"
}

function Move-ExactItemToBackup {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$ExpectedLeaf
  )
  if (-not (Test-Path -LiteralPath $Path)) { return }
  if ((Split-Path -Leaf $Path) -ne $ExpectedLeaf) {
    throw "Safety check rejected unexpected target: $Path"
  }
  try {
    New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null
    $destination = Join-Path $backupRoot $ExpectedLeaf
    if (Test-Path -LiteralPath $destination) { throw "Backup destination already exists: $destination" }
    Move-Item -LiteralPath $Path -Destination $destination -Force -ErrorAction Stop
    $script:Changed++
    Write-CleanupLog "Moved exact legacy target to backup: $Path -> $destination"
  } catch {
    Add-CleanupWarning "无法移动 $Path：$($_.Exception.Message)"
  }
}

function Remove-ExactFile {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$ExpectedLeaf
  )
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return }
  if ((Split-Path -Leaf $Path) -ne $ExpectedLeaf) {
    throw "Safety check rejected unexpected file: $Path"
  }
  try {
    Remove-Item -LiteralPath $Path -Force -ErrorAction Stop
    $script:Changed++
    Write-CleanupLog "Removed exact legacy file: $Path"
  } catch {
    Add-CleanupWarning "无法删除 $Path：$($_.Exception.Message)"
  }
}

function Stop-VerifiedLegacyHelpers {
  param([Parameter(Mandatory = $true)][string]$StateRoot)
  foreach ($stateName in @('state.json', 'watcher-state.json')) {
    $statePath = Join-Path $StateRoot $stateName
    if (-not (Test-Path -LiteralPath $statePath -PathType Leaf)) { continue }
    try {
      $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
      foreach ($property in @('injectorPid', 'watcherPid')) {
        if (-not $state.$property) { continue }
        $savedPid = [int]$state.$property
        $processInfo = Get-CimInstance Win32_Process -Filter "ProcessId=$savedPid" -ErrorAction SilentlyContinue
        if ($processInfo -and $processInfo.CommandLine -match '(?i)CodexDreamSkin|KleeCodexSkin|watch-dream-skin|injector\.mjs') {
          Stop-Process -Id $savedPid -Force -ErrorAction SilentlyContinue
          Write-CleanupLog "Stopped verified legacy helper PID: $savedPid"
        }
      }
    } catch {
      Add-CleanupWarning "无法核对旧版进程状态 $statePath；没有按名称批量结束其他进程。"
    }
  }
}

function Restore-Config {
  param(
    [Parameter(Mandatory = $true)][string]$StateRoot,
    [Parameter(Mandatory = $true)][string]$CodexHome
  )
  $config = Join-Path $CodexHome 'config.toml'
  $original = Join-Path $StateRoot 'config.before-dream-skin.toml'
  if (Test-Path -LiteralPath $config -PathType Leaf) {
    Backup-File -Path $config -Name 'config.toml.before-klee-cleanup.bak'
  }
  if (-not (Test-Path -LiteralPath $config -PathType Leaf)) {
    Write-CleanupLog 'No active config.toml was found; no configuration file was created.'
    return
  }
  $originalAppearance = @()
  if (Test-Path -LiteralPath $original -PathType Leaf) {
    Backup-File -Path $original -Name 'config.before-dream-skin.toml'
    $originalAppearance = @(Get-Content -LiteralPath $original | Where-Object {
      $_ -match '^\s*(appearanceTheme|appearanceLightCodeThemeId|appearanceLightChromeTheme)\s*='
    })
  }
  $content = Get-Content -LiteralPath $config -Raw
  $pattern = '(?m)^\s*(appearanceTheme|appearanceLightCodeThemeId|appearanceLightChromeTheme)\s*=.*(?:\r?\n|$)'
  $cleaned = [regex]::Replace($content, $pattern, '')
  if ($originalAppearance.Count -gt 0) {
    $cleaned = $cleaned.TrimEnd() + [Environment]::NewLine + ($originalAppearance -join [Environment]::NewLine) + [Environment]::NewLine
  }
  if ($cleaned -ne $content) {
    [System.IO.File]::WriteAllText($config, $cleaned, [System.Text.UTF8Encoding]::new($false))
    $script:Changed++
    Write-CleanupLog 'Restored only the original appearance keys and preserved every other current config entry.'
  } else {
    Write-CleanupLog 'No v1.x appearance keys were found in config.toml.'
  }
}

try {
  if (-not $Yes -and -not $NoUi) {
    $answer = [System.Windows.Forms.MessageBox]::Show(
      "这个脚本只清理旧版可莉 Codex 皮肤残留。`n`n会处理：旧版辅助进程、启动项、状态目录，以及旧版写入的三项外观配置。`n`n不会处理：Codex 应用包、缓存、登录状态、sessions、archived_sessions 或项目目录。`n`n是否继续？",
      '清理旧版可莉皮肤残留',
      [System.Windows.Forms.MessageBoxButtons]::YesNo,
      [System.Windows.Forms.MessageBoxIcon]::Warning
    )
    if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { return }
  }

  New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null
  Write-CleanupLog 'Klee v1.x cleanup started.'

  $stateRoot = Join-Path $LocalAppDataPath 'CodexDreamSkin'
  $codexHome = Join-Path $HomePath '.codex'
  Stop-VerifiedLegacyHelpers -StateRoot $stateRoot
  if (Test-Path -LiteralPath $stateRoot -PathType Container) {
    Restore-Config -StateRoot $stateRoot -CodexHome $codexHome
  } else {
    Write-CleanupLog 'No v1.x state directory was found; config.toml was not edited.'
  }

  $desktopFolder = $DesktopPath
  $startMenu = Join-Path $RoamingAppDataPath 'Microsoft\Windows\Start Menu\Programs'
  $startup = $StartupPath
  $legacyFiles = @(
    @{ Path = (Join-Path $desktopFolder 'Codex Dream Skin.lnk'); Name = 'Codex Dream Skin.lnk' },
    @{ Path = (Join-Path $desktopFolder 'Codex Dream Skin - Restore.lnk'); Name = 'Codex Dream Skin - Restore.lnk' },
    @{ Path = (Join-Path $startMenu 'Codex Dream Skin.lnk'); Name = 'Codex Dream Skin.lnk' },
    @{ Path = (Join-Path $startup 'Codex Dream Skin Watcher.lnk'); Name = 'Codex Dream Skin Watcher.lnk' }
  )
  foreach ($item in $legacyFiles) {
    Remove-ExactFile -Path $item.Path -ExpectedLeaf $item.Name
  }
  Move-ExactItemToBackup -Path $stateRoot -ExpectedLeaf 'CodexDreamSkin'

  Write-CleanupLog "Cleanup finished. Changed targets: $script:Changed; warnings: $($script:Warnings.Count)."
  Write-CleanupLog 'Protected: application package, app caches, auth.json contents, .codex sessions, archived sessions, and projects.'
  $message = "清理完成。`n`n已处理：$script:Changed 项`n警告：$($script:Warnings.Count) 项`n`nCodex 应用包、缓存、对话记录、登录文件内容和项目目录都没有删除。备份与日志已保存在桌面。"
  if ($script:Warnings.Count -gt 0) { $message += "`n`n请查看桌面的清理日志。" }
  if (-not $NoUi) {
    [System.Windows.Forms.MessageBox]::Show($message, '清理完成', 'OK', 'Information') | Out-Null
  }
  return
} catch {
  $message = $_.Exception.Message
  try { Write-CleanupLog "FATAL: $message" } catch {}
  if (-not $NoUi) {
    [System.Windows.Forms.MessageBox]::Show(
      "清理失败：`n$message`n`n脚本不会删除 Codex 应用包、缓存或会话目录。请把桌面的清理日志附到 GitHub issue。",
      '清理失败',
      'OK',
      'Error'
    ) | Out-Null
  }
  throw
}
