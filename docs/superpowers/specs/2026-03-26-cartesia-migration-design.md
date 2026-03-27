# Design: Replace ElevenLabs with Cartesia API

**Date:** 2026-03-26
**Status:** Approved

---

## Context

The app uses ElevenLabs for two things: voice cloning (parent records a family member's voice → stored as a cloned voice) and TTS (story builder converts text to MP3 using cloned or stock voices). We're replacing ElevenLabs with Cartesia's Sonic-3 API. The APIs are structurally similar, making this an in-place surgical swap.

**Why Cartesia:** Not specified — assumed cost, quality, or API preference.

---

## Approach: In-place surgical replacement (Approach A)

Edit the two existing service files directly. Keep the same service names (already provider-agnostic). Update HTTP calls, rename constants, add the `Cartesia-Version` header, rename the DB column via migration.

---

## Architecture

No structural changes. The same files, same method signatures, same providers. Only the HTTP internals and a DB column name change.

---

## Changes by File

### 1. `app/lib/services/voice_clone_service.dart`

**Before:**
```
POST https://api.elevenlabs.io/v1/voices/add
Header: xi-api-key: <key>
Response: { "voice_id": "..." }

DELETE https://api.elevenlabs.io/v1/voices/{id}
Header: xi-api-key: <key>
```

**After:**
```
POST https://api.cartesia.ai/voices/clone
Headers:
  Authorization: Bearer <key>
  Cartesia-Version: 2025-04-16
Body: multipart/form-data { clip, name, language: "en" }
Response: { "id": "..." }   ← field renamed from voice_id to id

DELETE https://api.cartesia.ai/voices/{id}
Headers:
  Authorization: Bearer <key>
  Cartesia-Version: 2025-04-16
```

Changes:
- Rename env var `ELEVENLABS_API_KEY` → `CARTESIA_API_KEY`
- Add `static const _cartesiaVersion = '2025-04-16'`
- Update `cloneVoice()`: new URL, headers, add `language: "en"` field, parse `.id` instead of `.voice_id`
- Update `deleteVoice()`: new URL, headers

### 2. `app/lib/services/story_builder_service.dart`

**Before:**
```
POST https://api.elevenlabs.io/v1/text-to-speech/{voiceId}
Header: xi-api-key: <key>
Body: { model_id: "eleven_v3", text, voice_settings: { stability, similarity_boost } }
Response: binary MP3
```

**After:**
```
POST https://api.cartesia.ai/tts/bytes
Headers:
  Authorization: Bearer <key>
  Cartesia-Version: 2025-04-16
Body: {
  model_id: "sonic-3",
  transcript: <text>,
  voice: { mode: "id", id: <voiceId> },
  output_format: { container: "mp3", bit_rate: 128, sample_rate: 44100 },
  language: "en"
}
Response: binary MP3 (same as before)
```

Changes:
- Rename env var constant to `CARTESIA_API_KEY`
- Add `_cartesiaVersion` constant (share pattern with voice_clone_service)
- Update `generateAudio()`: new URL (no voiceId in path), new headers, restructured body
- Replace voice settings (`stability`/`similarity_boost`) with none (Cartesia defaults are good for kids' stories)
- **Stock voices:** Replace `_voiceIds` list with `_loadStockVoices()` async method that calls `GET /voices?language=en&limit=6` and caches the result in memory. The `StoryBuilderState` stock voice display names/emojis will be generic (Voice 1–6) until voices load, then show real names from the API response.
- **SSML:** No changes needed — Cartesia supports `<break time="..."/>` with identical syntax.

### 3. `app/lib/models/voice_profile.dart`

- Rename field `elevenLabsVoiceId` → `voiceId`
- Update `fromMap()`: read from `voice_id` column (after migration)
- Update `toMap()`: write to `voice_id` column

### 4. `app/lib/db/database_service.dart`

- Add DB version bump (e.g., version 3 → 4)
- Migration via table recreation (SQLite `RENAME COLUMN` requires 3.25+ and is unreliable on older Android):
  1. `CREATE TABLE voice_profiles_new (id, name, voice_id, sample_path, created_at)`
  2. `INSERT INTO voice_profiles_new SELECT id, name, elevenlabs_voice_id, sample_path, created_at FROM voice_profiles`
  3. `DROP TABLE voice_profiles`
  4. `ALTER TABLE voice_profiles_new RENAME TO voice_profiles`
- Update all SQL queries referencing `elevenlabs_voice_id` → `voice_id`

### 5. `app/android/app/src/main/res/xml/network_security_config.xml`

- Replace domain entry `api.elevenlabs.io` → `api.cartesia.ai`

### 6. `app/build_release.sh` + `env.json.example` (if exists)

- Rename `ELEVENLABS_API_KEY` → `CARTESIA_API_KEY` in the build script
- Update any example/template env files

### 7. `app/lib/providers/voice_profiles_provider.dart`

- Update field references: `elevenLabsVoiceId` → `voiceId`

### 8. `app/lib/providers/story_builder_provider.dart` + state

- `StoryBuilderState._voiceIds`: remove hardcoded list
- Stock voices now fetched from API; provider loads them on init
- Voice display: use `name` from Cartesia API response instead of hardcoded names (Sarah, Rachel, etc.)

---

## Stock Voices: Dynamic Loading

Instead of 6 hardcoded ElevenLabs voice IDs, the story builder will call:

```
GET https://api.cartesia.ai/voices?language=en&limit=6
Headers: Authorization, Cartesia-Version
```

Returns public voices accessible to the account. No `is_public` filter needed — Cartesia returns accessible voices by default.

Result cached in memory for the session. Story builder shows a loading state while fetching. On failure, shows an empty stock voices section (family voices still work).

---

## Data Flow (unchanged)

```
Parent records → VoiceCloneService.cloneVoice() → voice_id stored in SQLite
Story builder → StoryBuilderService.generateAudio(text, voiceId) → MP3 saved locally
```

---

## Error Handling

No new error modes introduced. Existing 60-second timeouts kept. Add one new case: if stock voices fail to load, show empty list gracefully (don't block story creation with a family voice).

---

## Not Changing

- OpenAI story generation logic
- SSML break tags in story prompts (compatible)
- Audio playback (`just_audio`)
- Database encryption
- All UI/UX flows
- PIN authentication

---

## Env Variables

| Old | New |
|---|---|
| `ELEVENLABS_API_KEY` | `CARTESIA_API_KEY` |

`env.json` format:
```json
{
  "OPENAI_API_KEY": "sk-proj-...",
  "CARTESIA_API_KEY": "sk_car_...",
  "GIPHY_API_KEY": "..."
}
```

---

## Verification

1. **Voice cloning:** Parent flow: record voice → processing screen → success. Check voice appears in Cartesia dashboard.
2. **Voice deletion:** Delete a profile → confirm it's removed from Cartesia dashboard.
3. **TTS with cloned voice:** Story builder → select family voice → generate → audio plays correctly with `<break>` pauses working.
4. **TTS with stock voice:** Story builder → stock voice → generate → audio plays.
5. **Stock voices load:** Story builder step 3 shows real voice names from Cartesia.
6. **DB migration:** Fresh install and upgrade path both work (voice profiles intact after upgrade).
7. **Build:** `flutter build apk --dart-define-from-file=env.json` succeeds with `CARTESIA_API_KEY`.
