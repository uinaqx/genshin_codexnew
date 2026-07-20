[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$AppVersion = '2.0.0'
$AppRoot = Split-Path -Parent $PSScriptRoot
$CleanupScript = Join-Path $AppRoot 'windows\Clean-Klee-Codex-Remnants.ps1'
$PreviewPath = Join-Path $AppRoot 'docs\previews\home-fullscreen.webp'
$ProjectUrl = 'https://github.com/uinaqx/genshin_codexnew'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

function Get-CodexPackageSummary {
  try {
    $packages = @(Get-AppxPackage -ErrorAction Stop | Where-Object {
      $_.Name -eq 'OpenAI.Codex' -or $_.Name -eq 'OpenAI.ChatGPT-Desktop'
    })
    if ($packages.Count -eq 0) { return '未检测到 Microsoft Store 版 ChatGPT/Codex' }
    return ($packages | ForEach-Object { "$($_.Name) $($_.Version)" }) -join '；'
  } catch {
    return '无法读取应用版本（不影响使用安全中心）'
  }
}

function Get-LegacyStatus {
  $targets = @(
    (Join-Path $env:LOCALAPPDATA 'CodexDreamSkin'),
    (Join-Path ([Environment]::GetFolderPath('Startup')) 'Codex Dream Skin Watcher.lnk'),
    (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Codex Dream Skin.lnk')
  )
  $stateExists = Test-Path -LiteralPath $targets[0]
  $watcherExists = Test-Path -LiteralPath $targets[1]
  $shortcutExists = Test-Path -LiteralPath $targets[2]
  if ($stateExists -or $watcherExists -or $shortcutExists) {
    return '检测到旧版残留；可点击“安全清理旧版残留”'
  }
  return '未检测到旧版可莉注入组件'
}

function Open-OfficialAppearanceSettings {
  $palette = @'
可莉主题官方配色
基础主题：浅色
强调色：#C94A3C
背景色：#FFF9F0
前景色：#4B2B28
辅助暖金：#E8B04A

请在 ChatGPT/Codex 的“设置 → 外观”中使用这些颜色。
'@
  [System.Windows.Forms.Clipboard]::SetText($palette)
  Start-Process 'codex://settings'
}

function Open-ThemePreview {
  if (-not (Test-Path -LiteralPath $PreviewPath -PathType Leaf)) {
    throw '安装目录中没有找到主题预览图。请重新安装安全版。'
  }
  Start-Process -FilePath $PreviewPath
}

function Invoke-LegacyCleanup {
  if (-not (Test-Path -LiteralPath $CleanupScript -PathType Leaf)) {
    throw '安装目录中没有找到安全清理脚本。请重新安装安全版。'
  }
  $answer = [System.Windows.Forms.MessageBox]::Show(
    "清理只针对旧版可莉皮肤组件和它写入的三项外观配置。`n`n不会重置应用包，不会删除登录信息、对话记录或项目文件。`n`n继续前请关闭 ChatGPT/Codex。是否开始？",
    '确认安全清理',
    [System.Windows.Forms.MessageBoxButtons]::YesNo,
    [System.Windows.Forms.MessageBoxIcon]::Warning
  )
  if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { return $false }
  & $CleanupScript -Yes -NoUi
  [System.Windows.Forms.MessageBox]::Show($form, '旧版残留已处理。备份和日志保存在桌面。', '清理完成', 'OK', 'Information') | Out-Null
  return $true
}

function Export-SafeDiagnostics {
  $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
  $desktop = [Environment]::GetFolderPath('Desktop')
  $path = Join-Path $desktop "KleeSafety-Diagnostics-$stamp.txt"
  $stateRoot = Join-Path $env:LOCALAPPDATA 'CodexDreamSkin'
  $programRoot = Join-Path $env:LOCALAPPDATA 'Programs\KleeCodexSafety'
  $watcher = Join-Path ([Environment]::GetFolderPath('Startup')) 'Codex Dream Skin Watcher.lnk'
  $config = Join-Path $HOME '.codex\config.toml'
  $appearanceKeys = @()
  if (Test-Path -LiteralPath $config -PathType Leaf) {
    try {
      $appearanceKeys = @(Select-String -LiteralPath $config -Pattern '^\s*(appearanceTheme|appearanceLightCodeThemeId|appearanceLightChromeTheme)\s*=' | ForEach-Object {
        if ($_.Line -match '^\s*([^=]+)=') { $Matches[1].Trim() }
      })
    } catch {}
  }
  $lines = @(
    'Klee Codex Safety Center diagnostics',
    'No file contents, account tokens, chat history, or project data are collected.',
    "Generated: $(Get-Date -Format o)",
    "Safety Center: $AppVersion",
    "Windows: $([Environment]::OSVersion.VersionString)",
    "PowerShell: $($PSVersionTable.PSVersion)",
    "Official app: $(Get-CodexPackageSummary)",
    "Legacy state folder exists: $(Test-Path -LiteralPath $stateRoot)",
    "Safety Center folder exists: $(Test-Path -LiteralPath $programRoot)",
    "Legacy watcher shortcut exists: $(Test-Path -LiteralPath $watcher)",
    "Legacy appearance keys: $(if ($appearanceKeys.Count) { $appearanceKeys -join ', ' } else { 'none detected' })"
  )
  Set-Content -LiteralPath $path -Value $lines -Encoding utf8
  Start-Process -FilePath (Join-Path $env:WINDIR 'explorer.exe') -ArgumentList "/select,`"$path`""
  return $path
}

function Uninstall-SafetyCenter {
  $uninstaller = Join-Path $AppRoot 'unins000.exe'
  if (-not (Test-Path -LiteralPath $uninstaller -PathType Leaf)) {
    throw '没有找到卸载程序。请在 Windows“设置 → 应用”中卸载“可莉 Codex 安全中心”。'
  }
  Start-Process -FilePath $uninstaller
}

$cream = [System.Drawing.Color]::FromArgb(255, 249, 240)
$softCream = [System.Drawing.Color]::FromArgb(255, 238, 218)
$red = [System.Drawing.Color]::FromArgb(201, 74, 60)
$darkRed = [System.Drawing.Color]::FromArgb(144, 47, 43)
$ink = [System.Drawing.Color]::FromArgb(75, 43, 40)
$muted = [System.Drawing.Color]::FromArgb(116, 82, 75)
$green = [System.Drawing.Color]::FromArgb(48, 117, 83)

$form = New-Object System.Windows.Forms.Form
$form.Text = '可莉 Codex 安全中心'
$form.Size = New-Object System.Drawing.Size(780, 665)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedSingle'
$form.MaximizeBox = $false
$form.BackColor = $cream
$form.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 10)

$header = New-Object System.Windows.Forms.Panel
$header.Dock = 'Top'
$header.Height = 116
$header.BackColor = $red
$form.Controls.Add($header)

$title = New-Object System.Windows.Forms.Label
$title.Text = '可莉 Codex 安全中心'
$title.ForeColor = [System.Drawing.Color]::White
$title.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 21, [System.Drawing.FontStyle]::Bold)
$title.AutoSize = $true
$title.Location = New-Object System.Drawing.Point(28, 22)
$header.Controls.Add($title)

$subtitle = New-Object System.Windows.Forms.Label
$subtitle.Text = '官方外观入口 · 旧版残留清理 · 不修改应用包和账号数据'
$subtitle.ForeColor = [System.Drawing.Color]::FromArgb(255, 238, 226)
$subtitle.AutoSize = $true
$subtitle.Location = New-Object System.Drawing.Point(31, 72)
$header.Controls.Add($subtitle)

$statusPanel = New-Object System.Windows.Forms.Panel
$statusPanel.Location = New-Object System.Drawing.Point(28, 138)
$statusPanel.Size = New-Object System.Drawing.Size(706, 92)
$statusPanel.BackColor = $softCream
$form.Controls.Add($statusPanel)

$appLabel = New-Object System.Windows.Forms.Label
$appLabel.Text = "官方应用：$(Get-CodexPackageSummary)"
$appLabel.ForeColor = $ink
$appLabel.AutoSize = $true
$appLabel.Location = New-Object System.Drawing.Point(18, 17)
$statusPanel.Controls.Add($appLabel)

$legacyLabel = New-Object System.Windows.Forms.Label
$legacyLabel.Text = "安全检查：$(Get-LegacyStatus)"
$legacyLabel.ForeColor = $green
$legacyLabel.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 10, [System.Drawing.FontStyle]::Bold)
$legacyLabel.AutoSize = $true
$legacyLabel.Location = New-Object System.Drawing.Point(18, 51)
$statusPanel.Controls.Add($legacyLabel)

function New-SafetyButton([string]$Text, [int]$X, [int]$Y, [int]$Width, [System.Drawing.Color]$BackColor, [System.Drawing.Color]$ForeColor) {
  $button = New-Object System.Windows.Forms.Button
  $button.Text = $Text
  $button.Location = New-Object System.Drawing.Point($X, $Y)
  $button.Size = New-Object System.Drawing.Size($Width, 58)
  $button.FlatStyle = 'Flat'
  $button.FlatAppearance.BorderSize = 0
  $button.BackColor = $BackColor
  $button.ForeColor = $ForeColor
  $button.Cursor = [System.Windows.Forms.Cursors]::Hand
  $button.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 10, [System.Drawing.FontStyle]::Bold)
  $form.Controls.Add($button)
  return $button
}

$appearanceButton = New-SafetyButton '复制可莉配色并打开官方外观设置' 28 252 706 $red ([System.Drawing.Color]::White)
$previewButton = New-SafetyButton '查看主题预览' 28 330 338 $softCream $darkRed
$cleanupButton = New-SafetyButton '安全清理旧版残留' 396 330 338 ([System.Drawing.Color]::White) $darkRed
$diagnosticsButton = New-SafetyButton '导出安全诊断' 28 408 338 ([System.Drawing.Color]::White) $ink
$projectButton = New-SafetyButton '打开 GitHub 使用说明' 396 408 338 $softCream $ink
$uninstallButton = New-SafetyButton '卸载安全中心' 28 486 706 ([System.Drawing.Color]::White) $muted

$hint = New-Object System.Windows.Forms.Label
$hint.Text = 'v2.0 已停用旧版 CDP 注入和自动恢复。安装、打开、卸载安全中心都不会更改 Codex。'
$hint.ForeColor = $muted
$hint.AutoSize = $true
$hint.Location = New-Object System.Drawing.Point(31, 568)
$form.Controls.Add($hint)

$versionLabel = New-Object System.Windows.Forms.Label
$versionLabel.Text = "Klee Spark Knight · Safety Edition v$AppVersion"
$versionLabel.ForeColor = $muted
$versionLabel.AutoSize = $true
$versionLabel.Location = New-Object System.Drawing.Point(31, 596)
$form.Controls.Add($versionLabel)

function Show-Error([string]$Message) {
  [System.Windows.Forms.MessageBox]::Show($form, $Message, '操作失败', 'OK', 'Error') | Out-Null
}

$appearanceButton.Add_Click({
  try {
    Open-OfficialAppearanceSettings
    [System.Windows.Forms.MessageBox]::Show($form, '可莉配色已复制到剪贴板，并已打开官方设置。请进入“外观”填写颜色。', '已打开官方设置', 'OK', 'Information') | Out-Null
  } catch { Show-Error $_.Exception.Message }
})
$previewButton.Add_Click({ try { Open-ThemePreview } catch { Show-Error $_.Exception.Message } })
$cleanupButton.Add_Click({
  try {
    if (Invoke-LegacyCleanup) { $legacyLabel.Text = "安全检查：$(Get-LegacyStatus)" }
  } catch { Show-Error $_.Exception.Message }
})
$diagnosticsButton.Add_Click({
  try {
    $path = Export-SafeDiagnostics
    [System.Windows.Forms.MessageBox]::Show($form, "诊断报告已保存：`n$path", '导出完成', 'OK', 'Information') | Out-Null
  } catch { Show-Error $_.Exception.Message }
})
$projectButton.Add_Click({ try { Start-Process $ProjectUrl } catch { Show-Error $_.Exception.Message } })
$uninstallButton.Add_Click({
  try {
    Uninstall-SafetyCenter
    $form.Close()
  } catch { Show-Error $_.Exception.Message }
})

[void][System.Windows.Forms.Application]::Run($form)
