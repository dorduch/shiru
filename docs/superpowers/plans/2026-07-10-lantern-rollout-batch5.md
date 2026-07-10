# Lantern Rollout — Batch 5 Implementation Plan

**Goal:** Migrate the 2 "bedtime-state-machine" screens named in the app-wide spec's batch sequencing (§6) — `StoryGeneratingScreen` and `AgeGateScreen` — to Lantern tokens. **Visual chrome only.** Neither screen's functional/async logic may change in any way.

**Spec:** `docs/superpowers/specs/2026-07-10-lantern-app-wide-design.md` — §7 explicitly protects `StoryGeneratingScreen`'s job-status state machine.

**Prior work:** Foundation, Batches 1-4 all done. All Lantern components needed here already exist (`GlowButton`/`LanternOutlineButton` cover the buttons; no new component needed this batch).

**Out of scope:** Batches 6-7, any other class in `storytime_screens.dart`, any copy/behavior/nav change.

---

## Critical constraint — read this before touching either file

**Neither screen has any test coverage of its state/timer logic, at any layer.** `StoryGeneratingScreen`'s job-status machine (queued→writing→checking→narrating→ready/failed) has zero tests — screen, provider, or repository. `AgeGateScreen`'s cooldown `Timer` has zero widget-level tests (its pure validation logic is separately unit-tested and that test must still pass, but the timer/submit-flow itself is untested). **There is no safety net catching a state-logic regression in this batch** — the discipline of touching visual chrome only must be exact, not "close enough."

## Inventory findings (grounded via Explore agent)

### `StoryGeneratingScreen`

- **File:** `app/lib/ui/storytime_screens.dart`, `StoryGeneratingScreen` (1169-1176) + `_StoryGeneratingScreenState` (1178-1399). No private helpers. Clean boundary before `StoryLibraryScreen` (1401+, already migrated Batch 4).
- **State mechanism (DO NOT TOUCH):** a `StreamSubscription<StoryJob>` from `storyGenerationRepositoryProvider.watchJob(uid, jobId).listen(_onJob, onError: ...)`. Lifecycle: `initState`→`Future.microtask(_start)`, `dispose()` cancels the subscription. Do not touch: `_start`, `_onJob`, `_import`, the `StreamSubscription` field/lifecycle, `_jobId`/`_status`/`_error`/`_importing` state fields, or any copy string.
- **Rendered states are binary**, not four-way: in-progress (status headline + indeterminate `LinearProgressIndicator`, no `value:`) vs error (title/message swap + 2 buttons). There is no rendered "success" state — on `ready` the screen navigates away (`context.go('/story/$id')`) rather than rendering anything.
- **Touch only the `build()` method's widget tree and styling args.**
- Already has a `Theme(data: StorytimeTheme.bedtime, child: Builder(...))` wrap (line ~1319) — **remove it**, now redundant since the root theme is permanently Lantern night (per spec §2, "remove opportunistically as each screen is touched").
- Token reads, all inside `build()`: `tokens.cream` ×2 (text color line ~1346; progress-track background `.withValues(alpha: 0.18)` line ~1358)→`moon`/`hush`-equivalent-alpha-of-`lantern` (use judgment — this is a progress-track background, should read as a dim version of the active color, not literally `hush`; check `GlowButton`/other progress-adjacent components for the established idiom). `tokens.ember` ×1 (progress indicator color, line ~1357)→`lantern`. `AppColors.destructiveOnDark` (line ~1367, static const, not a `tokens` field)→check whether this already renders correctly on dark (name suggests it's already dark-ground-appropriate; verify, don't blindly swap to `hueCoral` if it's already correct — but likely should still become `tokens.hueCoral` for consistency, use judgment and flag if ambiguous).
- Already-dark: `Scaffold` has no background override, body is `Container(decoration: BoxDecoration(gradient: tokens.nightGradient))` — this will need updating from `StorytimeTokens.nightGradient` to `LanternTokens.nightGradient` once `tokens` becomes a `LanternTokens` read, but the screen was already visually dark before this batch (unlike most prior batches' targets).
- Both `StButton`s ("Try again" ember, "Back home" `line` variant) are on the spec's safe list — but for consistency with every other migrated screen, swap "Try again"→`GlowButton` and "Back home"→`LanternOutlineButton` anyway (matches the pattern established in `StoryEndScreen`/`AgeGateScreen`'s sibling screens — a mix of old-safe-variant `StButton` and new Lantern buttons across the app looks inconsistent even where the old variant "works").
- `PixelSprite` unchanged (no Lantern equivalent needed, per spec §4).
- No test exists — confirm nothing under `app/test/` breaks (there's nothing to break, but re-confirm via grep, don't assume the report is still accurate).

### `AgeGateScreen`

- **File:** `app/lib/ui/age_gate_screen.dart` (dedicated file, not in `storytime_screens.dart`). `AgeGateScreen` (18-25) + `_AgeGateScreenState` (27-300, end of file). No other classes.
- **Timer mechanism (DO NOT TOUCH):** `Timer? _cooldownTimer`, a real `Timer.periodic` (1s tick) started after 3 failed validation attempts, running a 60s cooldown. Cancelled in `dispose()`. Do not touch: `_startCooldown`, `_cooldownTimer` field/lifecycle, `_continue()`'s validation call (`validateAdultBirthDate` from `logic/age_gate_logic.dart`), `_selectedBirthDate`/`_errorMessage`/`_isSubmitting`/`_failedAttempts`/`_cooldownEndsAt` state fields.
- **Touch only the `build()` method's widget tree and styling args.**
- No `Theme(...)` wrap — relies on ambient/root theme. **Scaffold paints `tokens.cream` directly** — this screen is currently light and won't auto-darken; needs an explicit ground fix (use the `nightDeep`+`nightGradient` no-AppBar pattern already established in `ParentAccessScreen`/`StoryComposerScreen` — this screen has no AppBar either, confirm which pattern fits by reading its actual layout first).
- Token reads, all cream-locked: `tokens.cream` ×2 (Scaffold bg, date-picker-row fill)→`nightDeep`/`nightCard`, `tokens.paper` ×1 (card container)→`nightCard`, `tokens.ink` ×2 (title, selected-date text)→`moon`, `tokens.ink2` ×3 (back icon, subtitle, calendar icon)→`moonDim`, `tokens.ink3` ×2 (placeholder-date text, chevron)→`moonFaint`, `tokens.line` ×1 (date-picker-row border)→`hush`.
- Out-of-band reads (not `StorytimeTokens`): `tokens.eyebrow` (a `TextStyle`, not color — check if `LanternTokens` needs an equivalent or if `AppTypography.eyebrow` suffices directly), `AppColors.eyebrow` (static const color `0xFFA8472F`, burnt terracotta — **per spec §3, this must NOT carry forward**; the spec already resolved this: eyebrow/label text uses `moonDim`, not a cream-specific accent color — apply that here), `Theme.of(context).colorScheme.error` (Material `ColorScheme` read, ×2 — check if this needs to become `tokens.hueCoral` for visual consistency with the rest of the app, or if it's fine to leave as the Material-standard error color; use judgment, flag if ambiguous), `tokens.ctaGradient` (submitting-state button gradient)→`LanternTokens.ctaGradient` (Lantern has its own `ctaGradient`, confirmed used by `GlowButton` — use that).
- **Confirmed hardcoded raw color**: `Colors.white` (line ~277, `CircularProgressIndicator`'s `valueColor` during `_isSubmitting`) — matches the spec's §3 tracked item exactly. Fix to a Lantern-appropriate color (likely `tokens.nightDeep` if the spinner sits on the ember/lantern gradient button per `GlowButton`'s own on-accent contrast convention, or `tokens.moon` if it sits elsewhere — check the actual layout before deciding).
- `StButton` ("Continue", ember variant) → swap to `GlowButton` for consistency (same reasoning as `StoryGeneratingScreen` above).
- Existing tests to keep green: `app/test/logic/age_gate_logic_test.dart`, `app/test/providers/adult_gate_provider_test.dart` — neither touches the widget tree, should be unaffected by a chrome-only re-skin, but run them explicitly to confirm.

## Task 1: `StoryGeneratingScreen`

**File:** `app/lib/ui/storytime_screens.dart` — touch only this class, per the constraints above.

## Task 2: `AgeGateScreen`

**File:** `app/lib/ui/age_gate_screen.dart` — touch only this class, per the constraints above.

Tasks 1 and 2 are independent (different files, no shared helpers) — run in parallel.

## Verification (both tasks)

- `flutter analyze` clean (baseline: 11 pre-existing infos).
- Full `flutter test` — compare against 136 passed / 9 failed baseline.
- `app/test/logic/age_gate_logic_test.dart` + `app/test/providers/adult_gate_provider_test.dart` specifically green after Task 2.
- **Manual reasoning check, not just automated**: for each screen, re-read the final diff and confirm every line touched is inside `build()` (or the widget tree it returns) — not inside `initState`/`dispose`/`_start`/`_onJob`/`_import`/`_continue`/`_startCooldown` or any state-field declaration. Given zero test coverage protects this boundary, the diff review itself is the safety net.
- `git diff` hunk audit: confirm zero hunks touch any other class in `storytime_screens.dart`.
