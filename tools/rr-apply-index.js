#!/usr/bin/env node
/** Expand Relative Readings MVP payloads. From repo root: node tools/rr-apply-index.js */
const fs = require("fs");
const zlib = require("zlib");
const path = require("path");
const root = path.join(__dirname, "..");
const files = {
  "functions/src/index.ts": "rr-index.ts.gz.b64",
  "public/invite/app.js": "rr-app.js.gz.b64",
};
for (const [rel, name] of Object.entries(files)) {
  const b64Path = path.join(__dirname, name);
  if (!fs.existsSync(b64Path)) { console.warn("skip missing", name); continue; }
  const out = path.join(root, rel);
  fs.mkdirSync(path.dirname(out), { recursive: true });
  fs.writeFileSync(out, zlib.gunzipSync(Buffer.from(fs.readFileSync(b64Path, "utf8").trim(), "base64")));
  console.log("wrote", rel, fs.statSync(out).size);
}
