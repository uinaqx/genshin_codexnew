import assert from "node:assert/strict";
import fs from "node:fs";

const manager = fs.readFileSync("manager/KleeSkinManager.ps1", "utf8");
const installer = fs.readFileSync("installer/windows/KleeCodexSkin.iss", "utf8");
const workflow = fs.readFileSync(".github/workflows/windows-installer.yml", "utf8");
const common = fs.readFileSync("scripts/lib/windows-common.ps1", "utf8");

for (const action of ["Invoke-EnableSkin", "Invoke-RestoreOfficial", "PrepareUninstall"]) {
  assert.ok(manager.includes(action), `manager is missing ${action}`);
}
assert.ok(manager.includes("klee-spark-knight"));
assert.ok(manager.includes("unins000.exe"));
assert.ok(installer.includes("PrivilegesRequired=lowest"));
assert.ok(installer.includes("[UninstallRun]"));
assert.ok(installer.includes("KleeSkinManager.ps1"));
assert.ok(workflow.includes("node.exe"), "portable Node must be bundled");
assert.ok(workflow.includes("gh release create"), "installer must be published as a release asset");
assert.ok(common.includes("runtime\\node\\node.exe"), "engine must discover bundled Node");

console.log("Windows installer contract passed.");
