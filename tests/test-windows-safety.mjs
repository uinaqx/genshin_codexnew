import assert from "node:assert/strict";
import fs from "node:fs";

const read = (file) => fs.readFileSync(file, "utf8");
const manager = read("manager/KleeSafetyCenter.ps1");
const cleanup = read("windows/Clean-Klee-Codex-Remnants.ps1");
const installer = read("installer/windows/KleeCodexSkin.iss");
const workflow = read(".github/workflows/windows-installer.yml");
const cleanupSandboxTest = read("tests/Test-CleanupSandbox.ps1");

for (const required of [
  "Open-OfficialAppearanceSettings",
  "Invoke-LegacyCleanup",
  "Export-SafeDiagnostics",
  "codex://settings",
]) {
  assert.ok(manager.includes(required), `safety center is missing ${required}`);
}

for (const forbidden of [
  "--remote-debugging-port",
  "Invoke-EnableSkin",
  "Reset-AppxPackage",
  "Add-AppxPackage",
  "Start-DreamCodex",
  "EmergencyRecover",
  "PrepareUninstall",
]) {
  assert.ok(!manager.includes(forbidden), `safety center contains forbidden behavior: ${forbidden}`);
  assert.ok(!installer.includes(forbidden), `installer contains forbidden behavior: ${forbidden}`);
}

assert.ok(installer.includes("PrivilegesRequired=lowest"));
assert.ok(installer.includes("KleeSafetyCenter.ps1"));
assert.ok(installer.includes("postinstall"), "installer may offer to open the safety center");
assert.ok(!installer.includes("[UninstallRun]"), "uninstall must not run a Codex mutation hook");
assert.ok(!installer.includes("[UninstallDelete]"), "uninstall must not delete user state folders");
assert.ok(!installer.includes("-EmergencyRecover"), "install must never auto-recover/reset Codex");
assert.ok(installer.includes("[InstallDelete]"), "upgrade must remove the old injected runtime from the app folder");
for (const oldFolder of ["Programs\\KleeCodexSkin", "{app}\\assets", "{app}\\scripts", "{app}\\runtime", "{app}\\manager"]) {
  assert.ok(installer.includes(oldFolder), `upgrade cleanup is missing ${oldFolder}`);
}
assert.ok(installer.includes("1AAF7D01-75F6-407A-BE69-C7E33A663493"), "v2 must use a new AppId so v1 uninstall hooks cannot be inherited");
assert.ok(installer.includes("Programs\\KleeCodexSafety"));
assert.ok(installer.includes("D3A25C8C-75CC-44AF-9F8A-98A8E7FA2B40"), "v2 must remove only the stale v1 uninstall registration");

for (const protectedText of [
  "不会处理：Codex 应用包、缓存、登录状态、sessions、archived_sessions 或项目目录",
  "Protected: application package, app caches, auth.json contents, .codex sessions, archived sessions, and projects.",
]) {
  assert.ok(cleanup.includes(protectedText), `cleanup is missing protection statement: ${protectedText}`);
}

for (const forbidden of [
  "Reset-AppxPackage",
  "Add-AppxPackage",
  "Remove-AppxPackage",
  "LocalCache\\Roaming\\Codex",
  "LocalCache\\Local\\Codex",
  "Remove-Item -LiteralPath $codexHome",
  "Get-Content -LiteralPath $active",
]) {
  assert.ok(!cleanup.includes(forbidden), `cleanup contains forbidden behavior: ${forbidden}`);
}

assert.ok(cleanup.includes("appearanceTheme|appearanceLightCodeThemeId|appearanceLightChromeTheme"));
assert.ok(cleanup.includes("Move-ExactItemToBackup -Path $stateRoot -ExpectedLeaf 'CodexDreamSkin'"));
assert.ok(!cleanup.includes("Restore-MissingAccountMarker"), "cleanup must not restore or replace account files");
assert.ok(workflow.includes('APP_VERSION: "2.0.0"'));
assert.ok(workflow.includes("KleeCodexSafety-Setup-v2.0.0.exe"));
assert.ok(!workflow.includes("node.exe"), "the Windows payload must not bundle a debug injection runtime");
assert.ok(workflow.includes("Test-CleanupSandbox.ps1"));
for (const protectedFixture of ["auth.json", "conversation.jsonl", "official-cache.db"]) {
  assert.ok(cleanupSandboxTest.includes(protectedFixture), `sandbox test is missing ${protectedFixture}`);
}

const forbiddenFiles = [
  "quickstart.ps1",
  "scripts/start-dream-skin.ps1",
  "scripts/watch-dream-skin.ps1",
  "scripts/recover-official-codex.ps1",
  "assets/renderer-inject.js",
  "Install AutoSkin on macOS.command",
  "Uninstall AutoSkin on macOS.command",
];
for (const file of forbiddenFiles) {
  assert.ok(!fs.existsSync(file), `legacy injection file must be removed: ${file}`);
}

for (const file of [
  "manager/KleeSafetyCenter.ps1",
  "windows/Clean-Klee-Codex-Remnants.ps1",
  "installer/windows/KleeCodexSkin.iss",
  "Open Klee Theme Settings on macOS.command",
]) {
  const source = read(file);
  assert.ok(!source.includes("--remote-debugging-port"), `${file} still documents or invokes CDP injection`);
  assert.ok(!source.includes("Reset-AppxPackage"), `${file} still resets the official package`);
  assert.ok(!source.includes("Add-AppxPackage"), `${file} still re-registers the official package`);
}

console.log("Windows safety contract passed.");
