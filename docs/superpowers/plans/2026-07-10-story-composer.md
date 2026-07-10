# Story Composer Implementation Plan

**Goal:** Replace the five-step `/make/:step` wizard and the `/review` screen with a single narrator-first Composer screen at `/compose`, rendered in a new from-scratch "Lantern" dark-first visual language, so the happy path from Home to a playing story is two taps. No changes to the story data model, the generation backend, or the family-voice add flow.

**Architecture:** Introduce a `LanternTokens` `ThemeExtension` alongside the existing `StorytimeTokens` and build the Composer + its three new widgets against it, leaving all other screens on the current tokens (screen-by-screen migration later, no big-bang restyle). The Composer is a pure re-skin over the existing `storyDraftProvider` / `StoryDraftNotifier` — `StoryDraft`, `resolvedNarratorKey`, and `toRequestJson()` are untouched, so `isComplete` remains the `/generate` guard and the backend contract is unchanged. Old make-flow routes redirect to `/compose` for one release, then get deleted.

**Tech Stack:** Flutter, Riverpod, `go_router`, `google_fonts` (Baloo 2 + Figtree), `just_audio` (existing `NarratorPreviewService`), `flutter_tts` (existing `AudioLabelService`).

**Spec:** `docs/superpowers/specs/2026-07-10-story-composer-design.md`

**Out of scope:** billing/entitlements (family voices stay ungated for testing), the voice-invite flow (separate spec), any change to `/parent/family-voices/**`, and migrating other screens to Lantern.

---

## File Map

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `app/lib/theme/lantern_tokens.dart` | `LanternTokens` ThemeExtension — night/lantern/moon/hush + concept hues, day+night variants |
| Modify | `app/lib/theme/app_theme.dart` | Register `LanternTokens` on both ThemeData variants |
| Create | `app/lib/ui/widgets/lantern/glow_button.dart` | `GlowButton` — primary CTA, always-live, lantern gradient |
| Create | `app/lib/ui/widgets/lantern/voice_card.dart` | `VoiceCard` — built-in / family / processing variants + preview |
| Create | `app/lib/ui/widgets/lantern/story_slot.dart` | `StorySlot` — 2×2 grid card, suggestion vs chosen state |
| Create | `app/lib/ui/widgets/lantern/shuffle_chip.dart` | `ShuffleChip` — spin-on-tap pill |
| Create | `app/lib/ui/widgets/lantern/voice_teaser.dart` | `VoiceTeaser` — non-interactive empty-state line |
| Create | `app/lib/ui/widgets/lantern/lantern.dart` | Barrel export for the above |
| Create | `app/lib/ui/story_composer_screen.dart` | `StoryComposerScreen` at `/compose` — shelf + slots + CTA |
| Create | `app/lib/ui/story_slot_sheet.dart` | `StorySlotSheet` — modal bottom sheet option picker |
| Modify | `app/lib/router.dart` | Add `/compose`; redirect `/make/:step` + `/review`; update Home tile target |
| Modify | `app/lib/providers/storytime_providers.dart` | Add `lastNarratorProvider` (persisted default narrator) |
| Modify | `app/lib/providers/storytime_providers.dart` | Add a `shuffleDraft()` helper on `StoryDraftNotifier` (or a free function) |
| Modify | `app/lib/services/key_value_store.dart` | Add `last_narrator_key` read/write |
| Delete (Phase F) | `app/lib/ui/storytime_screens.dart` → `StoryReviewScreen`, `StoryWizardScreen`, `_NarratorRow`, `_WizardChoice` | Remove superseded wizard/review after redirects bake |
| Create | `app/assets/storytime/concept_glyphs/*` (re-export) | Concept SVGs with night-legible `#241F3D` outline (build-time, no redraw) |
| Create | `app/lib/ui/widgets/lantern/family_voice_glyph.dart` | New lantern-lit profile SVG for family voices (replaces 🎙) |
| Test | `app/test/story_composer_test.dart` | Widget + interaction tests (see Task 9) |

---

## Task 1: Lantern design tokens

**Files:**
- Create: `app/lib/theme/lantern_tokens.dart`
- Modify: `app/lib/theme/app_theme.dart`

Define `LanternTokens extends ThemeExtension<LanternTokens>` with the spec §4.2 palette as fields:
- Grounds: `nightDeep #141227`, `nightMid #211E3F`, `nightCard #2B2750`.
- Accent: `lantern #FFB566`, `lanternDeep #E8834A`.
- Text: `moon #FFF3DC`, `moonDim #C9C2E0`, `moonFaint #8B84AD`.
- Lines: `hush #3A3566`.
- Concept hues: `hueSun #FFD479`, `hueSky #7FB5F0`, `hueBlossom #F2A7C3`, `hueLilac #B9A5F5`, `hueMeadow #7ED4A6`, `hueCoral #FF8E7A`.
- Gradients: `ctaGradient` (`lantern → lanternDeep`, horizontal), `nightGradient` (`nightMid → nightDeep`, top→bottom).
- Convenience: `slotHueFor(SlotKind)` and `slotFillFor(SlotKind)` (hue at 0.24 on night / 1.0 on day).

Provide a `.night()` factory (primary) and `.day()` factory (parent-zone / future toggle). Implement `copyWith` and `lerp`. Register both on the matching `ThemeData` via `extensions: [...]` in `app_theme.dart` — night is the default for the kid flow.

**Notes:**
- Do **not** touch `StorytimeTokens`; the two coexist. The Composer reads only `Theme.of(context).extension<LanternTokens>()!`.
- CTA text color is `nightDeep` on the lantern gradient (white fails AA on the light end — same rationale as the existing `onAccent = night1`).

**Acceptance:**
- `flutter analyze` clean; `LanternTokens` resolvable from a widget under the app theme.
- Contrast check (manual or golden): `moon` on `nightDeep` ≥ 4.5:1; body text is never set in `lantern`.

---

## Task 2: Lantern primitive widgets

**Files:**
- Create: `app/lib/ui/widgets/lantern/glow_button.dart`, `voice_card.dart`, `story_slot.dart`, `shuffle_chip.dart`, `voice_teaser.dart`, `family_voice_glyph.dart`, `lantern.dart` (barrel)

Build each per spec §4.5. Keep them dumb/stateless where possible; state lives in the screen.

- **GlowButton:** full-width, 56 (compact) / 64 (≥720) tall via `AppResponsive.buttonSize`, `ctaGradient`, `nightDeep` label in Baloo 2, radius 999, lantern glow shadow, `AnimatedScale` 0.97 on press. **No disabled visual** — assert `onTap != null` in the kid flow. `Semantics(button: true, excludeSemantics: true)`.
- **VoiceCard:** props `{name, subline, glyph, variant (builtin|family|processing), selected, onTap, onPreview, previewPlaying}`. 108×148 (compact) / 128×160 (≥720). Selected → 2.5px `lantern` ring + glow + 22px check badge. Processing → shimmer over the glyph well, "Getting ready…", 60% opacity, `Semantics(enabled: false)`, non-tappable. `Semantics(button, selected, excludeSemantics: variant != builtin)` — keep child semantics for built-ins so the nested preview button stays reachable (mirror the current `_NarratorRow` convention).
- **StorySlot:** props `{kind, label, valueName, glyph, suggested, onTap}`. Aspect 1.15, hue fill @ 24%, glyph 56, uppercase label + Baloo value. `suggested` → 85% opacity + ⟳ mark. No selection ring (that vocabulary belongs to voices only). `Semantics(button, label: "$label, $valueName", excludeSemantics: true)`.
- **ShuffleChip:** pill, `nightCard` fill, `hush` border, ⟳ + "Shuffle", 44pt min, icon rotates 360° on tap.
- **VoiceTeaser:** a single non-interactive line, Body 14 `moonFaint`, lock glyph + "Grown-ups can add your family's voices in Settings." No tap target. Copy string pulled from a `LanternCopy` const so it can match the parent-zone label (spec §7 open q4).
- **FamilyVoiceGlyph:** inline SVG (48 viewBox, single outline + 2 fills), lantern-lit profile + sound-wave arc. Replaces the 🎙 emoji everywhere a family voice renders.

**Notes:**
- Concept glyphs keep the **seamless-surface rule**: glyph on transparent bg, host card supplies the tint. Re-export the existing 30-piece SVG set with outline `#241F3D` (a one-variable change at export, not a redraw). If a re-export pipeline doesn't exist yet, override the outline color at render via `ColorFilter`/string-replace on the existing `concept_icons.dart` strings — cheaper than new assets.

**Acceptance:**
- Each widget renders in `/dev/gallery` (add a Lantern section) in isolation.
- Reduced-motion: press/spin/shimmer degrade to no-motion; states still distinguishable by shape/ring/badge, never motion or color alone.

---

## Task 3: Persisted default narrator

**Files:**
- Modify: `app/lib/services/key_value_store.dart`
- Modify: `app/lib/providers/storytime_providers.dart`

- Add `last_narrator_key` (String) to `KeyValueStore` — same string format as `StoryDraft.resolvedNarratorKey` (`family:<id>` or a `NarratorKey.name`).
- Add `lastNarratorProvider` that reads it; write it whenever the Composer confirms a narrator selection.
- **Default-selection resolution order** (spec §2.2): persisted `last_narrator_key` if still valid → else first *ready* family voice → else `NarratorKey.wizardWally`. A persisted family voice that no longer exists (deleted) falls through to the next rule.

**Acceptance:**
- Picking Grandma, backing out, re-entering `/compose` → Grandma pre-selected.
- Deleting that voice in the parent zone, re-entering → falls back to next ready voice or Wally, no crash.

---

## Task 4: Shuffle logic

**Files:**
- Modify: `app/lib/providers/storytime_providers.dart`

- Add `shuffleAll()` and `shuffleSlot(SlotKind)` to `StoryDraftNotifier` (or free functions operating on the notifier).
- Uniform random pick per slot from the enum `.values`; **guarantee a different value than current** (re-roll on collision when `.values.length > 1`).
- Shuffle **never** writes narrator/`familyVoiceId`.
- Compose a single TTS sentence for a full shuffle: `"A story about {character}, {scene}!"` (spec §3.3) — return it so the screen can hand it to `AudioLabelService.speak`.

**Acceptance:**
- Unit test: `shuffleAll()` changes all four concept fields, leaves narrator untouched, and never repeats the prior value for a given slot across 100 iterations.

---

## Task 5: The Composer screen

**Files:**
- Create: `app/lib/ui/story_composer_screen.dart`

`StoryComposerScreen` (ConsumerStatefulWidget) at `/compose`. Layout top→bottom (spec §2.2):
1. Header: back → `/home`, title "Tonight's story", no dots.
2. Section label "Who's reading tonight?" → **Voice Shelf** (horizontal `ListView`): ready family voices first (newest first) → processing family voices → three built-ins. **No add control.** When `familyVoices` is empty (none ready or processing), append a `VoiceTeaser` after the built-ins; remove it the instant any family voice exists.
3. Section label "The story" + `ShuffleChip` (global) → **2×2 slot grid** (`GridView`, `AppResponsive` gutters).
4. `GlowButton` "Tell tonight's story" → `context.go('/generate')`.

Wiring:
- Watch `storyDraftProvider`, `familyVoicesProvider` (filter ready + processing), `narratorPreviewServiceProvider`, `lastNarratorProvider`.
- On first build, if the draft is empty (fresh entry), the Home tile already reset+shuffled (Task 7); the screen just resolves the default narrator (Task 3) and persists it.
- Voice tap → `setNarrator`/`setFamilyVoice`, write `last_narrator_key`, `AudioLabelService.speak(name)`. Preview tap → `NarratorPreviewService.play` (built-ins only). Selecting does **not** auto-play preview.
- Slot tap → open `StorySlotSheet` (Task 6). Global shuffle → Task 4 + staggered flip (60ms apart) + speak the composed sentence.
- CTA is always live (no disabled path).
- a11y order: shelf fully traversable **before** slots (narrator-first applies to screen-reader order too).

**Notes:**
- Use `AppResponsive` tokens exclusively (breakpoints 480/720/1024) — do **not** carry over the old inline `width > 760` check. This screen is the first to normalize the make-flow onto the token system.
- Motion per spec §4.6; gate every animation on `MediaQuery.disableAnimations` / `prefers-reduced-motion`.

**Acceptance:**
- From a fresh entry, all four slots are pre-filled and a narrator is selected — CTA works with zero further taps.
- Family voice appears first and is default-selected when ready + previously used.
- Processing voice shows "Getting ready…", is non-tappable, announced unavailable.
- Empty-state teaser shows only at zero family voices, exposes no tap target, disappears once one exists.

---

## Task 6: Slot sheet

**Files:**
- Create: `app/lib/ui/story_slot_sheet.dart`

`showModalBottomSheet` (drag-dismiss, ~65% height, Lantern-grounded, radius 32 top). Contents (spec §2.3):
- Title = the slot question ("Who is our hero?" etc.).
- Per-slot `ShuffleChip` in the header.
- 6 options as square tiles — 2/row (<720) or 3/row (≥720) — glyph seamless on hue @ 40% fill; current value ringed + check badge.
- Select → haptic tick, `AudioLabelService.speak(label)`, auto-dismiss after 250ms so the slot updates visibly behind the sheet; then flip-animate the slot.
- No confirm button; selection is confirmation. Per-slot shuffle re-rolls one slot and dismisses.

**Acceptance:**
- Select → sheet dismisses → slot flips to new value → TTS speaks label → slot promoted from suggestion to chosen (full opacity, ⟳ gone).

---

## Task 7: Routing + Home entry

**Files:**
- Modify: `app/lib/router.dart`

- Add `GoRoute('/compose')` → `StoryComposerScreen`. Wrap `/generate` transition unchanged.
- **Redirects (one release):** `/make/:step` and `/review` → `redirect` to `/compose` (preserve deep links / resume). Keep `StoryDraft` session behavior: fresh entry from Home resets + shuffles; in-session re-entry keeps the draft.
- Home "Make a Story" tile: `storyDraftProvider.notifier.reset()` → `shuffleAll()` → `context.go('/compose')` (was `/make/character`).
- Leave the `onEnter`/`_protectAdultRoute` parent-gate logic alone — the Composer is not under `/parent`.

**Acceptance:**
- `/make/character`, `/make/narrator`, `/review` all land on `/compose`.
- Home tile → Composer with slots pre-shuffled.

---

## Task 8: Delete superseded wizard (Phase F — after redirects bake)

**Files:**
- Modify: `app/lib/ui/storytime_screens.dart`

Once the redirects have shipped one release and no deep links hit the old paths:
- Delete `StoryWizardScreen`, `StoryReviewScreen`, `_NarratorRow`, `_WizardChoice`, and their private helpers.
- Remove the redirects; `/make` and `/review` become 404 → catch-all to `/home`.
- Keep `StDots` (may serve a future genuinely-stepped flow) but drop its make-flow usage.

**Acceptance:**
- App compiles with the wizard removed; no dangling references (`grep` for `StoryWizardScreen`, `StoryReviewScreen`, `_NarratorRow`).
- Net LOC negative vs. pre-Composer.

---

## Task 9: Tests

**Files:**
- Create: `app/test/story_composer_test.dart`

Cover:
- Default narrator resolution (persisted → ready family → Wally) incl. the deleted-voice fallback.
- `shuffleAll` changes all four slots, never repeats a value, never touches narrator.
- Composer renders shelf-before-slots in the semantics tree.
- Processing voice is non-tappable and announced unavailable.
- Empty-state teaser visibility toggles on family-voice presence and exposes no button semantics.
- Slot sheet select updates the draft and dismisses.
- `toRequestJson()` output is byte-identical before/after for the same selections (backend-contract guard).

**Notes:** the 9 pre-existing failing tests on a clean checkout are unrelated — don't chase them; assert only the new suite passes.

---

## Build order / phasing

- **Phase A — foundation:** Task 1 (tokens) → Task 2 (widgets in `/dev/gallery`). No routing changes yet; nothing user-visible.
- **Phase B — logic:** Task 3 (default narrator) + Task 4 (shuffle). Pure providers, unit-tested.
- **Phase C — screen:** Task 5 (Composer) + Task 6 (slot sheet), reachable via a temporary `/compose` link from `/dev/gallery`.
- **Phase D — cutover:** Task 7 (routing + Home tile + redirects). Ship. The old wizard is now unreachable but still in the tree.
- **Phase E — verify:** Task 9 tests green; drive the flow on device (Home → Composer → generate → player) per the `verify` skill.
- **Phase F — cleanup:** Task 8, one release after cutover.

Phases A–E are one PR/branch; Phase F is a separate follow-up PR so the redirect safety net lives for a release.

---

## Risks / watch-items

- **Concept-glyph outline recolor:** if there's no SVG re-export pipeline, do the `#241F3D` outline swap at render time on the existing `concept_icons.dart` strings rather than shipping 30 new assets. Confirm which is cheaper before Task 2.
- **`flutter_tts` liveness:** the spec leans on `AudioLabelService`; codebase research flagged `flutter_tts` as possibly-orphaned. Verify it actually speaks on a device early in Phase B — if it's dead, the read-aloud is a no-op and needs a fix or a scope note.
- **`google_fonts` at runtime vs bundled:** Baloo 2 + Figtree fetched on first run need a network fallback; consider bundling the two faces as assets to avoid a flash of fallback at bedtime (dim-room, offline-ish contexts).
- **Responsive normalization:** the Composer is the first make-flow screen on `AppResponsive`; keep the change scoped to this screen — don't refactor Home's `680` check in the same PR.
