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
