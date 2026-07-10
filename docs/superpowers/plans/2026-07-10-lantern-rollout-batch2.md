# Lantern Rollout — Batch 2 Implementation Plan

**Goal:** Migrate the 5 "simple forms" screens named in the app-wide spec's batch sequencing (§6) to Lantern tokens, and build the two new shared components that batch needs plus one more the inventory surfaced.

**Spec:** `docs/superpowers/specs/2026-07-10-lantern-app-wide-design.md`
**Prior work:** Foundation + Batch 1 (`docs/superpowers/plans/2026-07-10-lantern-rollout-foundation-batch1.md`) — root theme, icon recolor, `LanternRow`/`LanternActionTile`/`LanternSectionHeader`/`LanternOutlineButton` already exist.

**Out of scope:** Batches 3-7 (separate future plans), `AudioRecorderWidget`'s internals (see Task 3 note), `AddAudioDetailsScreen`'s card-color swatches (content data, not chrome), any copy/feature/nav change.

---

## Inventory findings (grounded, not assumed)

- All 5 screens read exclusively cream-locked `StorytimeTokens` fields (`ink`/`ink2`/`ink3`/`cream`/`paper`/`line`) or the theme-constant `ember` — zero mode-aware reads anywhere. None auto-adapt to the dark root theme.
- **3 of 5 screens actively paint `tokens.cream` as their `Scaffold`/`AppBar` background** (`AddAudioCaptureScreen`, `AddAudioDetailsScreen`, `VoiceUploadScreen`) — a literal bright cream rectangle sitting on the dark root theme, not just wrong-toned text. Higher-priority visual break than the other two.
- `ChildSetupScreen`/`StorytimeAuthScreen` inherit the dark root theme already (no Scaffold override) — their bug is cream-locked text/border/field colors floating on dark, not a painted-over background.
- `StorytimeAuthScreen` has 2 `StButtonVariant.ghost` buttons ("Continue with Apple/Google") — the same white-pill-on-dark bug fixed for `StorytimeWelcomeScreen` in Batch 1. `LanternOutlineButton` already supports a `leading` icon, so it's a direct swap.
- `ChildSetupScreen`'s avatar picker uses a bespoke private `_AvatarChoice` widget, not any shared `St*` component — confirmed the spec's flagged gap (no general-purpose selectable card existed). **Resolved as part of this plan's foundation**: built `LanternChoiceCard`.
- `AddAudioCaptureScreen` embeds `AudioRecorderWidget` (`lib/ui/widgets/audio_recorder_widget.dart`) — a separately shared, heavily hardcoded widget (24+ raw `Color(0x...)` literals) also used by `parent_edit_screen.dart` (not in any planned batch yet, still cream). Same shape of problem as `StSectionHeader` in Batch 1: it has another still-unmigrated consumer, so **do not edit it in this batch** — re-skin `AddAudioCaptureScreen`'s own chrome only, leave the embedded recorder UI old-style, flag it as a known gap for whenever `parent_edit_screen.dart` is scheduled.
- Only `AddAudioDetailsScreen` has existing test coverage (`app/test/ui/add_audio_screens_test.dart`, 4 `testWidgets`, all behavioral — card creation/update — not visual). No stale routing found in any of the 5 screens.

## File map

| Screens | File | Notes |
|---|---|---|
| `ChildSetupScreen`, `StorytimeAuthScreen` | `app/lib/ui/storytime_screens.dart` | Same file — one task, avoid concurrent edits (Batch 1 precedent) |
| `AddAudioCaptureScreen`, `AddAudioDetailsScreen` | `app/lib/ui/add_audio_screens.dart` | Same file — one task |
| `VoiceUploadScreen` | `app/lib/ui/family_voices_screens.dart` | Shared file — also defines `FamilyVoicesScreen`/`VoiceConsentScreen`/`GuidedCaptureScreen` (Batch 3) and the already-migrated Batch 1 screens. **Touch only `VoiceUploadScreen`.** |

## Foundation (done before dispatching screen work)

- `LanternTextField` (`lib/ui/widgets/lantern/lantern_text_field.dart`) — built, barrel-exported, gallery entry added.
- `LanternSegment` (`lib/ui/widgets/lantern/lantern_segment.dart`) — built, barrel-exported, gallery entry added. Note: `StSegment` hardcodes `Colors.white` for its selected pill (a third instance of the raw-white-on-dark bug pattern, alongside `StButton`'s `ghost`/`soft`) — `LanternSegment`'s selected pill is `lantern` filled with `nightDeep` text instead.
- `LanternChoiceCard` (`lib/ui/widgets/lantern/lantern_choice_card.dart`) — built, barrel-exported, gallery entry added. General-purpose selectable card (glyph + label + selection state), shape copied from `_AvatarChoice`.
- `flutter analyze` clean, full `flutter test` at 136/9 baseline — confirmed before dispatching screen tasks.

## Task 1: `ChildSetupScreen` + `StorytimeAuthScreen`

**File:** `app/lib/ui/storytime_screens.dart`

- `ChildSetupScreen`: swap `StTextField`→`LanternTextField`, `StSegment`→`LanternSegment`, replace private `_AvatarChoice` usages with `LanternChoiceCard` (delete `_AvatarChoice` once unused), `tokens.ember`/`.paper`/`.line`→`lantern`/`nightCard`/`hush` on any remaining direct reads. `StButton` (ember variant, `Done`) stays as-is (safe per spec).
- `StorytimeAuthScreen`: swap both `StTextField`s→`LanternTextField`, swap both `StButtonVariant.ghost` buttons ("Continue with Apple"/"Continue with Google")→`LanternOutlineButton` (pass the Apple/Google icon as `leading`), leave the primary `Continue` button (ember variant) as-is.
- Neither screen currently overrides its `Scaffold` background — don't add one; confirm it still resolves to the dark root theme after other tokens are swapped (no regression).

## Task 2: `AddAudioCaptureScreen` + `AddAudioDetailsScreen`

**File:** `app/lib/ui/add_audio_screens.dart`

- Both screens: `Scaffold.backgroundColor`/`AppBar.backgroundColor` `tokens.cream`→`tokens.nightDeep`/`nightGradient` (match the `nightGradient`-on-`Container` pattern used by other migrated screens, not a flat `Scaffold.backgroundColor` alone, for visual consistency), AppBar title/foreground `tokens.ink`→`tokens.moon`.
- `AddAudioCaptureScreen`: `StSectionHeader`→`LanternSectionHeader`. **Do not edit `AudioRecorderWidget`** (embedded, separately shared, has another unmigrated consumer) — leave it rendering in its current (old) style; this is a known, deliberate gap, not an oversight.
- `AddAudioDetailsScreen`: `StTextField`→`LanternTextField`, swatch-selection border colors (`tokens.ink`/`.line`)→`lantern`/`hush`. **Do not touch `_swatches`' raw hex values** — those are user-facing card-color content, not chrome.
- Keep `app/test/ui/add_audio_screens_test.dart` passing — its 4 tests are behavioral (card creation/update via `updateCard`), should be unaffected by a token-only re-skin, but verify.

## Task 3: `VoiceUploadScreen`

**File:** `app/lib/ui/family_voices_screens.dart`

- Touch **only** `VoiceUploadScreen` (lines ~802-945 per inventory) — this file has 5 other classes, 2 already migrated (Batch 1), 3 not yet in scope (Batch 3). Do not touch them.
- `Scaffold`/`AppBar` `tokens.cream`→dark ground (same pattern as Task 2), `tokens.ink`/`.ink3`→`moon`/`moonFaint`, `tokens.paper`/`.line`/`.ember`→`nightCard`/`hush`/`lantern` on the upload-box selection states.
- `StSectionHeader`→`LanternSectionHeader`, `StHint`→ re-skin colors in place if it's cheap (no Lantern equivalent exists yet and it's low-usage per Batch 1's spec note — inline if a dedicated component isn't worth it for one call site, matching the spec's existing guidance on `StToggle`).

## Verification (per task, and again after all 3 land)

- `flutter analyze` clean (no new issues beyond the existing 11 pre-existing infos).
- Full `flutter test` — compare against the 136 passed / 9 failed baseline (order-dependent/flaky set, not a fixed list — see memory).
- `app/test/ui/add_audio_screens_test.dart` specifically green after Task 2.
- Visual spot-check via simulator or `/dev/gallery` if convenient.

## Build order

Tasks 1-3 are independent (different files) — run in parallel. No task depends on another.
