// Regenerate the curated starter-story audio with the real ElevenLabs narrator
// voices, capturing per-word timings for synced read-along.
//
// For each story in app/assets/storytime/starter_stories.json:
//   - resolve narratorKey -> ELEVENLABS_VOICE_{WALLY|FERN|RAY}
//   - POST the byte-identical storyText to /with-timestamps
//   - write <slug>.mp3 (from audio_base64) and <slug>.timing.json (word starts)
//
// Reads the real key + voice ids from functions/.secret.local. Hits the LIVE
// ElevenLabs API (the mock returns fake alignment), so this spends credits and
// overwrites bundled assets.
//
// Usage (from functions/):  node dev/generate_starter_stories.mjs
//   --dry   inspect the first response's shape without writing files

import {readFileSync, writeFileSync} from "node:fs";
import {fileURLToPath} from "node:url";
import {dirname, join} from "node:path";

const here = dirname(fileURLToPath(import.meta.url));
const assetsDir = join(here, "../../app/assets/storytime");
const manifestPath = join(assetsDir, "starter_stories.json");
const dryRun = process.argv.includes("--dry");

// --- secrets ---------------------------------------------------------------
const secrets = Object.fromEntries(
  readFileSync(join(here, "../.secret.local"), "utf8")
    .split("\n")
    .filter((l) => l.includes("="))
    .map((l) => {
      const idx = l.indexOf("=");
      return [l.slice(0, idx).trim(), l.slice(idx + 1).trim()];
    }),
);
const apiKey = secrets.ELEVENLABS_API_KEY;
if (!apiKey) throw new Error("ELEVENLABS_API_KEY not found in functions/.secret.local");

const voiceFor = {
  wizardWally: secrets.ELEVENLABS_VOICE_WALLY,
  fairyFern: secrets.ELEVENLABS_VOICE_FERN,
  roboRay: secrets.ELEVENLABS_VOICE_RAY,
};

// --- tokenizer (MUST match the Flutter StoryTokenizer) ---------------------
// Split into \S+ runs, each carrying its character offset into storyText.
function tokenize(text) {
  const tokens = [];
  const re = /\S+/g;
  let m;
  while ((m = re.exec(text)) !== null) {
    tokens.push({i: tokens.length, offset: m.index});
  }
  return tokens;
}

// Map each storyText character index to its start time (seconds) from the
// literal `alignment` block. The literal alignment's characters reconstruct the
// exact input text; if they don't line up, walk both to stay robust.
function charStartTimes(text, alignment) {
  const chars = alignment.characters ?? [];
  const starts =
    alignment.character_start_times_seconds ??
    alignment.characterStartTimesSeconds ??
    [];
  if (chars.join("") === text && starts.length === text.length) {
    return starts;
  }
  // Fallback: align the two character streams, carrying the last known start
  // through any positions the API collapsed or expanded.
  const out = new Array(text.length).fill(0);
  let ai = 0;
  let last = 0;
  for (let ti = 0; ti < text.length; ti++) {
    if (ai < chars.length && chars[ai] === text[ti]) {
      last = starts[ai] ?? last;
      out[ti] = last;
      ai++;
    } else {
      out[ti] = last;
    }
  }
  return out;
}

function deriveTiming(text, alignment) {
  const startAt = charStartTimes(text, alignment);
  const words = tokenize(text).map((t) => ({
    i: t.i,
    start: Number((startAt[t.offset] ?? 0).toFixed(3)),
  }));
  return {words};
}

async function ttsWithTimestamps(voiceId, text) {
  const res = await fetch(
    `https://api.elevenlabs.io/v1/text-to-speech/${voiceId}/with-timestamps`,
    {
      method: "POST",
      headers: {"xi-api-key": apiKey, "content-type": "application/json"},
      body: JSON.stringify({
        text,
        model_id: "eleven_multilingual_v2",
        voice_settings: {stability: 0.55, similarity_boost: 0.75},
      }),
    },
  );
  if (!res.ok) {
    throw new Error(`TTS ${res.status}: ${await res.text().catch(() => "")}`);
  }
  return res.json();
}

// --- main ------------------------------------------------------------------
const manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
let first = true;

for (const story of manifest) {
  const voiceId = voiceFor[story.narratorKey];
  if (!voiceId) throw new Error(`No voice id for narrator ${story.narratorKey}`);
  const slug = story.audioAsset.split("/").pop().replace(/\.[^.]+$/, "");

  process.stdout.write(`• ${story.id} (${story.narratorKey}) … `);
  const body = await ttsWithTimestamps(voiceId, story.storyText);

  if (first) {
    first = false;
    const al = body.alignment ?? {};
    console.log(
      `\n  [shape] top keys: ${Object.keys(body).join(", ")}` +
        `\n  [shape] alignment keys: ${Object.keys(al).join(", ")}` +
        `\n  [shape] chars=${(al.characters ?? []).length} ` +
        `starts=${(al.character_start_times_seconds ?? al.characterStartTimesSeconds ?? []).length} ` +
        `textLen=${story.storyText.length}`,
    );
    if (dryRun) {
      console.log("  --dry: stopping after first response");
      break;
    }
    process.stdout.write(`  ${story.id} … `);
  }

  const mp3 = Buffer.from(body.audio_base64 ?? body.audioBase64, "base64");
  const timing = deriveTiming(story.storyText, body.alignment ?? {});

  writeFileSync(join(assetsDir, `${slug}.mp3`), mp3);
  writeFileSync(
    join(assetsDir, `${slug}.timing.json`),
    JSON.stringify(timing),
  );
  console.log(`mp3 ${mp3.length}B, ${timing.words.length} words`);
}

if (!dryRun) console.log("done.");
