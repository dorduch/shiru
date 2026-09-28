#!/usr/bin/env node
/** Expand Relative Readings MVP payloads into the repo. Run from repo root: node tools/rr-apply-index.js */
const fs = require("fs");
const zlib = require("zlib");
const path = require("path");
const root = path.join(__dirname, "..");
const b64 = fs.readFileSync(path.join(__dirname, "rr-index.ts.gz.b64"), "utf8").trim();
const out = path.join(root, "functions/src/index.ts");
fs.writeFileSync(out, zlib.gunzipSync(Buffer.from(b64, "base64")));
console.log("wrote", out, fs.statSync(out).size);
