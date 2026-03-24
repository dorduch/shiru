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
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Emoji — small square
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Emoji',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 72,
                        child: TextField(
                          controller: _emojiController,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 32),
                          decoration: InputDecoration(
                            hintText: '🎵',
                            hintStyle: const TextStyle(fontSize: 32, color: Colors.black26),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
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
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  // Category Name — fills remaining width
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
