// Minimal mock of the ElevenLabs API for local emulator e2e of M4.
const http = require("http");
http.createServer((req, res) => {
  const chunks = [];
  req.on("data", (c) => chunks.push(c));
  req.on("end", () => {
    const bytes = Buffer.concat(chunks).length;
    if (req.method === "POST" && req.url === "/v1/voices/add") {
      console.log(`[mock] POST /v1/voices/add  (${bytes} bytes multipart received)`);
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
