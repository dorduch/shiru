// lib/ui/parent_category_edit_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../models/category.dart';
import '../models/audio_card.dart';
import '../providers/categories_provider.dart';
import '../providers/cards_provider.dart';
import '../db/database_service.dart';

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

    final cardsAsync = ref.watch(cardsProvider);
    final allCategories = ref.watch(categoriesProvider).value ?? [];
    final categoryId = widget.category?.id;

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
              const SizedBox(height: 24),
              // Emoji + Name row
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
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
              // Card assignment list (only when editing)
              if (isEditing) ...[
                const SizedBox(height: 28),
                const Text('Cards',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Expanded(
                  child: cardsAsync.when(
                    data: (cards) {
                      if (cards.isEmpty) {
                        return const Center(
                          child: Text('No cards yet.',
                              style: TextStyle(fontSize: 16, color: Colors.black54)),
                        );
                      }
                      return ListView.separated(
                        itemCount: cards.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final card = cards[index];
                          final isInThis = card.collectionId == categoryId;
                          final otherCat = (!isInThis && card.collectionId != null)
                              ? allCategories.where((c) => c.id == card.collectionId).firstOrNull
                              : null;

                          return GestureDetector(
                            onTap: () => _toggleCard(card, isInThis),
                            child: Container(
                              height: 64,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: isInThis ? const Color(0xFFECFDF5) : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: isInThis
                                    ? Border.all(color: const Color(0xFF22C55E), width: 2)
                                    : Border.all(color: const Color(0xFFE5E7EB), width: 1),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isInThis ? Icons.check_circle : Icons.circle_outlined,
                                    color: isInThis ? const Color(0xFF22C55E) : const Color(0xFFD1D5DB),
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      card.title,
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (otherCat != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF3F4F6),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${otherCat.emoji} ${otherCat.name}',
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, s) => Center(child: Text(e.toString())),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleCard(AudioCard card, bool isCurrentlyInThis) async {
    final newCollectionId = isCurrentlyInThis ? null : widget.category!.id;
    final updated = AudioCard(
      id: card.id,
      collectionId: newCollectionId,
      title: card.title,
      color: card.color,
      spriteKey: card.spriteKey,
      customImagePath: card.customImagePath,
      audioPath: card.audioPath,
      playbackPosition: card.playbackPosition,
      position: card.position,
      createdAt: card.createdAt,
    );
    await DatabaseService.instance.updateCard(updated);
    ref.read(cardsProvider.notifier).loadCards();
  }
}
