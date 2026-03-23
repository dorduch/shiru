# Yoto DIY — UI Design Guide
**For Designers · v1.0 · March 2026 · Confidential**

| | |
|---|---|
| **Platform** | Android Tablet — 800×1280px (React Native) |
| **Audience** | Children ages 3–10 + Parents |
| **Visual Style** | Pixel art, animated sprites |
| **Key Constraint** | Tablet-only — 800×1280px, no phone support |

---

## 1. Overview & Design Goals

Yoto DIY is a screen-free audio player app for kids. The visual design must communicate **"toy" not "app"**. The primary interface is used by children as young as 3 — it must require zero reading ability and zero prior smartphone experience to operate.

There are two distinct contexts the designer must serve:

| | Kid Mode | Parent Mode |
|---|---|---|
| **Default state** | Full screen. No chrome. | PIN-protected. Standard mobile UI. |
| **Content** | Giant tappable cards, animated sprites. | Form fields, pickers, settings. |
| **Target user** | Must work for a 3-year-old. | Must work for a tired parent. |
| **Navigation** | No text required to navigate. | Efficient, clear, minimal steps. |

> ⚠️ **The child should never feel like they are using a phone. They should feel like they are playing with a toy.**

---

## 2. Visual Identity

### 2.1 The Pixel Art Aesthetic

The entire app visual language is inspired by early Nintendo Game Boy and Yoto's own LCD pixel display. All card artwork is rendered as animated pixel sprites — small, chunky, lovable characters on colored backgrounds.

**Core rules:**
- All sprites are drawn on a **16×16 pixel grid**
- Maximum **4 colors** per sprite (including transparent)
- **No anti-aliasing, no gradients** within sprites — hard pixel edges only
- Sprites are displayed at **6x scale** — a 16px sprite renders at 96px on screen
- Pixel blocks must appear as **sharp squares** — never blur or smooth

> ⚠️ Design sprites in **Aseprite** or **Piskel** at exactly 16×16px. Export as PNG sprite sheets. Do not resize with smoothing — always use **nearest-neighbor** scaling.

---

### 2.2 Color Palette

The app uses two color systems: the **UI chrome palette** (consistent across the app) and the **card background palette** (12 vibrant child-friendly colors auto-assigned to cards).

#### UI Chrome Palette

| Hex | Name | Usage |
|---|---|---|
| `#0D1117` | Near Black | App background (kid mode) |
| `#1A1A2E` | Deep Navy | Player bar, overlays |
| `#FFFFFF` | White | Primary text on dark |
| `#F5F7FA` | Off White | Parent mode backgrounds |
| `#1E4D8C` | Royal Blue | Primary action, highlights |
| `#3A6DB5` | Mid Blue | Secondary UI elements |
| `#6B7280` | Gray | Muted labels, placeholders |

#### Card Background Palette (12 Colors)

All colors must read well with **white text and white pixel sprites** on top.

| Hex | Name | Sprite Palette Suggestion |
|---|---|---|
| `#E74C3C` | Red | White + light yellow + dark red |
| `#E67E22` | Orange | White + cream + dark brown |
| `#F1C40F` | Yellow | White + light orange + dark gold |
| `#2ECC71` | Green | White + light mint + dark green |
| `#1ABC9C` | Teal | White + light cyan + dark teal |
| `#3498DB` | Blue | White + sky blue + dark navy |
| `#9B59B6` | Purple | White + lavender + dark purple |
| `#E91E63` | Pink | White + light pink + dark rose |
| `#00BCD4` | Cyan | White + pale cyan + dark teal |
| `#FF5722` | Deep Orange | White + peach + dark brown |
| `#8BC34A` | Light Green | White + pale lime + dark green |
| `#FF9800` | Amber | White + light yellow + dark amber |

---

### 2.3 Typography

The app uses a single typeface throughout. In kid mode, text is intentionally minimal — children should navigate by visuals, not words.

**Typeface: [Nunito](https://fonts.google.com/specimen/Nunito)** (Google Fonts). The rounded letterforms complement the pixel art aesthetic. Never use a system serif font anywhere in this app.

| Style | Size | Weight | Used For |
|---|---|---|---|
| Card Title (kid) | 18sp | ExtraBold 800 | Card label in kid mode |
| Card Title (parent) | 14sp | Bold 700 | Card list in parent mode |
| Section Header | 20sp | Bold 700 | Parent mode screens |
| Body / Labels | 14sp | Regular 400 | Settings, descriptions |
| Player Track Name | 13sp | SemiBold 600 | Mini-player bar |
| PIN Digits | 32sp | Bold 700 | PIN entry screen |

---

## 3. Screen Specifications

### 3.1 Kid Mode — Card Grid (Primary Screen)

This is the main screen. It is the only screen children ever see. Design everything else around making this screen feel magical.

#### Layout
- Full-screen, edge-to-edge, no status bar visible (or status bar tinted to match background)
- Background: `#0D1117` — makes colored cards pop
- **3-column grid** — optimized for 800px width
- Card size: square, fills column width with **16px gap** between cards
- **16px padding** on left and right edges
- Mini-player bar fixed to bottom — **72px tall** — always visible when audio is playing

#### Card Component
- Square card with **12px border radius**
- Background: card's assigned color from the 12-color palette
- Centered pixel art sprite — rendered at **96px** (16×16 sprite × 6x scale)
- Card title below sprite — Nunito ExtraBold 18sp, white, centered, max 2 lines, ellipsis
- 8px padding inside card between sprite and edges
- Drop shadow: `0px 4px 12px rgba(0,0,0,0.4)`

#### Card States

| State | Visual | Animation |
|---|---|---|
| Idle | Normal card, full opacity | Sprite loops idle frames at 6fps |
| Tap (press) | Card scales down to 0.92x instantly | Spring back to 1.0x on release (reanimated) |
| Playing / Active | 3px white border glow around card | Sprite switches to active frames at 10fps |
| Other card playing | Opacity reduced to 0.6x | Sprite continues idle, dimmed |

#### Mini-Player Bar
- Fixed to bottom, **72px tall**, background `#1A1A2E`
- Left: animated 24px sprite (small version of active card's sprite)
- Center: track title — Nunito SemiBold 13sp, white, single line, ellipsis
- Right: play/pause icon button (32px) + stop icon button (32px)
- Thin 1px top border in `#3A6DB5`
- Hidden / zero-height when nothing is playing

---

### 3.2 Parent Mode — Card Management

Accessed via PIN gate. Standard mobile UI — clean, efficient. Parents are in task mode, not play mode.

#### Card List / Edit Screen
- White background, standard list layout
- Each row: small card color swatch (24px circle) + sprite thumbnail (24px) + card title + chevron
- Swipe left on row to reveal **Delete** (red) action
- Drag handle on right for reorder
- FAB bottom right: **+** to add new card

#### Create / Edit Card Screen
- Full-screen modal sheet
- **Field 1:** Title — large text input, Nunito Bold 18sp, placeholder "Card name"
- **Field 2:** Audio file — tappable row, shows filename once selected, "Choose audio file" as placeholder
- **Field 3:** Sprite picker — horizontal scroll of sprite previews (48px each), selected has blue border
- **Field 4:** Background color — 12-color palette grid, tappable swatches, selected has checkmark
- Save button: full-width primary blue, "Save Card", disabled until title + audio are filled

#### Sprite Picker Component
- Horizontal scrollable row of all 20+ predefined sprites
- Each sprite rendered at **48px** in a 56px square container with light gray background
- Selected state: 2px blue border, blue checkmark badge top-right
- First item is **"Auto"** — magic wand icon, assigns sprite from title hash

> ✨ The sprite picker is the most "fun" part of the parent flow. Lean into it — make it feel like choosing a sticker, not filling a form field.

---

### 3.3 PIN Screen

Shown when parent tries to access card management or settings from kid mode.

- Full-screen modal, dark background `#0D1117` — consistent with kid mode
- Center: **4 large dot indicators** (filled = entered, empty = pending)
- Below: 3×4 number pad, large touch targets (minimum **72×72dp** per key)
- Each key: white number on dark rounded square, scale-down animation on tap
- Backspace icon in bottom-right of keypad
- "Cancel" text button below keypad — returns to kid mode
- On wrong PIN: dots shake horizontally (error shake animation), then reset

> ⚠️ No "forgot PIN" text on this screen — keep it clean. Biometric fallback is triggered by holding the lock icon for 2 seconds.

---

### 3.4 Onboarding (First Launch)

Shown once on first launch, before kid mode. Parent-facing. Simple 3-step flow.

- **Step 1:** Welcome — app name, tagline, "Set up your first card" CTA
- **Step 2:** PIN setup — enter 4 digits, confirm 4 digits
- **Step 3:** Create first card — inline card creation, same UI as parent create flow
- After step 3: launches directly into kid mode with the first card visible
- Progress dots at top (1 of 3, 2 of 3, etc.)

---

## 4. Pixel Art Sprite Specification

This section is the most critical part of the design deliverable. The sprites define the entire visual character of the app. **Take time here.**

### 4.1 Sprite Grid Rules

| Rule | Value |
|---|---|
| Canvas size | 16 × 16 pixels |
| Display size | 96px (6x scale) in cards · 24px (1.5x scale) in player |
| Max colors per sprite | 4 (including transparent as color 0) |
| Scaling method | Nearest-neighbor only — never bilinear |
| Transparent pixels | Palette index 0 — shows card background color through |
| Idle frame count | 2–4 frames |
| Active frame count | 4–8 frames |
| Tap frame count | 3–5 frames (one-shot burst) |
| Idle animation speed | 6 fps |
| Active animation speed | 10 fps |
| Export format | PNG sprite sheet (all frames horizontal, single row) |

---

### 4.2 Sprite Sheet Export Format

Export each sprite as a **single PNG file** containing all frames side by side in one horizontal strip. Frame order: idle frames first, then active, then tap.

```
Filename:  cat.png  (256px wide × 16px tall = 16 frames × 16px)
Layout:    [ idle_1 | idle_2 | idle_3 | active_1 | ... | active_6 | tap_1 | tap_2 | tap_3 ]
```

Accompany each sprite sheet with a **metadata JSON file**:

```json
{
  "id": "cat",
  "idleFrames": 3,
  "activeFrames": 6,
  "tapFrames": 3,
  "palette": ["#E74C3C", "#FFFFFF", "#1A1A2E", "#F1C40F"]
}
```

---

### 4.3 Required Sprites — Delivery Checklist

Minimum **20 sprites** required for MVP, across 5 categories:

| Category | Sprite ID | Animation Notes |
|---|---|---|
| Animals | `cat` | Idle: blinking · Active: bouncing · Tap: jump with sparkle |
| Animals | `dog` | Idle: tail wag · Active: running in place · Tap: spin |
| Animals | `owl` | Idle: head turn · Active: wing flap · Tap: fly up off screen |
| Animals | `bunny` | Idle: ear wiggle · Active: hop · Tap: disappear into hat |
| Nature | `sun` | Idle: slow ray pulse · Active: spinning rays · Tap: flash burst |
| Nature | `moon` | Idle: twinkle stars around · Active: glow pulse · Tap: full moon flash |
| Nature | `star` | Idle: slow shimmer · Active: fast spin · Tap: explode into stars |
| Nature | `rainbow` | Idle: color shift · Active: full arc bounce · Tap: cloud puff |
| Adventure | `rocket` | Idle: hover float · Active: flames on + ascending · Tap: blast off |
| Adventure | `castle` | Idle: flag wave · Active: drawbridge lower · Tap: fireworks |
| Adventure | `treasure` | Idle: chest glow · Active: chest open + coins · Tap: coins shower |
| Adventure | `dragon` | Idle: slow breathing · Active: wings open · Tap: fire breath |
| Music | `note` | Idle: slow bob · Active: fast bounce + echo · Tap: chord burst |
| Music | `headphones` | Idle: cable sway · Active: bass pulse · Tap: music notes fly out |
| Music | `drum` | Idle: still · Active: drumstick hit animation · Tap: cymbal crash |
| Music | `guitar` | Idle: string shimmer · Active: strum animation · Tap: chord flash |
| Bedtime | `moon_z` | Idle: ZZZ drift upward slowly · Active: glow · Tap: pillow puff |
| Bedtime | `pillow` | Idle: gentle sway · Active: zzz bubbles rise · Tap: cloud appear |
| Bedtime | `sheep` | Idle: blink + wool bounce · Active: jump over fence · Tap: poof |
| Bedtime | `bear` | Idle: breathing · Active: rocking · Tap: snore bubble |

---

## 5. Design Do's and Don'ts

### ✅ Do's
- Make cards feel like physical objects — shadows, slight scale on tap
- Use full-bleed card color — no white card borders in kid mode
- Keep text in kid mode to an absolute minimum — the sprite tells the story
- Test every card color with white text at the smallest rendered size
- Design for fat fingers — minimum **48×48dp** touch targets everywhere
- Keep the bottom mini-player unobtrusive — it should not compete with cards
- Animate idling sprites slowly — it feels alive without being distracting
- Make the PIN screen feel consistent with kid mode — same dark background

### ❌ Don'ts
- Never use gradients inside pixel art sprites — hard edges only
- Never use more than 4 colors in a single sprite (including transparent)
- Never scale sprites with smoothing/bilinear — always nearest-neighbor
- Never put navigation chrome (back buttons, tabs, menus) in kid mode
- Never use red or green for UI feedback — color-blind accessibility
- Never use small text in kid mode — the youngest user cannot read
- Never use white card backgrounds — they blend into the dark background
- Never play animations at full speed in idle state — it becomes noise

---

## 6. Deliverables & Handoff

### 6.1 Design Files
- Figma file with all screens: kid mode, parent mode, PIN, onboarding
- All components in a dedicated component page — cards, buttons, mini-player, sprite picker, color picker
- Auto-layout used throughout for responsive behavior
- Pixel art sprites placed at 1x (16px) with a 6x preview alongside
- **Dark mode only** — this app does not have a light mode

### 6.2 Sprite Deliverables
- 20 PNG sprite sheets (one per sprite ID in section 4.3)
- 1 metadata JSON file per sprite (frame counts + palette)
- All sprites exported at exactly 1x — 16px per frame, single-row horizontal strip
- Naming convention: `<id>.png` and `<id>.json` (e.g. `cat.png` + `cat.json`)
- Delivered in a single `/sprites` folder

### 6.3 Handoff Checklist
- [ ] All screens designed at **800×1280px** (Android tablet, portrait)
- [ ] Landscape layout considered for card grid — 4-column at 1280px wide
- [ ] All interactive states designed (idle, tap, active, disabled)
- [ ] All 20 sprites delivered as PNG + JSON pairs
- [ ] Color tokens documented and named to match PRD naming
- [ ] Typography styles named and consistent across all screens
- [ ] Figma prototype link showing kid mode card tap → audio playing flow
- [ ] Redline annotations on card component with spacing in dp

---

> 💡 When in doubt, look at the real Yoto device and app for inspiration. The goal is not to copy — it is to capture the same feeling of a toy that happens to play audio.
