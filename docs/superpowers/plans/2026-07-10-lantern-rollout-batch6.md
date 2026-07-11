# Lantern Rollout — Batch 6 Implementation Plan

**Goal:** Migrate the 3 "keypad + hybrid-dark" screens named in the app-wide spec's batch sequencing (§6) — `PinGateScreen`, `ChangePinScreen`, `GuidedCaptureScreen` — to Lantern tokens. Extract a shared `LanternKeypad` component for the genuinely-duplicated keypad UI (not the whole screens). Drop `GuidedCaptureScreen`'s manual dark-paint hack.

**Spec:** `docs/superpowers/specs/2026-07-10-lantern-app-wide-design.md`
**Prior work:** Foundation, Batches 1-5 all done.

**Out of scope:** Batch 7 (separate future plan), any copy/feature/nav change, any change to lockout/recording business logic.

---

## Inventory findings (grounded via Explore agent)

### Dedup verdict — read this before building anything

The spec's "near-duplicate, dedupe" claim **holds only at the keypad-widget level**, not the whole screen. Confirmed via line-by-line comparison:
- **True near-duplicate** (same shapes/sizes modulo a few drifted literals, same typography, no animation on either, same haptic feedback, same lockout-timer mechanics down to identical store keys `pin_failed_attempts`/`pin_lock_until` shared across both screens via the key-value store): the digit-grid keypad, the 4-dot input indicator, and the locked-out overlay (icon + "Too many attempts..." countdown text).
- **Genuinely different, do not force together**: step semantics (`PinGateScreen`'s `enter/create/confirm` is conditional on whether a PIN already exists; `ChangePinScreen`'s `enterCurrent/enterNew/confirmNew` is always all three), success side effects (`PinGateScreen` sets `parentAuthProvider` + `context.go(nextLocation)`; `ChangePinScreen` calls `pinProvider.updatePin` + SnackBar + `context.pop()`), back-navigation direction (`context.go('/')` vs `context.pop()` — not interchangeable), an entire extra empty-state Scaffold only `ChangePinScreen` has (no saved PIN yet), and differing Scaffold structure (`PinGateScreen` one Scaffold with inner async branches; `ChangePinScreen` four separate top-level Scaffolds).
- **Conclusion: extract a shared `LanternKeypad` widget covering the keypad/dots/lockout-overlay only. Keep `PinGateScreen` and `ChangePinScreen` as separate screen classes with their own orchestration logic untouched.**

**Small literal drift found between the two "identical" keypads** (accidental copy-paste divergence, not intentional): keypad width spacing (48 vs 60), per-key horizontal padding (8 vs 10), DEL key fill color (`paper` always vs `cream` conditionally), DEL icon color (`ink` vs `ink2`), spacing before the dot row (24 vs 32). When unifying into one component, pick **one** canonical value per property — default to `PinGateScreen`'s values (it has real test coverage to validate the visual result against; `ChangePinScreen` has none), and note the unification in the report rather than silently picking one.

### `PinGateScreen`

- **File:** `app/lib/ui/pin_gate_screen.dart` (whole file). `PinGateScreen` (24-31), `_PinGateScreenState` (33-479).
- **Do-not-touch (real async/lockout logic):** `Timer? _lockTimer` (`Timer.periodic(1s)`), `_failedAttempts`/`_lockedUntil` persisted via `keyValueStoreProvider`, `_loadLockState`/`_persistLockState`/`_clearLockState`, the 3-way `_step` flow in `_handleComplete`. Success path: `parentAuthProvider.notifier.state = true` + `AnalyticsService.instance.logParentAreaEntered()` + `context.go(widget.nextLocation)`.
- **Real test coverage exists and must stay green**: `app/test/ui/pin_gate_screen_test.dart` drives this screen end-to-end — create-flow copy, enter-flow copy, full create+confirm navigation, and lockout after 5 wrong attempts (asserts `'Too many attempts.'`/`'Try again in'` text). **It finds digit buttons via `find.text(digit)`** — `LanternKeypad` must render key-caps as literal `Text('0')`...`Text('9')`/`Text('DEL')`, not icons or a different label scheme, or this test breaks.
- Cream-locked reads throughout: `cream`/`ember`/`paper`/`ink`/`.ink2`/`.ink3`/`line`/`.line2`/`eyebrow` (TextStyle) + `AppColors.eyebrow` override (must not carry forward, per spec §3 — use `moonDim` instead, same resolution as every prior batch). Out-of-band: `Theme.of(context).colorScheme.error` (error-state text) — decide `hueCoral` vs leave as Material error, same judgment call pattern as Batch 5's `AgeGateScreen`.
- No shared `St*` widget used at all — 100% bespoke keypad/dots/card.
- Scaffold paints `tokens.cream` directly — needs an explicit dark-ground fix.
- Single routing call site (`/pin`), no stale routing.

### `ChangePinScreen`

- **File:** `app/lib/ui/change_pin_screen.dart` (whole file). `ChangePinScreen` (21-26), `_ChangePinScreenState` (28-485).
- **Do-not-touch**: identical lockout mechanism (same `Timer`, same store keys — shared lockout state with `PinGateScreen` at the data layer, not independent). 3-step flow in `_handleComplete`. Success path: `pinProvider.notifier.updatePin(_newPin)` + `AnalyticsService.instance.logPinChanged()` + SnackBar + `context.pop()`.
- **No test coverage at all** — confirm via grep before assuming, but the inventory found none.
- Same cream-locked token set as `PinGateScreen`, same `AppColors.eyebrow` resolution needed. No `colorScheme.error` read (its error-state Scaffold uses plain `tokens.ink` — a pre-existing inconsistency with `PinGateScreen`, not something to fix beyond the token migration itself unless trivial).
- Extra branch `PinGateScreen` doesn't have: if `currentPin == null`, renders a distinct "Set up a parent PIN first" Scaffold with a plain `ElevatedButton` "Back" — no keypad. Migrate this branch's colors too, it's simple chrome.
- Four separate top-level Scaffolds (loading/error/no-pin-yet/data), each currently `backgroundColor: tokens.cream` — all four need the dark-ground fix.
- Two routing callers (`parent_list_screen.dart`, `storytime_screens.dart`), both current, no stale calls.

### `GuidedCaptureScreen`

- **File:** `app/lib/ui/family_voices_screens.dart`. `GuidedCaptureScreen` (604-617), `_GuidedCaptureScreenState` (619-804). Confirmed untouched by Batches 1/3/4 (git-history checked) — still the only class in this file reading `StorytimeTokens` instead of `LanternTokens`.
- **The "manual dark-paint hack," precisely**: `Scaffold(backgroundColor: tokens.night1, ...)`, `AppBar(..., foregroundColor: tokens.cream)`, body text forced to `tokens.cream`/`.cream.withValues(alpha: ...)` throughout — `night1` and `cream` are both cream-locked/theme-constant fields (identical across day/bedtime), so this screen hardcodes a specific dark-on-dark look independent of the ambient theme, rather than reading whatever the root theme provides. **This whole hack becomes unnecessary now that the root theme is permanently dark — migrate this screen exactly like every other screen (read `LanternTokens` via `Theme.of(context)`), don't preserve the manual override pattern.**
- **Do-not-touch (real but simpler than Batch 5's screens — no Timer, no StreamSubscription)**: `RecordingService _recorder` (disposed in `dispose()`), `_promptIndex`/`_recordedPaths`/`_recording`/`_uploading`/`_error` state fields, `_toggleRecord()` (mic permission + start/stop), `_submitSamples()` (upload Future + navigate on success), `PopScope.onPopInvokedWithResult` (stops in-flight recording on back-nav — functional, not just chrome).
- Token reads: `tokens.night1` (the hack itself, drop it — screen background becomes the standard `nightDeep`/`nightGradient` no-AppBar-or-with-AppBar pattern, check whether this screen's AppBar means it should use the `nightMid`+transparent-AppBar recipe instead — it has an AppBar per line ~712, so likely the `nightMid` pattern, not `nightDeep`), `tokens.cream` (×4, body/step-counter/prompt text)→`moon`/`moonDim` as appropriate, `tokens.ember` (StChip tint)→`lantern`.
- `AppColors.destructive` (error text) — **notably not** `AppColors.destructiveOnDark` even though this screen is already dark-painted (an existing inconsistency in the current code, not something introduced by migration) → `tokens.hueCoral`, matching the resolution used everywhere else.
- **Confirmed hardcoded raw color**: `Colors.white` (uploading-state `CircularProgressIndicator`) — same spec-tracked item as `AgeGateScreen`'s spinner in Batch 5. Fix using the same on-accent convention (check what it visually sits on top of here — likely just the dark ground directly, not a gradient button, so probably `tokens.lantern` or `tokens.moon` rather than `nightDeep` — use judgment based on what's actually behind it).
- **Shared `St*` widgets, three categories:**
  - `StDots` — spec says reuse-as-is safe (not color-coupled). Leave it.
  - `StChip` — swap to `LanternChip` (already exists from Batch 3), passing the semantic hue directly per its established contract.
  - `StPrompt`/`StVoiceWave`/`StRecordButton` (from `lib/ui/widgets/storytime/st_voice_capture.dart`) — **these were purpose-built cream-on-dark specifically for this screen** (they already hardcode `tokens.cream`/`tokens.night3`/`tokens.gold` internally, i.e. not mode-aware, effectively private-in-spirit even though technically in the shared `st_*` directory). **Before touching them, check for other consumers** (`grep -rn "StPrompt\|StVoiceWave\|StRecordButton" app/lib/`) — if `GuidedCaptureScreen` is their only consumer (likely, given the naming and the inventory's characterization), migrate their internals directly to `LanternTokens` rather than building 3 new Lantern-prefixed components for single-use widgets. If they do have other consumers, stop and report back rather than guessing.
- **No test coverage at all** for this class or file-level recording/upload flow.
- Single routing call site (`/parent/family-voices/capture`), no stale routing.

## Task 1: `LanternKeypad` + `PinGateScreen` + `ChangePinScreen`

**Files:** create `app/lib/ui/widgets/lantern/lantern_keypad.dart` (export from `lantern.dart`, add gallery entry), modify `app/lib/ui/pin_gate_screen.dart` and `app/lib/ui/change_pin_screen.dart`.

One task, not split — both screens depend on the same new component and should land together to keep the unification decisions (canonical spacing/DEL-fill/DEL-icon-color) consistent across both call sites rather than drifting again.

- `LanternKeypad`: encapsulate the digit-grid (1-9, blank, 0, DEL), the 4-dot input indicator, and the locked-out overlay (icon + countdown text) as one component. **Preserve literal key-cap text** (`'0'`-`'9'`, `'DEL'`) for `find.text(digit)` compatibility with `pin_gate_screen_test.dart`. Business logic (which step, what happens on complete, lock timer itself) stays in each screen — `LanternKeypad` should take something like `{required int enteredLength, required int totalDigits, required ValueChanged<String> onKeyPress, bool locked, int? lockSecondsRemaining}` and be otherwise stateless/dumb.
- Migrate `PinGateScreen`/`ChangePinScreen` to use `LanternKeypad`, dark ground fix (Scaffold no longer paints `cream`), `AppColors.eyebrow`→`moonDim` resolution, `colorScheme.error`→`hueCoral` judgment call for `PinGateScreen`.
- Keep `app/test/ui/pin_gate_screen_test.dart` green — this is the load-bearing check for this task.

## Task 2: `GuidedCaptureScreen`

**File:** `app/lib/ui/family_voices_screens.dart` — touch only this class (5 other classes in the file, all already migrated in Batches 1/3/4, do not touch them).

Drop the manual dark-paint hack per the inventory notes above. Migrate `StChip`→`LanternChip`. Investigate and resolve `StPrompt`/`StVoiceWave`/`StRecordButton` per the inventory's instructions (check consumers first). Fix the confirmed `Colors.white` spinner hardcode.

Tasks 1 and 2 are independent (different files) — run in parallel.

## Verification (both tasks)

- `flutter analyze` clean (baseline: 11 pre-existing infos).
- Full `flutter test` — compare against 136 passed / 9 failed baseline.
- `app/test/ui/pin_gate_screen_test.dart` specifically green after Task 1 — this is the one batch-6 test with real functional assertions on the exact thing being refactored (the keypad), treat it as load-bearing, not a formality.
- Manual diff review confirming lockout `Timer`/persistence logic, recording/upload logic, and `PopScope` handling are untouched in both tasks (same discipline as Batch 5, given the async logic here — smaller than Batch 5's but still real).
