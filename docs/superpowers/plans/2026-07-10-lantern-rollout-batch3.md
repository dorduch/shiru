# Lantern Rollout — Batch 3 Implementation Plan

**Goal:** Migrate the 2 "lists with state" screens named in the app-wide spec's batch sequencing (§6) — `FamilyVoicesScreen` and `VoiceConsentScreen` — to Lantern tokens, and build the one new shared component that batch needs.

**Spec:** `docs/superpowers/specs/2026-07-10-lantern-app-wide-design.md`
**Prior work:** Foundation, Batch 1, Batch 2 all done — `LanternRow`/`LanternActionTile`/`LanternSectionHeader`/`LanternOutlineButton`/`LanternTextField`/`LanternSegment`/`LanternChoiceCard` all exist and are barrel-exported from `lib/ui/widgets/lantern/lantern.dart`.

**Out of scope:** Batches 4-7 (separate future plans), `GuidedCaptureScreen` (same file, deferred to Batch 6 per spec §6 — do not touch, confirmed clean boundary at line 799/801 in `family_voices_screens.dart`), any copy/feature/nav change.

---

## Inventory findings (grounded via Explore agent, not assumed)

- **File:** `app/lib/ui/family_voices_screens.dart`. Both target classes confirmed at current line ranges: `FamilyVoicesScreen` (+ private `_EmptyVoices`/`_VoicesList`/`_VoiceRow`) at lines 47-227, `VoiceConsentScreen`/`_VoiceConsentScreenState` at 231-446. `GuidedCaptureScreen` (599-799, deferred) sits between the two already-migrated classes and this batch's targets — no boundary risk.
- Both screens are 100% cream-locked or theme-constant token reads (`cream`/`ink`/`ink2`/`ink3`/`paper`/`line`, plus theme-constant `ember`) — zero mode-aware reads, same pattern as every prior batch. Both `Scaffold`/`AppBar` paint `tokens.cream` directly (the "literal bright cream rectangle on dark root" issue, not just wrong-toned text).
- **`StChip` has a real, worse-than-usual bug**: its label text color is hardcoded to `tokens.ink` with **no prop to override it** (only the fill `color` is customizable). `_VoiceRow`'s only call site (`FamilyVoicesScreen`, line ~213) passes a semantic status color as a 15%-alpha fill (`_statusColor(...).withValues(alpha: 0.15)`) but the label text stays `ink` regardless — on a dark ground this renders dark text on a dark-tinted translucent background, i.e. **actually illegible**, not just wrong-toned. `LanternChip` must take the semantic hue and derive BOTH fill tint and text color from it (see Foundation below) — a genuine improvement over `StChip`'s design, not just a token-source swap.
- **`_statusColor()` helper** (lines ~20-34) is a pre-existing straddle: it already reads `LanternTokens.hueMeadow` directly for the `ready` case (a Batch-1-era special-case) while accepting a `StorytimeTokens tokens` param for its `gold` fallback. It has exactly one call site left (`_VoiceRow`) after this batch — `GuidedCaptureScreen`'s own `StChip` usage (deferred, out of scope) does **not** call `_statusColor()`. Convert its signature fully to `LanternTokens` (drop the `StorytimeTokens` param, `gold` fallback → `lantern` for the "processing" case) as part of this batch, since it'll have no remaining cream-locked consumer.
- **Green hardcode already resolved**: repo-wide `0xFF4CAF50` returns zero hits — both original instances were already converted to `hueMeadow` in Batches 1-2. Nothing to do here.
- Neither screen has existing test coverage (`grep -rl "FamilyVoicesScreen\|VoiceConsentScreen" app/test/` → no matches).
- Both have genuine state complexity, not static re-skin targets: `FamilyVoicesScreen` handles `AsyncValue.when(loading/error/data)` via `familyVoicesProvider` plus an empty-vs-populated branch (`_EmptyVoices` vs `_VoicesList`) that also conditionally hides a FAB; `VoiceConsentScreen` is a multi-field form (`_nameCtrl`/`_relCtrl`/`_agreed`/`_personIsLiving`/`_busy`/`_error`) with an async submit path and inline error banner. Token re-skin must not touch this state logic.
- No stale routing in either screen (`context.push('/parent/family-voices/consent')`, `context.push('/parent/family-voices/capture-intro', ...)` both match current `router.dart` routes).

## Foundation: `LanternChip`

**File:** `app/lib/ui/widgets/lantern/lantern_chip.dart`, exported from `lantern.dart`, gallery entry added.

- Signature: `LanternChip({required String label, required Color hue, VoidCallback? onTap})`. Unlike `StChip` (fill-only customizable, text hardcoded), **both fill and text derive from the single `hue` param**: fill = `hue.withValues(alpha: 0.15)`, text = `hue` at full strength. This is the fix for the illegibility bug above — a status pill's text must be legible against its own tinted fill regardless of which semantic hue (`hueMeadow`/`hueCoral`/`lantern`) is passed.
- Shape/spacing/radius copied 1:1 from `StChip` (10h/4v padding, `AppRadius.full`).
- `onTap` optional, same as `StChip` (no disabled-state concern — chips here are read-only status indicators, not called with a null-to-disable pattern anywhere in this batch).

## Task 1: `FamilyVoicesScreen` + `VoiceConsentScreen`

**File:** `app/lib/ui/family_voices_screens.dart` — single task, both classes are in the same file (concurrent-edit risk if split, per established precedent from Batches 1-2).

- Both screens: `Scaffold`/`AppBar` `tokens.cream`→dark ground, matching the `nightMid` + transparent AppBar + `nightGradient`-body pattern already used by `VoiceCaptureIntroScreen`/`VoiceReadyScreen`/`VoiceUploadScreen` earlier in this same file (read those for the exact established pattern, don't re-derive it).
- `FamilyVoicesScreen`: `StSectionHeader`→`LanternSectionHeader`, `StErrorView`→re-skin colors in place (per spec, reuse structurally), `StChip`→`LanternChip` (pass the semantic status color — `hueMeadow`/`hueCoral`/`lantern` — as `hue`, not a pre-alpha-blended fill). Resolve the `_statusColor()` helper per the inventory note above: convert fully to `LanternTokens`, drop the `StorytimeTokens` param and `gold` fallback in favor of `lantern`. Row card fill/border (`paper`/`line`)→`nightCard`/`hush`. `ember` avatar-circle fill/icon→`lantern`. The `onAccent` FAB-foreground read is already mode-aware — check whether it still makes sense once the surface is permanently dark (likely stays correct, verify rather than assume).
- `VoiceConsentScreen`: `StSectionHeader`→`LanternSectionHeader` (has an `eyebrow: 'Step 1 of 2'` — confirm `LanternSectionHeader` handles this or note the gap, same as Batch 1's family_voices agent flagged for `VoiceCaptureIntroScreen`'s "Step 2 of 2"), `StTextField`→`LanternTextField` (×2), `StHint`→re-skin in place (no shared Lantern equivalent yet, single call site, matches spec's existing `StToggle` guidance), `ember` Switch/Checkbox/agreement-card colors→`lantern`. `AppColors.destructiveDark`→`tokens.hueCoral` (matches the pattern already applied in Batches 1-2 for `AppColors.destructive`).
- Primary `StButton`s (ember variant — "Add a voice", "Continue") stay as-is, already safe on dark per spec.
- **Do not touch `GuidedCaptureScreen`** (lines 599-799) even though it also calls `StChip` — that class is deferred to Batch 6.
- No test file exists for either class, so no test updates expected — confirm via grep before finishing, don't assume.

## Verification

- `flutter analyze` clean (no new issues beyond the existing 11 pre-existing infos).
- Full `flutter test` — compare against the 136 passed / 9 failed baseline (order-dependent/flaky set, not a fixed list).
- Confirm `GuidedCaptureScreen`'s `StChip` call site and the rest of that class are byte-for-byte untouched (`git diff` should show zero hunks touching lines 599-799).
