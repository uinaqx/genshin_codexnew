[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Join-Path $env:TEMP "klee-cleanup-test-$([Guid]::NewGuid().ToString('N'))"
$homePath = Join-Path $root 'home'
$localPath = Join-Path $root 'local'
$roamingPath = Join-Path $root 'roaming'
$desktopPath = Join-Path $root 'desktop'
$startupPath = Join-Path $root 'startup'
$codexHome = Join-Path $homePath '.codex'
$stateRoot = Join-Path $localPath 'CodexDreamSkin'
$sessions = Join-Path $codexHome 'sessions'
$fakeOfficialCache = Join-Path $localPath 'Packages\OpenAI.Codex_test\LocalCache'

try {
  foreach ($folder in @($codexHome, $stateRoot, $sessions, $desktopPath, $startupPath, $fakeOfficialCache)) {
    New-Item -ItemType Directory -Force -Path $folder | Out-Null
  }
  Set-Content -LiteralPath (Join-Path $codexHome 'config.toml') -Encoding utf8 -Value @(
    'model = "current"',
    'custom_setting = true',
    'appearanceTheme = "skin-light"',
    'appearanceLightCodeThemeId = "skin-code"'
  )
  Set-Content -LiteralPath (Join-Path $stateRoot 'config.before-dream-skin.toml') -Encoding utf8 -Value @(
    'model = "original"',
    'appearanceTheme = "original-dark"'
  )
  Set-Content -LiteralPath (Join-Path $codexHome 'auth.json') -Encoding utf8 -Value 'preserve-auth-file'
  Set-Content -LiteralPath (Join-Path $sessions 'conversation.jsonl') -Encoding utf8 -Value 'preserve-conversation'
  Set-Content -LiteralPath (Join-Path $fakeOfficialCache 'official-cache.db') -Encoding utf8 -Value 'preserve-cache'
  Set-Content -LiteralPath (Join-Path $startupPath 'Codex Dream Skin Watcher.lnk') -Encoding utf8 -Value 'legacy-shortcut'

  & (Join-Path $PSScriptRoot '..\windows\Clean-Klee-Codex-Remnants.ps1') `
    -Yes -NoUi `
    -HomePath $homePath `
    -LocalAppDataPath $localPath `
    -RoamingAppDataPath $roamingPath `
    -DesktopPath $desktopPath `
    -StartupPath $startupPath

  if (Test-Path -LiteralPath $stateRoot) { throw 'Legacy state root was not moved out of the active path.' }
  $backup = Get-ChildItem -LiteralPath $desktopPath -Directory -Filter 'KleeSkinCleanup-Backup-*' | Select-Object -First 1
  if (-not $backup) { throw 'Cleanup backup folder was not created.' }
  if (-not (Test-Path -LiteralPath (Join-Path $backup.FullName 'CodexDreamSkin'))) { throw 'Legacy state was not preserved in the backup.' }
  if (Test-Path -LiteralPath (Join-Path $startupPath 'Codex Dream Skin Watcher.lnk')) { throw 'Legacy watcher shortcut was not removed.' }

  $config = Get-Content -LiteralPath (Join-Path $codexHome 'config.toml') -Raw
  if ($config -notmatch 'model\s*=\s*"current"') { throw 'A current non-theme config entry was changed.' }
  if ($config -notmatch 'custom_setting\s*=\s*true') { throw 'A current custom config entry was removed.' }
  if ($config -notmatch 'appearanceTheme\s*=\s*"original-dark"') { throw 'The original appearance value was not restored.' }
  if ($config -match 'appearanceLightCodeThemeId') { throw 'A skin-only appearance key was not removed.' }
  if ((Get-Content -LiteralPath (Join-Path $codexHome 'auth.json') -Raw).Trim() -ne 'preserve-auth-file') { throw 'auth.json changed.' }
  if ((Get-Content -LiteralPath (Join-Path $sessions 'conversation.jsonl') -Raw).Trim() -ne 'preserve-conversation') { throw 'Session history changed.' }
  if ((Get-Content -LiteralPath (Join-Path $fakeOfficialCache 'official-cache.db') -Raw).Trim() -ne 'preserve-cache') { throw 'Official cache changed.' }

  Write-Host 'Cleanup sandbox integration test passed.'
} finally {
  if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}
