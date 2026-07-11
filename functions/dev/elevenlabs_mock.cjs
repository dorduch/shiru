// Minimal mock of the ElevenLabs API for local emulator e2e of M4.
const http = require("http");

// Tiny multipart/form-data parser — dev-only, just enough to recover each
// part's Content-Disposition name/filename and Content-Type so the harness
// can confirm processVoiceClone is labeling webm vs m4a samples correctly.
function parseMultipart(buffer, boundary) {
  const boundaryBuf = Buffer.from(`--${boundary}`);
  const parts = [];
  let start = buffer.indexOf(boundaryBuf, 0);
  while (start !== -1) {
    const nextStart = buffer.indexOf(boundaryBuf, start + boundaryBuf.length);
    if (nextStart === -1) break;
    let partBuf = buffer.slice(start + boundaryBuf.length, nextStart);
    if (partBuf.slice(0, 2).toString("latin1") === "\r\n") partBuf = partBuf.slice(2);
    const headerEnd = partBuf.indexOf("\r\n\r\n");
    if (headerEnd !== -1) {
      const headerStr = partBuf.slice(0, headerEnd).toString("utf8");
      let body = partBuf.slice(headerEnd + 4);
      if (body.slice(-2).toString("latin1") === "\r\n") body = body.slice(0, -2);
      // No leading `.*` before `name=` — a greedy `.*name="` would backtrack through
      // "filename=" (which also contains "name=") and capture the filename into the
      // name group instead. Anchoring right after "form-data;" avoids that.
      const dispMatch = headerStr.match(/Content-Disposition:\s*form-data;\s*name="([^"]*)"(?:;\s*filename="([^"]*)")?/i);
      const typeMatch = headerStr.match(/Content-Type:\s*(\S+)/i);
      parts.push({
        name: dispMatch ? dispMatch[1] : undefined,
        filename: dispMatch ? dispMatch[2] : undefined,
        contentType: typeMatch ? typeMatch[1] : undefined,
        bodyLength: body.length,
      });
    }
    start = nextStart;
  }
  return parts;
}

http.createServer((req, res) => {
  const chunks = [];
  req.on("data", (c) => chunks.push(c));
  req.on("end", () => {
    const buf = Buffer.concat(chunks);
    if (req.method === "POST" && req.url === "/v1/voices/add") {
      console.log(`[mock] POST /v1/voices/add  (${buf.length} bytes multipart received)`);
      const contentType = req.headers["content-type"] || "";
      const boundaryMatch = contentType.match(/boundary=(?:"([^"]+)"|([^;]+))/);
      const boundary = boundaryMatch ? (boundaryMatch[1] || boundaryMatch[2]) : null;
      if (boundary) {
        const parts = parseMultipart(buf, boundary);
        const fileParts = parts.filter((p) => p.name === "files");
        for (const p of fileParts) {
          console.log(`[mock]   file part: filename=${p.filename} contentType=${p.contentType} bytes=${p.bodyLength}`);
        }
        // Dev-only sanity check: webm fixtures must NOT be mislabeled as audio/mp4, and
        // vice versa, so a human running the harness can see the fix is actually working.
        for (const p of fileParts) {
          if (p.filename && p.filename.endsWith(".webm") && p.contentType !== "audio/webm") {
            console.error(`[mock]   MISMATCH: ${p.filename} sent with contentType=${p.contentType}, expected audio/webm`);
          }
          if (p.filename && p.filename.endsWith(".m4a") && p.contentType !== "audio/mp4") {
            console.error(`[mock]   MISMATCH: ${p.filename} sent with contentType=${p.contentType}, expected audio/mp4`);
          }
        }
      } else {
        console.log("[mock]   (no multipart boundary found on content-type header; skipping part inspection)");
      }
      res.writeHead(200, {"content-type": "application/json"});
      res.end(JSON.stringify({voice_id: "mock_voice_" + Date.now(), requires_verification: false}));
    } else if (req.method === "DELETE" && req.url.startsWith("/v1/voices/")) {
      console.log(`[mock] DELETE ${req.url}`);
      res.writeHead(200, {"content-type": "application/json"});
      res.end("{}");
    } else {
      console.log(`[mock] ${req.method} ${req.url} -> 404`);
      res.writeHead(404);
      res.end("not found");
    }
  });
}).listen(4999, "127.0.0.1", () => console.log("[mock] ElevenLabs mock listening on http://127.0.0.1:4999"));
