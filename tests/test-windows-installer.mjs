import assert from "node:assert/strict";
import fs from "node:fs";

const manager = fs.readFileSync("manager/KleeSkinManager.ps1", "utf8");
const installer = fs.readFileSync("installer/windows/KleeCodexSkin.iss", "utf8");
const workflow = fs.readFileSync(".github/workflows/windows-installer.yml", "utf8");
const common = fs.readFileSync("scripts/lib/windows-common.ps1", "utf8");
const recovery = fs.readFileSync("scripts/recover-official-codex.ps1", "utf8");

for (const action of ["Invoke-EnableSkin", "Invoke-RestoreOfficial", "PrepareUninstall"]) {
  assert.ok(manager.includes(action), `manager is missing ${action}`);
}
assert.ok(manager.includes("klee-spark-knight"));
assert.ok(manager.includes("unins000.exe"));
assert.ok(manager.includes("-NoAutoRecover"), "manager must not arm the watcher before a healthy launch");
assert.ok(manager.includes("Start-DreamCodexOfficial"), "restore must relaunch the official app entrypoint");
assert.ok(manager.includes("Export-DreamDiagnostics"), "manager must provide a local diagnostic report");
assert.ok(manager.includes("26.700.0.0"), "incompatible Store builds must be blocked before configuration changes");
assert.ok(manager.includes("Invoke-EmergencyRecovery"), "manager must expose exact recovery");
assert.ok(installer.includes("PrivilegesRequired=lowest"));
assert.ok(installer.includes("[UninstallRun]"));
assert.ok(installer.includes("KleeSkinManager.ps1"));
assert.ok(workflow.includes("node.exe"), "portable Node must be bundled");
assert.ok(workflow.includes("gh release create"), "installer must be published as a release asset");
assert.ok(common.includes("runtime\\node\\node.exe"), "engine must discover bundled Node");
assert.ok(common.includes("shell:AppsFolder"), "official recovery must use the Store app entrypoint");
assert.ok(installer.includes("-EmergencyRecover"), "installer must recover instead of auto-enabling on affected builds");
assert.ok(recovery.includes("LocalCache\\Roaming\\Codex"), "recovery must reset the real MSIX roaming profile");
assert.ok(recovery.includes("LocalCache\\Local\\Codex"), "recovery must collect and reset the real MSIX local profile");
assert.ok(recovery.includes("Reset-AppxPackage"), "recovery must reset the current-user MSIX package state");
assert.ok(recovery.includes("Add-AppxPackage"), "recovery must re-register the official package");
assert.ok(recovery.includes("auth.json"), "full recovery must force a clean account session");
assert.ok(recovery.includes("cap_sid"), "full recovery must reset the secondary account session marker");
assert.ok(recovery.includes("before-klee-recovery"), "every moved item must have a recoverable backup name");
assert.ok(recovery.includes("Official app logs"), "recovery must capture official app errors before and after reset");
assert.ok(!recovery.includes("Get-Content -LiteralPath $auth"), "recovery must not read auth.json contents");

console.log("Windows installer contract passed.");
