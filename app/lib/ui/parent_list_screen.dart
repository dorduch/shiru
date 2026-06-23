import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' as intl;
import 'package:just_audio/just_audio.dart';

import '../models/audio_card.dart';
import '../models/category.dart';
import '../models/sprites.dart';
import '../providers/auth_provider.dart';
import '../providers/audio_player_provider.dart';
import '../providers/cards_provider.dart';
import '../providers/categories_provider.dart';
import '../services/export_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_responsive.dart';
import '../theme/app_typography.dart';
import 'pixel_sprite.dart';

class ParentListScreen extends ConsumerStatefulWidget {
  const ParentListScreen({super.key});

  @override
  ConsumerState<ParentListScreen> createState() => _ParentListScreenState();
}

class _ParentListScreenState extends ConsumerState<ParentListScreen> {
  String? _selectedCategoryId;

  @override
  Widget build(BuildContext context) {
    final cardsAsync = ref.watch(cardsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final categories = categoriesAsync.value ?? <Category>[];
    final categoriesById = {
      for (final category in categories) category.id: category,
    };
    final sizeClass = AppResponsive.sizeClass(context);
    final isPortrait = AppResponsive.isPortrait(context);
    final isTwoColumn = MediaQuery.sizeOf(context).width >= 720;
    final gridChildAspectRatio = switch ((sizeClass, isPortrait)) {
      (SizeClass.lg, _) => 2.35,
      (SizeClass.md, _) => 1.45,
      _ => 2.2,
    };

    return Scaffold(
      backgroundColor: AppColors.backgroundParent,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppResponsive.basePadding(context),
            vertical: AppResponsive.spacing(context, 16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _LibraryHeader(
                onMenuSelected: (action) {
                  switch (action) {
                    case _LibraryMenuAction.changePin:
                      context.push('/parent/change-pin');
                      break;
                    case _LibraryMenuAction.about:
                      context.push('/parent/about');
                      break;
                    case _LibraryMenuAction.categories:
                      context.push('/parent/categories');
                      break;
                  }
                },
              ),
              SizedBox(height: AppResponsive.spacing(context, 20)),
              Expanded(
                child: cardsAsync.when(
                  data: (cards) {
                    if (cards.isEmpty) {
                      return _LibraryEmptyState(
                        onAddCard: () => context.go('/parent/edit'),
                        onBulkImport: () => context.push('/parent/bulk-import'),
                        onGenerateStory: () =>
                            context.push('/parent/generate-story'),
                      );
                    }

                    final effectiveCategoryId =
                        categoriesById.containsKey(_selectedCategoryId)
                        ? _selectedCategoryId
                        : null;
                    final visibleCards = effectiveCategoryId == null
                        ? cards
                        : cards
                              .where(
                                (card) =>
                                    card.collectionId == effectiveCategoryId,
                              )
                              .toList();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _LibraryToolbar(
                          onAddCard: () => context.go('/parent/edit'),
                          onBulkImport: () =>
                              context.push('/parent/bulk-import'),
                          onGenerateStory: () =>
                              context.push('/parent/generate-story'),
                        ),
                        if (categories.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _CategoryFilters(
                            categories: categories,
                            selectedCategoryId: effectiveCategoryId,
                            onSelected: (categoryId) {
                              setState(() => _selectedCategoryId = categoryId);
                            },
                          ),
                        ],
                        const SizedBox(height: 16),
                        Expanded(
                          child: visibleCards.isEmpty
                              ? _FilteredLibraryEmptyState(
                                  categoryName:
                                      categoriesById[effectiveCategoryId]?.name,
                                  onClearFilter: () {
                                    setState(() => _selectedCategoryId = null);
                                  },
                                )
                              : isTwoColumn
                              ? GridView.builder(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  itemCount: visibleCards.length,
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        crossAxisSpacing: 18,
                                        mainAxisSpacing: 18,
                                        childAspectRatio: gridChildAspectRatio,
                                      ),
                                  itemBuilder: (context, index) {
                                    final card = visibleCards[index];
                                    return _LibraryCardTile(
                                      card: card,
                                      category:
                                          categoriesById[card.collectionId],
                                      isListLayout: false,
                                    );
                                  },
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  itemCount: visibleCards.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 16),
                                  itemBuilder: (context, index) {
                                    final card = visibleCards[index];
                                    return _LibraryCardTile(
                                      card: card,
                                      category:
                                          categoriesById[card.collectionId],
                                      isListLayout: true,
                                    );
                                  },
                                ),
                        ),
                      ],
                    );
                  },
                  loading: () => const _LibraryLoadingState(),
                  error: (_, _) => _LibraryErrorState(
                    onRetry: () => ref.read(cardsProvider.notifier).loadCards(),
                  ),
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
  final ValueChanged<_LibraryMenuAction> onMenuSelected;

  const _LibraryHeader({required this.onMenuSelected});

  @override
  Widget build(BuildContext context) {
    final buttonSize = AppResponsive.buttonSize(
      context,
    ).clamp(48.0, 64.0).toDouble();

    return Row(
      children: [
        IconButton(
          tooltip: 'Back to player',
          constraints: BoxConstraints.tightFor(
            width: buttonSize,
            height: buttonSize,
          ),
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: AppResponsive.iconSize(context, 24),
            color: AppColors.textMuted,
          ),
          onPressed: () => context.go('/'),
        ),
        SizedBox(width: AppResponsive.spacing(context, 8)),
        Expanded(
          child: Text(
            'Library',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.displayLarge.copyWith(
              fontSize: AppResponsive.fontSize(context, 32),
              color: AppColors.textPrimary,
            ),
          ),
        ),
        SizedBox(width: AppResponsive.spacing(context, 8)),
        PopupMenuButton<_LibraryMenuAction>(
          tooltip: 'Library settings',
          onSelected: onMenuSelected,
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: _LibraryMenuAction.changePin,
              child: _MenuLabel(icon: Icons.lock_outline, label: 'Change PIN'),
            ),
            PopupMenuItem(
              value: _LibraryMenuAction.categories,
              child: _MenuLabel(
                icon: Icons.category_outlined,
                label: 'Categories',
              ),
            ),
            PopupMenuItem(
              value: _LibraryMenuAction.about,
              child: _MenuLabel(icon: Icons.info_outline, label: 'About Shiru'),
            ),
          ],
          child: Container(
            width: buttonSize,
            height: buttonSize,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: const Icon(
              Icons.settings_rounded,
              color: AppColors.textSecondary,
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
  final VoidCallback onGenerateStory;

  const _LibraryEmptyState({
    required this.onAddCard,
    required this.onBulkImport,
    required this.onGenerateStory,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isWide =
        media.size.width >= 720 && media.orientation == Orientation.landscape;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compactTopPadding = (constraints.maxHeight * 0.08)
            .clamp(20.0, 64.0)
            .toDouble();
        return SingleChildScrollView(
          padding: EdgeInsets.only(
            top: isWide ? 16 : compactTopPadding,
            bottom: 24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: isWide
                  ? Row(
                      key: const ValueKey('library-empty-wide'),
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Expanded(child: _EmptyStateArtwork(isWide: true)),
                        SizedBox(width: AppResponsive.spacing(context, 44)),
                        Expanded(
                          child: _EmptyStateContent(
                            textAlign: TextAlign.left,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            onAddCard: onAddCard,
                            onBulkImport: onBulkImport,
                            onGenerateStory: onGenerateStory,
                          ),
                        ),
                      ],
                    )
                  : SizedBox(
                      width: media.size.width,
                      child: Column(
                        key: const ValueKey('library-empty-compact'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const _EmptyStateArtwork(isWide: false),
                          const SizedBox(height: 24),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: SizedBox(
                              width: double.infinity,
                              child: _EmptyStateContent(
                                textAlign: TextAlign.center,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                onAddCard: onAddCard,
                                onBulkImport: onBulkImport,
                                onGenerateStory: onGenerateStory,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyStateArtwork extends StatelessWidget {
  final bool isWide;

  const _EmptyStateArtwork({required this.isWide});

  @override
  Widget build(BuildContext context) {
    final dimension = isWide ? 196.0 : 144.0;
    final spriteScale = isWide ? 7.0 : 5.5;

    return Semantics(
      image: true,
      label: 'Animated moon character',
      child: Center(
        child: SizedBox.square(
          dimension: dimension,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.logoSurface,
                    borderRadius: BorderRadius.circular(isWide ? 56 : 44),
                  ),
                ),
              ),
              Positioned(
                top: isWide ? 22 : 16,
                right: isWide ? 24 : 18,
                child: const _PixelSpark(color: AppColors.logoMint, size: 18),
              ),
              Positioned(
                bottom: isWide ? 24 : 18,
                left: isWide ? 26 : 20,
                child: const _PixelSpark(color: Color(0xFFFFE3A3), size: 13),
              ),
              PixelSprite(
                sprite: predefinedSprites['moon']!,
                state: SpriteState.idle,
                scale: spriteScale,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PixelSpark extends StatelessWidget {
  final Color color;
  final double size;

  const _PixelSpark({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Transform.rotate(
        angle: 0.78,
        child: SizedBox.square(
          dimension: size,
          child: ColoredBox(color: color),
        ),
      ),
    );
  }
}

class _EmptyStateContent extends StatelessWidget {
  final TextAlign textAlign;
  final CrossAxisAlignment crossAxisAlignment;
  final VoidCallback onAddCard;
  final VoidCallback onBulkImport;
  final VoidCallback onGenerateStory;

  const _EmptyStateContent({
    required this.textAlign,
    required this.crossAxisAlignment,
    required this.onAddCard,
    required this.onBulkImport,
    required this.onGenerateStory,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = AppResponsive.isCompact(context);
    final centerActions = textAlign == TextAlign.center;

    return Column(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Add your first card',
          textAlign: textAlign,
          style: AppTypography.displayLarge.copyWith(
            fontSize: AppResponsive.fontSize(context, isCompact ? 30 : 34),
            color: AppColors.textPrimary,
            height: 1.12,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Record a story, choose a song, or add a family video.',
          textAlign: textAlign,
          style: AppTypography.bodySmall.copyWith(
            fontSize: AppResponsive.fontSize(
              context,
              17,
            ).clamp(14.0, 21.0).toDouble(),
            color: AppColors.textSecondary,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 26),
        if (isCompact)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _LibraryActionButton(
                label: 'New card',
                icon: Icons.add_rounded,
                variant: _LibraryActionVariant.primary,
                onTap: onAddCard,
                expand: true,
              ),
              const SizedBox(height: 12),
              _LibraryActionButton(
                label: 'Import multiple',
                icon: Icons.folder_open_outlined,
                variant: _LibraryActionVariant.secondary,
                onTap: onBulkImport,
                expand: true,
              ),
              const SizedBox(height: 6),
              _LibraryActionButton(
                label: 'Generate a story',
                icon: Icons.auto_awesome_outlined,
                variant: _LibraryActionVariant.tertiary,
                onTap: onGenerateStory,
                expand: true,
              ),
            ],
          )
        else
          Column(
            crossAxisAlignment: centerActions
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: centerActions
                    ? WrapAlignment.center
                    : WrapAlignment.start,
                children: [
                  _LibraryActionButton(
                    label: 'New card',
                    icon: Icons.add_rounded,
                    variant: _LibraryActionVariant.primary,
                    onTap: onAddCard,
                  ),
                  _LibraryActionButton(
                    label: 'Import multiple',
                    icon: Icons.folder_open_outlined,
                    variant: _LibraryActionVariant.secondary,
                    onTap: onBulkImport,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _LibraryActionButton(
                label: 'Generate a story',
                icon: Icons.auto_awesome_outlined,
                variant: _LibraryActionVariant.tertiary,
                onTap: onGenerateStory,
              ),
            ],
          ),
      ],
    );
  }
}

class _LibraryToolbar extends StatelessWidget {
  final VoidCallback onAddCard;
  final VoidCallback onBulkImport;
  final VoidCallback onGenerateStory;

  const _LibraryToolbar({
    required this.onAddCard,
    required this.onBulkImport,
    required this.onGenerateStory,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = AppResponsive.isCompact(context);

    return Semantics(
      container: true,
      label: 'Library actions',
      child: isCompact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _LibraryActionButton(
                        label: 'New card',
                        icon: Icons.add_rounded,
                        variant: _LibraryActionVariant.primary,
                        onTap: onAddCard,
                        expand: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _LibraryActionButton(
                        label: 'Import media',
                        icon: Icons.folder_open_outlined,
                        variant: _LibraryActionVariant.secondary,
                        onTap: onBulkImport,
                        expand: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                _LibraryActionButton(
                  label: 'Generate story',
                  icon: Icons.auto_awesome_outlined,
                  variant: _LibraryActionVariant.tertiary,
                  onTap: onGenerateStory,
                ),
              ],
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _LibraryActionButton(
                    label: 'New card',
                    icon: Icons.add_rounded,
                    variant: _LibraryActionVariant.primary,
                    onTap: onAddCard,
                  ),
                  const SizedBox(width: 10),
                  _LibraryActionButton(
                    label: 'Import media',
                    icon: Icons.folder_open_outlined,
                    variant: _LibraryActionVariant.secondary,
                    onTap: onBulkImport,
                  ),
                  const SizedBox(width: 6),
                  _LibraryActionButton(
                    label: 'Generate story',
                    icon: Icons.auto_awesome_outlined,
                    variant: _LibraryActionVariant.tertiary,
                    onTap: onGenerateStory,
                  ),
                ],
              ),
            ),
    );
  }
}

class _CategoryFilters extends StatelessWidget {
  final List<Category> categories;
  final String? selectedCategoryId;
  final ValueChanged<String?> onSelected;

  const _CategoryFilters({
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Filter library by category',
      child: SizedBox(
        height: 48,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: categories.length + 1,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final category = index == 0 ? null : categories[index - 1];
            final id = category?.id;
            return _CategoryFilterChip(
              label: category == null
                  ? 'All'
                  : '${category.emoji} ${category.name}',
              selected: selectedCategoryId == id,
              onTap: () => onSelected(id),
            );
          },
        ),
      ),
    );
  }
}

class _CategoryFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label category',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFDCFCE7) : AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? AppColors.primaryStrong : AppColors.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Center(
              child: Text(
                label,
                style: AppTypography.labelLarge.copyWith(
                  color: selected ? AppColors.primaryInk : AppColors.textMuted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FilteredLibraryEmptyState extends StatelessWidget {
  final String? categoryName;
  final VoidCallback onClearFilter;

  const _FilteredLibraryEmptyState({
    required this.categoryName,
    required this.onClearFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.filter_alt_off_outlined,
            size: 42,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 14),
          Text(
            categoryName == null
                ? 'No cards here yet'
                : 'No cards in $categoryName yet',
            textAlign: TextAlign.center,
            style: AppTypography.headlineMedium.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          _LibraryActionButton(
            label: 'Show all cards',
            icon: Icons.clear_all_rounded,
            variant: _LibraryActionVariant.secondary,
            onTap: onClearFilter,
          ),
        ],
      ),
    );
  }
}

class _LibraryLoadingState extends StatelessWidget {
  const _LibraryLoadingState();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Loading library',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 276,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.backgroundMuted,
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            const SizedBox(height: 22),
            for (var index = 0; index < 3; index++) ...[
              Container(
                height: 112,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.border),
                ),
              ),
              if (index < 2) const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    );
  }
}

class _LibraryErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _LibraryErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        liveRegion: true,
        container: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.library_music_outlined,
                size: 34,
                color: AppColors.destructiveDark,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              "Couldn't load your library",
              textAlign: TextAlign.center,
              style: AppTypography.headlineMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check your device storage, then try again.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            _LibraryActionButton(
              label: 'Retry',
              icon: Icons.refresh_rounded,
              variant: _LibraryActionVariant.primary,
              onTap: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _LibraryCardTile extends ConsumerStatefulWidget {
  final AudioCard card;
  final Category? category;
  final bool isListLayout;

  const _LibraryCardTile({
    required this.card,
    required this.category,
    required this.isListLayout,
  });

  @override
  ConsumerState<_LibraryCardTile> createState() => _LibraryCardTileState();
}

class _LibraryCardTileState extends ConsumerState<_LibraryCardTile> {
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final category = widget.category;
    final isTitleRtl = intl.Bidi.detectRtlDirectionality(card.title);
    final currentCardId = ref.watch(currentPlayingCardIdProvider);
    final isPlaying = ref.watch(isPlayingProvider);
    final isPreviewing = currentCardId == card.id && isPlaying;
    final actionButtonSize = AppResponsive.buttonSize(
      context,
    ).clamp(48.0, 64.0).toDouble();
    final actionButtons = [
      _RoundIconButton(
        semanticLabel: isPreviewing
            ? 'Stop preview for ${card.title}'
            : 'Preview ${card.title}',
        icon: isPreviewing ? Icons.stop_rounded : Icons.play_arrow_rounded,
        foregroundColor: AppColors.primaryInk,
        backgroundColor: const Color(0xFFDCFCE7),
        onPressed: () => _togglePreview(context, ref),
      ),
      if (_isExporting)
        SizedBox(
          width: actionButtonSize,
          height: actionButtonSize,
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF1D4ED8),
              ),
            ),
          ),
        )
      else
        _RoundIconButton(
          semanticLabel:
              'Share ${card.mediaType == CardMediaType.video ? 'video' : 'audio'} for ${card.title}',
          icon: Icons.share,
          foregroundColor: const Color(0xFF1D4ED8),
          backgroundColor: const Color(0xFFEFF6FF),
          onPressed: _exportCard,
        ),
      _RoundIconButton(
        semanticLabel: 'Edit ${card.title}',
        icon: Icons.edit_outlined,
        foregroundColor: AppColors.textSecondary,
        backgroundColor: AppColors.backgroundMuted,
        onPressed: () => context.push('/parent/edit', extra: card.id),
      ),
      _RoundIconButton(
        semanticLabel: 'Delete ${card.title}',
        icon: Icons.delete_outline,
        foregroundColor: AppColors.destructiveDark,
        backgroundColor: const Color(0xFFFEF2F2),
        onPressed: () => _confirmDelete(context, ref),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final useCompactCardLayout =
            constraints.maxWidth < 520 ||
            (widget.isListLayout && constraints.maxWidth < 720);
        final cardPadding = useCompactCardLayout ? 16.0 : 18.0;

        return Container(
          padding: EdgeInsets.all(cardPadding),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
          ),
          child: useCompactCardLayout
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _CardArtwork(card: card),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: isTitleRtl
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              Text(
                                card.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: isTitleRtl
                                    ? TextAlign.right
                                    : TextAlign.left,
                                textDirection: isTitleRtl
                                    ? TextDirection.rtl
                                    : TextDirection.ltr,
                                style: TextStyle(
                                  fontSize: AppResponsive.fontSize(context, 22),
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
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
                                      label: category.name,
                                      backgroundColor: const Color(0xFFECFDF3),
                                      foregroundColor: AppColors.primaryInk,
                                    ),
                                  if (card.mediaType == CardMediaType.video)
                                    const _MetaChip(
                                      label: 'Video',
                                      icon: Icons.videocam_rounded,
                                      backgroundColor: Color(0xFFEFF6FF),
                                      foregroundColor: Color(0xFF1D4ED8),
                                    ),
                                  _MetaChip(
                                    label: _formatDate(card.createdAt),
                                    backgroundColor: const Color(0xFFF3F4F6),
                                    foregroundColor: AppColors.textMuted,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(spacing: 10, runSpacing: 10, children: actionButtons),
                  ],
                )
              : Row(
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
                            textAlign: isTitleRtl
                                ? TextAlign.right
                                : TextAlign.left,
                            textDirection: isTitleRtl
                                ? TextDirection.rtl
                                : TextDirection.ltr,
                            style: TextStyle(
                              fontSize: AppResponsive.fontSize(context, 22),
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
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
                                  label: category.name,
                                  backgroundColor: const Color(0xFFECFDF3),
                                  foregroundColor: AppColors.primaryInk,
                                ),
                              if (card.mediaType == CardMediaType.video)
                                const _MetaChip(
                                  label: 'Video',
                                  icon: Icons.videocam_rounded,
                                  backgroundColor: Color(0xFFEFF6FF),
                                  foregroundColor: Color(0xFF1D4ED8),
                                ),
                              _MetaChip(
                                label: _formatDate(card.createdAt),
                                backgroundColor: const Color(0xFFF3F4F6),
                                foregroundColor: AppColors.textMuted,
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
                        for (int i = 0; i < actionButtons.length; i++) ...[
                          if (i > 0) const SizedBox(width: 10),
                          actionButtons[i],
                        ],
                      ],
                    ),
                  ],
                ),
        );
      },
    );
  }

  Future<void> _togglePreview(BuildContext context, WidgetRef ref) async {
    if (widget.card.mediaType == CardMediaType.video) {
      await context.push(
        '/parent/video/${Uri.encodeComponent(widget.card.id)}',
      );
      return;
    }

    final player = ref.read(audioPlayerProvider);
    final currentCardId = ref.read(currentPlayingCardIdProvider);
    final isPlaying = ref.read(isPlayingProvider);

    if (currentCardId == widget.card.id && isPlaying) {
      await player.stop();
      ref.read(currentPlayingCardIdProvider.notifier).state = null;
      ref.read(isPlayingProvider.notifier).state = false;
      return;
    }

    try {
      await player.stop();
      ref.read(currentPlayingCardIdProvider.notifier).state = widget.card.id;
      ref.read(isPlayingProvider.notifier).state = true;
      await player.setFilePath(widget.card.mediaPath);
      await player.play();
      player.playerStateStream
          .firstWhere(
            (state) => state.processingState == ProcessingState.completed,
          )
          .then((_) {
            if (ref.read(currentPlayingCardIdProvider) == widget.card.id) {
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
          content: Text("Couldn't play this recording right now."),
        ),
      );
    }
  }

  Future<void> _exportCard() async {
    setState(() => _isExporting = true);
    try {
      await preserveParentAuthDuringExternalFileFlow(
        ref,
        () => ExportService.shareCard(widget.card),
      );
    } on ExportException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Export failed')));
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete card?'),
        content: Text(
          '“${widget.card.title}” will be removed from this device.',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              foregroundColor: AppColors.textMuted,
            ),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              foregroundColor: AppColors.destructiveDark,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !mounted) return;
    await ref.read(cardsProvider.notifier).deleteCard(widget.card.id);
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
    final spriteDef = card.spriteKey != null
        ? (predefinedSprites[card.spriteKey!] ?? autoAssignSprite(card.title))
        : autoAssignSprite(card.title);
    final customImagePath = card.customImagePath;
    final imageFile = customImagePath != null && customImagePath.isNotEmpty
        ? File(customImagePath)
        : null;
    final hasCustomImage = imageFile != null && imageFile.existsSync();

    return SizedBox.square(
      dimension: 88,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
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
                      scale: AppResponsive.spriteScale(context) * 0.45,
                    ),
                  ),
          ),
          if (card.mediaType == CardMediaType.video)
            const PositionedDirectional(
              top: 6,
              end: 6,
              child: _ArtworkVideoBadge(),
            ),
        ],
      ),
    );
  }
}

class _ArtworkVideoBadge extends StatelessWidget {
  const _ArtworkVideoBadge();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Video',
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: const Color(0xE6111827),
          borderRadius: BorderRadius.circular(9),
        ),
        child: const Icon(
          Icons.videocam_rounded,
          color: Color(0xFFF8FAFC),
          size: 18,
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
  final bool expand;

  const _LibraryActionButton({
    required this.label,
    required this.icon,
    required this.variant,
    required this.onTap,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final buttonHeight = AppResponsive.buttonSize(
      context,
    ).clamp(48.0, 56.0).toDouble();
    final backgroundColor = switch (variant) {
      _LibraryActionVariant.primary => AppColors.primaryStrong,
      _LibraryActionVariant.secondary => AppColors.surface,
      _LibraryActionVariant.tertiary => Colors.transparent,
    };
    final foregroundColor = switch (variant) {
      _LibraryActionVariant.primary => const Color(0xFFF8FAFC),
      _LibraryActionVariant.secondary => AppColors.textMuted,
      _LibraryActionVariant.tertiary => AppColors.accentDark,
    };

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: SizedBox(
        width: expand ? double.infinity : null,
        height: buttonHeight,
        child: Material(
          color: backgroundColor,
          shape: StadiumBorder(
            side: variant == _LibraryActionVariant.secondary
                ? const BorderSide(color: AppColors.border, width: 1.5)
                : BorderSide.none,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppResponsive.spacing(context, 18),
              ),
              child: Row(
                mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: AppResponsive.iconSize(context, 20),
                    color: foregroundColor,
                  ),
                  SizedBox(width: AppResponsive.spacing(context, 8)),
                  if (expand)
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyLarge.copyWith(
                          fontSize: AppResponsive.fontSize(
                            context,
                            16,
                          ).clamp(14.0, 20.0).toDouble(),
                          color: foregroundColor,
                        ),
                      ),
                    )
                  else
                    Text(
                      label,
                      style: AppTypography.bodyLarge.copyWith(
                        fontSize: AppResponsive.fontSize(
                          context,
                          16,
                        ).clamp(14.0, 20.0).toDouble(),
                        color: foregroundColor,
                      ),
                    ),
                ],
              ),
            ),
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
    final buttonSize = AppResponsive.buttonSize(
      context,
    ).clamp(48.0, 64.0).toDouble();

    return Semantics(
      label: semanticLabel,
      button: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          width: buttonSize,
          height: buttonSize,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(
            icon,
            color: foregroundColor,
            size: AppResponsive.iconSize(context, 24),
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color backgroundColor;
  final Color foregroundColor;

  const _MetaChip({
    required this.label,
    this.icon,
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: foregroundColor),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: foregroundColor,
            ),
          ),
        ],
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
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Text(
          label,
          style: AppTypography.bodyMedium.copyWith(
            fontSize: 15,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

enum _LibraryActionVariant { primary, secondary, tertiary }

enum _LibraryMenuAction { changePin, about, categories }
