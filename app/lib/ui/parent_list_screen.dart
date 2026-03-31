import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' as intl;
import 'package:just_audio/just_audio.dart';

import '../models/audio_card.dart';
import '../models/category.dart';
import '../models/sprites.dart';
import '../providers/audio_player_provider.dart';
import '../providers/cards_provider.dart';
import '../providers/categories_provider.dart';
import 'pixel_sprite.dart';

class ParentListScreen extends ConsumerWidget {
  const ParentListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardsAsync = ref.watch(cardsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final categoriesById = {
      for (final category in categoriesAsync.value ?? <Category>[])
        category.id: category,
    };
    final width = MediaQuery.of(context).size.width;
    final isTwoColumn = width >= 980;
    final childAspectRatio = isTwoColumn ? (width >= 1280 ? 3.0 : 2.65) : 3.15;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _LibraryHeader(
                onBulkImport: () => context.push('/parent/bulk-import'),
                onAddCard: () => context.go('/parent/edit'),
                onMenuSelected: (action) {
                  switch (action) {
                    case _LibraryMenuAction.changePin:
                      context.push('/parent/change-pin');
                      break;
                    case _LibraryMenuAction.categories:
                      context.push('/parent/categories');
                      break;
                  }
                },
              ),
              const SizedBox(height: 24),
              Expanded(
                child: cardsAsync.when(
                  data: (cards) {
                    if (cards.isEmpty) {
                      return _LibraryEmptyState(
                        onAddCard: () => context.go('/parent/edit'),
                        onBulkImport: () => context.push('/parent/bulk-import'),
                      );
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.only(bottom: 12),
                      itemCount: cards.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isTwoColumn ? 2 : 1,
                        crossAxisSpacing: 18,
                        mainAxisSpacing: 18,
                        childAspectRatio: childAspectRatio,
                      ),
                      itemBuilder: (context, index) {
                        final card = cards[index];
                        return _LibraryCardTile(
                          card: card,
                          category: categoriesById[card.collectionId],
                        );
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(child: Text(error.toString())),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LibraryHeader extends StatelessWidget {
  final VoidCallback onBulkImport;
  final VoidCallback onAddCard;
  final ValueChanged<_LibraryMenuAction> onMenuSelected;

  const _LibraryHeader({
    required this.onBulkImport,
    required this.onAddCard,
    required this.onMenuSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 28),
              onPressed: () => context.go('/'),
            ),
            const SizedBox(width: 8),
            const Text(
              'Library',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _LibraryActionButton(
                  label: 'Bulk Import',
                  icon: Icons.folder_open_outlined,
                  variant: _LibraryActionVariant.secondary,
                  onTap: onBulkImport,
                ),
                _LibraryActionButton(
                  label: 'Add Card',
                  icon: Icons.add,
                  variant: _LibraryActionVariant.primary,
                  onTap: onAddCard,
                ),
                PopupMenuButton<_LibraryMenuAction>(
                  tooltip: 'Library settings',
                  onSelected: onMenuSelected,
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: _LibraryMenuAction.changePin,
                      child: _MenuLabel(
                        icon: Icons.lock_outline,
                        label: 'Change PIN',
                      ),
                    ),
                    PopupMenuItem(
                      value: _LibraryMenuAction.categories,
                      child: _MenuLabel(
                        icon: Icons.category_outlined,
                        label: 'Categories',
                      ),
                    ),
                  ],
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFE5E7EB),
                        width: 2,
                      ),
                    ),
                    child: const Icon(Icons.settings, color: Color(0xFF6B7280)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LibraryEmptyState extends StatelessWidget {
  final VoidCallback onAddCard;
  final VoidCallback onBulkImport;

  const _LibraryEmptyState({
    required this.onAddCard,
    required this.onBulkImport,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x120F172A),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.library_music_outlined,
                    size: 42,
                    color: Color(0xFFFF6B6B),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Start building your library',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Add a single recording or import a batch of audio files to get the first library ready.',
                  style: TextStyle(
                    fontSize: 18,
                    height: 1.45,
                    color: Color(0xFF6B7280),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    _LibraryActionButton(
                      label: 'Add Card',
                      icon: Icons.add,
                      variant: _LibraryActionVariant.primary,
                      onTap: onAddCard,
                    ),
                    _LibraryActionButton(
                      label: 'Bulk Import',
                      icon: Icons.folder_open_outlined,
                      variant: _LibraryActionVariant.secondary,
                      onTap: onBulkImport,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LibraryCardTile extends ConsumerWidget {
  final AudioCard card;
  final Category? category;

  const _LibraryCardTile({required this.card, required this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTitleRtl = intl.Bidi.detectRtlDirectionality(card.title);
    final currentCardId = ref.watch(currentPlayingCardIdProvider);
    final isPlaying = ref.watch(isPlayingProvider);
    final isPreviewing = currentCardId == card.id && isPlaying;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          _CardArtwork(card: card),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: isTitleRtl
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Text(
                  card.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: isTitleRtl ? TextAlign.right : TextAlign.left,
                  textDirection: isTitleRtl
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (category != null)
                      _MetaChip(
                        label: '${category!.emoji} ${category!.name}',
                        backgroundColor: const Color(0xFFECFDF3),
                        foregroundColor: const Color(0xFF16A34A),
                      ),
                    _MetaChip(
                      label: _formatDate(card.createdAt),
                      backgroundColor: const Color(0xFFF3F4F6),
                      foregroundColor: const Color(0xFF6B7280),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RoundIconButton(
                semanticLabel: isPreviewing
                    ? 'Stop preview for ${card.title}'
                    : 'Preview ${card.title}',
                icon: isPreviewing
                    ? Icons.stop_rounded
                    : Icons.play_arrow_rounded,
                foregroundColor: isPreviewing
                    ? const Color(0xFF166534)
                    : const Color(0xFF16A34A),
                backgroundColor: const Color(0xFFDCFCE7),
                onPressed: () => _togglePreview(context, ref),
              ),
              const SizedBox(width: 10),
              _RoundIconButton(
                semanticLabel: 'Edit ${card.title}',
                icon: Icons.edit_outlined,
                foregroundColor: const Color(0xFF6B7280),
                backgroundColor: const Color(0xFFF3F4F6),
                onPressed: () => context.push('/parent/edit', extra: card.id),
              ),
              const SizedBox(width: 10),
              _RoundIconButton(
                semanticLabel: 'Delete ${card.title}',
                icon: Icons.delete_outline,
                foregroundColor: const Color(0xFFEF4444),
                backgroundColor: const Color(0xFFFEF2F2),
                onPressed: () =>
                    ref.read(cardsProvider.notifier).deleteCard(card.id),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _togglePreview(BuildContext context, WidgetRef ref) async {
    final player = ref.read(audioPlayerProvider);
    final currentCardId = ref.read(currentPlayingCardIdProvider);
    final isPlaying = ref.read(isPlayingProvider);

    if (currentCardId == card.id && isPlaying) {
      await player.stop();
      ref.read(currentPlayingCardIdProvider.notifier).state = null;
      ref.read(isPlayingProvider.notifier).state = false;
      return;
    }

    try {
      await player.stop();
      ref.read(currentPlayingCardIdProvider.notifier).state = card.id;
      ref.read(isPlayingProvider.notifier).state = true;
      await player.setFilePath(card.audioPath);
      await player.play();
      player.playerStateStream
          .firstWhere(
            (state) => state.processingState == ProcessingState.completed,
          )
          .then((_) {
            if (ref.read(currentPlayingCardIdProvider) == card.id) {
              ref.read(currentPlayingCardIdProvider.notifier).state = null;
              ref.read(isPlayingProvider.notifier).state = false;
            }
          });
    } catch (_) {
      ref.read(currentPlayingCardIdProvider.notifier).state = null;
      ref.read(isPlayingProvider.notifier).state = false;
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not preview this story right now.'),
        ),
      );
    }
  }

  String _formatDate(int createdAt) {
    final createdDate = DateTime.fromMillisecondsSinceEpoch(createdAt);
    return intl.DateFormat('MMM d').format(createdDate);
  }
}

class _CardArtwork extends StatelessWidget {
  final AudioCard card;

  const _CardArtwork({required this.card});

  @override
  Widget build(BuildContext context) {
    final spriteDef = autoAssignSprite(card.title);
    final customImagePath = card.customImagePath;
    final imageFile = customImagePath != null && customImagePath.isNotEmpty
        ? File(customImagePath)
        : null;
    final hasCustomImage = imageFile != null && imageFile.existsSync();

    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        color: hexOrFallback(card.color),
        borderRadius: BorderRadius.circular(22),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasCustomImage
          ? Image.file(imageFile, fit: BoxFit.cover)
          : Center(
              child: PixelSprite(
                sprite: spriteDef,
                state: SpriteState.idle,
                scale: 2.7,
              ),
            ),
    );
  }
}

class _LibraryActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final _LibraryActionVariant variant;
  final VoidCallback onTap;

  const _LibraryActionButton({
    required this.label,
    required this.icon,
    required this.variant,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isPrimary = variant == _LibraryActionVariant.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(27),
        child: Ink(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: isPrimary ? const Color(0xFFFF6B6B) : Colors.white,
            borderRadius: BorderRadius.circular(27),
            border: isPrimary
                ? null
                : Border.all(color: const Color(0xFFE5E7EB), width: 2),
            boxShadow: isPrimary
                ? const [
                    BoxShadow(
                      color: Color(0x1AFF6B6B),
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: isPrimary ? Colors.white : const Color(0xFF6B7280),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isPrimary ? Colors.white : const Color(0xFF374151),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final String semanticLabel;
  final IconData icon;
  final Color foregroundColor;
  final Color backgroundColor;
  final VoidCallback onPressed;

  const _RoundIconButton({
    required this.semanticLabel,
    required this.icon,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(icon, color: foregroundColor, size: 24),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  const _MetaChip({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: foregroundColor,
        ),
      ),
    );
  }
}

class _MenuLabel extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MenuLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF6B7280)),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
      ],
    );
  }
}

enum _LibraryActionVariant { primary, secondary }

enum _LibraryMenuAction { changePin, categories }
