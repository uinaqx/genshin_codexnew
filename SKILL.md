---
name: klee-codex-official-theme
description: Help users apply the Klee palette through the official ChatGPT/Codex Appearance settings or safely clean legacy v1.x remnants.
---

# Klee Codex Official Theme

Use only the official Appearance settings workflow in this repository.

1. Read `themes/klee-spark-knight/palette.json`.
2. Ask the user to open `codex://settings` and select Appearance.
3. Provide the supported colors for manual confirmation.
4. On Windows, use `windows/Clean-Klee-Codex-Remnants.ps1` only when the user explicitly wants to clean v1.x remnants.
5. Preserve app packages, caches, account state, `.codex/sessions`, `.codex/archived_sessions`, and project directories.

Never restore the removed injection engine, debug-port launcher, watcher, automatic app restart, package reset, package re-registration, cache deletion, or internal configuration writer.
