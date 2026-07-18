import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const report = JSON.parse(execFileSync(process.execPath, ["scripts/injector.mjs", "--themes"], {
  cwd: root,
  encoding: "utf8",
}));

assert.equal(report.defaultTheme, "klee-spark-knight");
const klee = report.themes.find((theme) => theme.name === "klee-spark-knight");
assert.ok(klee, "Klee theme was not discovered");
assert.equal(klee.default, true);
assert.equal(klee.extraCss, true, "Klee theme extra.css was rejected");
assert.deepEqual(klee.stickers, ["bubble", "board", "corner"]);

for (const relativePath of [
  "themes/klee-spark-knight/art.webp",
  "themes/klee-spark-knight/theme.json",
  "themes/klee-spark-knight/extra.css",
  "docs/previews/home-fullscreen.webp",
  "docs/previews/chat.webp",
]) {
  const absolutePath = path.join(root, relativePath);
  assert.ok(fs.statSync(absolutePath).size > 0, `${relativePath} is missing or empty`);
}

console.log("Klee theme validation passed.");
