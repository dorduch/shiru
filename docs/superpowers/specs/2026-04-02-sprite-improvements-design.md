# Sprite Improvements Design

**Date:** 2026-04-02
**Status:** Approved

## Overview

Two paired improvements to the pixel art creature system:

1. **New sprite content** — 30 new hand-crafted creatures across two new categories (Animals, Fantasy), supplementing the existing 103 Sci-Fi/Abstract sprites.
2. **Parent sprite picker** — A bottom sheet in ParentEditScreen that lets parents choose any creature for a card, with the selection persisted to the existing (but unused) `spriteKey` DB column.

## Section 1: New Sprite Categories

### Category System

Add a `SpriteCategory` enum to `lib/models/sprites.dart`:

```dart
enum SpriteCategory { animals, fantasy, sciFi }
```

Add a `category` field to `SpriteDef`:

```dart
class SpriteDef {
  final String id;
  final String name;
  final SpriteCategory category; // new
  final List<String> palette;
  final Map<String, List<List<int>>> frames;
  final Map<String, int> fps;
}
```

Existing `kid_*`, `moon`, `rocket`, and `dog` sprites are tagged `SpriteCategory.sciFi`. No renames or pixel data changes.

### New Sprites

**Animals (15):** cat, bunny, frog, bear, duck, owl, penguin, fox, elephant, turtle, bee, crab, lion, hedgehog, fish

**Fantasy (15):** dragon, unicorn, wizard, knight, pirate, fairy, dinosaur, ghost, mermaid, astronaut, chef, ninja, superhero, phoenix, witch

Each sprite follows the existing `SpriteDef` structure: 16×16 pixel grid, 4-color palette, 3 animation states (`idle`, `active`, `tap`), per-state FPS.

Total sprite count after: 133 (103 existing + 30 new).

## Section 2: Sprite Picker UI

### Trigger

In `ParentEditScreen`, add a **"Change Creature"** button below the existing sprite preview container. Tapping calls `showModalBottomSheet()`.

### Bottom Sheet

- **Category tabs** at top: `Animals` · `Fantasy` · `Sci-Fi` — tapping filters the grid. Default tab is the category of the currently assigned sprite.
- **4-column sprite grid** — each cell renders a `PixelSprite` widget at scale 3.0 with the creature name in small text below.
- Currently selected sprite is highlighted with a colored border.
- **Tapping a sprite selects it immediately and closes the sheet.** No separate Done button.
- The sprite preview in the edit form updates instantly.

### State

A local `selectedSpriteKey` state variable in `ParentEditScreen` tracks the picker selection. On sheet open, it initialises to `card.spriteKey ?? autoAssignSprite(card.title)`.

## Section 3: Data Model & Persistence

### The Fix

The `spriteKey` column already exists in the `cards` SQLite table and `AudioCard` model but is never written. Wire it up:

1. **`ParentEditScreen` — save:** include `spriteKey: selectedSpriteKey` when building the `AudioCard` for insert/update.
2. **`ParentEditScreen` — load:** initialise `selectedSpriteKey` from `card.spriteKey` if non-null, otherwise from `autoAssignSprite(card.title)`.
3. **`_CardArtwork` (ParentListScreen):** change `autoAssignSprite(card.title)` → `card.spriteKey ?? autoAssignSprite(card.title)`.
4. **`AudioCardTile` (KidHomeScreen):** same one-line change.

### No DB Migration Needed

The `spriteKey` column is already present. No schema changes required.

### Backwards Compatibility

Existing cards with `spriteKey = null` continue to use `autoAssignSprite(card.title)` as today — behaviour is unchanged until a parent explicitly picks a creature.

## Files Changed

| File | Change |
|------|--------|
| `lib/models/sprites.dart` | Add `SpriteCategory` enum, add `category` to `SpriteDef`, tag all existing sprites, add 30 new `SpriteDef` entries |
| `lib/ui/parent_edit_screen.dart` | Add picker button, bottom sheet widget, `selectedSpriteKey` state, wire save/load |
| `lib/ui/parent_list_screen.dart` | Use `card.spriteKey` before fallback in `_CardArtwork` |
| `lib/ui/kid_home_screen.dart` | Use `card.spriteKey` before fallback in `AudioCardTile` |

## Out of Scope

- Custom image upload (the `customImagePath` DB field remains unused)
- Giphy integration
- Changes to `autoAssignSprite()` logic for new cards
