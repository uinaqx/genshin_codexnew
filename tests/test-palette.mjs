import assert from "node:assert/strict";
import fs from "node:fs";

const palette = JSON.parse(fs.readFileSync("themes/klee-spark-knight/palette.json", "utf8"));
assert.equal(palette.id, "klee-spark-knight");
assert.equal(palette.version, 2);
assert.equal(palette.mode, "light");
for (const key of ["accent", "background", "foreground", "secondary", "surface"]) {
  assert.match(palette.colors[key], /^#[0-9A-F]{6}$/);
}
assert.deepEqual(palette.safety, {
  modifiesApplicationPackage: false,
  usesDebugPort: false,
  writesCodexConfig: false,
  installsWatcher: false,
});

const luminance = (hex) => {
  const channel = (offset) => {
    const value = Number.parseInt(hex.slice(offset, offset + 2), 16) / 255;
    return value <= 0.03928 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4;
  };
  return 0.2126 * channel(1) + 0.7152 * channel(3) + 0.0722 * channel(5);
};
const contrast = (a, b) => {
  const high = Math.max(luminance(a), luminance(b));
  const low = Math.min(luminance(a), luminance(b));
  return (high + 0.05) / (low + 0.05);
};
assert.ok(contrast(palette.colors.foreground, palette.colors.background) >= 7, "foreground contrast must be AAA");
assert.ok(contrast("#FFFFFF", palette.colors.accent) >= 4.5, "white on accent must meet AA");
console.log("Klee palette contract passed.");
