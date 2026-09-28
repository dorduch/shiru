#!/usr/bin/env node
/** Join tools/rr-index-parts/partN.txt into functions/src/index.ts */
const fs = require("fs");
const path = require("path");
const root = path.join(__dirname, "..");
const dir = path.join(__dirname, "rr-index-parts");
const parts = fs.readdirSync(dir).filter((f) => /^part\d+\.txt$/.test(f)).sort((a, b) => {
  return parseInt(a.match(/\d+/)[0], 10) - parseInt(b.match(/\d+/)[0], 10);
});
let out = "";
for (const f of parts) out += fs.readFileSync(path.join(dir, f), "utf8");
const dest = path.join(root, "functions/src/index.ts");
fs.mkdirSync(path.dirname(dest), {recursive: true});
fs.writeFileSync(dest, out);
const crypto = require("crypto");
const hash = crypto.createHash("sha256").update(out).digest("hex");
const expected = fs.readFileSync(path.join(__dirname, "rr-index.sha256"), "utf8").trim();
if (hash !== expected) {
  console.error("hash mismatch", hash, "!=", expected);
  process.exit(1);
}
console.log("wrote", dest, out.length, hash);
