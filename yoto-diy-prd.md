# Yoto DIY — Product Requirements Document
**A Screen-Free Audio Player App for Kids · v1.0 · March 2026 · Draft**

| | |
|---|---|
| **Version** | 1.0 |
| **Date** | March 2026 |
| **Status** | Draft |
| **Platform** | Android Tablet — 800×1280px (React Native / Expo) |
| **Storage** | Fully Local — No Backend |

---

## 1. Product Overview

Yoto DIY is a mobile application built for Android tablets that brings the Yoto experience to families without requiring dedicated hardware. Parents create a library of audio "cards" on their tablet — each card linked to a local audio file — and children interact with a simple, colorful card grid to play stories, music, and more. Everything runs locally on-device with no internet connection required.

### 1.1 Problem Statement

Parents want to give young children access to audio content — audiobooks, music, sleep sounds — without exposing them to the addictive loops of tablet apps, YouTube, or streaming services. Dedicated devices like Yoto cost $100+ and require purchasing proprietary cards. There is no good free, flexible, screen-friendly (but not screen-addictive) alternative for families with their own audio libraries.

### 1.2 Vision

A beautifully simple audio player that feels like a physical toy — tapping a card just plays something — with zero cognitive load for the child and full control for the parent.

### 1.3 Success Metrics

| Metric | Target |
|---|---|
| Time to first card playing | < 3 minutes from install |
| Child independence | Kids 3+ can operate without parent help |
| Parental setup time | < 2 min to add a new card |
| App Store rating | 4.5+ stars within 3 months |

---

## 2. Users & Personas

### 2.1 Primary: The Parent (Creator)

Age 28–40. Wants screen-free options for their child. Has a collection of MP3 audiobooks, downloaded music, or recorded bedtime stories. Comfortable with smartphones but not a developer. Values simplicity and control.

### 2.2 Secondary: The Child (Consumer)

Age 3–10. Does not read well (or at all). Needs to operate the app independently. Responds to visual cues — big colorful images, simple layout. Should not be able to accidentally navigate away or break things.

### 2.3 Out of Scope

- Families wanting streaming / online content (Spotify, podcasts)
- Shared family libraries across multiple devices (v2+ consideration)
- Users who want a web app

---

## 3. Feature Requirements

### 3.1 Feature Priority Matrix

| Feature | Priority | Phase | Notes |
|---|---|---|---|
| Card grid (kid view) | Must Have | 1 | Core loop |
| Tap card → play audio | Must Have | 1 | Core loop |
| Create / edit card | Must Have | 1 | Parent flow |
| Pick audio from device | Must Have | 1 | expo-document-picker |
| Play / pause / stop | Must Have | 1 | Persistent player bar |
| Local SQLite persistence | Must Have | 1 | expo-sqlite |
| Parental PIN lock | Must Have | 1 | Settings protection |
| Predefined pixel art library | Must Have | 1 | 20+ built-in sprites, auto-assigned |
| PixelSprite animated component | Must Have | 1 | Frame-by-frame RN renderer |
| Idle / active / tap animations | Must Have | 1 | 3 states per sprite |
| Custom pixel art upload (PNG) | Should Have | 2 | Parent-supplied sprite sheets |
| Card cover image fallback | Should Have | 2 | Photo as card art (no pixel art) |
| Collections / folders | Should Have | 2 | Group cards by theme |
| Sleep timer | Should Have | 2 | Common parent request |
| Kid lock mode | Should Have | 2 | Prevent accidental exit |
| Progress resume | Should Have | 2 | Resumes where left off |
| Backup / export library | Nice to Have | 3 | Data safety |

---

### 3.2 MVP Feature Details

#### Card Grid (Kid View)
- Full-screen grid of cards, 3-column layout on 800×1280 Android tablet
- Each card renders an animated pixel art sprite (16×16, scaled 6x) centered on a colored background
- If no custom sprite is assigned, a predefined sprite is auto-assigned deterministically from the card title hash
- Tap = immediate audio play, no confirmation dialogs
- Currently playing card switches sprite to active animation state
- No back button, no navigation — this is the only screen kids see

#### Audio Playback
- Supports MP3, M4A, AAC, WAV formats
- Persistent mini-player at bottom: track name, play/pause, stop
- Tapping a new card while audio is playing stops current and starts new
- Volume controlled by device hardware buttons
- Continues playing if screen turns off

#### Card Management (Parent View)
- Access via long-press on empty area or PIN-protected settings button
- Create card: title (required) + audio file (required) + pixel art sprite (optional, auto-assigned if skipped) + background color
- Sprite picker: scrollable grid of all 20+ predefined sprites with live preview
- Edit card: change any field including sprite
- Delete card: swipe or long-press with confirmation
- Reorder cards: drag and drop

#### Parental PIN
- 4-digit PIN set on first launch
- Required to access: card management, settings, collections, exit kid mode
- PIN reset via device biometrics (Face ID / fingerprint)

---

### 3.3 Pixel Art UI System

The visual identity of the app is built around Yoto-style animated pixel art. Every card has a living, breathing sprite — not a static icon. The system must work out of the box without any parent configuration.

#### PixelSprite Component
- Renders a 16×16 pixel grid as React Native Views (colored squares), scaled up 6x for display
- Accepts a sprite definition: array of frames, color palette, frame size, fps
- Animates via `setInterval` cycling through frames — target 6–8 fps for authentic pixel art feel
- No anti-aliasing — pixel blocks must appear as sharp squares
- Three animation states per sprite: **idle** (slow, 2–3 frames), **active/playing** (faster, expressive), **tap** (one-shot burst)

#### Predefined Sprite Library

20+ sprites shipped with the app across 5 categories:

| Category | Sprites | Idle Anim | Active Anim |
|---|---|---|---|
| Animals | Cat, Dog, Owl, Bunny, Bear | Breathing / blinking | Bouncing / dancing |
| Nature | Sun, Moon, Star, Rainbow, Cloud | Slow pulse | Spinning / glowing |
| Adventure | Rocket, Castle, Treasure, Dragon | Hovering | Shaking / flashing |
| Music | Music note, Headphones, Drum, Guitar | Bobbing | Playing / vibrating |
| Bedtime | Moon, Pillow, Sheep, ZZZ | Very slow drift | Stars appear |

#### Auto-Assignment Fallback Logic

When a card is created without a sprite selection, the app assigns one deterministically so the library always looks populated and intentional — never blank:

- Hash the card title string → modulo 20 → sprite index
- Same title always gets the same sprite (consistent across sessions)
- Background color is also derived from the hash (from a palette of 12 kid-friendly colors)
- Parent can always override in card settings

#### Sprite Data Format

Sprites are defined as inline JavaScript objects in a bundled `sprites.ts` file — no network fetch, no asset files to manage:

```ts
{
  id: string,
  name: string,
  palette: string[],         // max 4 hex colors, index 0 = transparent
  frames: {
    idle: number[][][],      // 2D arrays of palette indices
    active: number[][][],
    tap: number[][][]
  },
  fps: { idle: number, active: number }
}
```

Each frame is a 16×16 matrix of palette indices (0 = transparent). A 16×16 8-frame sprite is ~2KB of JSON.

#### Animation Rules
- Max 4 colors per sprite (palette index 0–3, 0 = transparent)
- No anti-aliasing — pixel blocks must render as sharp squares
- 6 fps idle, 10 fps active — enforced in PixelSprite component
- Tap animation is always one-shot (plays once then returns to active state)
- All animations pause when app is backgrounded (battery consideration)

---

## 4. Technical Architecture

### 4.1 Stack

| Layer | Technology |
|---|---|
| Framework | React Native + Expo SDK 51+ (Android tablet) |
| Navigation | Expo Router (file-based) |
| Database | expo-sqlite (SQLite on-device) |
| Audio | expo-av or expo-audio |
| File System | expo-file-system (copy files to app dir) |
| File Picker | expo-document-picker |
| Image Picker | expo-image-picker |
| Pixel Art Renderer | Custom PixelSprite component (View grid) |
| Animation | react-native-reanimated (tap spring + scale) |
| Sprite Definitions | Bundled sprites.ts (inline JSON, no assets) |
| State | Zustand (lightweight global store) |
| Styling | StyleSheet + custom design tokens |
| Build | EAS Build (Expo Application Services) |

### 4.2 Data Model

All data lives on-device in SQLite:

```sql
collections ( id, name, color, position, created_at )

cards (
  id, collection_id, title, color,
  sprite_key,           -- references sprites.ts · NULL = auto-assign via title hash
  custom_image_path,    -- overrides pixel art when set
  audio_path, playback_position, position, created_at
)
```

### 4.3 File Storage Strategy

All audio and image files are copied into the app's document directory on import. This ensures files persist regardless of where the original was located (Downloads, SD card, etc.).

- Audio path: `<DocumentDirectory>/audio/<uuid>.<ext>`
- Image path: `<DocumentDirectory>/images/<uuid>.<ext>`
- Original filenames not preserved — UUID prevents collisions

---

## 5. UX & Design Principles

| Principle | Guidance |
|---|---|
| One tap, one action | Tapping a card always plays. No modal, no confirmation, no loading screen. |
| No rabbit holes | Kid mode has no navigation. No "you might also like". No way to browse. |
| Delight through simplicity | Big cards, big text, vibrant colors. Feels like a toy, not an app. |
| Parent is in control | Everything that could distract or change settings is behind the PIN. |
| Forgiving | Accidental taps are fine — tapping another card just switches. No dead ends. |
| Offline first | No loading spinners. No empty states due to network. It always just works. |

---

## 6. Development Roadmap

### Phase 1 — MVP (Weeks 1–4)
- Project scaffold: Expo + expo-router + SQLite
- Bundle `sprites.ts` with 20+ predefined pixel art definitions
- `PixelSprite` component: grid renderer + frame animation loop
- Auto-assignment logic: title hash → sprite + background color
- Card grid UI with animated pixel art cards
- Audio playback via expo-av
- Card creation flow (title + audio file picker + optional sprite picker)
- Local SQLite persistence (`sprite_key` field)
- Parental PIN gate

**Milestone: One card plays audio with an animated pixel sprite on a real device.**

### Phase 2 — Polish (Weeks 5–8)
- Custom sprite upload (parent provides PNG sprite sheet, 16×16 frames)
- Photo as card art fallback (expo-image-picker replaces pixel art)
- Collections / grouping
- Sleep timer
- Kid lock mode (prevent exit)
- Progress resume (save playback position)
- Empty state + onboarding flow

**Milestone: Beta-ready. Send to 5 families for feedback.**

### Phase 3 — Delight (Weeks 9–12)
- Card tap animations and sound effects via reanimated
- Library backup / export
- App Store submission

**Milestone: App Store launch.**

---

## 7. Out of Scope

- Online streaming or cloud content
- Multi-device sync
- User accounts or authentication
- Social / sharing features
- Content marketplace
- Web app version
- Hardware NFC card integration

---

## 8. Open Questions

| # | Question | Status |
|---|---|---|
| 1 | Should kid mode be a separate Guided Access profile or in-app? | 🟡 Open |
| 2 | What file size limit per card? (affects storage warnings) | 🟡 Open |
| 3 | Should we support audiobook chapters (multi-file cards)? | 🟡 Open |
| 4 | Free app or one-time paid ($2.99)? | 🟡 Open |
