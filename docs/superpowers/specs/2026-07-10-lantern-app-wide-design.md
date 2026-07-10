# Lantern App-Wide Rollout

**Date:** 2026-07-10
**Status:** Approved (direction confirmed via mockup — "Lantern Night" selected over "Lantern Day" and "keep current cream")
**Supersedes:** `StorytimeTheme.day`/`.bedtime` as a per-screen choice; the whole app becomes one dark theme
**Builds on:** `docs/superpowers/specs/2026-07-10-story-composer-design.md` (Lantern's origin — this spec generalizes it)

---

## 1. The decision

The Composer shipped as the one dark screen in an otherwise cream app, and the reaction on sight was "doesn't look related." The fork — dark everywhere, a bright `LanternTokens.day()` everywhere, or leave it cream — was resolved by mockup: **dark everywhere.** Lantern Night becomes the app's only visual language. There is no more day/bedtime split to design around — every screen, at all times, renders on `LanternTokens.night()`.

This is a bigger structural simplification than it sounds: the app currently decides "day vs. bedtime" per-screen via manual `Theme(data: StorytimeTheme.day|.bedtime)` wraps (see inventory, §1). Once every screen is the same theme, that per-screen branching is gone — the whole app can run on one root `ThemeData`.

## 2. Root theme change

- `main.dart`: `MaterialApp.router`'s `theme:` becomes the single Lantern night `ThemeData` (built the same way `StorytimeTheme.bedtime` is built today, i.e. `LanternTokens.night()` registered as an extension). Drop `darkTheme:`/`themeMode:` entirely — there is only one theme now.
- Every screen-level `Theme(data: StorytimeTheme.bedtime, child: ...)` wrap (currently on `StorytimeLaunchScreen`, `StoryGeneratingScreen`, `StoryPlayerScreen`, `StoryEndScreen`, `StoryComposerScreen`, `StorySlotSheet`) becomes **redundant, not wrong** — the root theme already provides night. Remove these wraps opportunistically as each screen is migrated (not urgent to do as a single sweep).
- `StorytimeTheme.day` and `LanternTokens.day()` are **not deleted** — keep them defined (cheap, harmless) in case a future screen genuinely needs a light exception (e.g. printable/exportable content), but nothing in this rollout uses them. Do not build new usages of `.day()`.
- The one existing hybrid case, `GuidedCaptureScreen` (day-ambient screen that hand-paints a dark background) — this pattern disappears naturally once the ambient theme is dark everywhere; the screen's manual `backgroundColor: tokens.night1` override becomes redundant and should be removed when that screen migrates, not preserved as a special case.

## 3. Token map — what replaces what

| Old (`StorytimeTokens`/`AppColors`) | New (`LanternTokens`) | Notes |
|---|---|---|
| `cream` / `paper` (grounds) | `nightMid` / `nightDeep` | Screen background gradient, same as Composer |
| `ink` / `ink2` / `ink3` (text) | `moon` / `moonDim` / `moonFaint` | Direct tier-for-tier swap |
| `ember` / `accentColor` / `accent2` | `lantern` / `lanternDeep` | The one accent color, app-wide now |
| `line` / `line2` (hairlines) | `hush` | Single hairline token (Lantern doesn't distinguish two line weights — check nothing relied on that distinction; inventory found none) |
| `AppColors.destructive` | `hueCoral` | Errors/destructive actions |
| `AppColors.tilePlay` (gold), theme colors generally | `hueSun`/`hueSky`/`hueBlossom`/`hueLilac`/`hueMeadow` as appropriate | Concept/status tints — pick per content, not a 1:1 swap |
| Hardcoded `Color(0xFF4CAF50)` (family-voices "ready" green, 2 occurrences) | `hueMeadow` | Centralize — this was never a token to begin with |
| `AppColors.eyebrow` (burnt terracotta, chosen for AA contrast on cream) | Re-derive: `lantern` fails as body text on `nightDeep` per the Composer's own contrast rule — eyebrow/label text uses `moonDim`, not `lantern`, exactly as the Composer already does | Do not carry the old eyebrow color forward — it was cream-specific |
| Raw `Colors.white` (spinners in `AgeGateScreen`, `GuidedCaptureScreen`) | `lantern` or `moon`, per contrast | Case-by-case; a white spinner on `nightDeep` still passes, but prefer a token over a raw literal |
| `AppRadius`, `AppShadows`, `AppResponsive` | **Unchanged, reused as-is** | These are shape/space tokens, not color — Lantern already reuses them (`AppRadius.large`, `AppResponsive.basePadding`, etc.). No new radius/spacing scale needed. |
| `AppSpacing` | **Adopt everywhere** | Already Lantern-exclusive; inventory found it essentially unused elsewhere — this rollout is the point at which the rest of the app should start using it too, replacing hardcoded `SizedBox(height: 12/16/20)` literals as each screen is touched |

**Concept icon outline recolor** (deferred during the Composer, now mandatory): `concept_icons.dart`'s `#7A4A14` / `#2A2230` outlines were chosen for cream backgrounds. Every screen is dark now, so this is no longer optional — recolor to a single night-legible outline (`#241F3D`, per the Composer spec's original intent) as a **one-time, one-file, one-variable change**, not a per-screen concern. Do this once, early, not per-batch.

## 4. Component equivalents

| Old (`lib/ui/widgets/storytime/`) | Lantern equivalent | Status |
|---|---|---|
| `StButton` | `GlowButton` (primary/ember variant) + New: `LanternOutlineButton` | **Both exist** (resolved during Batch 1 — see §5, open question 1). `GlowButton` stays single-purpose (primary CTA only, by design — no variant enum). `LanternOutlineButton` is the quiet secondary button (transparent fill, `hush` border, `moonDim` text) — use it for every non-CTA button instead of `StButton`'s `ghost`/`soft` (hardcode a white fill — wrong on dark) or `line` (renders correctly via mode-aware `textPrimary`, but is a style mismatch, not just a technical gap). `LanternOutlineButton.onTap` is nullable (`enabled: onTap != null` dims the button and reports `Semantics(enabled: false)`, matching `StButton`'s contract) — a Batch 2 agent first shipped it non-nullable and worked around a busy-state disable inside the closure, which silently broke `Semantics(enabled:)` for screen readers; fixed at the component level, not per call-site. |
| `StChoiceCard` | `VoiceCard` / `StorySlot` (context-specific) + New: `LanternChoiceCard` | **Resolved during Batch 2.** `LanternChoiceCard` is the general-purpose selectable card the spec flagged as missing (glyph + label + selection state) — built to replace `ChildSetupScreen`'s bespoke private `_AvatarChoice`, reusable for any future selectable-card need that isn't `VoiceCard`/`StorySlot`'s Composer-specific shape. |
| `StTextField` | New: `LanternTextField` | **Resolved during Batch 2.** Shape/spacing copied 1:1 from `StTextField`; `nightCard` fill, `hush` border (`lantern` on focus), `moon`/`moonDim`/`moonFaint` text. |
| `StSegment` | New: `LanternSegment` | **Resolved during Batch 2.** `StSegment` hardcodes `Colors.white` for its selected pill (a third instance of the raw-white-on-dark pattern, alongside `StButton`'s `ghost`/`soft`) — `LanternSegment`'s selected pill is `lantern` filled with `nightDeep` text instead. |
| `StDots` | — | Reuse as-is (progress dots aren't color-coupled; just needs to read `LanternTokens` instead of `StorytimeTokens` internally, or take colors as params) |
| `StScreenHeader` / `StSectionHeader` | New: `LanternSectionHeader` | **Resolved during Batch 1 (was going to be "reuse structurally," turned out not to be possible).** `StSectionHeader` reads `StorytimeTokens.ink`/`.ink2` directly rather than the mode-aware `textPrimary`/`textSecondary` slots — and `ink`/`ink2` are identical constants across day and bedtime (see `app_theme.dart`), so its text is always dark and is now illegible on the permanent dark root theme. It still has other cream-surface consumers elsewhere in the app not yet migrated (Home, wizard, Library, Family Voices, Add Audio), so the shared widget itself is intentionally left untouched — don't edit it. Migrated screens use `LanternSectionHeader` instead. When a later batch migrates all remaining `StSectionHeader` consumers, revisit whether the old widget can be deleted outright rather than left as dead cream-only code. |
| `StTile` (big home action tile) | New: `LanternActionTile` | Home's "Make a Story"/"Listen" tiles need a Lantern version — closest existing analog is `VoiceCard`'s glow-on-selected treatment, but this is a bigger, non-selectable tile. **New component.** |
| `StRow` (resume strip, list rows) | New: `LanternRow` | Used for the resume strip and every list-style screen (dashboard entries, voice rows, story rows). **New component** — high reuse value, build once. |
| `StTextField` | New: `LanternTextField` | Forms (auth, child setup, voice consent). **New component.** |
| `StToggle` | New: `LanternToggle` | Privacy screen's diagnostics toggle. **New component**, low usage — may not be worth a dedicated component for one call site; consider inlining. |
| `StSegment` | New: `LanternSegment` | Child setup's age-band picker. **New component.** |
| `StChip` | New: `LanternChip` | Family-voice status pills. **New component**, small. |
| `StErrorView` | — | Reuse structurally, re-skin |
| Bespoke keypad in `PinGateScreen`/`ChangePinScreen` | New: shared `LanternKeypad` | These two screens are near-duplicates today (inventory flagged this) — **migrating is the moment to deduplicate them into one shared widget**, not just retint two copies. |
| `PixelSprite` (ambient mascots) | **Unchanged** | Sprites aren't part of the color system — they render on any background per their own palette. No Lantern equivalent needed. |
| `StScenePlayer` / read-along highlighting (`StoryPlayerScreen`) | **Unchanged mechanism, re-skinned colors** | The synced-highlight logic (`2026-06-30-real-voices-and-read-along-sync-design.md`) is untouched; only the container's gradient/text colors move to Lantern tokens. |

## 5. Open questions — resolved during Batch 1

1. ~~Does `GlowButton` need `dark`/`ghost`/`line`/`soft` variants...~~ **Resolved:** separate component, `LanternOutlineButton` (see §4). `GlowButton` keeps its single-purpose contract (no disabled state, no variants — it's *the* primary CTA).
2. `LanternRow` and `LanternActionTile` are the two highest-leverage new components (used across 8+ screens combined) — build these first, before touching individual screens, the same way Lantern's Composer-specific widgets were built before the Composer screen itself. (Done — Foundation task 3.)
3. `StTile`/`StRow`'s existing internals already read `AppRadius`/`AppShadows`/`AppSpacing` correctly — the new Lantern versions should copy that shape logic exactly and only change color sourcing. Don't redesign spacing/shape while migrating color.
4. **New, surfaced during Batch 1:** any shared `St*` widget that reads `StorytimeTokens.ink`/`.ink2`/`.ink3`/`.cream`/`.paper`/`.line`/`.line2` directly (not the mode-aware `textPrimary`/`textSecondary`/`textTertiary` slots) is *not* safely reusable as-is on the dark root theme — those fields are identical across day/bedtime, so such a widget always renders its old cream-appropriate colors. Confirmed affected (grepped in `lib/ui/widgets/storytime/`): `StRow`, `StTile`, `StButton` (`dark`/`ghost`/`soft` variants only — `ember`/`line` are fine), `StChoiceCard`, `StSegment`, `StToggle`, `StTextField`, `StChips`, `StTabBar`, `StHint`, `StParentGate`, `StVoiceCapture`, `StScenePlayer`, `StSectionHeader`. Each future batch should check this list before assuming "reuse structurally, re-skin colors" is actually possible for a given `St*` widget — if it's on this list, build (or reuse, once one exists) a `Lantern*` replacement instead of patching the shared widget mid-migration.

## 6. Batch sequencing

Directly from the inventory's complexity ranking (cheapest/most-token-compliant first). Each batch is independently shippable (the app is mid-migration-safe at every point since the OLD `StorytimeTokens`/`AppColors` values still resolve to *something* even if visually inconsistent with already-migrated screens — this is a progressive rollout, not a big-bang cutover).

- **Foundation** (blocks all batches): root theme cutover (§2), concept-icon outline recolor (§3), build `LanternRow` + `LanternActionTile` (§4/§5).
- **Batch 1 — cheapest, static screens:** `ParentAccessScreen`, `StorytimeAccountScreen`, `StorytimePrivacyScreen`, `StorytimeParentDashboard`, `StorytimeWelcomeScreen`, `StoryEndScreen`, `VoiceCaptureIntroScreen`, `VoiceReadyScreen`.
- **Batch 2 — simple forms (done):** `ChildSetupScreen`, `StorytimeAuthScreen`, `AddAudioCaptureScreen`, `AddAudioDetailsScreen`, `VoiceUploadScreen`. Also needed (and built) `LanternChoiceCard`, not anticipated at spec time — see §4. `AudioRecorderWidget` (embedded in `AddAudioCaptureScreen`) deliberately left unmigrated — separately shared, another consumer (`parent_edit_screen.dart`) not yet in any batch.
- **Batch 3 — lists with state (done):** `FamilyVoicesScreen`, `VoiceConsentScreen`. Built `LanternChip` — fixes a real `StChip` bug (hardcoded, non-overridable text color) by deriving both fill tint and text color from one semantic `hue` param, not just a token-source swap. `GuidedCaptureScreen` (same file, also uses `StChip`) confirmed untouched — deferred to Batch 6.
- **Batch 4 — adaptive/content-heavy (done):** `StorytimeHomeScreen`, `StoryLibraryScreen`, `_ResumeStrip`. Built `LanternScreenHeader` (structural wrapper, mirrors `StScreenHeader`) and extended `LanternSectionHeader` with `eyebrow`/`largeTitle` — retroactively closing the eyebrow gap two earlier batches had worked around inline (`VoiceCaptureIntroScreen`, `VoiceConsentScreen`, both cleaned up to use the real param).
- **Batch 5 — bedtime-state-machine screens (done):** `StoryGeneratingScreen`, `AgeGateScreen`. Chrome-only re-skin — neither screen's async job-status/cooldown-timer logic was touched (zero test coverage on either, so this was verified via manual diff/hunk-boundary review, not automated tests). Fixed `GlowButton` to support a nullable `onTap` (dims + `Semantics(enabled: false)`) after `AgeGateScreen`'s cooldown-disabled "Continue" button exposed the same accessibility gap `LanternOutlineButton` had in Batch 2 — its "no disabled state" design was correct for the Composer's always-live CTA but didn't hold once reused for a genuinely-sometimes-disabled primary action.
- **Batch 6 — keypad + hybrid-dark:** `PinGateScreen`, `ChangePinScreen` (dedupe into `LanternKeypad`), `GuidedCaptureScreen` (drop its manual dark-paint hack — root theme now does it).
- **Batch 7 — heaviest:** `StorytimeLaunchScreen` (async orchestration, low visual risk), `StoryPlayerScreen` (highest complexity, do last, most to lose if rushed).

Each batch: migrate the listed screens' color/token sourcing to Lantern (§3/§4), verify with `flutter analyze` + existing widget tests + a full-suite regression run, no behavior changes unless explicitly noted (e.g. `PinGateScreen`/`ChangePinScreen` dedup, `GuidedCaptureScreen` hack removal).

## 7. Explicitly out of scope

- No copy changes, no new features, no navigation changes — this is a re-skin.
- No change to `StoryPlayerScreen`'s read-along sync mechanism, `StoryGeneratingScreen`'s job-status state machine, or any backend contract.
- Deleting the dead v1 screen family (`KidHomeScreen` et al.) — unrelated cleanup, not part of this rollout.
- `PinGateScreen`/`ChangePinScreen` deduplication is in-scope for *this* migration (Batch 6) since it's cheap to do while already touching both, but no other refactors should piggyback on token-migration PRs.
