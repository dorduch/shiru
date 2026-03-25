# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Shiru** is a Flutter mobile app — a DIY audio player for kids (ages 3–10). Parents set up a library of audio "cards"; children tap cards to play them. The UI is intentionally distraction-free with animated pixel art. All content is stored locally (no backend).

## Commands

All commands run from the `app/` directory:

```sh
cd app
flutter pub get        # Install dependencies
flutter run            # Run on connected device/emulator
flutter analyze        # Lint
flutter build apk      # Android build
flutter build ios      # iOS build
```

Sprite generation (Python utility, run from `app/`):
```sh
python generate_sprites.py
```

## Architecture

### State Management
Riverpod providers in `lib/providers/`:
- `cardsProvider` (`StateNotifierProvider`) — card CRUD and list state, backed by SQLite
- `audioPlayerProvider` — singleton `just_audio` AudioPlayer instance
- `currentPlayingCardIdProvider` / `isPlayingProvider` — playback state

### Navigation
Go Router in `lib/router.dart`:
- `/` → `KidHomeScreen` (child-facing grid of cards)
- `/pin` → `PinGateScreen` (4-digit PIN: hardcoded `1234`)
- `/parent` → `ParentListScreen` (card library management)
- `/parent/edit` → `ParentEditScreen` (create/edit card)

### Persistence
SQLite via `sqflite` — `DatabaseService` singleton in `lib/db/database_service.dart`. Single `cards` table. Audio files are copied to the app documents directory with UUID filenames on import.

### Custom Pixel Art Renderer
`PixelSprite` widget (`lib/ui/pixel_sprite.dart`) uses `CustomPaint` to render 16×16 pixel grids at 6× scale (96×96px). Sprites have three animation states (idle, active, tap) and animate at 6–10 fps via `Timer`.

### Sprite System
`SpriteDef` structs in `lib/models/sprites.dart` (4,700+ lines). `autoAssignSprite(cardTitle)` hashes the title to deterministically assign a sprite and background color. Parents can override manually. Giphy integration (`lib/services/giphy_service.dart`) is experimental/unused.

### Device Config
Forced landscape orientation, immersive sticky UI (hides nav/status bars), wakelock enabled — all set at startup in `lib/main.dart`.

## Working Style

**You are the team lead.** Never do tasks yourself — always delegate to teammates by spawning them using `team tmux`. Choose the model based on task complexity:

- **haiku** — simple/mechanical tasks: file searches, straightforward edits, running commands, formatting
- **sonnet** — moderate to complex tasks: feature implementation, debugging, code review, architecture analysis

Before dispatching a teammate, fully define the task: provide clear context, specify which files are involved, what the expected outcome is, and any constraints. Ambiguous handoffs waste cycles.
