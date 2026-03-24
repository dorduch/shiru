# Categories Feature — Design Spec
**Date:** 2026-03-24
**App:** Shiru (Flutter, kids audio player)
**Status:** Ready for implementation planning

---

## Overview

Parents can organize audio cards into named categories (e.g. "Songs", "Bedtime", "Stories"). Each category has an emoji icon and a display order. Children see a tab bar at the top of the home screen and can tap a tab to filter the card grid to that category.

---

## Data Model

### New `categories` table (DB migration: version 1 → 2)

```sql
CREATE TABLE categories (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  emoji TEXT NOT NULL,
  position INTEGER DEFAULT 0
)
```

### New `Category` model — `lib/models/category.dart`

```dart
class Category {
  final String id;       // UUID
  final String name;     // e.g. "Songs"
  final String emoji;    // e.g. "🎵"
  final int position;    // display order in tab bar
}
```

With `fromMap`, `toMap`, `copyWith` methods matching the existing `AudioCard` pattern.

### `AudioCard` — no schema changes

The existing `collectionId` field (already present in the model and the `cards` DB column) stores the category `id`. Cards with `collectionId == null` are uncategorized.

---

## Database Changes

- Bump DB version from 1 → 2.
- Add an `onUpgrade` migration that creates the `categories` table.
- `DatabaseService` gains five new methods:
  - `readAllCategories()` → `List<Category>` ordered by `position ASC`
  - `createCategory(Category)` → insert
  - `updateCategory(Category)` → full row update
  - `deleteCategory(String id)` → delete; does **not** cascade. Orphaned `collectionId` values on cards are acceptable permanent DB state — no cleanup query needed.
  - `batchUpdateCategoryPositions(List<Category>)` → updates `position` for all provided categories in a single SQLite transaction (used by reorder)

---

## State Management

### New `categoriesProvider` — `lib/providers/categories_provider.dart`

```dart
// StateNotifierProvider<CategoriesNotifier, AsyncValue<List<Category>>>
```

- Mirrors the structure of the existing `cardsProvider`.
- Methods: `loadCategories()`, `addCategory(Category)`, `updateCategory(Category)`, `deleteCategory(String id)`, `reorderCategory(int oldIndex, int newIndex)`.
- `reorderCategory` recomputes `position` for the full list and persists all changes via a new `DatabaseService.batchUpdateCategoryPositions(List<Category>)` method that wraps all row updates in a single SQLite transaction.

### `cardsProvider` — no changes

Filtering by category is done at the UI layer, not in the provider, to keep it simple.

---

## Parent UI

### 1. New screen: `ParentCategoriesScreen` — `/parent/categories`

- **Header:** back arrow (→ `/parent`) | "Categories" title | `+` icon tap → navigates to `/parent/categories/edit` (no `state.extra`, creates a new category).
- **List:** `ReorderableListView` of categories. Each row:
  - Drag handle (left)
  - Emoji (28 px)
  - Category name
  - Pencil icon → edit this category (navigate to `/parent/categories/edit` with the `Category` object passed via `state.extra`, matching the existing `ParentEditScreen` pattern)
  - Trash icon → confirm-delete dialog. On confirm: `deleteCategory(id)`. Cards in that category become uncategorized (their `collectionId` is left as-is; they will still appear under "All").
- **Add Category button** (pinned bottom): green pill, navigates to `/parent/categories/edit`.
- Drag-to-reorder calls `reorderCategory` on drop.

### 2. New screen: `ParentCategoryEditScreen` — `/parent/categories/edit`

- **Inputs:**
  - Category name (text field, required)
  - Emoji (single text/emoji input field, required; validated as exactly 1 grapheme cluster using Dart's `characters` package, so any single visible emoji is accepted regardless of its underlying code-unit length)
- **Save:** creates or updates the category, then pops back.
- New categories get `position = max(existing positions) + 1`.

### 3. Modified: `ParentListScreen`

- Add a "Manage Categories" button/link in the header (or as a row at the top of the list) that navigates to `/parent/categories`.

### 4. Modified: `ParentEditScreen`

- Add a **Category** dropdown field below the existing title input.
- Populated from `categoriesProvider`: shows each category as `"[emoji] [name]"`, plus a "— None —" option at the top.
- Pre-selects the card's current `collectionId`.
- On save, writes the chosen category `id` (or `null`) into `collectionId`.

---

## Kid Home Screen (KidHomeScreen)

### Tab bar

- Rendered between the header and the card grid.
- Tabs:
  1. **"All"** — always present, always first, shows all cards (no filter).
  2. One tab per category, ordered by `position`.
- Active tab: solid green pill, white label.
- Inactive tabs: light-tinted pill, muted label.
- Tab format: `"[emoji] [name]"` (e.g. "🎵 Songs").
- Tab bar is horizontally scrollable if there are many categories (Flutter `SingleChildScrollView` with horizontal axis wrapping the `Row`).

### Card filtering

- Selected tab state held in a local `useState`/`StateProvider` on the screen.
- When a category tab is selected, `cardsProvider` list is filtered client-side: `cards.where((c) => c.collectionId == selectedCategoryId)`.
- When "All" is selected, no filter is applied.
- Uncategorized cards (collectionId == null) appear only under "All".

### Reads from `categoriesProvider`

- `KidHomeScreen` watches `categoriesProvider` to build the tab list.
- If `categoriesProvider` has no categories, the tab bar is not shown (falls back to flat grid, preserving current behavior).

---

## Navigation (router.dart)

Two new routes added under `/parent`:

| Route | Screen |
|-------|--------|
| `/parent/categories` | `ParentCategoriesScreen` |
| `/parent/categories/edit` | `ParentCategoryEditScreen` (optional `categoryId` passed via `state.extra`, matching the existing `ParentEditScreen` pattern) |

---

## Edge Cases

- **No categories defined:** Tab bar is hidden; home screen shows flat grid as today.
- **Card has a `collectionId` pointing to a deleted category:** Card appears only in "All" (orphaned `collectionId` is silently ignored since no matching category tab exists). Orphaned values are acceptable permanent DB state — no cleanup query is run on delete.
- **Reorder:** Positions are contiguous integers; on reorder, all affected rows are updated in a single batch.
- **Empty category:** A category with no cards still appears as a tab; tapping it shows an empty grid (no error state needed for MVP).

---

## Out of Scope

- Cards belonging to multiple categories (one-category-only design).
- Per-category card ordering (global `position` field on cards is reused as-is).
- Category icons other than emoji (no image/sprite picker for categories).
- Search or filtering by title within the kid home screen.
