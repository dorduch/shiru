# AI-Generated Stories — Design Spec

**Date:** 2026-04-21  
**Status:** Approved

---

## Context

Shiru is a local-first audio card player for kids. Parents manage a library of audio cards; children tap them to play. This feature lets parents generate personalised bedtime/adventure stories using AI — picking a hero, theme, language, and length — and have the resulting audio automatically added to the library as a playable card.

---

## User Flow

Entry point: a **✨ Generate Story** button in `ParentListScreen` (parent area, PIN-protected).

The parent goes through a 3-step wizard on a dedicated screen (`/parent/generate-story`):

1. **Pick a hero** — scrollable grid of 10 options
2. **Pick a theme** — scrollable grid of 10 options
3. **Language & length** — 3-button language toggle (He / En / Es) + Short / Long toggle, then a **Generate** button

On Generate, a loading screen shows progress ("Writing story… Converting to audio… Saving to library…"). On success the screen closes and the new card appears in `ParentListScreen`. On failure an inline error with a **Retry** button is shown; no partial state is saved.

---

## Hero List

| Key | Display |
|-----|---------|
| knight | Knight / Princess 🧝 |
| wizard | Wizard 🧙 |
| astronaut | Astronaut 👨‍🚀 |
| pirate | Pirate 🏴‍☠️ |
| fairy | Fairy 🧚 |
| dragon | Dragon 🐉 |
| robot | Robot 🤖 |
| lion | Lion Cub 🦁 |
| bunny | Bunny 🐰 |
| superhero | Superhero 🦸 |

---

## Theme List

| Key | Display |
|-----|---------|
| adventure | Adventure / Quest ⚔️ |
| bedtime | Bedtime / Sleepy 🌙 |
| friendship | Friendship 🤝 |
| magic | Magic & Spells ✨ |
| space | Space 🚀 |
| ocean | Ocean / Underwater 🌊 |
| forest | Enchanted Forest 🌲 |
| funny | Funny / Silly 😂 |
| birthday | Birthday Surprise 🎂 |
| kindness | Kindness / Helping 💛 |

---

## Languages & Voices

One fixed ElevenLabs voice per language, using the `eleven_multilingual_v2` model:

| Language | Code | Voice |
|----------|------|-------|
| Hebrew | he | TBD — child-friendly Hebrew/multilingual voice |
| English | en | TBD — child-friendly English voice |
| Spanish | es | TBD — child-friendly Spanish voice |

Voice IDs are hardcoded constants in `ElevenLabsService`.

---

## Story Length

| Option | Target word count | Approx. duration |
|--------|------------------|------------------|
| Short  | ~300–400 words   | ~2 min |
| Long   | ~700–900 words   | ~4–5 min |

---

## Architecture

### New files

| File | Purpose |
|------|---------|
| `lib/services/story_service.dart` | Orchestrates: builds prompt → calls Claude → calls ElevenLabs → saves audio → returns `AudioCard` |
| `lib/services/elevenlabs_service.dart` | ElevenLabs TTS wrapper. `synthesize(text, language)` → MP3 bytes |
| `lib/ui/parent_generate_story_screen.dart` | 3-step wizard UI. Local ephemeral state (no Riverpod provider needed) |
| `lib/models/story_options.dart` | `StoryHero`, `StoryTheme`, `StoryLength` enums with multilingual display names (He/En/Es) |

### Modified files

| File | Change |
|------|--------|
| `pubspec.yaml` | Add `http: ^1.1.0`, `flutter_dotenv: ^5.1.0` |
| `pubspec.yaml` (assets) | Register `assets/.env` |
| `lib/main.dart` | Load `.env` via `dotenv.load()` at startup |
| `lib/router.dart` | Add `/parent/generate-story` route (protected, same as other parent routes) |
| `lib/ui/parent_list_screen.dart` | Add ✨ Generate Story button (app bar action or FAB) |

### Generation pipeline

```
StoryService.generate(hero, theme, language, length)
  │
  ├─ 1. Build Claude prompt
  │     "Write a [short/long] story in [language] about a [hero] in a [theme].
  │      Return JSON: { title: string, story: string }"
  │
  ├─ 2. POST https://api.anthropic.com/v1/messages
  │     Model: claude-haiku-4-5-20251001  (fast + low cost)
  │     → parse { title, storyText }
  │
  ├─ 3. ElevenLabsService.synthesize(storyText, language)
  │     POST https://api.elevenlabs.io/v1/text-to-speech/{voiceId}
  │     model_id: eleven_multilingual_v2
  │     → MP3 bytes
  │
  ├─ 4. Write bytes to temp file (UUID.mp3)
  │
  ├─ 5. LibraryImportService.importAudioToLibrary(tempPath)
  │     → managed audio path
  │
  ├─ 6. autoAssignSprite(title) → spriteKey + color
  │
  └─ 7. cardsProvider.notifier.addCard(AudioCard(...))
        → card appears in library
```

### API keys

Loaded at startup from `assets/.env` via `flutter_dotenv`. The existing `app/.env` (at repo root, not yet a Flutter asset) contains `ELEVENLABS_API_KEY` — this file needs to be:
1. Copied/moved to `app/assets/.env`
2. Registered in `pubspec.yaml` under `flutter: assets:`
3. `ANTHROPIC_API_KEY` added to it (not currently present — `OPENAI_API_KEY` is there but unused)

### Error handling

All errors (network, API, parse) are caught in `StoryService`. The wizard shows an inline error message + Retry button. No partial state is written to the database or filesystem on failure.

---

## Card created

- **Title:** returned by Claude in the selected language (e.g., *"הפרש והיער הקסום"*)
- **Sprite:** `autoAssignSprite(title).id` — same deterministic assignment as all other cards
- **Color:** picked from a theme-to-color map in `StoryOptions` (e.g., bedtime → `#1e1b4b`, space → `#0f172a`, forest → `#14532d`, adventure → `#7c2d12`). Fallback: a fixed warm default.
- **Audio:** imported via `LibraryImportService` (UUID filename, copied to app Documents)
- **Position:** appended to end of library

---

## Out of scope

- Voice selection UI (one voice per language, hardcoded)
- Kid-facing story wizard (parent-only flow)
- Story history / re-generation of existing stories
- Custom hero/theme additions by parent
- Streaming audio (full generation completes before saving)
