# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Storytime** (package name `shiru`, Firebase project `shiru-bcdd2`) is a Flutter mobile app that generates and narrates original AI bedtime stories for kids (ages 3–10). A parent sets up a child profile and can create a family voice (invite a relative to record samples, cloned via ElevenLabs); the child (or parent) composes a story from a few guided prompts, the story is generated and narrated server-side, and the finished story plays back with a synced word-by-word read-along highlight. The UI is intentionally distraction-free, using a warm "day" theme for the kid-facing composer/library flows and a night "bedtime" theme (Lantern design tokens) for generating/player/story-end screens.

Unlike the app's original incarnation (a purely local, backend-free DIY audio-card player — see git history for that era), Storytime is now Firebase-backed: Auth, Firestore, Cloud Functions, and Storage are all live dependencies, alongside a local SQLite cache for the on-device story/audio library. A companion static web page (`public/invite/`) lets a relative record voice samples in a browser via an invite link, calling the same Cloud Functions.

## Commands

All commands run from the `app/` directory:

```sh
cd app
flutter pub get        # Install dependencies
flutter run            # Run on connected device/emulator
flutter analyze        # Lint
flutter test           # Run the test suite
flutter build apk      # Android build
flutter build ios      # iOS build
```

Local Firebase Emulator Suite mode (no real backend calls):
```sh
flutter run --dart-define=USE_EMULATOR=true
```

Sprite generation (Python utility, run from `app/`):
```sh
python generate_sprites.py
```

Cloud Functions (TypeScript) live in `functions/` and are built/tested independently — see that directory for its own `package.json` scripts (build, test, emulators).

## Architecture

### State Management
Riverpod providers in `lib/providers/` and `lib/services/`, including:
- `authUserProvider` / `auth_provider.dart` — Firebase Auth user stream, gates the whole app (unauthenticated → `/welcome`)
- `childProfileProvider` (`child_profile_service.dart`) — the single child profile for the signed-in account
- `pinProvider` (`pin_provider.dart`) — parent-chosen 4-digit PIN, held in secure storage (`flutter_secure_storage` via `key_value_store.dart`), **not** hardcoded
- `cardsProvider` (`StateNotifierProvider`) — local story/audio library CRUD, backed by SQLite
- `storytime_providers.dart` — story-generation quota, active-job resume, narrator/voice state
- `audioPlayerProvider` — singleton `just_audio` AudioPlayer instance; `currentPlayingCardIdProvider` / `isPlayingProvider` — playback state

### Navigation
Go Router in `lib/router.dart`, entry point `/`:
- `/` → `StorytimeLaunchScreen` — routes to `/welcome` (signed out), `/child-setup` (no profile yet), or `/home` (ready)
- `/welcome`, `/auth` → sign-up/sign-in (Firebase Auth: email/password, Apple, Google)
- `/child-setup` → create the child profile
- `/home` → `StorytimeHomeScreen`, the kid-facing entry (day theme)
- `/compose` → `StoryComposerScreen` — pick theme/hero/narrator prompts
- `/generate` → `StoryGeneratingScreen` (night theme) — polls the Firestore story job
- `/listen` → `StoryLibraryScreen` — generated + curated + imported stories
- `/story/:cardId` → `StoryPlayerScreen` (night theme, read-along); `/story/:cardId/end` → `StoryEndScreen`
- `/parent-access` → `/age-check` → `/pin` → `/parent` — adult gate into `StorytimeParentDashboard` (library management, account, family voices, change PIN, etc.)
- `/dev/gallery` — component gallery for design work; gated behind `!kReleaseMode`, does not exist in release builds

### Story Generation Pipeline
Generation is asynchronous and server-driven, not a direct API call from the app:
1. The app calls the `createStoryJob` Cloud Function (`functions/src/index.ts`), which writes a job doc to Firestore and checks/decrements the daily generation quota (`storytimeConfig/generation.dailyQuota`, tracked per-user per-UTC-day).
2. A backend pipeline generates the story text, runs a safety review pass, and narrates it via the **ElevenLabs** TTS API (built-in narrator voices, or a cloned family voice), deriving per-word timing (`functions/src/timing.ts`, `deriveWordStarts`) from ElevenLabs' character-level alignment data.
3. The app (`story_generation_repository.dart`, `active_story_job_service.dart`) subscribes to the job doc in Firestore and reacts to status transitions (`queued` → … → `ready`/`failed`); on `ready` it downloads the audio, imports it into the local SQLite library, and carries the per-word `wordStarts` array for the read-along highlight.
4. Curated "starter" stories ship pre-narrated in the app bundle (`app/assets/storytime/starter_stories.json` + matching `.mp3`/`.timing.json` files, seeded by `starter_story_service.dart`) so a child has stories to listen to before ever generating one.

### Family Voices & Voice Invites
A parent can clone a relative's voice for narration. In-app capture/upload goes through `family_voices_screens.dart` and `voice_repository.dart`. For a remote relative, the parent sends an invite link to `public/invite/` (a small vanilla-JS SPA, no framework/bundler) where the recipient records 5 guided prompts in-browser; `redeemVoiceInvite`/`uploadVoiceInviteSample`/`submitVoiceInvite` (all in `functions/src/inviteRedeem.ts` + `index.ts`) are invite-claim-gated callables (no App Check, no prior auth) scoped by a synthetic Firebase Auth user carrying `{invite: true, parentUid, voiceId}` custom claims, active only within a bounded post-redemption session window.

### Persistence
Two tiers:
- **Firebase** (Auth, Firestore, Storage, Cloud Functions) is the source of truth for accounts, child profile, generation jobs, quotas, voices, and invites.
- **SQLite** via `sqflite` — `DatabaseService` singleton in `lib/db/database_service.dart`, single `cards` table — is the on-device cache/library of playable stories (generated, curated, and any parent-imported audio). Audio files are copied to the app documents directory with UUID filenames on import.

### Custom Pixel Art Renderer
`PixelSprite` widget (`lib/ui/pixel_sprite.dart`) uses `CustomPaint` to render 16×16 pixel grids at 6× scale (96×96px). Sprites have three animation states (idle, active, tap) and animate at 6–10 fps via `Timer`. `SpriteDef` structs live in `lib/models/sprites.dart`; `autoAssignSprite(cardTitle)` hashes the title to deterministically assign a sprite and background color.

### Device Config
Forced landscape orientation, immersive sticky UI (hides nav/status bars), wakelock enabled, Firebase/App Check/Crashlytics initialization — all set at startup in `lib/main.dart`.

## Working Style

**You are the team lead.** Never do tasks yourself — always delegate to teammates by spawning them using `team tmux`. Choose the model based on task complexity:

- **haiku** — simple/mechanical tasks: file searches, straightforward edits, running commands, formatting
- **sonnet** — moderate to complex tasks: feature implementation, debugging, code review, architecture analysis

Before dispatching a teammate, fully define the task: provide clear context, specify which files are involved, what the expected outcome is, and any constraints. Ambiguous handoffs waste cycles.
