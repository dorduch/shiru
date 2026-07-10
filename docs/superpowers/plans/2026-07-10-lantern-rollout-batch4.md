# Lantern Rollout — Batch 4 Implementation Plan

**Goal:** Migrate the 2 "adaptive/content-heavy" screens named in the app-wide spec's batch sequencing (§6) — `StorytimeHomeScreen` and `StoryLibraryScreen` — to Lantern tokens, using the already-built `LanternActionTile`. Also close a recurring gap: properly extend `LanternSectionHeader` with `eyebrow`/`largeTitle` support and build `LanternScreenHeader`, rather than continuing to inline eyebrow workarounds per screen.

**Spec:** `docs/superpowers/specs/2026-07-10-lantern-app-wide-design.md`
**Prior work:** Foundation, Batches 1-3 all done. `LanternActionTile` already exists (Foundation). `LanternRow`, `LanternSectionHeader` (title/sub/centerAlign only — no eyebrow yet), `LanternChoiceCard`, `LanternChip` all exist too.

**Out of scope:** Batches 5-7 (separate future plans), `StoryWizardScreen`/`StoryReviewScreen`/`StoryGeneratingScreen`/`StoryPlayerScreen` (sit between the two target screens in the same file — do not touch), any copy/feature/nav change.

---

## Inventory findings (grounded via Explore agent)

- **File:** `app/lib/ui/storytime_screens.dart`. `StorytimeHomeScreen` at lines 517-619 (+ `_ResumeStrip` helper at 622-639). `StoryLibraryScreen` at 1391-1509 (+ `_StoryTile` at 1511-1571, `_StoryGridTile` at 1573-1627). Clean boundaries — `StoryWizardScreen`/`StoryReviewScreen`/`StoryGeneratingScreen` (642-1390) sit between them, untouched by any batch, not in scope here.
- **`_ResumeStrip` is shared** by both target screens (`StorytimeHomeScreen` line 561, `StoryLibraryScreen` line 1468) — one task, not split, same reasoning as every prior batch with a shared file/helper.
- **`StorytimeHomeScreen`**: paints `tokens.cream` directly (Scaffold bg). Uses `StScreenHeader` (title/sub/trailing "Grown-up" pill), 2× `StTile` ("Make a Story" `color: AppColors.tilePlay`, "Listen" `color: AppColors.tileListen` — confirmed via `git blame` that only the "Make a Story" tile's `onTap` routing was touched by earlier Composer work, its *visual* styling is untouched, still 100% `StTile`). Adaptive layout is a bespoke `LayoutBuilder` + hardcoded `680px` breakpoint (not `AppResponsive` — that helper is unused anywhere in this file). No `AppSpacing` usage either.
- **`_ResumeStrip`**: uses `StRow`, plus raw **static** `AppColors.ember`/`AppColors.ink3` reads (not routed through a `tokens` instance at all — bypasses the theme-extension pattern entirely, unlike everything else migrated so far).
- **`StoryLibraryScreen`**: branches on `parentMode` — `true` gives an `AppBar`+`ListView.separated` of `_StoryTile`; `false` (default, kid mode) gives no `AppBar`, a `StScreenHeader`, optional `_ResumeStrip`, and a `GridView.builder` of `_StoryGridTile` (`SliverGridDelegateWithMaxCrossAxisExtent`, 200px max extent). Both branches paint `tokens.cream` directly. `_StoryTile` uses raw static `AppColors.ink3` (×3, icons) and `StRow`. `_StoryGridTile` uses cream-locked `tokens.paper`/`.line`/`.ink`/`.ink2` for its own card chrome. Both `StButton("Try again")` calls are the safe ember variant.
- **No selectable-card fit**: neither `_StoryTile` nor `_StoryGridTile` has selection/toggle state — both are one-shot navigation tiles. `LanternChoiceCard` doesn't apply here; these map to plain re-skinned containers, not a new component.
- **`_StoryGridTile`'s avatar/thumbnail color** (`hexOrFallback(card.color)`) is per-card user data, same as Batch 2's card-swatch finding — out of scope, don't touch.
- **`StScreenHeader`** (`lib/ui/widgets/storytime/st_screen_header.dart`) is a **pure structural wrapper with zero color reads of its own** — it lays out an optional back-button/trailing control row and an optional `progress` slot around a delegated `StSectionHeader` call. Its `eyebrow`/`largeTitle` params pass straight through to `StSectionHeader`. This means the actual color risk is entirely in the delegated `StSectionHeader` call (same illegible-text bug already fixed via `LanternSectionHeader` in Batch 1) — but `LanternSectionHeader` currently has no `eyebrow`, `largeTitle`, `onBack`, `trailing`, or `progress` support, so it can't be dropped in as a 1:1 replacement yet.
- **Recurring gap, now worth fixing properly**: Batch 1 (`VoiceCaptureIntroScreen`, "STEP 2 OF 2") and Batch 3 (`VoiceConsentScreen`, "STEP 1 OF 2") both hit `LanternSectionHeader`'s missing `eyebrow` slot and worked around it with an inline hand-rolled `Text` above the header. That's real duplicated logic now in 2 places. This batch needs `eyebrow` for `StorytimeHomeScreen`'s header anyway (check whether it currently passes one) and definitely needs `trailing` (the "Grown-up" pill) — so this is the moment to fix `LanternSectionHeader` properly rather than add a third inline workaround.
- **Test coverage**: `app/test/ui/story_library_grid_test.dart` exists, builds a minimal router with `StoryLibraryScreen`, wraps in `MaterialApp.router(theme: StorytimeTheme.day, ...)`, asserts `find.byType(GridView)` + origin-subtitle text. `StorytimeTheme.day` already registers `LanternTokens.day()` alongside `StorytimeTokens`, so migrating the screen won't break the extension lookup — but double check the test's assertions don't hard-code any color expectations (inventory didn't find any, but verify). No test references `StorytimeHomeScreen` by name.
- No stale routing found in either screen (all `context.go(...)` targets match live routes in `router.dart`).

## Foundation: extend `LanternSectionHeader`, build `LanternScreenHeader`

**Files:** modify `app/lib/ui/widgets/lantern/lantern_section_header.dart`, create `app/lib/ui/widgets/lantern/lantern_screen_header.dart`, export from `lantern.dart`, add/update gallery entries.

- Add `eyebrow` (`String?`) and `largeTitle` (`bool`, default `false`) params to `LanternSectionHeader`, matching `StSectionHeader`'s contract. Render the eyebrow the same way the two prior inline workarounds did (`AppTypography` bold ~13sp, letter-spacing, `moonDim`, `.toUpperCase()` — confirm exact style against `StSectionHeader`'s own eyebrow rendering, which already uppercases internally per Batch 3's agent finding).
- Build `LanternScreenHeader` as a thin wrapper mirroring `StScreenHeader` exactly: optional back-button/`trailing` control row, optional `progress` slot, delegating title/sub/eyebrow/largeTitle to `LanternSectionHeader`. Zero new color logic needed here — it's structural, same as the original.
- **Cleanup, in scope since it directly resolves prior flagged gaps**: replace the two existing inline eyebrow workarounds (`VoiceCaptureIntroScreen`'s "STEP 2 OF 2", `VoiceConsentScreen`'s "STEP 1 OF 2", both in `family_voices_screens.dart`) with the real `eyebrow` param now that it exists. Small, low-risk, closes the loop — don't skip it.

## Task 1: `StorytimeHomeScreen` + `StoryLibraryScreen` + `_ResumeStrip`

**File:** `app/lib/ui/storytime_screens.dart` — single task (shared `_ResumeStrip` helper, same file).

- `StorytimeHomeScreen`: dark ground (this screen has an implicit header area but check whether it needs the AppBar-bearing `nightMid` pattern or the AppBar-less `nightDeep` pattern — it has no `AppBar` per the inventory, so likely `nightDeep`+`nightGradient`, matching `ParentAccessScreen`/`StoryComposerScreen`'s established pattern — verify against those two, don't re-derive). `StScreenHeader`→`LanternScreenHeader`, passing the "Grown-up" pill as `trailing` (re-skin the pill itself: `ink2`/`paper`/`line`→`moonDim`/`nightCard`/`hush`). Both `StTile`s→`LanternActionTile`: "Make a Story" gets `emphasized: true` (primary action, matches the precedent already set in the component gallery's own `LanternActionTile` showcase), "Listen" gets `emphasized: false`. Drop `AppColors.tilePlay`/`tileListen` — `LanternActionTile` doesn't take an arbitrary color, only the `emphasized` flag.
- `_ResumeStrip`: `StRow`→`LanternRow`. Raw static `AppColors.ember`/`.ink3`→`tokens.lantern`/`tokens.moonFaint` (this requires threading a `LanternTokens` instance into the widget, since it currently uses static `AppColors` directly with no `tokens` param at all — check its constructor, may need to add one, or read `Theme.of(context)` inside its own `build()`).
- `StoryLibraryScreen` parent-mode branch (`AppBar` present): `nightMid` + transparent AppBar + `nightGradient` body pattern (matching `VoiceUploadScreen`/`AddAudioCaptureScreen`'s established convention from Batch 2/3 — read one of those for the exact recipe). AppBar title `tokens.ink`→`tokens.moon`. `_StoryTile`: `StRow`→`LanternRow`, static `AppColors.ink3`→`tokens.moonFaint` (×3).
- `StoryLibraryScreen` kid-mode branch (no `AppBar`): `nightDeep`+`nightGradient` pattern. `StScreenHeader`→`LanternScreenHeader`. `_StoryGridTile`: `paper`/`line`/`ink`/`ink2`→`nightCard`/`hush`/`moon`/`moonDim`.
- Both `StButton("Try again")` calls stay as-is (safe ember variant).
- **Do not touch** `hexOrFallback(card.color)` per-card thumbnail colors, `StoryWizardScreen`/`StoryReviewScreen`/`StoryGeneratingScreen`/`StoryPlayerScreen` (untouched classes in the same file).
- Keep `app/test/ui/story_library_grid_test.dart` green — verify its assertions don't break on the `GridView`/text-content lookups it uses.

## Verification

- `flutter analyze` clean (baseline: 11 pre-existing infos, no new ones).
- Full `flutter test` — compare against the 136 passed / 9 failed baseline.
- `app/test/ui/story_library_grid_test.dart` specifically green.
- `git diff` hunk audit: confirm zero hunks touch `StoryWizardScreen`/`StoryReviewScreen`/`StoryGeneratingScreen`/`StoryPlayerScreen`'s line ranges (642-1390, 1629+).
