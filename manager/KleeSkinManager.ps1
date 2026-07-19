[CmdletBinding()]
param(
  [switch]$InstallAndLaunch,
  [switch]$PrepareUninstall,
  [switch]$NonInteractive
)

$ErrorActionPreference = 'Stop'
$AppRoot = Split-Path -Parent $PSScriptRoot
$ScriptsRoot = Join-Path $AppRoot 'scripts'
$Port = 9335
$StateRoot = Join-Path $env:LOCALAPPDATA 'CodexDreamSkin'
$ManagerLog = Join-Path $StateRoot 'manager.log'

. (Join-Path $ScriptsRoot 'lib\windows-common.ps1')
$NodePath = Resolve-DreamNode -Root $AppRoot
$env:CODEX_DREAM_NODE = $NodePath
$env:PATH = (Split-Path -Parent $NodePath) + ';' + $env:PATH

New-Item -ItemType Directory -Force -Path $StateRoot | Out-Null

function Write-ManagerLog([string]$Message) {
  try { Add-Content -LiteralPath $ManagerLog -Encoding utf8 -Value "[$(Get-Date -Format o)] $Message" } catch {}
}

function Assert-CodexReady {
  try { $null = Get-DreamCodexPackage } catch {
    throw '没有检测到Microsoft Store版Codex。请先安装Codex并正常打开一次。'
  }
  $config = Join-Path $HOME '.codex\config.toml'
  if (-not (Test-Path -LiteralPath $config)) {
    throw 'Codex还没有完成初始化。请先打开Codex、登录账号，然后再启用皮肤。'
  }
}

function Invoke-EnableSkin([ValidateSet('fullscreen', 'banner')][string]$Layout) {
  Assert-CodexReady
  Write-ManagerLog "Enable requested, layout=$Layout"
  try {
    # Auto-recovery stays off until the first launch is proven healthy. This avoids
    # a hidden watcher repeatedly relaunching a Codex build that is stuck at splash.
    & (Join-Path $ScriptsRoot 'install-dream-skin.ps1') -Port $Port -NoShortcuts -NoAutoRecover | Out-Null
    & (Join-Path $ScriptsRoot 'start-dream-skin.ps1') -Port $Port -RestartExisting | Out-Null
    & $NodePath (Join-Path $ScriptsRoot 'set-theme.mjs') 'klee-spark-knight' $Layout | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "主题切换失败，退出码：$LASTEXITCODE" }
    Write-ManagerLog "Enable completed, layout=$Layout"
  } catch {
    $reason = $_.Exception.Message
    Write-ManagerLog "Enable failed; rolling back to official Codex: $reason"
    try { Invoke-RestoreOfficial -NoRestart } catch {
      Write-ManagerLog "Rollback restore warning: $($_.Exception.Message)"
    }
    try { Stop-DreamCodexProcesses } catch {}
    try { Start-DreamCodexOfficial | Out-Null } catch {
      Write-ManagerLog "Official relaunch warning: $($_.Exception.Message)"
    }
    throw "皮肤没有通过启动检查，已自动恢复并重启官方Codex。原始错误：$reason"
  }
}

function Invoke-RestoreOfficial([switch]$NoRestart) {
  Write-ManagerLog 'Restore official interface requested.'
  try {
    & (Join-Path $ScriptsRoot 'restore-dream-skin.ps1') -Port $Port -Uninstall -RestoreBaseTheme | Out-Null
  } catch {
    Write-ManagerLog "Restore with config backup failed: $($_.Exception.Message)"
    & (Join-Path $ScriptsRoot 'restore-dream-skin.ps1') -Port $Port -Uninstall | Out-Null
  }
  if (-not $NoRestart) {
    Stop-DreamCodexProcesses
    Start-DreamCodexOfficial | Out-Null
  }
  Write-ManagerLog 'Official interface restored.'
}

function Export-DreamDiagnostics {
  $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
  $desktop = [Environment]::GetFolderPath('Desktop')
  $path = Join-Path $desktop "KleeCodexSkin-Diagnostics-$stamp.txt"
  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add('Klee Codex Skin diagnostics (no auth.json contents are collected)')
  $lines.Add("Generated: $(Get-Date -Format o)")
  $lines.Add("Manager: 1.1.1")
  $lines.Add("Windows: $([Environment]::OSVersion.VersionString)")
  $lines.Add("PowerShell: $($PSVersionTable.PSVersion)")
  try {
    $package = Get-DreamCodexPackage
    $lines.Add("Codex package: $($package.PackageFullName)")
    $lines.Add("Codex version: $($package.Version)")
  } catch { $lines.Add("Codex package error: $($_.Exception.Message)") }
  $auth = Join-Path $HOME '.codex\auth.json'
  $config = Join-Path $HOME '.codex\config.toml'
  $lines.Add("Auth file exists: $(Test-Path -LiteralPath $auth)")
  $lines.Add("Config file exists: $(Test-Path -LiteralPath $config)")
  $lines.Add("Watcher shortcut exists: $(Test-Path -LiteralPath (Join-Path ([Environment]::GetFolderPath('Startup')) 'Codex Dream Skin Watcher.lnk'))")
  foreach ($hostName in @('127.0.0.1', '[::1]')) {
    try {
      $targets = @(Invoke-RestMethod "http://$($hostName):$Port/json/list" -TimeoutSec 1)
      $lines.Add("CDP $hostName`:$Port reachable: True; app pages: $(@($targets | Where-Object { $_.url -like 'app://*' }).Count)")
    } catch { $lines.Add("CDP $hostName`:$Port reachable: False") }
  }
  $lines.Add('')
  $lines.Add('Processes:')
  try {
    $processes = Get-CimInstance Win32_Process -Filter "Name='ChatGPT.exe' OR Name='Codex.exe'" -ErrorAction Stop |
      Select-Object ProcessId, Name, ExecutablePath, CommandLine | Format-List | Out-String
    $lines.Add($processes.TrimEnd())
  } catch { $lines.Add("Process query error: $($_.Exception.Message)") }
  foreach ($logName in @('manager.log', 'injector-error.log', 'injector.log', 'watcher.log')) {
    $logPath = Join-Path $StateRoot $logName
    $lines.Add('')
    $lines.Add("===== $logName =====")
    if (Test-Path -LiteralPath $logPath) {
      $tail = Get-Content -LiteralPath $logPath -Tail 120 -ErrorAction SilentlyContinue
      if ($tail) { $lines.Add(($tail -join [Environment]::NewLine)) } else { $lines.Add('(empty)') }
    } else { $lines.Add('(missing)') }
  }
  Set-Content -LiteralPath $path -Value $lines -Encoding utf8
  Write-ManagerLog "Diagnostics exported: $path"
  Start-Process -FilePath (Join-Path $env:WINDIR 'explorer.exe') -ArgumentList $desktop
  return $path
}

function Get-SkinStatusText {
  $statePath = Join-Path $StateRoot 'state.json'
  if (-not (Test-Path -LiteralPath $statePath)) { return '当前状态：官方界面' }
  try {
    $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
    if ($state.injectorPid) {
      $process = Get-Process -Id ([int]$state.injectorPid) -ErrorAction Stop
      if ($process.ProcessName -eq 'node') { return '当前状态：可莉皮肤已启用' }
    }
  } catch {}
  return '当前状态：皮肤未运行，可点击启用或修复'
}

function Invoke-PrepareUninstall {
  try { Invoke-RestoreOfficial } catch { Write-ManagerLog "Prepare uninstall warning: $($_.Exception.Message)" }
}

if ($PrepareUninstall) {
  Invoke-PrepareUninstall
  exit 0
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$cream = [System.Drawing.Color]::FromArgb(255, 250, 241)
$softCream = [System.Drawing.Color]::FromArgb(255, 240, 220)
$red = [System.Drawing.Color]::FromArgb(201, 74, 60)
$darkRed = [System.Drawing.Color]::FromArgb(159, 48, 47)
$ink = [System.Drawing.Color]::FromArgb(75, 43, 40)
$muted = [System.Drawing.Color]::FromArgb(118, 80, 73)

$form = New-Object System.Windows.Forms.Form
$form.Text = '可莉 Codex 皮肤管理器'
$form.Size = New-Object System.Drawing.Size(760, 650)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedSingle'
$form.MaximizeBox = $false
$form.BackColor = $cream
$form.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 10)

$header = New-Object System.Windows.Forms.Panel
$header.Dock = 'Top'
$header.Height = 112
$header.BackColor = $red
$form.Controls.Add($header)

$title = New-Object System.Windows.Forms.Label
$title.Text = '♣  可莉 Codex 皮肤管理器'
$title.ForeColor = [System.Drawing.Color]::White
$title.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 21, [System.Drawing.FontStyle]::Bold)
$title.AutoSize = $true
$title.Location = New-Object System.Drawing.Point(28, 22)
$header.Controls.Add($title)

$subtitle = New-Object System.Windows.Forms.Label
$subtitle.Text = '一键换肤 · 版式切换 · 随时恢复官方界面'
$subtitle.ForeColor = [System.Drawing.Color]::FromArgb(255, 238, 226)
$subtitle.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 10)
$subtitle.AutoSize = $true
$subtitle.Location = New-Object System.Drawing.Point(32, 70)
$header.Controls.Add($subtitle)

$statusPanel = New-Object System.Windows.Forms.Panel
$statusPanel.Location = New-Object System.Drawing.Point(28, 135)
$statusPanel.Size = New-Object System.Drawing.Size(686, 62)
$statusPanel.BackColor = $softCream
$form.Controls.Add($statusPanel)

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = (Get-SkinStatusText)
$statusLabel.ForeColor = $ink
$statusLabel.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 11, [System.Drawing.FontStyle]::Bold)
$statusLabel.AutoSize = $true
$statusLabel.Location = New-Object System.Drawing.Point(20, 19)
$statusPanel.Controls.Add($statusLabel)

function New-ManagerButton([string]$Text, [int]$X, [int]$Y, [int]$Width, [System.Drawing.Color]$BackColor, [System.Drawing.Color]$ForeColor) {
  $button = New-Object System.Windows.Forms.Button
  $button.Text = $Text
  $button.Location = New-Object System.Drawing.Point($X, $Y)
  $button.Size = New-Object System.Drawing.Size($Width, 56)
  $button.FlatStyle = 'Flat'
  $button.FlatAppearance.BorderSize = 0
  $button.BackColor = $BackColor
  $button.ForeColor = $ForeColor
  $button.Cursor = [System.Windows.Forms.Cursors]::Hand
  $button.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 10, [System.Drawing.FontStyle]::Bold)
  $form.Controls.Add($button)
  return $button
}

$enableButton = New-ManagerButton '启用或修复可莉皮肤' 28 222 686 $red ([System.Drawing.Color]::White)
$fullscreenButton = New-ManagerButton '切换为全屏版式' 28 298 328 $softCream $darkRed
$bannerButton = New-ManagerButton '切换为横幅版式' 386 298 328 $softCream $darkRed
$restoreButton = New-ManagerButton '恢复官方界面' 28 374 328 ([System.Drawing.Color]::White) $ink
$uninstallButton = New-ManagerButton '彻底卸载皮肤管理器' 386 374 328 ([System.Drawing.Color]::White) $darkRed
$diagnosticsButton = New-ManagerButton '导出诊断报告' 28 450 686 $softCream $ink

$hint = New-Object System.Windows.Forms.Label
$hint.Text = '启用皮肤时Codex会自动重启一次。聊天、项目、登录信息和插件不会被删除。'
$hint.ForeColor = $muted
$hint.AutoSize = $true
$hint.Location = New-Object System.Drawing.Point(31, 535)
$form.Controls.Add($hint)

$version = New-Object System.Windows.Forms.Label
$version.Text = 'Klee Spark Knight · v1.1.1'
$version.ForeColor = $muted
$version.AutoSize = $true
$version.Location = New-Object System.Drawing.Point(31, 565)
$form.Controls.Add($version)

$buttons = @($enableButton, $fullscreenButton, $bannerButton, $restoreButton, $uninstallButton, $diagnosticsButton)

function Invoke-UiAction([string]$BusyText, [scriptblock]$Action, [string]$SuccessText) {
  foreach ($button in $buttons) { $button.Enabled = $false }
  $statusLabel.Text = $BusyText
  [System.Windows.Forms.Application]::DoEvents()
  try {
    & $Action
    $statusLabel.Text = $SuccessText
    [System.Windows.Forms.MessageBox]::Show($form, $SuccessText, '操作完成', 'OK', 'Information') | Out-Null
  } catch {
    $message = $_.Exception.Message
    Write-ManagerLog "UI action failed: $message"
    $statusLabel.Text = '操作失败，请查看提示'
    [System.Windows.Forms.MessageBox]::Show($form, $message, '操作失败', 'OK', 'Error') | Out-Null
  } finally {
    foreach ($button in $buttons) { $button.Enabled = $true }
  }
}

$enableButton.Add_Click({ Invoke-UiAction '正在启动可莉皮肤…' { Invoke-EnableSkin 'fullscreen' } '可莉皮肤已启用' })
$fullscreenButton.Add_Click({ Invoke-UiAction '正在切换全屏版式…' { Invoke-EnableSkin 'fullscreen' } '已切换为全屏版式' })
$bannerButton.Add_Click({ Invoke-UiAction '正在切换横幅版式…' { Invoke-EnableSkin 'banner' } '已切换为横幅版式' })
$restoreButton.Add_Click({ Invoke-UiAction '正在恢复并重启官方Codex…' { Invoke-RestoreOfficial } '已恢复并重启官方Codex' })
$diagnosticsButton.Add_Click({
  Invoke-UiAction '正在生成诊断报告…' { $script:LastDiagnosticsPath = Export-DreamDiagnostics } '诊断报告已保存到桌面'
})
$uninstallButton.Add_Click({
  $answer = [System.Windows.Forms.MessageBox]::Show($form, '确定彻底卸载可莉皮肤管理器吗？Codex会恢复为官方界面。', '确认卸载', 'YesNo', 'Warning')
  if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { return }
  $uninstaller = Join-Path $AppRoot 'unins000.exe'
  if (-not (Test-Path -LiteralPath $uninstaller)) {
    [System.Windows.Forms.MessageBox]::Show($form, '没有找到卸载程序，请在Windows设置的应用列表中卸载。', '无法卸载', 'OK', 'Error') | Out-Null
    return
  }
  Start-Process -FilePath $uninstaller -ArgumentList '/SILENT'
  $form.Close()
})

if ($InstallAndLaunch) {
  $form.Add_Shown({
    $form.Activate()
    Invoke-UiAction '首次安装，正在自动启用可莉皮肤…' { Invoke-EnableSkin 'fullscreen' } '安装完成，可莉皮肤已启用'
  })
}

if (-not $NonInteractive) {
  [void][System.Windows.Forms.Application]::Run($form)
}
