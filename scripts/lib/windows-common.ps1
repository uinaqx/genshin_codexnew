function Resolve-DreamNode {
  [CmdletBinding()]
  param([string]$Root)

  if ($env:CODEX_DREAM_NODE -and (Test-Path -LiteralPath $env:CODEX_DREAM_NODE)) {
    return (Resolve-Path -LiteralPath $env:CODEX_DREAM_NODE).Path
  }

  if (-not $Root) {
    $Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  }

  $bundled = Join-Path $Root 'runtime\node\node.exe'
  if (Test-Path -LiteralPath $bundled) {
    return (Resolve-Path -LiteralPath $bundled).Path
  }

  $systemNode = Get-Command node.exe -ErrorAction SilentlyContinue
  if (-not $systemNode) { $systemNode = Get-Command node -ErrorAction SilentlyContinue }
  if ($systemNode) { return $systemNode.Source }

  throw 'Node.js was not found. Reinstall Klee Codex Skin or install Node.js 20+.'
}

function Get-DreamCodexPackage {
  $package = Get-AppxPackage OpenAI.Codex -ErrorAction SilentlyContinue |
    Sort-Object Version -Descending | Select-Object -First 1
  if (-not $package) { throw 'The Microsoft Store OpenAI.Codex package is not installed.' }
  return $package
}

function Stop-DreamCodexProcesses {
  [CmdletBinding()]
  param([int]$GraceSeconds = 6)

  $names = @('ChatGPT', 'Codex')
  $visible = @($names | ForEach-Object {
    Get-Process -Name $_ -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 }
  })
  foreach ($process in $visible) {
    try { [void]$process.CloseMainWindow() } catch {}
  }

  $deadline = (Get-Date).AddSeconds([Math]::Max(1, $GraceSeconds))
  do {
    $remaining = @($names | ForEach-Object { Get-Process -Name $_ -ErrorAction SilentlyContinue })
    if ($remaining.Count -eq 0) { return }
    Start-Sleep -Milliseconds 250
  } while ((Get-Date) -lt $deadline)

  $remaining | Stop-Process -Force -ErrorAction SilentlyContinue
  Start-Sleep -Milliseconds 700
  $names | ForEach-Object {
    Get-Process -Name $_ -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
  }
  Start-Sleep -Milliseconds 300
}

function Start-DreamCodexOfficial {
  [CmdletBinding()]
  param()

  $package = Get-DreamCodexPackage
  $manifest = Get-AppxPackageManifest -Package $package.PackageFullName
  $application = @($manifest.Package.Applications.Application) | Select-Object -First 1
  $appId = [string]$application.Id
  if (-not $appId) { throw 'The Codex AppUserModelId could not be resolved.' }
  $aumid = "$($package.PackageFamilyName)!$appId"
  $explorer = Join-Path $env:WINDIR 'explorer.exe'
  Start-Process -FilePath $explorer -ArgumentList "shell:AppsFolder\$aumid"
  return $aumid
}
