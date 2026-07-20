[CmdletBinding()]
param(
  [switch]$NonInteractive,
  [switch]$SkipAccountReset
)

$ErrorActionPreference = 'Stop'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$desktop = [Environment]::GetFolderPath('Desktop')
$logPath = Join-Path $desktop "Recover-Official-Codex-$stamp.log"
$script:RenamedItems = New-Object System.Collections.Generic.List[string]

function Write-RecoveryLog([string]$Message) {
  $line = "[$(Get-Date -Format o)] $Message"
  Add-Content -LiteralPath $logPath -Encoding utf8 -Value $line
  Write-Host $line
}

function Stop-OfficialCodex {
  Get-Process -Name ChatGPT, codex -ErrorAction SilentlyContinue |
    Stop-Process -Force -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 2
  Get-Process -Name ChatGPT, codex -ErrorAction SilentlyContinue |
    Stop-Process -Force -ErrorAction SilentlyContinue
  Start-Sleep -Milliseconds 500
}

function Rename-ForRecovery {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Label
  )

  if (-not (Test-Path -LiteralPath $Path)) {
    Write-RecoveryLog "$Label not present: $Path"
    return
  }

  $parent = Split-Path -Parent $Path
  $leaf = Split-Path -Leaf $Path
  $destination = Join-Path $parent "$leaf.before-klee-recovery-$stamp"
  $counter = 1
  while (Test-Path -LiteralPath $destination) {
    $destination = Join-Path $parent "$leaf.before-klee-recovery-$stamp-$counter"
    $counter++
  }

  Move-Item -LiteralPath $Path -Destination $destination -Force
  $script:RenamedItems.Add("$Label`t$Path`t$destination")
  Write-RecoveryLog "$Label backed up to: $destination"
}

function Backup-PackageItem {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Label
  )

  if (-not (Test-Path -LiteralPath $Path)) {
    Write-RecoveryLog "$Label not present: $Path"
    return
  }

  $safeName = $Label -replace '[^A-Za-z0-9._-]', '-'
  $destination = Join-Path $script:RecoveryVault $safeName
  New-Item -ItemType Directory -Force -Path $script:RecoveryVault | Out-Null
  try {
    Move-Item -LiteralPath $Path -Destination $destination -Force
    $script:RenamedItems.Add("$Label`t$Path`t$destination")
    Write-RecoveryLog "$Label moved outside the MSIX reset area to: $destination"
  } catch {
    Write-RecoveryLog "$Label could not be moved; attempting a protected copy: $($_.Exception.Message)"
    try {
      Copy-Item -LiteralPath $Path -Destination $destination -Recurse -Force -ErrorAction Stop
      $script:RenamedItems.Add("$Label (copied)`t$Path`t$destination")
      Write-RecoveryLog "$Label copied outside the MSIX reset area to: $destination"
    } catch {
      throw "Could not preserve $Label before the package reset: $($_.Exception.Message)"
    }
  }
}

function Add-LogEvidence {
  param(
    [Parameter(Mandatory = $true)][string[]]$Roots,
    [Parameter(Mandatory = $true)][string]$Phase
  )

  Add-Content -LiteralPath $logPath -Encoding utf8 -Value "`r`n===== Official app logs: $Phase ====="
  $files = New-Object System.Collections.Generic.List[System.IO.FileInfo]
  foreach ($root in $Roots) {
    if (-not (Test-Path -LiteralPath $root)) { continue }
    try {
      Get-ChildItem -LiteralPath $root -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -in @('.log', '.txt') } |
        ForEach-Object { $files.Add($_) }
    } catch {
      Write-RecoveryLog "Could not enumerate logs under $root : $($_.Exception.Message)"
    }
  }

  $latest = @($files | Sort-Object LastWriteTime -Descending | Select-Object -First 8)
  if ($latest.Count -eq 0) {
    Add-Content -LiteralPath $logPath -Encoding utf8 -Value '(no official app logs found)'
    return
  }

  foreach ($file in $latest) {
    Add-Content -LiteralPath $logPath -Encoding utf8 -Value "`r`n--- $($file.FullName) [$($file.LastWriteTime.ToString('o'))] ---"
    try {
      $tail = @(Get-Content -LiteralPath $file.FullName -Tail 500 -ErrorAction Stop)
      $important = @($tail | Where-Object {
        $_ -match '(?i)error|fatal|exception|failed|failure|denied|crash|deactivated_workspace|payment required|status[ =:]*(401|402|403|407|429|5\d\d)|unsupported feature|gpu process|ERR_|timed? ?out'
      })
      if ($important.Count -gt 0) {
        Add-Content -LiteralPath $logPath -Encoding utf8 -Value ($important | Select-Object -Last 160)
      } else {
        Add-Content -LiteralPath $logPath -Encoding utf8 -Value ($tail | Select-Object -Last 60)
      }
    } catch {
      Add-Content -LiteralPath $logPath -Encoding utf8 -Value "(could not read log: $($_.Exception.Message))"
    }
  }
}

try {
  Write-RecoveryLog 'Full official Codex reset started (v1.1.3).'
  Write-RecoveryLog "Windows: $([Environment]::OSVersion.VersionString); PowerShell: $($PSVersionTable.PSVersion)"

  $stateRoot = Join-Path $env:LOCALAPPDATA 'CodexDreamSkin'
  New-Item -ItemType Directory -Force -Path $stateRoot | Out-Null
  $script:RecoveryVault = Join-Path $stateRoot ("OfficialRecovery\" + $stamp)
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
  Stop-OfficialCodex
  Write-RecoveryLog 'Stopped skin helpers and all ChatGPT/Codex processes.'

  $package = Get-AppxPackage OpenAI.Codex -ErrorAction Stop |
    Sort-Object Version -Descending | Select-Object -First 1
  $packageRoot = Join-Path $env:LOCALAPPDATA ("Packages\" + $package.PackageFamilyName)
  Write-RecoveryLog "Codex package: $($package.PackageFullName); status: $($package.Status)"
  Write-RecoveryLog "MSIX data root: $packageRoot"

  $roamingCodex = Join-Path $env:APPDATA 'Codex'
  $localCodex = Join-Path $env:LOCALAPPDATA 'Codex'
  $packageRoamingCodex = Join-Path $packageRoot 'LocalCache\Roaming\Codex'
  $packageLocalCodex = Join-Path $packageRoot 'LocalCache\Local\Codex'
  $packageLocalState = Join-Path $packageRoot 'LocalState'
  $packageTempState = Join-Path $packageRoot 'TempState'
  $logRoots = @(
    (Join-Path $roamingCodex 'Logs'),
    (Join-Path $localCodex 'Logs'),
    (Join-Path $packageRoamingCodex 'Logs'),
    (Join-Path $packageLocalCodex 'Logs')
  )
  Add-LogEvidence -Roots $logRoots -Phase 'before reset'

  Rename-ForRecovery -Path $roamingCodex -Label 'Roaming Codex profile'
  Rename-ForRecovery -Path $localCodex -Label 'Local Codex profile'
  Backup-PackageItem -Path $packageRoamingCodex -Label 'MSIX-roaming-Codex-profile'
  Backup-PackageItem -Path $packageLocalCodex -Label 'MSIX-local-Codex-profile'
  Backup-PackageItem -Path $packageLocalState -Label 'MSIX-LocalState'
  Backup-PackageItem -Path $packageTempState -Label 'MSIX-TempState'
  Backup-PackageItem -Path (Join-Path $packageRoot 'Settings') -Label 'MSIX-Settings'

  $codexHome = Join-Path $HOME '.codex'
  $config = Join-Path $codexHome 'config.toml'
  Rename-ForRecovery -Path $config -Label 'Codex config.toml'
  if (-not $SkipAccountReset) {
    Rename-ForRecovery -Path (Join-Path $codexHome 'auth.json') -Label 'Codex auth.json'
    Rename-ForRecovery -Path (Join-Path $codexHome 'cap_sid') -Label 'Codex cap_sid'
    Write-RecoveryLog 'Account session was backed up and reset; the next launch should request sign-in.'
  } else {
    Write-RecoveryLog 'Account reset skipped by request.'
  }

  $resetCommand = Get-Command Reset-AppxPackage -ErrorAction SilentlyContinue
  if ($resetCommand) {
    try {
      $package | Reset-AppxPackage -ErrorAction Stop
      Write-RecoveryLog 'Reset the current-user MSIX package state.'
    } catch {
      Write-RecoveryLog "Reset-AppxPackage warning: $($_.Exception.Message)"
    }
  } else {
    Write-RecoveryLog 'Reset-AppxPackage is unavailable on this Windows build.'
  }

  Stop-OfficialCodex
  $package = Get-AppxPackage OpenAI.Codex -ErrorAction Stop |
    Sort-Object Version -Descending | Select-Object -First 1
  $manifestPath = Join-Path $package.InstallLocation 'AppxManifest.xml'
  try {
    Add-AppxPackage -DisableDevelopmentMode -Register $manifestPath -ErrorAction Stop
    Write-RecoveryLog 'Re-registered the official Codex MSIX package.'
  } catch {
    Write-RecoveryLog "MSIX re-registration warning: $($_.Exception.Message)"
  }

  $manifest = Get-AppxPackageManifest -Package $package.PackageFullName
  $application = @($manifest.Package.Applications.Application) | Select-Object -First 1
  $appId = [string]$application.Id
  if (-not $appId) { throw 'Could not resolve the official Codex application ID.' }
  $aumid = "$($package.PackageFamilyName)!$appId"
  Start-Process -FilePath (Join-Path $env:WINDIR 'explorer.exe') -ArgumentList "shell:AppsFolder\$aumid"
  Write-RecoveryLog "Launched official Codex entry: $aumid"

  Start-Sleep -Seconds 15
  $running = @(Get-Process -Name ChatGPT, codex -ErrorAction SilentlyContinue)
  Write-RecoveryLog "Official process count after launch: $($running.Count)"
  $newPackageRoot = Join-Path $env:LOCALAPPDATA ("Packages\" + $package.PackageFamilyName)
  $newLogRoots = @(
    (Join-Path $env:APPDATA 'Codex\Logs'),
    (Join-Path $env:LOCALAPPDATA 'Codex\Logs'),
    (Join-Path $newPackageRoot 'LocalCache\Roaming\Codex\Logs'),
    (Join-Path $newPackageRoot 'LocalCache\Local\Codex\Logs')
  )
  Add-LogEvidence -Roots $newLogRoots -Phase '15 seconds after clean launch'

  Add-Content -LiteralPath $logPath -Encoding utf8 -Value "`r`n===== Recoverable backups ====="
  if ($script:RenamedItems.Count -gt 0) {
    Add-Content -LiteralPath $logPath -Encoding utf8 -Value $script:RenamedItems
  } else {
    Add-Content -LiteralPath $logPath -Encoding utf8 -Value '(no prior state was present)'
  }
  Write-RecoveryLog 'Full reset finished. No project folders or .codex session history were deleted.'
  Write-RecoveryLog 'A fresh sign-in may be required. Do not restore the backed-up cache/config before confirming startup.'

  if (-not $NonInteractive) {
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show(
      "已经执行完整恢复并启动官方Codex。`n`n这次清理了Microsoft Store真实缓存，并把登录状态安全改名备份。请按官方窗口提示重新登录。`n`n如果仍停在Logo，把桌面的恢复日志发给我。项目目录和聊天会话文件没有删除。",
      'Codex完整恢复', 'OK', 'Information'
    ) | Out-Null
  }
} catch {
  $message = $_.Exception.Message
  try { Write-RecoveryLog "Recovery failed: $message" } catch {}
  if (-not $NonInteractive) {
    try {
      Add-Type -AssemblyName System.Windows.Forms
      [System.Windows.Forms.MessageBox]::Show(
        "恢复过程中出现错误：$message`n`n请把桌面的恢复日志发给我。所有已移动的内容都保留为 before-klee-recovery 备份。",
        'Codex恢复失败', 'OK', 'Error'
      ) | Out-Null
    } catch {}
    exit 1
  }
  throw
}
