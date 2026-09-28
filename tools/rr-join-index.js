#!/usr/bin/env node
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const zlib = require("zlib");
const root = path.join(__dirname, "..");

function joinParts(dirName, destRel, shaFile) {
  const dir = path.join(__dirname, dirName);
  if (!fs.existsSync(dir)) { console.warn("skip missing", dirName); return null; }
  const b64parts = fs.readdirSync(dir).filter((f) => /^part\d+\.b64$/.test(f)).sort(
    (a, b) => parseInt(a.match(/\d+/)[0], 10) - parseInt(b.match(/\d+/)[0], 10),
  );
  const txtparts = fs.readdirSync(dir).filter((f) => /^part\d+\.txt$/.test(f)).sort(
    (a, b) => parseInt(a.match(/\d+/)[0], 10) - parseInt(b.match(/\d+/)[0], 10),
  );
  let out;
  if (b64parts.length) {
    out = Buffer.concat(b64parts.map((f) => Buffer.from(fs.readFileSync(path.join(dir, f), "utf8").trim(), "base64")));
  } else if (txtparts.length) {
    out = Buffer.from(txtparts.map((f) => fs.readFileSync(path.join(dir, f), "utf8")).join(""), "utf8");
  } else {
    console.warn("no parts in", dirName); return null;
  }
  const dest = path.join(root, destRel);
  fs.mkdirSync(path.dirname(dest), {recursive: true});
  fs.writeFileSync(dest, out);
  if (shaFile && fs.existsSync(path.join(__dirname, shaFile))) {
    const hash = crypto.createHash("sha256").update(out).digest("hex");
    const expected = fs.readFileSync(path.join(__dirname, shaFile), "utf8").trim();
    if (hash !== expected) {
      console.error("hash mismatch", destRel, hash, "!=", expected);
      process.exit(1);
    }
  }
  console.log("wrote", destRel, out.length);
  return out;
}

function expandB64(name, destRel, shaFile) {
  const b64Path = path.join(__dirname, name);
  if (!fs.existsSync(b64Path)) { console.warn("skip missing", name); return; }
  const out = zlib.gunzipSync(Buffer.from(fs.readFileSync(b64Path, "utf8").trim(), "base64"));
  const dest = path.join(root, destRel);
  fs.mkdirSync(path.dirname(dest), {recursive: true});
  fs.writeFileSync(dest, out);
  if (shaFile && fs.existsSync(path.join(__dirname, shaFile))) {
    const hash = crypto.createHash("sha256").update(out).digest("hex");
    const expected = fs.readFileSync(path.join(__dirname, shaFile), "utf8").trim();
    if (hash !== expected) {
      console.error("hash mismatch", destRel, hash, "!=", expected);
      process.exit(1);
    }
  }
  console.log("wrote", destRel, out.length);
}

joinParts("rr-index-parts", "functions/src/indexBody.ts", "rr-index-body.sha256");
expandB64("rr-app.js.gz.b64", "public/invite/app.js", "rr-app.sha256");
