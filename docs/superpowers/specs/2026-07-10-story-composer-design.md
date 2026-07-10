# Story Composer — Wizard Compression & Visual Redesign

**Date:** 2026-07-10
**Status:** Proposed
**Supersedes:** the 5-step `/make/:step` wizard + `/review` screen, and (visually) DESIGN.md for the make-flow
**Out of scope:** billing/entitlements (family voices stay ungated for testing), the remote voice-invite flow (next spec — this design reserves its affordances), generation backend changes

---

## 1. Why

The current make-flow is five sequential full-screen steps (Character → Scene → Theme → Plot → Narrator) plus a review screen: **six screens and a minimum of six taps** before anything happens. Post-pivot, the product's differentiator is *whose voice reads the story*, not the plot combinatorics — yet the narrator is the *last* step, and family voices are buried at the bottom of it.

Goals, in priority order:

1. **Narrator first.** The voice choice opens the flow and is the emotional headline of the screen.
2. **One screen.** Composing a story is a single screen ("the Composer"); the review screen is eliminated because the Composer *is* the review.
3. **Zero-to-two decisions on a typical night.** Story slots arrive pre-shuffled; narrator defaults to last-used. The happy path is one tap.
4. **Reserve the "Add a voice" seam** for the upcoming voice-invite flow without building it.

Non-goals: changing `StoryDraft`, the request contract (`{character, scene, theme, plot, narratorKey}`), quotas, or generation UX beyond restyling.

---

## 2. Flow

### 2.1 Before → after

```
BEFORE  /make/character → /make/scene → /make/theme → /make/plot → /make/narrator → /review → /generate
AFTER   /compose ──────────────────────────────────────────────────────────────────────────→ /generate
```

- `/compose` replaces `/make/:step` and `/review`. Old routes 301-redirect to `/compose` (deep links, resume state).
- Home's "Make a Story" tile: `storyDraftProvider.reset()` → **shuffle all four story slots** → `context.go('/compose')`.
- `/generate` is unchanged functionally; it inherits the new visual language (§5).

### 2.2 The Composer screen, top to bottom

```
┌──────────────────────────────────────┐
│ ←   Tonight's story                  │  header
│                                      │
│ WHO'S READING TONIGHT?               │  section label
│ ┌────┐ ┌────┐ ┌────┐ ┌────┐          │
│ │Dad │ │Wally│ │Fern│ │Ray │         │  Voice Shelf (horizontal)
│ └────┘ └────┘ └────┘ └────┘          │
│  (if no family voice yet:)           │
│  Grown-ups can add voices in Settings│  quiet, non-interactive teaser
│                                      │
│ THE STORY                    ⟳ Shuffle │
│ ┌─────────┐ ┌─────────┐              │
│ │ 🦁 Hero │ │ 🏰 Where │              │  Story Slots (2×2)
│ ├─────────┤ ├─────────┤              │
│ │ 💛 About│ │ ✨ What  │              │
│ └─────────┘ └─────────┘              │
│                                      │
│ ┌──────────────────────────────────┐ │
│ │      ✦  Tell tonight's story     │ │  CTA
│ └──────────────────────────────────┘ │
└──────────────────────────────────────┘
```

**Header.** Back returns to `/home`. Title "Tonight's story". No step dots — there are no steps.

**Voice Shelf.** A horizontally scrolling row of Voice Cards, order: **ready family voices first** (newest first), then the three built-ins.
- Family voice card: portrait-shaped card, warm glyph (🎙 replaced by a custom lantern-lit face silhouette, see §4.6), name, relationship as the sub-line. Preview button once family previews exist; until then, none (matches current capability).
- Built-in card: character glyph, name, one-word personality ("Playful" / "Gentle" / "Silly"), 44 pt preview control playing the existing preview `.wav` assets via `NarratorPreviewService`.
- A voice **in processing** (`consented/queued/cloning`) shows as a shimmering "Getting ready…" card, non-selectable. (Today these are invisible; surfacing them rewards the parent for starting a clone.)
- **No "add a voice" control lives on this screen.** The Composer is a child-facing play surface; adding a voice is a parent administrative action (recording, biometric consent, later the paid tier) and belongs in adult contexts — see §2.2.1. Putting a PIN-gated control on a kid screen presents an affordance children can't use and risks ambushing them with a keypad mid-story.
- **Empty-state teaser (only when zero family voices exist):** a quiet, **non-interactive** line sits after the built-in cards — *"Grown-ups can add your family's voices in Settings."* It plants the pivot's core intent ("this could be *your* voice") at the highest-intent moment — a parent choosing a narrator with their child — without being a button. It disappears permanently once any family voice exists (ready or processing).
- **Default selection:** last-used narrator (persist `last_narrator_key` in `KeyValueStore`); first launch defaults to the first family voice if one is ready, else Wizard Wally.

#### 2.2.1 Where voices are actually added

Voice creation has exactly two entry points, both in calm adult contexts, neither on a kid screen:

1. **Onboarding** — the "Whose voice reads the stories?" step (post child-setup, pre first story). The single best first-voice conversion moment.
2. **Parent dashboard** — `/parent/family-voices`, reached through the existing age-check → PIN gate. Manage, add, and (later) the remote-invite flow live here.

The upcoming **voice-invite spec** claims these two entry points, plus a third that never touches the app's kid surface or PIN at all: a **remote web invite** a parent sends to a relative (e.g., a grandparent without the app), who records via a link with its own auth. The Composer intentionally has no seam into any of these — the empty-state teaser only points a parent toward Settings.

**Story Slots.** A 2×2 grid of slots labelled in kid language — **Hero** (character), **Where** (scene), **About** (theme), **What happens** (plot). Each slot shows the selected concept's glyph + label on its concept tint.
- Slots arrive **pre-filled by shuffle** (see §3.1). A pre-filled-but-untouched slot renders at 85% opacity with a small ⟳ mark, signalling "suggestion — tap to make it yours"; any interaction (tap-select in the sheet, or per-slot shuffle) promotes it to full opacity.
- Tapping a slot opens the **Slot Sheet** (§2.3).
- The **Shuffle** control re-rolls all four slots with a staggered flip animation (§5.3). It never changes the narrator.

**CTA.** "Tell tonight's story" — full-width, always enabled (slots are always filled by shuffle; the narrator always has a default). Tap → `/generate` with the existing `createStoryJob` call. Because nothing can be un-filled, **the disabled-button state is eliminated from this flow entirely.**

### 2.3 The Slot Sheet

Tapping a slot opens a modal bottom sheet (drag-dismissable, ~65% height):

- Title = the slot question in the current copy voice: "Who is our hero?" / "Where does it happen?" / "What is it about?" / "What happens?"
- The 6 options as large square tiles (2 per row on phones, 3 on ≥720 px), concept glyph seamless on its tint, current selection ringed.
- A per-slot **shuffle chip** in the sheet header.
- Selecting a tile: haptic tick, TTS reads the label aloud (keep `AudioLabelService.speak` — it serves pre-readers), sheet auto-dismisses after 250 ms so the child sees the slot update behind it.
- No confirm button. Selection is the confirmation.

### 2.4 What is deleted

- `StoryReviewScreen` and the `/review` route.
- `StDots` usage in the make-flow (component stays for any future genuinely-stepped flow).
- The pinned Continue button and its disabled state.
- The narrator step's vertical list (`_NarratorRow`) — replaced by Voice Cards.
- Any "add a voice" affordance on the make-flow — the Composer never links to voice creation (see §2.2.1). No `addVoiceEntryPoint` callback is introduced.

---

## 3. Interaction rules

### 3.1 Shuffle semantics

- On entry, all four slots are filled by uniform random pick. **Re-entering `/compose` within the same app session keeps the draft** (the existing `storyDraftProvider` behavior); a fresh entry from Home resets and re-shuffles.
- Global shuffle re-rolls all four slots; per-slot shuffle (in the sheet) re-rolls one. Both guarantee a *different* value than the current one (re-roll on collision).
- Shuffle **never** touches the narrator. The voice is a deliberate choice; the plot is a toy.

### 3.2 Narrator preview

- One preview plays at a time (existing `NarratorPreviewService` semantics). Starting a preview while another plays crossfades within 150 ms.
- Selecting a voice does **not** auto-play its preview (bedtime context; unexpected audio is hostile). The preview affordance is explicit.

### 3.3 Read-aloud

Every selection event (voice, slot value, shuffle result) speaks its label via TTS. Shuffle speaks a single composed sentence: *"A story about a brave lion, in space!"* — not four separate utterances.

### 3.4 State & model

No changes to `StoryDraft`, `StoryDraftNotifier`, `resolvedNarratorKey`, or `toRequestJson()`. The Composer is a pure re-skin over the existing provider. `isComplete` remains the `/generate` guard but is now always true on entry by construction.

---

## 4. Style guide — "Lantern"

A from-scratch visual language for the make-flow and, progressively, the rest of the kid-facing app. The metaphor: **a lantern lit in a dark room**. The app is used at bedtime, in dim rooms, on a device a parent is holding next to a child — so the design is **dark-first**: the night ground is the primary theme, and the light ("Daylight") variant is the secondary derivation, not the other way around.

### 4.1 Principles

1. **Warm light on deep night.** Everything glows; nothing glares. No pure white, no pure black, no cold greys.
2. **The voice is the jewel.** The strongest visual emphasis on any screen belongs to the selected voice. Concept slots are colorful but secondary.
3. **Soft geometry.** Generous radii, squishy press states, nothing sharp. The UI should feel like felt toys, not glass.
4. **Calm by default, delight on action.** Ambient screens are still; motion happens only as a *response* to the child's touch.

### 4.2 Color

| Token | Hex | Role |
|---|---|---|
| `night.deep` | `#141227` | Screen ground (bottom of gradient) |
| `night.mid` | `#211E3F` | Screen ground (top of gradient), sheet ground |
| `night.card` | `#2B2750` | Card / surface fill on night |
| `lantern` | `#FFB566` | Primary accent — CTA, selection rings, glow |
| `lantern.deep` | `#E8834A` | Accent gradient end, pressed states |
| `moon` | `#FFF3DC` | Primary text on night |
| `moon.dim` | `#C9C2E0` | Secondary text on night (70 % equivalent, pre-mixed) |
| `moon.faint` | `#8B84AD` | Tertiary text, disabled |
| `hush` | `#3A3566` | Hairlines, dividers, inactive tracks |

**Concept hues** (slot tints — used as *fills behind glyphs*, never as text):

| Token | Hex | Assigned to |
|---|---|---|
| `hue.sun` | `#FFD479` | Hero slot |
| `hue.sky` | `#7FB5F0` | Where slot |
| `hue.blossom` | `#F2A7C3` | About slot |
| `hue.lilac` | `#B9A5F5` | What-happens slot |
| `hue.meadow` | `#7ED4A6` | Success / ready states |
| `hue.coral` | `#FF8E7A` | Errors / destructive |

On the night ground, concept hues are used at **24 % opacity as slot card fills** with the full-strength hue reserved for the glyph itself — this keeps the screen dim-room-friendly while the glyphs stay saturated. In the Slot Sheet (a brighter, focused context) tiles use a 40 % fill.

**Daylight theme** (parent-zone screens, and an eventual user toggle): ground `#FDF7EC`, card `#FFFFFF`, text `#2A2440` / `#5E5877` / `#A29BC0`, hairline `#EBE3D6`. `lantern` and the hues are shared across both themes; on Daylight, hue fills run at 100 %. Contrast requirement: all text-on-ground pairs ≥ 4.5:1, glyph-bearing fills ≥ 3:1 against their ground — `lantern` on `night.deep` passes for large text/icons only, so **body text is never set in `lantern`**; accent-colored text uses `moon` on a `lantern`-tinted chip instead.

### 4.3 Typography

| Role | Face | Size / weight | Usage |
|---|---|---|---|
| Display | **Baloo 2** | 30 / 700 | Screen titles ("Tonight's story") |
| Title | Baloo 2 | 20 / 700 | Sheet titles, card names |
| Section label | **Figtree** | 13 / 700, +1.4 tracking, uppercase, `moon.dim` | "WHO'S READING TONIGHT?" |
| Body | Figtree | 16 / 500 | Descriptions, sub-lines |
| Chip / button | Figtree | 15 / 600 | CTAs, chips, preview buttons |
| Story text | Baloo 2 | 19 / 500, line-height 1.8 | Read-along body (player) |

Both faces ship via `google_fonts`. Baloo 2 is round, chunky, and legible at bedtime brightness; Figtree is its quiet workhorse. Numerals in any counter use tabular figures. Minimum body size anywhere in the kid flow: 15.

### 4.4 Shape, space, depth

- **Radius:** card 20, sheet 32 (top corners), chip/pill 999, slot glyph well 16.
- **Spacing scale:** 4 / 8 / 12 / 16 / 24 / 32 / 48. Screen gutter 20 (phones), 32 (≥720 px).
- **Depth = glow, not shadow.** On the night ground, elevation is expressed as a soft `lantern` glow: selected/primary elements get `lantern @ 22 %, blur 28, y+6`. Neutral cards get no shadow at all — they separate by fill (`night.card` on `night.mid`). Drop shadows exist only in the Daylight theme (`#2A2440 @ 8 %, blur 16, y+4`).

### 4.5 Components

**GlowButton** (primary CTA). Full-width, 56 pt tall (64 on ≥720 px), `lantern → lantern.deep` horizontal gradient, text in `night.deep` (dark-on-light passes AA; white does not), radius 999, lantern glow. Press: scale 0.97 + glow tightens, 120 ms. There is no disabled visual in the kid flow — flows are designed so the CTA is always live.

**VoiceCard.** 112×140 pt (compact) / 128×160 (≥720). Vertical: glyph well (72 pt, circular, concept-tinted for built-ins / `lantern @ 18 %` for family voices) → name (Title) → sub-line (Body, `moon.dim`) → preview pill when applicable. Selected: 2.5 pt `lantern` ring + glow + a `lantern` check badge, top-right, 22 pt. Unselected: `night.card` fill, `hush` 1 pt border. Processing variant: shimmer sweep over the glyph well, sub-line "Getting ready…", 60 % opacity, non-tappable, `Semantics(enabled: false)`.

**StorySlot.** Square-ish card (aspect 1.15), slot hue fill @ 24 %, glyph 56 pt centered-upper, slot label (Section label style, e.g. "HERO") above the value name (Title). Suggestion state: 85 % opacity + 16 pt ⟳ mark next to the value. Selected-by-child state: full opacity, no ring (slots are always "selected"; the ring vocabulary belongs to the voice shelf alone).

**SlotSheet tile.** Square, hue fill @ 40 %, glyph 64 pt, name below in Title 17. Current value: 2.5 pt `lantern` ring + check badge (same selection vocabulary as VoiceCard).

**ShuffleChip.** Pill, `night.card` fill, `hush` border, ⟳ icon + "Shuffle", 44 pt min height. Spins its icon 360° on tap (180 ms).

**VoiceTeaser** (empty-state only). A single line, not a card: Body 14 in `moon.faint`, left-aligned after the last built-in card in the shelf's scroll, no border, no fill, `Semantics(excludeSemantics: false)` but **not** a button — it exposes no tap target. Copy: "Grown-ups can add your family's voices in Settings." Rendered only when zero family voices exist; removed the instant one appears.

**Concept glyphs.** Keep the existing 30-piece inline-SVG set and the **seamless-surface rule**: glyphs render on transparent backgrounds and the host card supplies the tint — never a colored icon square inside a differently-colored card. Glyph outline color changes from warm brown to `#241F3D` (night-legible ink) — a one-variable re-export, not a redraw.

**Family-voice glyph (new).** A single new SVG: a soft lantern-lit profile silhouette with a small sound-wave arc, drawn in the existing icon grammar (48 viewBox, single outline + 2 fills). Replaces the 🎙 emoji everywhere a family voice appears.

### 4.6 Motion

| Event | Animation | Duration |
|---|---|---|
| Screen entry | Voice shelf slides in 12 pt + fades; slots pop in staggered 40 ms apart, scale 0.92→1 | 320 ms total |
| Slot shuffle | Card flips on Y axis; new glyph revealed mid-flip; global shuffle staggers 4 cards 60 ms apart | 280 ms/card |
| Selection | Ring draws + glow fades in | 160 ms ease-out |
| Sheet | Standard slide-up, drag-dismiss | 260 ms |
| CTA press → generate | The screen's ambient dims 10 % as the fade to `/generate` begins — the "lantern carried into the story" beat | 420 ms |

`prefers-reduced-motion`: flips become crossfades, staggers collapse to simultaneous, glow transitions become instant. Selection is **never** communicated by motion or color alone — the check badge and ring are always present.

### 4.7 Sound & haptics

- Selection: light haptic tick + TTS label (existing).
- Global shuffle: single soft "dice" haptic (medium impact) + the composed TTS sentence (§3.3). No sound effects — the only audio identity this app needs is voices.

### 4.8 Copy voice

Second person, present tense, spoken-aloud-friendly (everything may be read by TTS). Kid-flow words are concrete and warm: "Tell tonight's story", "Who's reading tonight?", "Shuffle". Banned in the kid flow: "generate", "AI", "content", "library", "settings", "error" (failures say what to do: "That didn't work — let's try again").

---

## 5. Engineering notes

- **One new screen** (`StoryComposerScreen` at `/compose`), one new sheet, three new widgets (VoiceCard, StorySlot, GlowButton) + ShuffleChip. Estimated net-negative LOC once the five-step scaffolding, `/review`, and `_NarratorRow` are deleted.
- **Routing:** `/make/:step` and `/review` redirect to `/compose` for one release, then delete.
- **Responsive:** the Composer uses `AppResponsive` tokens exclusively (breakpoints 480/720/1024) — this retires the make-flow's ad-hoc `width > 760` check and is the first step in normalizing the app's three competing breakpoint conventions.
- **Theming:** introduce the Lantern tokens as a new `ThemeExtension` (`LanternTokens`) alongside the existing `StorytimeTokens`; the Composer and Slot Sheet consume only `LanternTokens`. Other screens migrate screen-by-screen in follow-up batches — no big-bang restyle.
- **Persistence:** one new `KeyValueStore` key, `last_narrator_key` (string, same format as `resolvedNarratorKey`).
- **Accessibility:** carry over the established Semantics conventions — `Semantics(button, selected, excludeSemantics)` on cards with no inner interactive children; keep child semantics where a preview button nests inside a card. All tap targets ≥ 44 pt. Voice shelf is a horizontal list: ensure it is fully reachable by screen-reader swipe order *before* the slots (narrator-first applies to a11y order too).

## 6. Acceptance checklist

- [ ] Happy path from Home to a playing story = 2 taps (Make a Story → Tell tonight's story), narrator defaulted, slots pre-shuffled.
- [ ] Family voice appears first on the shelf and is selected by default when ready and previously used.
- [ ] Processing voice shows "Getting ready…" card; tapping does nothing; screen-reader announces it as unavailable.
- [ ] No add-a-voice control exists on the Composer; there is no PIN-gated tap target on this screen.
- [ ] Empty-state teaser line shows only when zero family voices exist, exposes no tap target, and disappears once any family voice exists.
- [ ] Slot Sheet select → auto-dismiss → slot updates with flip; TTS speaks the label.
- [ ] Global shuffle changes all four slots (never to their current value), speaks one composed sentence, never changes the narrator.
- [ ] `/make/character` deep link lands on `/compose`.
- [ ] Reduced-motion: no flips, no staggers; all states still distinguishable without motion/color.
- [ ] All text ≥ 4.5:1 on its ground in both themes; CTA text is `night.deep` on the lantern gradient.
- [ ] No regression to `toRequestJson()` payloads (backend contract untouched).

## 7. Open questions (for the voice-invite spec)

1. **Resolved:** voice creation does not surface on the Composer at all. Entry points are onboarding and the parent dashboard (§2.2.1); the Composer shows only a non-interactive empty-state teaser. The voice-invite spec owns the onboarding step, the dashboard flow, and the remote web invite.
2. Family-voice previews: generate a fixed preview line at clone time (one extra TTS call) so family voices get parity with built-ins on the shelf.
3. Should the shelf cap visible voices (e.g., 6) with a "See all" overflow into the parent zone?
4. Empty-state teaser copy points to "Settings" — confirm the parent-zone label the child-facing app uses for that destination so the wording matches (candidate: "the grown-up area").
