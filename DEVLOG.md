# Development log

## 2.0.0 — safety rewrite

- Retired every CDP/debug-port injection path on Windows and macOS.
- Removed automatic launch interception, watchers, package reset, package re-registration, cache cleanup, and account-state cleanup.
- Replaced the Windows skin manager with a non-invasive safety center.
- Added an exact-target v1.x cleanup script that backs up configuration first and preserves conversations, projects, app caches, and current account files.
- Moved the Klee experience to the official Appearance settings palette.
- Added negative safety contracts, PowerShell parsing, minimal installer payload, release hashes, and an incident report.
