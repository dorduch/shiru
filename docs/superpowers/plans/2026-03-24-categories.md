# Categories Feature Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let parents organize audio cards into emoji-labeled categories, and let children filter cards by category via a tab bar.

**Architecture:** New `categories` SQLite table + `Category` model + `categoriesProvider` (Riverpod StateNotifier). Two new parent screens for CRUD. Kid home screen gains a tab bar that filters cards client-side by `collectionId`. The existing `collectionId` field on `AudioCard` links cards to categories.

**Tech Stack:** Flutter, Riverpod, sqflite, go_router, uuid

**Spec:** `docs/superpowers/specs/2026-03-24-categories-design.md`

---

## File Map

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `lib/models/category.dart` | Category data model with fromMap/toMap/copyWith |
| Modify | `lib/db/database_service.dart` | DB migration v1→v2, categories CRUD + batch position update |
| Create | `lib/providers/categories_provider.dart` | CategoriesNotifier + categoriesProvider |
| Create | `lib/ui/parent_categories_screen.dart` | Category list with reorder/delete |
| Create | `lib/ui/parent_category_edit_screen.dart` | Create/edit category form |
| Modify | `lib/ui/parent_list_screen.dart:25-55` | Add "Categories" button in header |
| Modify | `lib/ui/parent_edit_screen.dart:27-96` | Add category dropdown to card edit form |
| Modify | `lib/router.dart:20-31` | Add two new routes under `/parent` |
| Modify | `lib/ui/kid_home_screen.dart:14-121` | Add tab bar + category filtering |

---

### Task 1: Category Model

**Files:**
- Create: `lib/models/category.dart`

- [ ] **Step 1: Create the Category model**

```dart
// lib/models/category.dart
class Category {
  final String id;
  final String name;
  final String emoji;
  final int position;

  Category({
    required this.id,
    required this.name,
    required this.emoji,
    required this.position,
  });

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'],
      name: map['name'],
      emoji: map['emoji'],
      position: map['position'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'emoji': emoji,
      'position': position,
    };
  }

  Category copyWith({
    String? name,
    String? emoji,
    int? position,
  }) {
    return Category(
      id: id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      position: position ?? this.position,
    );
  }
}
```

- [ ] **Step 2: Verify no analysis errors**

Run: `cd app && flutter analyze lib/models/category.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add app/lib/models/category.dart
git commit -m "feat: add Category data model"
```

---

### Task 2: Database Migration & Categories CRUD

**Files:**
- Modify: `lib/db/database_service.dart`

This task modifies `DatabaseService` to:
1. Bump version from 1 to 2
2. Add `onUpgrade` that creates the `categories` table
3. Also create the `categories` table in `_createDB` (for fresh installs)
4. Add five new methods for category operations

- [ ] **Step 1: Add import for Category model**

At the top of `lib/db/database_service.dart`, add:

```dart
import '../models/category.dart';
```

- [ ] **Step 2: Update _initDB to version 2 with onUpgrade**

Replace `lib/db/database_service.dart:17-26` — change version from `1` to `2` and add `onUpgrade`:

```dart
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }
```

- [ ] **Step 3: Add categories table to _createDB**

After the existing `cards` CREATE TABLE in `_createDB` (after line 42), add:

```dart
    await db.execute('''
CREATE TABLE categories (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  emoji TEXT NOT NULL,
  position INTEGER DEFAULT 0
)
''');
```

- [ ] **Step 4: Add _upgradeDB method**

Add after `_createDB`:

```dart
  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
CREATE TABLE categories (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  emoji TEXT NOT NULL,
  position INTEGER DEFAULT 0
)
''');
    }
  }
```

- [ ] **Step 5: Add five category CRUD methods**

Add before the `close()` method:

```dart
  // ── Categories ──

  Future<List<Category>> readAllCategories() async {
    final db = await instance.database;
    final result = await db.query('categories', orderBy: 'position ASC');
    return result.map((map) => Category.fromMap(map)).toList();
  }

  Future<Category> createCategory(Category category) async {
    final db = await instance.database;
    await db.insert('categories', category.toMap());
    return category;
  }

  Future<int> updateCategory(Category category) async {
    final db = await instance.database;
    return db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> deleteCategory(String id) async {
    final db = await instance.database;
    return await db.delete(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> batchUpdateCategoryPositions(List<Category> categories) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      for (final cat in categories) {
        await txn.update(
          'categories',
          {'position': cat.position},
          where: 'id = ?',
          whereArgs: [cat.id],
        );
      }
    });
  }
```

- [ ] **Step 6: Verify no analysis errors**

Run: `cd app && flutter analyze lib/db/database_service.dart`
Expected: No issues found

- [ ] **Step 7: Commit**

```bash
git add app/lib/db/database_service.dart
git commit -m "feat: add categories table migration and CRUD methods"
```

---

### Task 3: Categories Provider

**Files:**
- Create: `lib/providers/categories_provider.dart`

Mirrors the pattern in `lib/providers/cards_provider.dart`.

- [ ] **Step 1: Create the provider**

```dart
// lib/providers/categories_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category.dart';
import '../db/database_service.dart';

class CategoriesNotifier extends StateNotifier<AsyncValue<List<Category>>> {
  CategoriesNotifier() : super(const AsyncValue.loading()) {
    loadCategories();
  }

  Future<void> loadCategories() async {
    try {
      final categories = await DatabaseService.instance.readAllCategories();
      state = AsyncValue.data(categories);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> addCategory(Category category) async {
    await DatabaseService.instance.createCategory(category);
    await loadCategories();
  }

  Future<void> updateCategory(Category category) async {
    await DatabaseService.instance.updateCategory(category);
    await loadCategories();
  }

  Future<void> deleteCategory(String id) async {
    await DatabaseService.instance.deleteCategory(id);
    await loadCategories();
  }

  Future<void> reorderCategory(int oldIndex, int newIndex) async {
    final current = state.value;
    if (current == null) return;

    final reordered = List<Category>.from(current);
    final item = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, item);

    // Recompute positions as contiguous integers
    final updated = <Category>[];
    for (int i = 0; i < reordered.length; i++) {
      updated.add(reordered[i].copyWith(position: i));
    }

    state = AsyncValue.data(updated);
    await DatabaseService.instance.batchUpdateCategoryPositions(updated);
  }
}

final categoriesProvider =
    StateNotifierProvider<CategoriesNotifier, AsyncValue<List<Category>>>((ref) {
  return CategoriesNotifier();
});
```

- [ ] **Step 2: Verify no analysis errors**

Run: `cd app && flutter analyze lib/providers/categories_provider.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add app/lib/providers/categories_provider.dart
git commit -m "feat: add categoriesProvider with CRUD and reorder"
```

---

### Task 4: Parent Category Edit Screen

**Files:**
- Create: `lib/ui/parent_category_edit_screen.dart`

Build the create/edit category form first (before the list screen, since the list navigates to it).

- [ ] **Step 1: Create the screen**

```dart
// lib/ui/parent_category_edit_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../models/category.dart';
import '../providers/categories_provider.dart';

class ParentCategoryEditScreen extends ConsumerStatefulWidget {
  final Category? category;
  const ParentCategoryEditScreen({Key? key, this.category}) : super(key: key);

  @override
  ConsumerState<ParentCategoryEditScreen> createState() =>
      _ParentCategoryEditScreenState();
}

class _ParentCategoryEditScreenState
    extends ConsumerState<ParentCategoryEditScreen> {
  final _nameController = TextEditingController();
  final _emojiController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      _nameController.text = widget.category!.name;
      _emojiController.text = widget.category!.emoji;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emojiController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a category name.')),
      );
      return;
    }
    if (_emojiController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an emoji.')),
      );
      return;
    }

    final emoji = _emojiController.text.characters.first;

    final notifier = ref.read(categoriesProvider.notifier);

    if (widget.category != null) {
      await notifier.updateCategory(
        widget.category!.copyWith(name: name, emoji: emoji),
      );
    } else {
      final existing = ref.read(categoriesProvider).value ?? [];
      final maxPos = existing.isEmpty
          ? -1
          : existing.map((c) => c.position).reduce((a, b) => a > b ? a : b);
      await notifier.addCategory(Category(
        id: const Uuid().v4(),
        name: name,
        emoji: emoji,
        position: maxPos + 1,
      ));
    }

    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.category != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios, size: 28),
                      onPressed: () => context.pop(),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isEditing ? 'Edit Category' : 'New Category',
                      style: const TextStyle(
                          fontSize: 32, fontWeight: FontWeight.w800),
                    ),
                  ]),
                  GestureDetector(
                    onTap: _save,
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x4022C55E),
                              blurRadius: 12,
                              offset: Offset(0, 4))
                        ],
                      ),
                      child: const Row(children: [
                        Icon(Icons.check, color: Colors.white),
                        SizedBox(width: 8),
                        Text('Save',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              const Text('Emoji',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _emojiController,
                style: const TextStyle(fontSize: 32),
                decoration: InputDecoration(
                  hintText: '🎵',
                  hintStyle: const TextStyle(fontSize: 32, color: Colors.black26),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.all(16),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                          color: Color(0xFFE5E7EB), width: 2)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                          color: Color(0xFF22C55E), width: 2)),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Category Name',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: 'e.g. Songs',
                  hintStyle: const TextStyle(color: Colors.black38),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.all(16),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                          color: Color(0xFFE5E7EB), width: 2)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                          color: Color(0xFF22C55E), width: 2)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify no analysis errors**

Run: `cd app && flutter analyze lib/ui/parent_category_edit_screen.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add app/lib/ui/parent_category_edit_screen.dart
git commit -m "feat: add ParentCategoryEditScreen for create/edit category"
```

---

### Task 5: Parent Categories List Screen

**Files:**
- Create: `lib/ui/parent_categories_screen.dart`

- [ ] **Step 1: Create the screen**

```dart
// lib/ui/parent_categories_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/category.dart';
import '../providers/categories_provider.dart';

class ParentCategoriesScreen extends ConsumerWidget {
  const ParentCategoriesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios, size: 28),
                      onPressed: () => context.pop(),
                    ),
                    const SizedBox(width: 8),
                    const Text('Categories',
                        style: TextStyle(
                            fontSize: 32, fontWeight: FontWeight.w800)),
                  ]),
                  IconButton(
                    icon: const Icon(Icons.add, size: 28),
                    onPressed: () => context.push('/parent/categories/edit'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // List
              Expanded(
                child: categoriesAsync.when(
                  data: (categories) {
                    if (categories.isEmpty) {
                      return const Center(
                        child: Text('No categories yet.',
                            style: TextStyle(
                                fontSize: 20, color: Colors.black54)),
                      );
                    }
                    return ReorderableListView.builder(
                      itemCount: categories.length,
                      onReorder: (oldIndex, newIndex) {
                        if (newIndex > oldIndex) newIndex--;
                        ref
                            .read(categoriesProvider.notifier)
                            .reorderCategory(oldIndex, newIndex);
                      },
                      itemBuilder: (context, index) {
                        final cat = categories[index];
                        return _CategoryRow(
                          key: ValueKey(cat.id),
                          category: cat,
                          onEdit: () => context.push(
                            '/parent/categories/edit',
                            extra: cat,
                          ),
                          onDelete: () =>
                              _confirmDelete(context, ref, cat),
                        );
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Center(child: Text(e.toString())),
                ),
              ),
              // Bottom add button
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => context.push('/parent/categories/edit'),
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x4022C55E),
                          blurRadius: 12,
                          offset: Offset(0, 4))
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Add Category',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, Category category) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${category.emoji} ${category.name}"?'),
        content: const Text(
            'Cards in this category will become uncategorized.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              ref
                  .read(categoriesProvider.notifier)
                  .deleteCategory(category.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final Category category;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CategoryRow({
    Key? key,
    required this.category,
    required this.onEdit,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
              color: Colors.black12, blurRadius: 12, offset: Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.drag_handle, color: Colors.grey),
          const SizedBox(width: 12),
          Text(category.emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(category.name,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700)),
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.grey),
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.redAccent),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verify no analysis errors**

Run: `cd app && flutter analyze lib/ui/parent_categories_screen.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add app/lib/ui/parent_categories_screen.dart
git commit -m "feat: add ParentCategoriesScreen with reorder and delete"
```

---

### Task 6: Router — Add Category Routes

**Files:**
- Modify: `lib/router.dart`

- [ ] **Step 1: Add imports**

Add at the top of `lib/router.dart`:

```dart
import 'ui/parent_categories_screen.dart';
import 'ui/parent_category_edit_screen.dart';
import 'models/category.dart';
```

- [ ] **Step 2: Add two new routes under `/parent`**

In `lib/router.dart`, the `/parent` route currently has one child (`edit`). Add two more children after it (inside the `routes: [...]` array at line 22-30):

```dart
        GoRoute(
          path: 'categories',
          builder: (context, state) => const ParentCategoriesScreen(),
          routes: [
            GoRoute(
              path: 'edit',
              builder: (context, state) {
                final category = state.extra as Category?;
                return ParentCategoryEditScreen(category: category);
              },
            ),
          ],
        ),
```

- [ ] **Step 3: Verify no analysis errors**

Run: `cd app && flutter analyze lib/router.dart`
Expected: No issues found

- [ ] **Step 4: Commit**

```bash
git add app/lib/router.dart
git commit -m "feat: add /parent/categories and /parent/categories/edit routes"
```

---

### Task 7: Modify ParentListScreen — Add Categories Button

**Files:**
- Modify: `lib/ui/parent_list_screen.dart:25-55`

- [ ] **Step 1: Add a "Categories" button in the header row**

In `lib/ui/parent_list_screen.dart`, find the header `Row` (line 25). Insert a "Categories" button between the title row and the "Add Card" button. Replace the entire `Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, ...)` (lines 25-54) with:

```dart
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(icon: const Icon(Icons.arrow_back_ios, size: 28), onPressed: () => context.go('/')),
                      const SizedBox(width: 8),
                      const Text('Library', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
                    ]
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.push('/parent/categories'),
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: const Color(0xFFE5E7EB), width: 2),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.category, color: Color(0xFF6B7280), size: 20),
                              SizedBox(width: 8),
                              Text('Categories', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => context.go('/parent/edit'),
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B6B),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: const [BoxShadow(color: Color(0x40FF6B6B), blurRadius: 12, offset: Offset(0, 4))]
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.add, color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text('Add Card', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white))
                            ]
                          )
                        )
                      ),
                    ],
                  )
                ]
              ),
```

- [ ] **Step 2: Add go_router import if missing (already present)**

Already imported. No change needed.

- [ ] **Step 3: Verify no analysis errors**

Run: `cd app && flutter analyze lib/ui/parent_list_screen.dart`
Expected: No issues found

- [ ] **Step 4: Commit**

```bash
git add app/lib/ui/parent_list_screen.dart
git commit -m "feat: add Categories button to ParentListScreen header"
```

---

### Task 8: Modify ParentEditScreen — Add Category Dropdown

**Files:**
- Modify: `lib/ui/parent_edit_screen.dart`

- [ ] **Step 1: Add imports and state**

Add import at the top of `lib/ui/parent_edit_screen.dart`:

```dart
import '../providers/categories_provider.dart';
import '../models/category.dart' as cat_model;
```

In `_ParentEditScreenState`, add a field after `_color` (line 31):

```dart
  String? _selectedCategoryId;
```

- [ ] **Step 2: Load category when editing an existing card**

In `_loadCard` method (line 45-55), after loading the card fields, add:

```dart
      _selectedCategoryId = card.collectionId;
```

- [ ] **Step 3: Pass collectionId when saving**

In `_save()`, when constructing the `AudioCard` (line 88-96), add `collectionId`:

Replace:
```dart
      final card = AudioCard(
        id: widget.cardId ?? const Uuid().v4(),
        title: _titleController.text,
        color: _color,
        spriteKey: _spriteKeyController.text.isNotEmpty ? _spriteKeyController.text : null,
        audioPath: finalAudioPath,
        position: widget.cardId == null ? cardsList.length : 0,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );
```

With:
```dart
      final card = AudioCard(
        id: widget.cardId ?? const Uuid().v4(),
        collectionId: _selectedCategoryId,
        title: _titleController.text,
        color: _color,
        spriteKey: _spriteKeyController.text.isNotEmpty ? _spriteKeyController.text : null,
        audioPath: finalAudioPath,
        position: widget.cardId == null ? cardsList.length : 0,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );
```

- [ ] **Step 4: Add the category dropdown to the form UI**

In the `build` method, find the `Column` that contains "Card Title" (line 176). Add the category dropdown after the title section (after the title `TextField` and its `SizedBox(height: 24)`). Insert before "Custom GIF Search":

```dart
                        const Text('Category', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Consumer(
                          builder: (context, ref, _) {
                            final categoriesAsync = ref.watch(categoriesProvider);
                            final categories = categoriesAsync.value ?? [];
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE5E7EB), width: 2),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String?>(
                                  isExpanded: true,
                                  value: _selectedCategoryId,
                                  hint: const Text('— None —'),
                                  items: [
                                    const DropdownMenuItem<String?>(
                                      value: null,
                                      child: Text('— None —'),
                                    ),
                                    ...categories.map((c) => DropdownMenuItem<String?>(
                                      value: c.id,
                                      child: Text('${c.emoji} ${c.name}', style: const TextStyle(fontSize: 16)),
                                    )),
                                  ],
                                  onChanged: (value) {
                                    setState(() => _selectedCategoryId = value);
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
```

- [ ] **Step 5: Add collectionId to AudioCard.copyWith**

In `lib/models/audio_card.dart`, the `copyWith` method (line 56-77) does not support `collectionId`. Add it:

Replace the `copyWith` method:

```dart
  AudioCard copyWith({
    String? collectionId,
    bool clearCollectionId = false,
    String? title,
    String? color,
    String? spriteKey,
    String? customImagePath,
    String? audioPath,
    int? playbackPosition,
    int? position,
  }) {
    return AudioCard(
      id: id,
      collectionId: clearCollectionId ? null : (collectionId ?? this.collectionId),
      title: title ?? this.title,
      color: color ?? this.color,
      spriteKey: spriteKey ?? this.spriteKey,
      customImagePath: customImagePath ?? this.customImagePath,
      audioPath: audioPath ?? this.audioPath,
      playbackPosition: playbackPosition ?? this.playbackPosition,
      position: position ?? this.position,
      createdAt: createdAt,
    );
  }
```

- [ ] **Step 6: Verify no analysis errors**

Run: `cd app && flutter analyze lib/ui/parent_edit_screen.dart lib/models/audio_card.dart`
Expected: No issues found

- [ ] **Step 7: Commit**

```bash
git add app/lib/ui/parent_edit_screen.dart app/lib/models/audio_card.dart
git commit -m "feat: add category dropdown to ParentEditScreen"
```

---

### Task 9: Kid Home Screen — Category Tab Bar + Filtering

**Files:**
- Modify: `lib/ui/kid_home_screen.dart`

This is the core kid-facing change. We add a tab bar between the header and the grid, and filter cards when a tab is selected.

- [ ] **Step 1: Convert KidHomeScreen from ConsumerWidget to ConsumerStatefulWidget**

The screen needs local state for the selected category. Replace the class declaration and build method shell. In `lib/ui/kid_home_screen.dart`, replace lines 14-16:

```dart
class KidHomeScreen extends ConsumerStatefulWidget {
  const KidHomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<KidHomeScreen> createState() => _KidHomeScreenState();
}

class _KidHomeScreenState extends ConsumerState<KidHomeScreen> {
  String? _selectedCategoryId; // null means "All"
```

- [ ] **Step 2: Add imports**

At the top of `lib/ui/kid_home_screen.dart`, add:

```dart
import '../providers/categories_provider.dart';
import '../models/category.dart' as cat_model;
```

- [ ] **Step 3: Update the build method to add tab bar and filtering**

Replace the `build` method. The key changes are:
1. Watch `categoriesProvider`
2. Build a `_buildCategoryTabs` widget between the header and the grid
3. Filter cards based on `_selectedCategoryId`

Replace the entire `build` method (starting at `@override Widget build(...)`) with:

```dart
  @override
  Widget build(BuildContext context) {
    final cardsAsync = ref.watch(cardsProvider);
    final currentlyPlayingId = ref.watch(currentPlayingCardIdProvider);
    final isPlaying = ref.watch(isPlayingProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final categories = categoriesAsync.value ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFFFFBEB),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header (unchanged)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          'assets/images/app_icon.png',
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Shiru',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF222f3e),
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () => context.push('/pin'),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          )
                        ],
                      ),
                      child: const Icon(Icons.lock, color: Colors.grey),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 16),

              // Category tabs (only shown if categories exist)
              if (categories.isNotEmpty) ...[
                _buildCategoryTabs(categories),
                const SizedBox(height: 16),
              ],

              Expanded(
                child: cardsAsync.when(
                  data: (cards) {
                    // Filter by selected category
                    final filtered = _selectedCategoryId == null
                        ? cards
                        : cards.where((c) => c.collectionId == _selectedCategoryId).toList();

                    if (filtered.isEmpty) {
                      return Center(
                        child: Text(
                          _selectedCategoryId == null
                              ? "Ask your parent to add some cards!"
                              : "No cards in this category yet!",
                          style: const TextStyle(fontSize: 24, color: Colors.black54),
                        ),
                      );
                    }
                    return GridView.builder(
                      padding: const EdgeInsets.only(bottom: 24),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 240,
                        crossAxisSpacing: 24,
                        mainAxisSpacing: 24,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final card = filtered[index];
                        final isPlayingThis = currentlyPlayingId == card.id;
                        final isAnotherPlaying = currentlyPlayingId != null && currentlyPlayingId != card.id;
                        return AudioCardTile(
                          card: card,
                          isPlayingThis: isPlayingThis,
                          isPlayingGlobal: isPlaying,
                          isAnotherPlaying: isAnotherPlaying,
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text('Error: $err')),
                )
              ),

              const SizedBox(height: 24),
              if (currentlyPlayingId != null)
                 _buildPlayerPill(ref, currentlyPlayingId, isPlaying)
            ]
          )
        )
      )
    );
  }

  Widget _buildCategoryTabs(List<cat_model.Category> categories) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildTab(label: 'All', isActive: _selectedCategoryId == null, onTap: () {
            setState(() => _selectedCategoryId = null);
          }),
          const SizedBox(width: 8),
          ...categories.map((cat) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _buildTab(
              label: '${cat.emoji} ${cat.name}',
              isActive: _selectedCategoryId == cat.id,
              onTap: () {
                setState(() => _selectedCategoryId = cat.id);
              },
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildTab({required String label, required bool isActive, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF22C55E) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isActive ? Colors.white : const Color(0xFF6B7280),
            ),
          ),
        ),
      ),
    );
  }
```

- [ ] **Step 4: Move _buildPlayerPill to the new state class**

The `_buildPlayerPill` method is currently on the old `KidHomeScreen` (ConsumerWidget). It needs to be inside `_KidHomeScreenState`. Move it (lines 125-204) into `_KidHomeScreenState`, changing `WidgetRef ref` parameter — use `ref` directly since it's available in `ConsumerState`:

```dart
  Widget _buildPlayerPill(WidgetRef ref, String playingId, bool isPlayingGlobal) {
    // ... body unchanged ...
  }
```

This method signature stays the same since we're passing `ref` explicitly from `build`.

- [ ] **Step 5: Verify no analysis errors**

Run: `cd app && flutter analyze lib/ui/kid_home_screen.dart`
Expected: No issues found

- [ ] **Step 6: Commit**

```bash
git add app/lib/ui/kid_home_screen.dart
git commit -m "feat: add category tab bar and filtering to KidHomeScreen"
```

---

### Task 10: Manual Integration Test

**Files:** None (verification only)

- [ ] **Step 1: Run the app**

Run: `cd app && flutter run`

- [ ] **Step 2: Verify parent flow**

1. Tap lock icon → enter PIN `1234` → arrive at Library
2. Tap "Categories" button → see empty categories screen
3. Tap "Add Category" → create "🎵 Songs" → save → see it in the list
4. Add a second category "🌙 Bedtime"
5. Drag to reorder → verify order persists after leaving and returning
6. Edit a category (tap pencil) → change name → save → verify updated
7. Delete a category (tap trash) → confirm → verify it disappears

- [ ] **Step 3: Verify card assignment**

1. Go back to Library → tap "Add Card" or edit an existing card
2. Verify "Category" dropdown appears with "— None —", "🎵 Songs", "🌙 Bedtime"
3. Assign a category → save

- [ ] **Step 4: Verify kid home screen**

1. Go to home screen (tap back to `/`)
2. Verify tab bar appears with "All", "🎵 Songs", "🌙 Bedtime"
3. Tap "🎵 Songs" → verify only cards assigned to Songs are shown
4. Tap "All" → verify all cards shown
5. Tap "🌙 Bedtime" with no assigned cards → verify empty state message

- [ ] **Step 5: Verify edge case — delete category with assigned cards**

1. Delete the "🎵 Songs" category via parent categories screen
2. Go back to kid home → verify the tab is gone
3. Verify the previously-assigned cards appear in "All"

- [ ] **Step 6: Final commit**

```bash
git add -A
git commit -m "feat: categories feature complete"
```
