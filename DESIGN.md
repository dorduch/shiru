# Design

The Storytime visual system: a warm "storybook" world for kids 3–10 and their
parents. Source of truth in code: `app/lib/theme/` (`app_colors.dart`,
`app_typography.dart`, `app_theme.dart`), `app/lib/ui/concept_icons.dart`, and
the `St*` component library under `app/lib/ui/widgets/storytime/`.

## Color

Warm ember/cream, never pure black or white. Two themes: **day** (cream
surfaces, ink text) and **bedtime** (night-gradient, cream text).

Core tokens (`AppColors`):
- `ember #E2885A` — primary accent / selection ring
- `gold #E9B873`, `dusk #9C4A4A`
- `cream #FBF6EE` (page), `paper #FFFDF9` (card)
- `ink #241F2E`, `ink2 #5C5566`, `ink3 #A49CB2`
- `line #EBE2D4` (hairline borders)
- bedtime gradient: `night1 #171228 → night2 #2A1B3D → night3 #5B2E48`

**Jewel palette** for concept icons (echoes `StoryTheme.color`): warm purple
`#8B7CF6`, coral `#E2575B`, teal `#3FB59A`, gold `#F2C84B`, blue `#4FA3E8`,
rose `#F4A6C8`. Each concept token uses a soft cream-based tint of its hue.

Strategy: **restrained** chrome (cream + ember), with **full-palette** color
concentrated on the playful "choosing" screens (the story wizard, review).
The reading/player and bedtime surfaces stay calm.

## Typography

Two typefaces (both via `google_fonts`):
- **Nunito** (rounded sans) — display / headline / title slots, the wordmark,
  and the story-read text. Weights 700–800 for headings, 500 for long-form
  reading. Relaxed tracking (≈ −0.2 → 0). This replaced Fraunces (serif), which
  read as dated for a kids' app.
- **Inter** — all body copy, labels, buttons, inputs, captions. Weights 400–600.

Every one of the 13 Material `TextTheme` slots is populated (see `_textTheme`
in `app_theme.dart`) so no widget falls back to the OS system font.

Scale lives in `AppTypography`: `displayLarge` 32/800 … `titleLarge` 20/700
(Nunito); `bodyLarge` 16/600 … `labelSmall` 12/400 (Inter); `storyBody`
Nunito 17/500 at line-height 1.85.

## Concept icons

The story-creation vocabulary (6 characters, 6 scenes, 6 themes, 6 plots, 3
narrators) is drawn as **rich, multi-color SVG icons** in `concept_icons.dart`,
rendered with `flutter_svg`. Not emoji, not pixel art.

Rules that keep the 30-piece set coherent:
- one warm ink outline across every glyph (`#7A4A14` / `#2A2230`),
- jewel-tone fills from the palette above,
- each glyph seated on its concept tint via `StConceptToken`.

**Seamless-token rule:** the concept tint fills the *whole* card/tile
(`StChoiceCard.tint`, review row), and the glyph renders on a transparent
background, so the icon background and the tile background are one surface.
Never put a colored icon square inside a contrasting card.

Selection is shown by an ember border + soft shadow on the tinted card, not a
background swap. Undrawn concepts fall back to the enum emoji on a neutral
cream token, so the set can grow without breaking.

Pixel art (`PixelSprite`, 16×16 at 6× scale) is retained only for the ambient
layer: home mascots, library row avatars, the player hero.

## Components

`St*` library (barrel: `widgets/storytime/storytime.dart`): `StButton`,
`StTile`, `StChoiceCard`, `StConceptToken`, `StScenePlayer`, `StSectionHeader`,
`StErrorView`, `StRow`, `StChips`, `StSegment`, `StTextField`, `StToggle`,
`StParentGate`, `StVoiceCapture`.

- Cards/tiles: `AppRadius.medium`, 1.5px `line` border, ember border when
  selected; shadow only on selection/elevation.
- CTAs (`StButton`) and tappable tiles expose proper button semantics
  (`Semantics(button: true, excludeSemantics: …)`); icon-only controls carry
  accessible labels.
- Errors use the shared `StErrorView` (icon + heading + body + retry), never a
  marooned one-line sentence.

## Motion

Restrained and purposeful. Pixel mascots animate at 6–10 fps. Choice cards
animate selection over ~160ms ease-out. Respect reduced-motion where available;
never rely on color or motion alone to signal state.
