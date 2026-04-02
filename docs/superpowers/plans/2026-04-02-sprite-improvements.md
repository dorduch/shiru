# Sprite Improvements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `SpriteCategory` to the sprite model, wire the existing unused `spriteKey` DB field through all display widgets, and build a category-filtered bottom sheet picker in ParentEditScreen.

**Architecture:** `SpriteCategory` is added as a default-valued field to `SpriteDef` (defaulting to `sciFi`) so the 103 existing sprites require no modification. The picker is a private `_SpritePicker` StatefulWidget inside `parent_edit_screen.dart`. The `spriteKey` save/load is wired in `_save()` and `_loadCard()` respectively.

**Tech Stack:** Flutter/Dart, Riverpod, sqflite. No new packages required.

**Spec:** `docs/superpowers/specs/2026-04-02-sprite-improvements-design.md`

**Scope note:** This plan covers the code infrastructure (Tasks 1–4). Adding the 30 new animal/fantasy SpriteDef entries (Plan B) is a separate content task — the category system is designed here so new sprites slot straight in.

---

## Files

| File | Change |
|------|--------|
| `lib/models/sprites.dart` | Add `SpriteCategory` enum + `category` field to `SpriteDef` |
| `lib/ui/parent_edit_screen.dart` | Add `_selectedSpriteKey` state, `_showSpritePicker()`, `_SpritePicker` widget, `_CategoryTab` widget; wire save/load |
| `lib/ui/parent_list_screen.dart` | `_CardArtwork`: prefer `card.spriteKey` before `autoAssignSprite` |
| `lib/ui/kid_home_screen.dart` | Two `autoAssignSprite` calls → prefer `card.spriteKey` |
| `test/models/sprites_test.dart` | Create: unit tests for SpriteCategory and sprite resolution |

---

## Task 1: Add SpriteCategory to the sprite model

**Files:**
- Modify: `lib/models/sprites.dart:4–18`
- Create: `test/models/sprites_test.dart`

- [ ] **Step 1: Create the failing test**

Create `app/test/models/sprites_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shiru/models/sprites.dart';

void main() {
  group('SpriteCategory', () {
    test('has three values', () {
      expect(SpriteCategory.values.length, 3);
      expect(SpriteCategory.values, containsAll([
        SpriteCategory.animals,
        SpriteCategory.fantasy,
        SpriteCategory.sciFi,
      ]));
    });
  });

  group('SpriteDef', () {
    test('defaults to sciFi category', () {
      final sprite = SpriteDef(
        id: 'test',
        name: 'Test',
        palette: ['#00000000', '#FF0000FF'],
        frames: {
          'idle': [
            [for (var i = 0; i < 16; i++) [for (var j = 0; j < 16; j++) 0]]
          ],
          'active': [
            [for (var i = 0; i < 16; i++) [for (var j = 0; j < 16; j++) 0]]
          ],
          'tap': [
            [for (var i = 0; i < 16; i++) [for (var j = 0; j < 16; j++) 0]]
          ],
        },
        fps: const {'idle': 4, 'active': 8, 'tap': 15},
      );
      expect(sprite.category, SpriteCategory.sciFi);
    });

    test('all predefined sprites have a category', () {
      for (final sprite in predefinedSprites.values) {
        expect(sprite.category, isNotNull,
            reason: 'Sprite ${sprite.id} is missing a category');
      }
    });

    test('all predefined sprites are tagged sciFi by default', () {
      for (final sprite in predefinedSprites.values) {
        expect(sprite.category, SpriteCategory.sciFi,
            reason: 'Sprite ${sprite.id} should be sciFi');
      }
    });
  });

  group('predefinedSprites', () {
    test('contains at least 103 entries', () {
      expect(predefinedSprites.length, greaterThanOrEqualTo(103));
    });

    test('lookup by key returns correct sprite', () {
      expect(predefinedSprites['moon']?.name, 'Moon');
      expect(predefinedSprites['rocket']?.name, 'Rocket');
      expect(predefinedSprites['dog']?.name, 'Dog');
    });

    test('autoAssignSprite returns a SpriteDef', () {
      final sprite = autoAssignSprite('Test Card Title');
      expect(sprite, isA<SpriteDef>());
      expect(sprite.id, isNotEmpty);
    });
  });
}
```

- [ ] **Step 2: Run test to confirm it fails**

```bash
cd app && flutter test test/models/sprites_test.dart
```

Expected: compilation error — `SpriteCategory` not defined.

- [ ] **Step 3: Add SpriteCategory enum and category field to SpriteDef**

In `lib/models/sprites.dart`, replace lines 4–18:

```dart
enum SpriteCategory { animals, fantasy, sciFi }

class SpriteDef {
  final String id;
  final String name;
  final SpriteCategory category;
  final List<String> palette;
  final Map<String, List<List<List<int>>>> frames;
  final Map<String, int> fps;

  const SpriteDef({
    required this.id,
    required this.name,
    this.category = SpriteCategory.sciFi,
    required this.palette,
    required this.frames,
    required this.fps,
  });
}
```

- [ ] **Step 4: Run tests to confirm they pass**

```bash
cd app && flutter test test/models/sprites_test.dart
```

Expected: all 7 tests pass.

- [ ] **Step 5: Verify app still analyzes clean**

```bash
cd app && flutter analyze
```

Expected: no errors.

- [ ] **Step 6: Commit**

```bash
cd app && git add lib/models/sprites.dart test/models/sprites_test.dart
git commit -m "feat: add SpriteCategory enum to SpriteDef model"
```

---

## Task 2: Wire spriteKey in display widgets

Teach `_CardArtwork` (ParentListScreen) and `AudioCardTile` / player pill (KidHomeScreen) to use `card.spriteKey` when set, falling back to `autoAssignSprite`.

**Files:**
- Modify: `lib/ui/parent_list_screen.dart:513`
- Modify: `lib/ui/kid_home_screen.dart:260` and `lib/ui/kid_home_screen.dart:498`

- [ ] **Step 1: Add a resolution test**

Append to `test/models/sprites_test.dart` inside `main()`:

```dart
  group('spriteKey resolution', () {
    test('known key resolves to correct sprite', () {
      final sprite = predefinedSprites['moon'];
      expect(sprite, isNotNull);
      expect(sprite!.name, 'Moon');
    });

    test('unknown key falls back gracefully via null check', () {
      const unknownKey = 'does_not_exist';
      final sprite = predefinedSprites[unknownKey];
      expect(sprite, isNull); // caller should fall back to autoAssignSprite
    });
  });
```

- [ ] **Step 2: Run to confirm tests pass (they're model-level, no code change needed)**

```bash
cd app && flutter test test/models/sprites_test.dart
```

Expected: all 9 tests pass.

- [ ] **Step 3: Update _CardArtwork in parent_list_screen.dart**

In `lib/ui/parent_list_screen.dart`, replace line 513:

```dart
// Before:
final spriteDef = autoAssignSprite(card.title);

// After:
final spriteDef = card.spriteKey != null
    ? (predefinedSprites[card.spriteKey!] ?? autoAssignSprite(card.title))
    : autoAssignSprite(card.title);
```

- [ ] **Step 4: Update AudioCardTile in kid_home_screen.dart (line ~498)**

In `lib/ui/kid_home_screen.dart`, find the `build` method of `AudioCardTile` (contains `autoAssignSprite(widget.card.title)`) and replace:

```dart
// Before:
final spriteDef = autoAssignSprite(widget.card.title);

// After:
final spriteDef = widget.card.spriteKey != null
    ? (predefinedSprites[widget.card.spriteKey!] ?? autoAssignSprite(widget.card.title))
    : autoAssignSprite(widget.card.title);
```

- [ ] **Step 5: Update the player pill in kid_home_screen.dart (line ~260)**

In `lib/ui/kid_home_screen.dart`, find the player pill builder (contains `autoAssignSprite(card.title)`) and replace:

```dart
// Before:
final spriteDef = autoAssignSprite(card.title);

// After:
final spriteDef = card.spriteKey != null
    ? (predefinedSprites[card.spriteKey!] ?? autoAssignSprite(card.title))
    : autoAssignSprite(card.title);
```

- [ ] **Step 6: Verify no analysis errors**

```bash
cd app && flutter analyze
```

Expected: no errors.

- [ ] **Step 7: Commit**

```bash
cd app && git add lib/ui/parent_list_screen.dart lib/ui/kid_home_screen.dart test/models/sprites_test.dart
git commit -m "feat: resolve card.spriteKey before fallback to autoAssignSprite"
```

---

## Task 3: Wire spriteKey save/load in ParentEditScreen

Add `_selectedSpriteKey` state, initialize it from the card on load, and persist it on save.

**Files:**
- Modify: `lib/ui/parent_edit_screen.dart`

- [ ] **Step 1: Add _selectedSpriteKey field**

In `_ParentEditScreenState`, add to the state fields (after line 35, `bool _isLoading = false;`):

```dart
String? _selectedSpriteKey;
```

- [ ] **Step 2: Load spriteKey from card in _loadCard()**

In `_loadCard()`, after the line `_selectedCategoryId = card.collectionId;` (line 66), add:

```dart
_selectedSpriteKey = card.spriteKey;
```

- [ ] **Step 3: Save spriteKey in _save()**

In `_save()`, in the `AudioCard(...)` constructor (line 101), replace:

```dart
spriteKey: null,
```

with:

```dart
spriteKey: _selectedSpriteKey ?? autoAssignSprite(title).id,
```

- [ ] **Step 4: Use _selectedSpriteKey in build()**

In `build()`, replace line 162:

```dart
// Before:
final spriteDef = autoAssignSprite(_titleController.text);

// After:
final spriteDef = _selectedSpriteKey != null
    ? (predefinedSprites[_selectedSpriteKey!] ?? autoAssignSprite(_titleController.text))
    : autoAssignSprite(_titleController.text);
```

- [ ] **Step 5: Pass spriteDef to _buildPreview**

`_buildPreview(spriteDef)` is already called on line 238 — no change needed here.

- [ ] **Step 6: Verify analysis is clean**

```bash
cd app && flutter analyze
```

Expected: no errors.

- [ ] **Step 7: Commit**

```bash
cd app && git add lib/ui/parent_edit_screen.dart
git commit -m "feat: wire _selectedSpriteKey save/load in ParentEditScreen"
```

---

## Task 4: Build the sprite picker bottom sheet

Add a "Change Creature" button to `_buildPreview` and implement the `_SpritePicker` / `_CategoryTab` private widgets.

**Files:**
- Modify: `lib/ui/parent_edit_screen.dart`

- [ ] **Step 1: Add _showSpritePicker() method to _ParentEditScreenState**

Add this method to `_ParentEditScreenState` (after `_save()`):

```dart
void _showSpritePicker() {
  final currentKey = _selectedSpriteKey ??
      autoAssignSprite(_titleController.text).id;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _SpritePicker(
      selectedKey: currentKey,
      onSelected: (key) {
        setState(() => _selectedSpriteKey = key);
        Navigator.pop(ctx);
      },
    ),
  );
}
```

- [ ] **Step 2: Add "Change Creature" button to _buildPreview**

In `_buildPreview()`, after the closing `),` of the sprite `Container` (after `SizedBox(height: 16)`), add a button before the title `Text`:

```dart
// The _buildPreview Column children currently are:
//   Text("Preview"), SizedBox, Container(white card with [artwork-container, SizedBox, title-text])
// Add the button inside the white card Column, between SizedBox(height: 16) and the title Text:

GestureDetector(
  onTap: _showSpritePicker,
  child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.shuffle_rounded, size: 16, color: Color(0xFF6B7280)),
        SizedBox(width: 6),
        Text(
          'Change Creature',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF6B7280),
          ),
        ),
      ],
    ),
  ),
),
const SizedBox(height: 8),
```

The full `_buildPreview` Column children order becomes:
1. `Text("Preview")`
2. `SizedBox(height: 16)`
3. White card `Container` whose inner Column has:
   a. Artwork `Container` (180px)
   b. `SizedBox(height: 16)`
   c. "Change Creature" `GestureDetector` (new)
   d. `SizedBox(height: 8)` (new)
   e. Title `Text`

- [ ] **Step 3: Add _SpritePicker StatefulWidget**

Append to the bottom of `lib/ui/parent_edit_screen.dart` (after the closing `}` of `_ParentEditScreenState`):

```dart
class _SpritePicker extends StatefulWidget {
  final String selectedKey;
  final void Function(String key) onSelected;

  const _SpritePicker({required this.selectedKey, required this.onSelected});

  @override
  State<_SpritePicker> createState() => _SpritePickerState();
}

class _SpritePickerState extends State<_SpritePicker> {
  late SpriteCategory _activeCategory;

  @override
  void initState() {
    super.initState();
    final selected = predefinedSprites[widget.selectedKey];
    _activeCategory = selected?.category ?? SpriteCategory.sciFi;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = predefinedSprites.values
        .where((s) => s.category == _activeCategory)
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Category tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _CategoryTab(
                    label: 'Animals',
                    active: _activeCategory == SpriteCategory.animals,
                    onTap: () =>
                        setState(() => _activeCategory = SpriteCategory.animals),
                  ),
                  const SizedBox(width: 8),
                  _CategoryTab(
                    label: 'Fantasy',
                    active: _activeCategory == SpriteCategory.fantasy,
                    onTap: () =>
                        setState(() => _activeCategory = SpriteCategory.fantasy),
                  ),
                  const SizedBox(width: 8),
                  _CategoryTab(
                    label: 'Sci-Fi',
                    active: _activeCategory == SpriteCategory.sciFi,
                    onTap: () =>
                        setState(() => _activeCategory = SpriteCategory.sciFi),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Sprite grid
            Expanded(
              child: GridView.builder(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.85,
                ),
                itemCount: filtered.length,
                itemBuilder: (ctx, i) {
                  final sprite = filtered[i];
                  final isSelected = sprite.id == widget.selectedKey;
                  return GestureDetector(
                    onTap: () => widget.onSelected(sprite.id),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? Border.all(
                                color: const Color(0xFF22C55E), width: 2.5)
                            : Border.all(
                                color: const Color(0xFFE5E7EB), width: 1),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          PixelSprite(
                            sprite: sprite,
                            state: SpriteState.idle,
                            scale: 3.0,
                          ),
                          const SizedBox(height: 4),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              sprite.name,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF374151),
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _CategoryTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF22C55E) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Verify analysis is clean**

```bash
cd app && flutter analyze
```

Expected: no errors or warnings.

- [ ] **Step 5: Run all tests**

```bash
cd app && flutter test
```

Expected: all tests pass.

- [ ] **Step 6: Manual smoke test**

Run on device/emulator:
1. Open Parent screen → tap a card's edit button
2. Confirm sprite preview renders correctly
3. Tap "Change Creature" → bottom sheet slides up
4. Confirm Sci-Fi tab is active by default, grid shows creatures
5. Tap Animals tab → grid shows only animal sprites (empty until Plan B adds them; Sci-Fi tab should show all existing sprites)
6. Tap a sprite in Sci-Fi tab → preview updates, sheet closes
7. Tap Save → reopen the card → confirm the same sprite is shown

- [ ] **Step 7: Commit**

```bash
cd app && git add lib/ui/parent_edit_screen.dart
git commit -m "feat: add sprite picker bottom sheet to ParentEditScreen"
```

---

## Plan B: New Sprite Content (deferred)

Adding the 30 new SpriteDef entries (15 animals + 15 fantasy) is creative pixel-art work, handled in a separate plan. Each new sprite follows this pattern in `lib/models/sprites.dart`:

```dart
'cat': SpriteDef(
  id: 'cat',
  name: 'Cat',
  category: SpriteCategory.animals,  // <-- set explicitly
  palette: [
    '#00000000', // 0 = transparent
    '#F97316',   // 1 = main color
    '#FED7AA',   // 2 = secondary
    '#1C1917',   // 3 = accent / eyes
  ],
  fps: const {'idle': 4, 'active': 8, 'tap': 15},
  frames: {
    'idle': buildFrames(['''
0000000000000000
...16 rows of 16 color-index digits...
0000000000000000''']),
    'active': buildFrames([...]),
    'tap': buildFrames([...]),
  },
),
```

Creatures to add:
- **Animals:** cat, bunny, frog, bear, duck, owl, penguin, fox, elephant, turtle, bee, crab, lion, hedgehog, fish
- **Fantasy:** dragon, unicorn, wizard, knight, pirate, fairy, dinosaur, ghost, mermaid, astronaut, chef, ninja, superhero, phoenix, witch

Once added, they appear automatically in the Animals/Fantasy tabs of the picker.
