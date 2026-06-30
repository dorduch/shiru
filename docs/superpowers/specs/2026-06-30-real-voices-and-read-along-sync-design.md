# Track B — Real narrator voices + synced read-along

**Date:** 2026-06-30
**Branch:** feature/storytime-mvp
**Scope:** Curated/bundled stories only.

## Problem

1. **#2 — Curated stories use system-TTS audio.** The 6 bundled starter stories
   ship placeholder `.wav` audio that sounds like system text-to-speech. Generated
   stories already use real ElevenLabs voices via the backend `builtinMap`
   (`functions/src/index.ts`), so only the curated set is affected.
2. **#3 — Read-along is not synced.** The player highlights words with a linear
   `progress × wordCount` estimate, which drifts. There is also a tokenization
   bug: the highlight index uses `storyText.split(\s+)` while the renderer uses
   `text.split(' ')`, so the two word arrays diverge at every `\n\n` paragraph
   break.

## Out of scope (deferred consciously)

- **Generated-story sync.** Wiring real timings for AI-generated stories means
  adding `/with-timestamps` at `functions/src/index.ts:346` and persisting word
  timings through Firestore/Storage → `AudioCard` → device. That is a larger,
  less-testable change on an in-flight backend, and generated story-gen currently
  fails on the simulator (App Check). Generated stories keep the linear estimate.
- **Narrator previews.** The `preview_*.wav` clips are not regenerated. Their line
  text is not in the manifest, and each preview shares its story's `voiceId` +
  settings, so they already sound like the same narrator. A tiny follow-on if a
  mismatch ever surfaces.

## Key facts

- Voice IDs already exist in `functions/.secret.local`:
  `ELEVENLABS_VOICE_WALLY`, `ELEVENLABS_VOICE_FERN`, `ELEVENLABS_VOICE_RAY`.
- Generation pattern established in `functions/dev/real_clone_demo.mjs`:
  model `eleven_multilingual_v2`, `voice_settings {stability: 0.55, similarity_boost: 0.75}`.
- `narratorKey` → voice: `wizardWally→WALLY`, `fairyFern→FERN`, `roboRay→RAY`.

## Design

### #2 — Regenerate curated audio (offline script)

`functions/dev/generate_starter_stories.mjs` (mirrors `real_clone_demo.mjs`,
reads `.secret.local`):

- For each story in `app/assets/storytime/starter_stories.json`: resolve the
  voice from `narratorKey`, POST the **byte-identical** `storyText` to
  `/v1/text-to-speech/{voiceId}/with-timestamps` with the model/settings above.
- Write `<slug>.mp3` (decoded from `audio_base64`) and `<slug>.timing.json`
  into `app/assets/storytime/`.
- Manifest: change each `audioAsset` to the `.mp3` file and add a `timingAsset`
  field. `just_audio` plays mp3; it is ~10× smaller than the `.wav` placeholders.
- Live API only — `functions/dev/elevenlabs_mock.cjs` returns fake alignment.
  This spends real ElevenLabs credits and overwrites bundled assets.

### #3 — Synced read-along

**Timing JSON** (per story): word start-times derived from the response's
`alignment` (literal characters — **not** `normalized_alignment`, which is keyed
to ElevenLabs' normalized text). Word *i*'s start = the start time of its first
character. Schema:

```json
{ "words": [{ "i": 0, "start": 0.0 }, { "i": 1, "start": 0.31 }, ...] }
```

**Offset-based tokenizer** (the real correctness fix, shared by all three
consumers — timing derivation, index lookup, render):

- Tokenize `storyText` into `\S+` tokens, each carrying its character offset.
- The renderer emits the inter-token whitespace **verbatim** (so `\n\n`
  paragraph breaks survive) and styles token *i* as highlighted.
- One canonical token list means the timing array, the index, and the rendered
  spans are always the same length.

**Player:** for curated cards, load the timing JSON and map the audio position to
the highlighted word via binary search over word start-times. No timing
(generated stories) → keep the linear estimate.

**Invariant test:** `renderedSpanCount == timingWordCount` for each of the 6
stories. If they ever differ, highlight drift is guaranteed.

### Self-heal for installed devices

The Track A self-heal only repoints `spriteKey`; it skips existing card ids for
everything else, so already-seeded devices would keep the old audio. Add a
curated **content-version** gate to `StarterStoryService`: when the version
bumps, re-import the new audio + timing for existing curated cards. Otherwise an
already-seeded device never hears the new voices.

## Verification

- Generate against the **live** API; inspect the first response to confirm field
  names before trusting them.
- On-device: confirm the narrator voice sounds natural, and check highlight
  alignment **at a paragraph boundary** and **near the end of a story** (where the
  old linear estimate drifted) — not just the opening words.
- `flutter analyze` clean; the new invariant test + existing suite green
  (baseline: 9 pre-existing failures).
