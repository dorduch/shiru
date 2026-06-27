# Parent audio upload/record + Listen page redesign — design

Date: 2026-06-27
Branch: feature/storytime-mvp

## Goal

Two related pieces of work in the Storytime flow:

1. **Add your own audio** — let a parent add a card from their own audio, either by
   recording live or picking an existing audio file. The resulting card plays for the
   child exactly like a generated story.
2. **Listen page redesign** — make the child-facing Listen page (`/listen`) match the
   richer Home screen layout instead of a plain vertical list.

All content stays local (no backend). The app runs in forced **landscape**.

## Approved decisions

- "Main domain" = the app's **Home screen** (`/home` → `StorytimeHomeScreen`) layout.
- Entry point for adding audio = **Grown-up dashboard** (behind the existing parent gate).
- Input methods = **both** record-in-app and upload-a-file.
- Card art = **auto-assigned sprite + parent-picked color** (reuse `autoAssignSprite`).
- Listen redesign applies to the **kid view only**; the parent "Manage stories" view stays
  a deletable list.
- One combined origin `uploaded` for both recorded and file-picked audio; subtitle "Your audio".
- **Edit** (title, color, replace audio) is supported for **uploaded cards only**, reached from the
  parent "Manage stories" screen. Generated/curated stories are not editable.
- **Icons must be rich custom art**, consistent with the rest of the app — real `PixelSprite`
  on grid tiles, and a new hand-drawn SVG glyph for the add-audio action (not Material icons).

---

## Part 1 — Listen page redesign

### Current state

`StoryLibraryScreen` (`lib/ui/storytime_screens.dart:1276`) is dual-use:

- `/listen` — kid view, `parentMode = false`, taps open `/story/:id`.
- `/parent/stories` — "Manage stories", `parentMode = true`, rows show a delete button.

Today both render an `AppBar` + a single-column `ListView.separated` of `_StoryTile`
(`StRow`) rows. In landscape this wastes the horizontal space the Home screen fills.

### Target — kid view (`parentMode == false`)

Replace the AppBar + ListView with a Home-style layout:

- Padding matching Home (`fromLTRB(20, 12, 20, 24)`), `tokens.cream` background.
- Header: back button (→ `/home`) + `Listen` title (`AppTypography.headlineMedium`, `tokens.ink`)
  + `{n} stories` subtitle (`bodySmall`, `tokens.ink2`).
- **Resume strip**: reuse Home's `_ResumeStrip` at the top when a resumable story exists
  (`playbackPosition > 5000`, most-recent `lastPlayedAt`). Promote `_ResumeStrip` so it can be
  shared by both screens (extract to a shared location or make it non-private).
- Body: a responsive **grid** of a new `_StoryGridTile` widget using
  `GridView.builder` + `SliverGridDelegateWithMaxCrossAxisExtent` (max extent ~200,
  `childAspectRatio` tuned so tile = art square + 2 text lines). Fills the landscape width
  with as many columns as fit.
- Empty state preserved: "No stories yet. Make one from Home." (`bodySmall`, `tokens.ink2`).
- Loading/error states preserved (spinner / "Try again" button).

### `_StoryGridTile`

A tappable tile (`onTap → context.go('/story/${card.id}')`), styled like the Home `StTile`
family on `tokens.paper`/`tokens.line`:

- **Art (rich, not a flat icon):** the card's real `PixelSprite`, exactly as the current
  `_StoryTile` builds it — `predefinedSprites[card.spriteKey]` else `autoAssignSprite(card.title)`,
  sitting on a square of the card's color (`hexOrFallback(card.color)`). Per project rule, the
  art's background equals the tile's color block.
- Title (`card.title`) + origin subtitle below.
- Semantics label: `'{title}, {origin phrase}'`, `button: true`.

### Origin subtitle mapping (shared helper)

A single helper used by both list and grid tiles:

| `storyOrigin` | subtitle      |
| ------------- | ------------- |
| `curated`     | "Ready-made"  |
| `uploaded`    | "Your audio"  |
| `generated`   | "Your story"  |

### Target — parent view (`parentMode == true`)

Keep the row list with the delete affordance and confirm dialog (`_StoryTile` / `_delete`).
Light restyle only for visual consistency; do **not** gridify, so the management/delete flow is
preserved. No add button here — adding audio lives on the dashboard.

**Edit affordance:** for rows where `storyOrigin == uploaded`, show an edit icon
(rich/consistent styling) next to delete → opens the edit flow (see "Edit (uploaded cards)"
below). Rows for `generated`/`curated` cards show delete only, no edit.

---

## Part 2 — Add your own audio (parent)

### Entry point

Add a `_DashboardEntry` to `StorytimeParentDashboard`
(`lib/ui/storytime_screens.dart:1743`), under "Manage stories":

- Title: "Add your own audio"
- Subtitle: "Record a voice or upload a file"
- Tap → `context.go('/parent/add-audio')` (under the parent-gated `/parent` subtree).

The dashboard entry today uses a Material `IconData`. To keep icons rich, the add-audio
action uses a **new hand-drawn SVG glyph** (see "New rich icon" below) rather than a flat
Material icon. (Other dashboard rows are out of scope and keep their current icons.)

### Routes

Add under the `/parent` route in `lib/router.dart`:

- `/parent/add-audio` → `AddAudioCaptureScreen` (create mode)
- `/parent/add-audio/details` → `AddAudioDetailsScreen` (create mode)
- `/parent/edit-audio/:id` → `AddAudioDetailsScreen` (edit mode, prefilled from the card)

Capture passes the imported audio path + duration forward to the details step via a small
Riverpod draft provider (`addAudioDraftProvider` holding `{audioPath, durationMs}`), matching how
the story wizard passes draft state through `storyDraftProvider`. The details route reads the
draft; if it is empty (e.g. deep-link/refresh), it redirects back to `/parent/add-audio`.

### Flow

**Step 1 — `AddAudioCaptureScreen`** (new, storytime-styled)

- Wraps the existing `AudioRecorderWidget` (`lib/ui/widgets/audio_recorder_widget.dart`),
  which already provides **both** record (`RecordingService`: start/pause/resume/stop) and
  file-pick. Do **not** resurrect the legacy `ParentEditScreen` (predates the StorytimeTokens
  design system and would look inconsistent).
- Storytime chrome: cream background, back button, `StSectionHeader`, the new rich SVG glyph
  as the screen's hero art, `StButton`s.
- On capture/selection complete, the file is imported via
  `LibraryImportService.importMediaToLibrary` / `importAudioToLibrary` (copies to app docs dir
  with a UUID, returns path + duration), then navigate to details.

**Step 2 — `AddAudioDetailsScreen`** (new — serves both create and edit)

Takes an optional `editingCardId`. In **create** mode it reads audio from
`addAudioDraftProvider`; in **edit** mode it loads the existing `AudioCard` and prefills.

- `StTextField` for the card title (default e.g. "My recording" / picked file name).
- Color picker: a row of swatches (reuse the tile palette in `AppColors` / `concept` colors).
- **Live preview tile** rendered with the same `_StoryGridTile`/`PixelSprite` look: the
  auto-assigned sprite (`autoAssignSprite(title)`) on the chosen color, so the parent sees the
  exact card the child will see.
- Save (`StButton`) builds an `AudioCard` and calls `ref.read(cardsProvider.notifier).addCard`:
  - `id`: new UUID
  - `title`: entered title
  - `color`: chosen swatch hex
  - `spriteKey`: null (let `autoAssignSprite(title)` resolve at render, matching generated cards)
  - `audioPath`: imported path
  - `mediaType`: `CardMediaType.audio`
  - `storyOrigin`: `StoryOrigin.uploaded`
  - `narratorKey`: null
  - `durationMs`: real duration from import
  - `position`: end of current list
  - `createdAt`: now
- On success, navigate back to the dashboard (or `/parent/stories`) with a brief confirmation.

### Edit (uploaded cards)

Reached from the parent "Manage stories" edit affordance → `/parent/edit-audio/:id`, opening
`AddAudioDetailsScreen` in edit mode prefilled from the card. Available for
`storyOrigin == uploaded` cards only.

- **Title + color**: editable inline, with the same live preview tile.
- **Replace audio**: a "Replace audio" `StButton` routes to `AddAudioCaptureScreen`, which on
  completion writes the new path/duration into `addAudioDraftProvider` and returns to the edit
  screen (carrying `editingCardId`); the screen then shows the new audio. If the parent doesn't
  replace, the existing `audioPath`/`durationMs` are kept.
- Save calls `ref.read(cardsProvider.notifier).updateCard` (not `addCard`), preserving the
  card's `id`, `position`, `createdAt`, and `playbackPosition` (reset `playbackPosition` to 0
  only when the audio is replaced). When audio is replaced, delete the old imported file to
  avoid orphaned files in the app docs dir.

### New rich icon

Add a new SVG constant to `lib/ui/concept_icons.dart` in the same style as
`storybookIconSvg` / `headphonesIconSvg` (48×48 viewBox, layered fills + strokes,
purple `#8B7CF6` / cream `#FBF6EE` / gold `#F2C84B` palette): a **microphone / voice-record**
motif. Rendered via `SvgPicture.string` at large size on the capture screen and (smaller) on
the dashboard entry. Drawn to sit directly on the tile/entry background, no token box behind it.

### Model change

`StoryOrigin` (`lib/models/storytime_models.dart:184`) becomes `{ curated, generated, uploaded }`.

- `AudioCard.fromMap` already has `orElse: StoryOrigin.generated`, so old DB rows are safe.
- `toMap` serializes `.name` — round-trips `uploaded` with no schema/migration change
  (the `story_origin` column already stores the enum name as text).
- Update the subtitle mapping everywhere it is derived (the shared origin-subtitle helper
  above; remove the current inline `curated ? 'Ready-made story' : 'Your story'` ternary).

---

## Files touched

| File | Change |
| ---- | ------ |
| `lib/models/storytime_models.dart` | Add `StoryOrigin.uploaded` |
| `lib/ui/storytime_screens.dart` | Redesign kid `StoryLibraryScreen`; add `_StoryGridTile`; share `_ResumeStrip`; origin-subtitle helper; new dashboard entry; edit affordance on uploaded rows in Manage stories |
| `lib/ui/concept_icons.dart` | New `addAudioIconSvg` (mic/voice glyph) |
| `lib/ui/add_audio_screens.dart` (new) | `AddAudioCaptureScreen` + `AddAudioDetailsScreen` (create + edit) |
| `lib/providers/...` (new or existing) | `addAudioDraftProvider` |
| `lib/router.dart` | Routes `/parent/add-audio`, `/parent/add-audio/details`, `/parent/edit-audio/:id` |
| (reused, no change) | `AudioRecorderWidget`, `RecordingService`, `LibraryImportService`, `cardsProvider`, `autoAssignSprite` |

## Out of scope

- Photo/custom-image cover for uploaded cards (model supports `customImagePath`; not in v1).
- Distinguishing recorded vs. file-picked origin (single `uploaded` origin).
- Editing generated/curated stories (edit is uploaded-cards-only).
- Gridifying or restyling the parent "Manage stories" beyond light visual cleanup.

## Testing

- Unit: `StoryOrigin.uploaded` round-trips through `AudioCard.fromMap`/`toMap`; origin-subtitle
  helper returns the right phrase for all three origins.
- Widget: Listen kid view renders a grid; empty/loading/error states; tile tap routes to
  `/story/:id`. Details screen builds a valid `AudioCard` and calls `addCard`.
- Manual: record a clip → save → it appears in Listen and on the child grid and plays;
  upload a file → same; resume strip shows after partial playback.
- Manual (edit): edit an uploaded card's title/color → reflected in Listen; replace its audio →
  new audio plays and old file is removed; edit affordance is absent on generated/curated rows.

## Process

Per `CLAUDE.md`, after this spec is approved: write the implementation plan, then delegate the
build to tmux teammates (haiku for model/route plumbing + the SVG constant; sonnet for the two
new screens and the Listen grid redesign).
