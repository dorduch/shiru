# Lantern Rollout — Batch 7 Implementation Plan (final batch)

**Goal:** Migrate the last 2 screens — `StorytimeLaunchScreen` (done directly, see below) and `StoryPlayerScreen` + `StScenePlayer` (this plan's real subject) — to Lantern tokens. This is the highest-risk batch in the rollout: the read-along word-highlight engine lives *inside* `StoryPlayerScreen.build()`, interleaved with chrome, and has zero test coverage at the screen/widget layer.

**Spec:** `docs/superpowers/specs/2026-07-10-lantern-app-wide-design.md`
**Prior work:** Foundation, Batches 1-6 all done. This closes the rollout.

**Out of scope:** any change to the read-along sync mechanism, audio playback logic, or `hexOrFallback(card.color)` per-card content colors.

---

## Already done: `StorytimeLaunchScreen`

Low risk (stateless `ConsumerWidget`, no engine inside `build()`, already dark) — migrated directly rather than dispatched, per explicit advisor guidance not to let it share fate with the player-screen work. `night1`→`nightDeep`, `gold`→`lantern`, dropped the redundant `Theme(data: StorytimeTheme.bedtime, ...)` wrap. Also migrated `_NightLoadingScaffold` (shared with `StoryPlayerScreen` — now already `LanternTokens`, the player task below doesn't need to touch it) and `_LaunchError`. **Left `_LoadingScaffold` untouched** — despite sitting textually next to the launch screen, its only consumer is `StoryReviewScreen` (unmigrated, out of scope). **Left `_goAfterBuild`'s signature untouched** — shared with `StoryReviewScreen`. `flutter analyze` clean on this file after the change.

## The real subject: `StScenePlayer` + `StoryPlayerScreen`

### Advisor-confirmed risk calibration (read this before touching either file)

- **The actual top risk is a broken read-along that no automated check can catch** — not analyze, not tests (zero coverage at this layer), not diff review alone. **The deliverable is not "done" until verified live on a simulator against a *curated* story** (curated stories have real per-word timings via `_wordStarts`, so a broken `highlightedWordIndex` visibly desyncs; generated stories use a linear estimate that can hide drift). Watch the highlighted word track the narration in real time, scrub the seek slider, hit pause/play. This on-device watch is the actual safety net for this batch — treat it as a hard gate before closing the task, not an optional nice-to-have.
- **`StScenePlayer` itself is lower risk than it might look.** It reads `cream` (light text on dark) and `gold`/`ember` (warm accents on dark) — it already renders as a correct dark surface today, unlike `StSectionHeader`'s illegible-dark-on-dark bug from Batch 1. Its migration is cosmetic and color-only, in a separate file with no playback engine of its own (confirmed via its own doc comment: "real audio sync is NOT wired here"). **Migrate it in place** (`StorytimeTokens`→`LanternTokens`) — do not build a `LanternScenePlayer`; 367 lines of duplication for one production consumer plus one gallery consumer is the wrong trade.
- **The real risk is `StoryPlayerScreen.build()`, and the boundary must be drawn at the statement level, not the method level** — unlike every prior batch, the sync engine (two `StreamBuilder`s off `player.positionStream`/`player.playerStateStream`, the `highlightedWordIndex` if/else chain, the `onPlayPause`/`onSeek` closure bodies) is physically inlined inside `build()`, interleaved line-by-line with pure chrome.

### `StScenePlayer` (`app/lib/ui/widgets/storytime/st_scene_player.dart`)

- Reads `StorytimeTokens` directly (line 59) — confirmed on the spec's §5 not-safely-reusable list, needs real internal migration, not a wrapping override.
- Token reads: `nightGradient` (container bg)→`LanternTokens.nightGradient`; `night3` (fallback art panel)→judgment call, likely `nightMid`/`nightCard`; `gold` (×4: fallback icon, slider active/thumb/overlay)→`lantern`; `cream` (×3: title/body-base/elapsed-total, all alpha-blended)→`moon` at matching alpha; `ember` (play/pause button fill)→`lantern`; `onAccent` (play/pause icon)→`nightDeep` (matches `GlowButton`'s own on-accent convention); `trackInactive` (slider inactive track, **mode-aware** — the only mode-aware field here, day=`line`/bedtime=`cream@0.5`)→pick a Lantern equivalent, likely `hush`, since `LanternTokens` has no `trackInactive` slot at all (this is a genuine remap, not a mechanical rename — `flutter analyze` will catch any missed/wrong getter, but the *choice* of `hush` vs something else is a judgment call to make deliberately).
- **The one static (non-`tokens`) read**: `AppColors.gold` at line 107, the highlighted-word text color — **advisor's recommendation: use `tokens.lantern`** for the highlight (more saturated than the old gold, pops harder against the `moon` base text, keeps "current word glows in the accent color"). This is a visual call — confirm it looks right on the device screenshot, not just in the diff.
- **Constraint on `_ReadAlongTextState._follow()`** (private helper inside this file, ~line 184): it builds a `TextPainter` from `baseStyle` to compute auto-scroll offsets. **Change color only on `baseStyle`/`highlightStyle` — never size, weight, or family** — doing so would shift the auto-scroll positioning math, which is out of scope.
- Second consumer: `component_gallery_screen.dart` (~464-479), driving it off local mock state, not real playback — resolves fine automatically since `LanternTokens` is registered on the same root theme; no special handling needed.
- **Worth adding, not just insurance**: a small permanent widget test pumping `StScenePlayer` with `highlightedWordIndex: N` and asserting the Nth word-span carries the highlight style (color). This directly locks the one invariant most likely to silently regress (a wrong or missing highlight color), filling a real, previously-nonexistent gap at this layer. Add it to `app/test/` if it's quick to write — this is real coverage worth keeping, not a throwaway.

### `StoryPlayerScreen` (`app/lib/ui/storytime_screens.dart`, confirm current exact line range — was 1655-1959 as of the inventory, file may have shifted slightly after the launch-screen edit above)

**Do-not-touch, verbatim, at the statement level inside `build()`:**
- The two `StreamBuilder` stream sources (`player.positionStream`, `player.playerStateStream`).
- The `highlightedWordIndex` if/else chain (curated-story binary search via `_wordStarts`/`wordIndexForTime`, vs generated-story linear estimate).
- The `onPlayPause`/`onSeek` closure **bodies** (the calls to `player.pause()`/`player.play()`/`player.seek()`).
- Everything outside `build()` entirely: `initState`, `_load()`, `_savePosition()`, `_complete()`, `didChangeAppLifecycleState`, `dispose()`, `_favorite()` — the `AudioPlayer`/`StreamSubscription`/`Timer` lifecycle, all of it.

**Fair game (pure chrome):**
- Both redundant `Theme(data: StorytimeTheme.bedtime, ...)` wraps (error-branch build path and main build path) — drop both, same resolution as every prior batch.
- Scaffold background `tokens.night1`→`nightDeep` (both branches).
- Back-icon color `tokens.cream`→`moon`.
- Favorite-icon color `tokens.gold`→`lantern`.
- Art-panel gradient: `AppColors.night3`→judgment call (likely `nightMid`/`nightCard`, match whatever `StScenePlayer`'s own fallback-panel judgment call lands on for consistency), `AppColors.night1`→`nightDeep`.
- `StScenePlayer(...)` call's own non-logic constructor args (it now reads `LanternTokens` internally per the section above — the caller doesn't need to pass new colors, just confirm the call site still compiles against `StScenePlayer`'s unchanged prop signature).
- **Leave untouched**: `hexOrFallback(_card!.color)` — per-card content color, not a design token.

**Test coverage**: zero at this layer (screen or widget). Two adjacent pure-logic tests exist and must stay green (`test/logic/story_tokenizer_test.dart`, `test/services/curated_timing_invariant_test.dart`) but neither exercises this screen — they're unaffected by a chrome-only change, just confirm via a run, don't assume.

## Task 1: `StScenePlayer` + `StoryPlayerScreen`

One task — both files are tightly coupled (the screen is `StScenePlayer`'s only real production consumer) and the caution required is the same coherent discipline across both.

## Verification

- `flutter analyze` clean (baseline: 11 pre-existing infos).
- Full `flutter test` — compare against the 140 passed / 5 failed baseline (post-Batch-6).
- `test/logic/story_tokenizer_test.dart` + `test/services/curated_timing_invariant_test.dart` specifically green.
- Manual statement-level diff review (not just method-level) confirming the `StreamBuilder` sources, `highlightedWordIndex` logic, and `onPlayPause`/`onSeek` bodies are byte-for-byte untouched.
- **Hard gate, not optional**: run the app on a simulator, open a **curated** story (real per-word timings), and watch the highlighted word track playback in real time; scrub the seek slider; pause and resume. Do not report this batch done without this check — it is the only thing that can catch a broken sync, since nothing else in this project's toolchain can.
