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
    await DatabaseService.instance.deleteCategoryAndUnassignCards(id);
    await loadCategories();
  }

  Future<void> reorderCategory(int oldIndex, int newIndex) async {
    final current = state.value;
    if (current == null) return;

    final reordered = List<Category>.from(current);
    final item = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, item);

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
