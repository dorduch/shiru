# Responsive Layout Design

**Date:** 2026-04-06
**Status:** Approved

## Context

Shiru is currently locked to landscape-only orientation (`SystemChrome.setPreferredOrientations([landscapeLeft, landscapeRight])`). An `AppResponsive` utility exists at `app/lib/ui/app_responsive.dart` with `scaleFactor`, `fontSize`, `padding`, `spriteScale`, and `isTablet` — but almost none of it is used. All dimensions (button sizes, grid widths, font sizes, padding) are hardcoded throughout the screens.

The goal is to make the app work on any device in any orientation — small phones in portrait through large tablets in landscape — using a unified breakpoint system so every future screen has a pattern to follow.

---

## Design

### 1. Orientation Unlock

Remove the forced landscape lock in `app/lib/main.dart`:

```dart
// Remove:
SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);

// Replace with (all orientations):
SystemChrome.setPreferredOrientations([]);
```

All other startup settings remain unchanged (immersiveSticky, wakelock).

---

### 2. Breakpoint System (`app/lib/ui/app_responsive.dart`)

Four size classes based on logical width:

| Class | Width      | Typical device             |
|-------|------------|----------------------------|
| `xs`  | < 480px    | Small phone portrait       |
| `sm`  | 480–720px  | Large phone portrait / small landscape |
| `md`  | 720–1024px | Tablet portrait / phone landscape |
| `lg`  | > 1024px   | Tablet landscape / large display |

Scale tokens per size class:

| Token          | xs    | sm    | md    | lg    |
|----------------|-------|-------|-------|-------|
| `scaleFactor`  | 0.80  | 0.90  | 1.00  | 1.20  |
| `spriteScale`  | 4.0   | 5.0   | 6.0   | 8.0   |
| `gridMaxExtent`| 160px | 200px | 240px | 300px |
| `buttonSize`   | 44px  | 48px  | 56px  | 64px  |
| `basePadding`  | 12px  | 16px  | 20px  | 28px  |

### Expanded AppResponsive API

Replace the existing body of `app_responsive.dart` with:

```dart
enum SizeClass { xs, sm, md, lg }

class AppResponsive {
  static SizeClass sizeClass(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w < 480) return SizeClass.xs;
    if (w < 720) return SizeClass.sm;
    if (w < 1024) return SizeClass.md;
    return SizeClass.lg;
  }

  static double scaleFactor(BuildContext context) =>
      const { SizeClass.xs: 0.80, SizeClass.sm: 0.90, SizeClass.md: 1.00, SizeClass.lg: 1.20 }[sizeClass(context)]!;

  static double spacing(BuildContext context, double base) => base * scaleFactor(context);
  static double fontSize(BuildContext context, double base) => base * scaleFactor(context);
  static double iconSize(BuildContext context, double base) => base * scaleFactor(context);

  static double buttonSize(BuildContext context) =>
      const { SizeClass.xs: 44.0, SizeClass.sm: 48.0, SizeClass.md: 56.0, SizeClass.lg: 64.0 }[sizeClass(context)]!;

  static double spriteScale(BuildContext context) =>
      const { SizeClass.xs: 4.0, SizeClass.sm: 5.0, SizeClass.md: 6.0, SizeClass.lg: 8.0 }[sizeClass(context)]!;

  static double gridMaxExtent(BuildContext context) =>
      const { SizeClass.xs: 160.0, SizeClass.sm: 200.0, SizeClass.md: 240.0, SizeClass.lg: 300.0 }[sizeClass(context)]!;

  static double basePadding(BuildContext context) =>
      const { SizeClass.xs: 12.0, SizeClass.sm: 16.0, SizeClass.md: 20.0, SizeClass.lg: 28.0 }[sizeClass(context)]!;

  static bool isCompact(BuildContext context) =>
      sizeClass(context) == SizeClass.xs || sizeClass(context) == SizeClass.sm;

  static bool isPortrait(BuildContext context) =>
      MediaQuery.of(context).orientation == Orientation.portrait;

  // Keep for backward compat — maps to isCompact
  static bool isTablet(BuildContext context) => !isCompact(context);
}
```

---

### 3. Screen Changes

#### KidHomeScreen (`app/lib/ui/kid_home_screen.dart`)

**Grid:**
- Replace `maxCrossAxisExtent: 240` with `AppResponsive.gridMaxExtent(context)`
- Replace `crossAxisSpacing: 24, mainAxisSpacing: 24` with `AppResponsive.spacing(context, 24)`
- Grid adapts automatically: ~2 cols portrait phone → 4+ cols tablet landscape

**Player pill:**
- Portrait (xs/sm): expand to full-width bottom bar — `width: double.infinity`, reduced height
- Landscape (md/lg): keep current floating pill behavior
- Switch via `AppResponsive.isPortrait(context)` wrapping the pill widget
- Sprite scale in pill: replace hardcoded `3.5` with `AppResponsive.spriteScale(context) * 0.6`

**Buttons / icons:**
- Settings button, stop button, play button: replace hardcoded `56` / `64` with `AppResponsive.buttonSize(context)`
- App icon: `AppResponsive.iconSize(context, 56)`
- Category tab height `44` → `AppResponsive.spacing(context, 44)`

**Padding:**
- `SafeArea` padding `horizontal: 24, vertical: 16` → `AppResponsive.basePadding(context)` / `AppResponsive.spacing(context, 16)`

#### ParentEditScreen (`app/lib/ui/parent_edit_screen.dart`)

**Layout switch:**
```dart
AppResponsive.isPortrait(context)
  ? Column(children: [_previewPanel(), _formPanel()])   // portrait: stacked
  : Row(children: [_previewPanel(), Expanded(child: _formPanel())])  // landscape: side by side
```

**Preview panel:** replace hardcoded `220` / `180` / `6.0` with `AppResponsive` calls
**Form width:** replace `500` / `screenWidth * 0.55` with `double.infinity` in portrait, constrained by parent `Expanded` in landscape
**Sprite picker:** replace hardcoded `crossAxisCount: 4` with `AppResponsive.isCompact(context) ? 3 : 4`
**Buttons / padding:** `AppResponsive.buttonSize()` and `AppResponsive.basePadding()`

#### ParentListScreen (`app/lib/ui/parent_list_screen.dart`)

- Replace `width > 980` check with `!AppResponsive.isCompact(context)` (i.e., `sizeClass >= md`) for 2-col grid
- Replace ad-hoc `childAspectRatio` tiers with single value driven by `AppResponsive.scaleFactor()`
- Padding and button sizes through `AppResponsive`

#### Other screens (minor changes only)

| Screen | Change |
|--------|--------|
| `age_gate_screen.dart` | Padding → `AppResponsive.basePadding()`; existing `ConstrainedBox(maxWidth: 640)` stays |
| `bulk_import_screen.dart` | Padding + font sizes → scale tokens; existing maxWidth constraints stay |
| `pin_gate_screen.dart` | Numpad button sizes → `AppResponsive.buttonSize()` |
| `about_screen.dart`, `change_pin_screen.dart` | Padding + font scaling only |

---

### 4. Sprite Scaling Consistency

All sprite usages replace hardcoded scales:

| Location | Current | New |
|----------|---------|-----|
| Kid home grid | `AppResponsive.spriteScale()` ✓ | Already correct |
| Kid home player pill | `3.5` | `AppResponsive.spriteScale(context) * 0.6` |
| Parent list thumbnail | `2.7` | `AppResponsive.spriteScale(context) * 0.45` |
| Parent edit preview | `6.0` | `AppResponsive.spriteScale(context)` |
| Sprite picker | `3.0` | `AppResponsive.spriteScale(context) * 0.5` |

---

## Verification

1. **Run on phone emulator in portrait** — kid home grid should show 2 columns; player pill should be full-width bar at bottom
2. **Rotate to landscape** — grid expands to 3–4 columns; player pill returns to floating pill
3. **Run on tablet emulator in landscape** — grid shows 4–5 columns; all buttons/sprites are larger
4. **Parent edit in portrait** — preview card appears above form; form scrolls below
5. **Parent edit in landscape** — preview on left, form on right (current behavior)
6. **Run `flutter analyze`** — no errors
7. **Run on physical device if available** — verify touch targets are comfortable in both orientations

---

## Files Modified

- `app/lib/main.dart` — remove orientation lock
- `app/lib/ui/app_responsive.dart` — full rewrite with breakpoint system
- `app/lib/ui/kid_home_screen.dart` — grid, player pill, buttons, padding
- `app/lib/ui/parent_edit_screen.dart` — orientation-aware layout switch
- `app/lib/ui/parent_list_screen.dart` — breakpoint check, padding
- `app/lib/ui/age_gate_screen.dart` — padding scaling
- `app/lib/ui/bulk_import_screen.dart` — padding + font scaling
- `app/lib/ui/pin_gate_screen.dart` — button sizes
