require('dotenv').config();

const express = require('express');
const https = require('https');
const path = require('path');

const app = express();
const PORT = 3456;

// Warn on startup if API keys are missing
if (!process.env.OPENAI_API_KEY) {
  console.warn('⚠️  Warning: OPENAI_API_KEY is not set in .env');
}
if (!process.env.CARTESIA_API_KEY) {
  console.warn('⚠️  Warning: CARTESIA_API_KEY is not set in .env');
}
if (!process.env.ELEVENLABS_API_KEY) {
  console.warn('⚠️  Warning: ELEVENLABS_API_KEY is not set in .env');
}

// Middleware
app.use(express.json({ limit: '10mb' }));
app.use(express.static(path.join(__dirname)));

// Helper: make an HTTPS request and return a Promise resolving to { statusCode, headers, body }
function httpsRequest(options, body) {
  return new Promise((resolve, reject) => {
    const req = https.request(options, (res) => {
      const chunks = [];
      res.on('data', (chunk) => chunks.push(chunk));
      res.on('end', () => resolve({ statusCode: res.statusCode, headers: res.headers, body: Buffer.concat(chunks) }));
    });
    req.on('error', reject);
    if (body) req.write(body);
    req.end();
  });
}

// GET /api/voices — proxy to Cartesia stock voices
app.get('/api/voices', async (req, res) => {
  const queryString = new URLSearchParams(req.query).toString();
  const urlPath = queryString ? `/voices?${queryString}` : '/voices';

  console.log(`[proxy] GET /api/voices -> GET https://api.cartesia.ai${urlPath}`);

  try {
    const response = await httpsRequest({
      hostname: 'api.cartesia.ai',
      path: urlPath,
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${process.env.CARTESIA_API_KEY}`,
        'Cartesia-Version': '2025-04-16',
      },
    });

    console.log(`[proxy] GET /api/voices <- ${response.statusCode}`);
    res.status(response.statusCode).type('application/json').send(response.body);
  } catch (err) {
    console.error('[proxy] GET /api/voices error:', err.message);
    res.status(500).json({ error: 'Failed to proxy request to Cartesia', details: err.message });
  }
});

// GET /api/elevenlabs/voices — proxy to ElevenLabs stock voices
app.get('/api/elevenlabs/voices', async (req, res) => {
  const queryString = new URLSearchParams(req.query).toString();
  const urlPath = queryString ? `/v1/voices?${queryString}` : '/v1/voices';

  console.log(`[proxy] GET /api/elevenlabs/voices -> GET https://api.elevenlabs.io${urlPath}`);

  try {
    const response = await httpsRequest({
      hostname: 'api.elevenlabs.io',
      path: urlPath,
      method: 'GET',
      headers: {
        'xi-api-key': process.env.ELEVENLABS_API_KEY,
        'Accept': 'application/json',
      },
    });

    console.log(`[proxy] GET /api/elevenlabs/voices <- ${response.statusCode}`);
    res.status(response.statusCode).type('application/json').send(response.body);
  } catch (err) {
    console.error('[proxy] GET /api/elevenlabs/voices error:', err.message);
    res.status(500).json({ error: 'Failed to proxy request to ElevenLabs', details: err.message });
  }
});

// POST /api/generate-story — proxy to OpenAI chat completions
app.post('/api/generate-story', async (req, res) => {
  console.log('[proxy] POST /api/generate-story -> POST https://api.openai.com/v1/chat/completions');

  const bodyStr = JSON.stringify(req.body);

  try {
    const response = await httpsRequest({
      hostname: 'api.openai.com',
      path: '/v1/chat/completions',
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${process.env.OPENAI_API_KEY}`,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(bodyStr),
      },
    }, bodyStr);

    console.log(`[proxy] POST /api/generate-story <- ${response.statusCode}`);
    res.status(response.statusCode).type('application/json').send(response.body);
  } catch (err) {
    console.error('[proxy] POST /api/generate-story error:', err.message);
    res.status(500).json({ error: 'Failed to proxy request to OpenAI', details: err.message });
  }
});

// POST /api/generate-audio — proxy to Cartesia TTS (returns raw MP3 bytes)
app.post('/api/generate-audio', async (req, res) => {
  console.log('[proxy] POST /api/generate-audio -> POST https://api.cartesia.ai/tts/bytes');

  const bodyStr = JSON.stringify(req.body);

  try {
    const response = await httpsRequest({
      hostname: 'api.cartesia.ai',
      path: '/tts/bytes',
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${process.env.CARTESIA_API_KEY}`,
        'Cartesia-Version': '2025-04-16',
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(bodyStr),
      },
    }, bodyStr);

    console.log(`[proxy] POST /api/generate-audio <- ${response.statusCode}`);
    res.status(response.statusCode).type('audio/mpeg').send(response.body);
  } catch (err) {
    console.error('[proxy] POST /api/generate-audio error:', err.message);
    res.status(500).json({ error: 'Failed to proxy request to Cartesia', details: err.message });
  }
});

// POST /api/elevenlabs/generate-audio — proxy to ElevenLabs streaming TTS
app.post('/api/elevenlabs/generate-audio', async (req, res) => {
  const voiceId = req.body?.voice_id || req.body?.voiceId;
  if (!voiceId) {
    return res.status(400).json({ error: 'voice_id is required for ElevenLabs synthesis' });
  }

  const payload = { ...req.body };
  delete payload.voice_id;
  delete payload.voiceId;
  const bodyStr = JSON.stringify(payload);

  const path = `/v1/text-to-speech/${voiceId}/stream`;
  console.log(`[proxy] POST /api/elevenlabs/generate-audio -> POST https://api.elevenlabs.io${path}`);

  try {
    const response = await httpsRequest({
      hostname: 'api.elevenlabs.io',
      path,
      method: 'POST',
      headers: {
        'xi-api-key': process.env.ELEVENLABS_API_KEY,
        'Accept': 'audio/mpeg',
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(bodyStr),
      },
    }, bodyStr);

    console.log(`[proxy] POST /api/elevenlabs/generate-audio <- ${response.statusCode}`);

    const contentType = response.headers['content-type'] || '';
    const isJson = contentType.includes('application/json');
    res.status(response.statusCode).type(isJson ? 'application/json' : 'audio/mpeg').send(response.body);
  } catch (err) {
    console.error('[proxy] POST /api/elevenlabs/generate-audio error:', err.message);
    res.status(500).json({ error: 'Failed to proxy request to ElevenLabs', details: err.message });
  }
});

app.listen(PORT, () => {
  console.log(`🎭 Story Playground running at http://localhost:${PORT}`);
});
