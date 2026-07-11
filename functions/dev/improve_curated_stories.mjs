// One-off content uplift for the 6 curated starter stories: rewrite each
// through the SAME AI model + safety-review methodology the production
// story-generation pipeline uses (see functions/src/index.ts storyPrompt() /
// createSafeStory(), and functions/src/domain.ts safetyPassed() /
// wordCountFor()) — targeting the "early" age band (~350 words). The 6
// bundled stories were hand-written directly and never passed through the
// generation+safety-review loop, and are all well under the production
// word-count target.
//
// This is a REWRITE, not a replacement: keeps each story's existing title,
// character(s)/names, setting, and core plot/resolution. Does not touch
// id / audioAsset / color / spriteKey / narratorKey / timingAsset.
//
// Hits the LIVE Anthropic API (spends real credits).
//
// Usage (from functions/):  node dev/improve_curated_stories.mjs
//   --dry   run the full 2-call flow for just the FIRST story, log
//           before/after word count + safety result, and do NOT write the file

import {readFileSync, writeFileSync} from "node:fs";
import {fileURLToPath} from "node:url";
import {dirname, join} from "node:path";

const here = dirname(fileURLToPath(import.meta.url));
const assetsDir = join(here, "../../app/assets/storytime");
const manifestPath = join(assetsDir, "starter_stories.json");
const dryRun = process.argv.includes("--dry");

const TARGET_WORDS = 350; // AgeBand.early — see domain.ts wordCountFor()
const MODEL = "claude-haiku-4-5-20251001";

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
const apiKey = secrets.ANTHROPIC_API_KEY;
if (!apiKey) throw new Error("ANTHROPIC_API_KEY not found in functions/.secret.local");

// --- Anthropic call + JSON extraction (mirrors anthropicJson() in index.ts) -
async function anthropicJson(prompt, maxTokens) {
  const response = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      model: MODEL,
      max_tokens: maxTokens,
      messages: [{role: "user", content: prompt}],
    }),
  });
  if (!response.ok) {
    throw new Error(`Anthropic ${response.status}: ${await response.text().catch(() => "")}`);
  }
  const body = await response.json();
  const text = body.content.find((item) => item.type === "text")?.text;
  if (!text) throw new Error("Anthropic returned no text");
  const json = text.match(/\{[\s\S]*\}/)?.[0];
  if (!json) throw new Error("Anthropic returned invalid JSON");
  return JSON.parse(json);
}

function wordCount(text) {
  return text.trim().split(/\s+/).filter(Boolean).length;
}

// --- rewrite prompt ----------------------------------------------------------
function rewritePrompt(title, storyText, retry) {
  return `Rewrite and improve this children's audio story to be a fuller, richer version of about ${TARGET_WORDS} words,
while keeping the exact same title, the same character name(s), the same setting, and the same core
plot and resolution. Improve pacing, sensory detail, warmth, and read-aloud rhythm — do not change who
the characters are, what happens, or the ending. Keep conflict gentle and emotionally safe. No graphic
danger, weapons, death, abuse, hate, romance, substances, self-harm, frightening imagery, brands, or
requests to buy. This story is for a child in age band "early" (ages ~3-5).
${retry ? "The previous version failed a child-safety review. Make this version calmer and safer." : ""}
Title: ${title}
Original story: ${storyText}
Return only JSON: {"title":"...","story":"..."}.`;
}

// --- safety review (verbatim shape of createSafeStory()'s review prompt) ----
function reviewPrompt(story) {
  return `Review this children's story for sexual content, graphic or intense violence, self-harm, abuse,
hate, substances, unsafe instructions, frightening intensity, or commercial persuasion.
Return only JSON: {"safe":true|false,"concerns":["..."]}. Story: ${story}`;
}

function safetyPassed(value) {
  if (!value || typeof value !== "object") return false;
  return value.safe === true && Array.isArray(value.concerns) && value.concerns.length === 0;
}

// --- per-story rewrite + review, max 2 attempts -----------------------------
async function improveStory(story) {
  const originalTitle = story.title;
  const originalWords = wordCount(story.storyText);

  for (let attempt = 0; attempt < 2; attempt++) {
    const generated = await anthropicJson(
      rewritePrompt(originalTitle, story.storyText, attempt > 0),
      2000,
    );
    if (typeof generated.title !== "string" || typeof generated.story !== "string") {
      console.log(`  [${story.id}] attempt ${attempt + 1}: malformed generation response, retrying`);
      continue;
    }

    let finalTitle = generated.title.trim();
    if (finalTitle !== originalTitle) {
      console.log(
        `  [${story.id}] WARNING: model changed title ("${finalTitle}") — keeping original ("${originalTitle}")`,
      );
      finalTitle = originalTitle;
    }

    const review = await anthropicJson(reviewPrompt(generated.story), 500);
    const passed = safetyPassed(review);
    const newWords = wordCount(generated.story);
    console.log(
      `  [${story.id}] attempt ${attempt + 1}/2: ${originalWords} -> ${newWords} words, safety ${
        passed ? "PASS" : "FAIL"
      }${passed ? "" : ` (concerns: ${JSON.stringify(review?.concerns ?? review)})`}`,
    );

    if (passed) {
      return {title: finalTitle, story: generated.story, attempts: attempt + 1, originalWords, newWords};
    }
  }

  throw new Error(`safety-rejected after 2 attempts for ${story.id}`);
}

// --- main --------------------------------------------------------------------
const manifest = JSON.parse(readFileSync(manifestPath, "utf8"));

if (dryRun) {
  const story = manifest[0];
  console.log(`--dry: running full rewrite+review flow for first story only (${story.id})`);
  try {
    const result = await improveStory(story);
    console.log(
      `\n--dry result: "${result.title}" — ${result.originalWords} -> ${result.newWords} words, ` +
        `${result.attempts} safety attempt(s). Not writing file.`,
    );
    console.log(`\n--- rewritten story text ---\n${result.story}\n--- end ---`);
  } catch (error) {
    console.error(`--dry FAILED: ${error.message}`);
    process.exitCode = 1;
  }
  process.exit(0);
}

console.log(`Rewriting ${manifest.length} curated stories to ~${TARGET_WORDS} words each...\n`);

let changed = 0;
for (const story of manifest) {
  console.log(`• ${story.id} ("${story.title}")`);
  try {
    const result = await improveStory(story);
    story.storyText = result.story;
    changed++;
    console.log(`  -> updated (${result.originalWords} -> ${result.newWords} words, ${result.attempts} attempt(s))\n`);
  } catch (error) {
    console.error(`  -> FAILED, leaving original text untouched: ${error.message}\n`);
  }
}

writeFileSync(manifestPath, JSON.stringify(manifest, null, 2));
console.log(`done. ${changed}/${manifest.length} stories updated. Wrote ${manifestPath}`);
