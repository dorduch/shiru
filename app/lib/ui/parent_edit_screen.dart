import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'widgets/audio_recorder_widget.dart';
import 'package:uuid/uuid.dart';

import '../db/database_service.dart';
import 'package:intl/intl.dart' as intl;
import '../models/audio_card.dart';
import '../models/category.dart';
import '../providers/cards_provider.dart';
import '../providers/categories_provider.dart';
import '../models/sprites.dart';
import '../services/library_import_service.dart';
import '../services/analytics_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_responsive.dart';
import '../theme/app_typography.dart';
import 'pixel_sprite.dart';
import 'video_playback_screen.dart';

class ParentEditScreen extends ConsumerStatefulWidget {
  final String? cardId;
  const ParentEditScreen({Key? key, this.cardId}) : super(key: key);

  @override
  _ParentEditScreenState createState() => _ParentEditScreenState();
}

class _ParentEditScreenState extends ConsumerState<ParentEditScreen> {
  final _titleController = TextEditingController();
  AudioCard? _existingCard;
  MediaSelection? _mediaSelection;
  String _color = '#F0FDF4';
  String? _selectedCategoryId;
  bool _isLoading = false;
  String? _selectedSpriteKey;
  Timer? _debounce;
  bool _saved = false;
  bool _saveOwnsStagedMedia = false;

  @override
  void initState() {
    super.initState();
    if (widget.cardId != null) {
      _loadCard(widget.cardId!);
    } else {
      _titleController.text = "New Card";
    }
  }

  Future<void> _loadCard(String id) async {
    AudioCard? card;
    final cards = ref.read(cardsProvider).value;
    if (cards != null) {
      for (final existing in cards) {
        if (existing.id == id) {
          card = existing;
          break;
        }
      }
    }

    card ??= await DatabaseService.instance.readCard(id);
    if (!mounted) return;

    _existingCard = card;
    _titleController.text = card.title;
    _mediaSelection = MediaSelection(
      path: card.mediaPath,
      mediaType: card.mediaType,
    );
    _color = card.color;
    _selectedCategoryId = card.collectionId;
    _selectedSpriteKey = card.spriteKey;
    setState(() {});
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final selectedMedia = _mediaSelection;
    if (title.isEmpty || selectedMedia == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a title and a media file to save.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    _saveOwnsStagedMedia = true;
    var mediaPathToClean = selectedMedia.path;

    try {
      final existingCard = widget.cardId == null
          ? null
          : (_existingCard ??
                await DatabaseService.instance.readCard(widget.cardId!));

      final mediaChanged =
          existingCard == null ||
          selectedMedia.path != existingCard.mediaPath ||
          selectedMedia.mediaType != existingCard.mediaType;
      final finalMedia = mediaChanged
          ? await LibraryImportService.importMediaToLibrary(
              selectedMedia.path,
              mediaType: selectedMedia.mediaType,
              duration: selectedMedia.duration,
            )
          : selectedMedia;
      mediaPathToClean = finalMedia.path;

      final cardsList = ref.read(cardsProvider).value ?? [];

      final card = AudioCard(
        id: existingCard?.id ?? const Uuid().v4(),
        collectionId: _selectedCategoryId,
        title: title,
        color: _color,
        spriteKey: _selectedSpriteKey ?? autoAssignSprite(title).id,
        audioPath: finalMedia.path,
        mediaType: finalMedia.mediaType,
        position: existingCard?.position ?? cardsList.length,
        createdAt:
            existingCard?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
      );

      if (existingCard == null) {
        await ref.read(cardsProvider.notifier).addCard(card);
        _saved = true;
        _saveOwnsStagedMedia = false;
        AnalyticsService.instance.logCardCreated(method: 'single');
      } else {
        await DatabaseService.instance.updateCard(card);
        _saved = true;
        _saveOwnsStagedMedia = false;
        await ref.read(cardsProvider.notifier).loadCards();

        if (mediaChanged) {
          try {
            final oldPath = existingCard.mediaPath;
            final oldMediaStillReferenced = await DatabaseService.instance
                .countCardsWithMediaPath(oldPath);
            if (oldMediaStillReferenced == 0 && oldPath != finalMedia.path) {
              await LibraryImportService.deleteImportedMedia(oldPath);
            }
          } catch (_) {}
        }
      }

      if (!mounted) return;
      context.pop();
    } catch (e) {
      _saveOwnsStagedMedia = false;
      if (!_saved && !mounted && mediaPathToClean != _existingCard?.mediaPath) {
        await LibraryImportService.deleteImportedMedia(mediaPathToClean);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Couldn\'t save this card. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showNewCategoryDialog() async {
    final existing = ref.read(categoriesProvider).value ?? [];
    final created = await showDialog<Category>(
      context: context,
      builder: (ctx) => _NewCategoryDialog(existingCategories: existing),
    );

    if (created == null) return;
    await ref.read(categoriesProvider.notifier).addCategory(created);
    if (mounted) setState(() => _selectedCategoryId = created.id);
  }

  void _showSpritePicker() {
    final currentKey =
        _selectedSpriteKey ??
        autoAssignSprite(
          _titleController.text.trim().isEmpty
              ? 'New Card'
              : _titleController.text.trim(),
        ).id;
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

  @override
  void dispose() {
    final stagedPath = _mediaSelection?.path;
    if (!_saved &&
        !_saveOwnsStagedMedia &&
        stagedPath != null &&
        stagedPath != _existingCard?.mediaPath) {
      unawaited(LibraryImportService.deleteImportedMedia(stagedPath));
    }
    _debounce?.cancel();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundParent,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryStrong),
        ),
      );
    }

    final isPortrait = AppResponsive.isPortrait(context);
    final isShortLandscape =
        !isPortrait && MediaQuery.sizeOf(context).height < 500;
    final basePadding = AppResponsive.basePadding(context);
    final sectionSpacing = isShortLandscape ? 14.0 : 24.0;
    final spriteDef = _selectedSpriteKey != null
        ? (predefinedSprites[_selectedSpriteKey!] ??
              autoAssignSprite(_titleController.text))
        : autoAssignSprite(_titleController.text);

    return Scaffold(
      backgroundColor: AppColors.backgroundParent,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: basePadding,
            vertical: isShortLandscape ? 8 : 16,
          ),
          child: Column(
            children: [
              _EditHeader(
                title: widget.cardId == null ? 'New card' : 'Edit card',
                onBack: () => context.pop(),
                onSave: _save,
              ),
              SizedBox(height: isShortLandscape ? 10 : 20),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1040),
                      child: isPortrait
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildPreview(context, spriteDef),
                                SizedBox(height: sectionSpacing),
                                _buildFormPanel(context),
                              ],
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildPreview(context, spriteDef),
                                SizedBox(width: sectionSpacing),
                                Expanded(child: _buildFormPanel(context)),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormPanel(BuildContext context) {
    final isCompact = AppResponsive.isCompact(context);
    final isCompactPortrait = isCompact && AppResponsive.isPortrait(context);
    final isShortLandscape =
        !AppResponsive.isPortrait(context) &&
        MediaQuery.sizeOf(context).height < 500;
    final sectionLabelSize = isCompact
        ? 16.0
        : AppResponsive.fontSize(context, 16);
    final fieldTextSize = isCompact
        ? 16.0
        : AppResponsive.fontSize(context, 18);
    final helperTextSize = isCompact
        ? 14.0
        : AppResponsive.fontSize(context, 14);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Title',
          style: AppTypography.bodyMedium.copyWith(
            fontSize: sectionLabelSize,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(
          height: isCompactPortrait
              ? 6.0
              : isShortLandscape
              ? 4.0
              : AppResponsive.spacing(context, 8),
        ),
        Semantics(
          label: 'Card title',
          child: TextField(
            controller: _titleController,
            onChanged: (v) {
              if (_debounce?.isActive ?? false) _debounce!.cancel();
              _debounce = Timer(const Duration(milliseconds: 700), () {
                if (mounted) setState(() {});
              });
            },
            style: TextStyle(
              fontSize: fieldTextSize,
              fontWeight: FontWeight.w500,
            ),
            textDirection:
                intl.Bidi.detectRtlDirectionality(_titleController.text)
                ? TextDirection.rtl
                : TextDirection.ltr,
            textAlign: intl.Bidi.detectRtlDirectionality(_titleController.text)
                ? TextAlign.right
                : TextAlign.left,
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: EdgeInsets.all(
                AppResponsive.spacing(context, 16),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: AppColors.primaryStrong,
                  width: 2,
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          height: isCompactPortrait
              ? 16.0
              : isShortLandscape
              ? 14.0
              : AppResponsive.spacing(context, 24),
        ),
        Text(
          'Category',
          style: AppTypography.bodyMedium.copyWith(
            fontSize: sectionLabelSize,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(
          height: isCompactPortrait
              ? 6.0
              : isShortLandscape
              ? 4.0
              : AppResponsive.spacing(context, 8),
        ),
        Consumer(
          builder: (context, ref, _) {
            final categoriesAsync = ref.watch(categoriesProvider);
            final categories = categoriesAsync.value ?? [];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppResponsive.spacing(context, 16),
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
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
                        ...categories.map(
                          (c) => DropdownMenuItem<String?>(
                            value: c.id,
                            child: Text(
                              c.name,
                              style: TextStyle(
                                fontSize: isCompact
                                    ? 15.0
                                    : AppResponsive.fontSize(context, 16),
                              ),
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedCategoryId = value);
                      },
                    ),
                  ),
                ),
                SizedBox(
                  height: isCompactPortrait
                      ? 4.0
                      : isShortLandscape
                      ? 2.0
                      : AppResponsive.spacing(context, 8),
                ),
                InkWell(
                  onTap: _showNewCategoryDialog,
                  borderRadius: BorderRadius.circular(12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_circle_outline,
                        size: AppResponsive.iconSize(context, 16),
                        color: AppColors.primaryInk,
                      ),
                      SizedBox(width: AppResponsive.spacing(context, 6)),
                      Text(
                        'Create category',
                        style: TextStyle(
                          fontSize: helperTextSize,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryInk,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        SizedBox(
          height: isCompactPortrait
              ? 16.0
              : isShortLandscape
              ? 14.0
              : AppResponsive.spacing(context, 24),
        ),
        Text(
          'Media',
          style: AppTypography.bodyMedium.copyWith(
            fontSize: sectionLabelSize,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(
          height: isCompactPortrait
              ? 6.0
              : isShortLandscape
              ? 4.0
              : AppResponsive.spacing(context, 8),
        ),
        AudioRecorderWidget(
          currentSelection: _mediaSelection,
          onMediaSelected: (selection) {
            final previous = _mediaSelection;
            setState(() => _mediaSelection = selection);
            if (previous != null &&
                previous.path != selection?.path &&
                previous.path != _existingCard?.mediaPath) {
              unawaited(
                LibraryImportService.deleteImportedMedia(previous.path),
              );
            }
          },
          onPreviewVideo: _mediaSelection?.mediaType == CardMediaType.video
              ? () => context.push(
                  '/parent/video-preview',
                  extra: VideoPlaybackRequest(
                    path: _mediaSelection!.path,
                    title: _titleController.text.trim().isEmpty
                        ? 'Video preview'
                        : _titleController.text.trim(),
                  ),
                )
              : null,
        ),
      ],
    );
  }

  Widget _buildPreview(BuildContext context, SpriteDef sprite) {
    final isPortrait = AppResponsive.isPortrait(context);
    final compactPortrait =
        isPortrait && MediaQuery.sizeOf(context).width < 600;
    final isShortLandscape =
        !isPortrait && MediaQuery.sizeOf(context).height < 500;
    final artworkSize = compactPortrait
        ? 116.0
        : isShortLandscape
        ? 132.0
        : isPortrait
        ? 220.0
        : 210.0;
    final title = _titleController.text.trim().isEmpty
        ? 'New card'
        : _titleController.text.trim();

    Widget artwork() => Container(
      width: compactPortrait ? artworkSize : double.infinity,
      height: artworkSize,
      decoration: BoxDecoration(
        color: hexOrFallback(_color),
        borderRadius: BorderRadius.circular(20),
      ),
      alignment: Alignment.center,
      child: FittedBox(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: PixelSprite(
            sprite: sprite,
            state: SpriteState.active,
            scale: compactPortrait ? 4.4 : AppResponsive.spriteScale(context),
          ),
        ),
      ),
    );

    Widget changeButton() => OutlinedButton.icon(
      onPressed: _showSpritePicker,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textMuted,
        minimumSize: const Size(0, 48),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      icon: const Icon(Icons.shuffle_rounded, size: 18),
      label: const Text('Change artwork'),
    );

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: isPortrait ? double.infinity : (isShortLandscape ? 210 : 300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Card preview',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: EdgeInsets.all(compactPortrait ? 12 : 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
            ),
            child: compactPortrait
                ? Row(
                    children: [
                      artwork(),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.titleLarge.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            changeButton(),
                          ],
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      artwork(),
                      const SizedBox(height: 14),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: AppTypography.titleLarge.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      changeButton(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _EditHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final VoidCallback onSave;

  const _EditHeader({
    required this.title,
    required this.onBack,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final buttonSize = AppResponsive.buttonSize(
      context,
    ).clamp(48.0, 64.0).toDouble();
    final compact = AppResponsive.isCompact(context);

    return Row(
      children: [
        IconButton(
          tooltip: 'Back to library',
          constraints: BoxConstraints.tightFor(
            width: buttonSize,
            height: buttonSize,
          ),
          onPressed: onBack,
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: AppResponsive.iconSize(context, 24),
            color: AppColors.textMuted,
          ),
        ),
        SizedBox(width: AppResponsive.spacing(context, 8)),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.displayLarge.copyWith(
              fontSize: AppResponsive.fontSize(context, compact ? 30 : 32),
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: onSave,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryStrong,
            foregroundColor: AppColors.surface,
            minimumSize: Size(compact ? 96 : 116, buttonSize),
            padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 22),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          icon: const Icon(Icons.check_rounded, size: 20),
          label: const Text('Save'),
        ),
      ],
    );
  }
}

class _NewCategoryDialog extends StatefulWidget {
  final List<Category> existingCategories;
  const _NewCategoryDialog({required this.existingCategories});

  @override
  State<_NewCategoryDialog> createState() => _NewCategoryDialogState();
}

class _NewCategoryDialogState extends State<_NewCategoryDialog> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final maxPos = widget.existingCategories.isEmpty
        ? -1
        : widget.existingCategories
              .map((c) => c.position)
              .reduce((a, b) => a > b ? a : b);
    Navigator.pop(
      context,
      Category(
        id: const Uuid().v4(),
        name: name,
        emoji: '',
        position: maxPos + 1,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'New Category',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      content: TextField(
        controller: _nameController,
        autofocus: true,
        onSubmitted: (_) => _submit(),
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: 'e.g. Songs',
          hintStyle: const TextStyle(color: Colors.black38),
          filled: true,
          fillColor: const Color(0xFFF9FAFB),
          contentPadding: const EdgeInsets.all(14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF22C55E), width: 2),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Color(0xFF6B7280)),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF22C55E),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: _submit,
          child: const Text(
            'Create',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

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

  static const _categoryLabels = {
    SpriteCategory.animals: 'Animals',
    SpriteCategory.fantasy: 'Fantasy',
    SpriteCategory.sciFi: 'Sci-Fi',
  };

  @override
  Widget build(BuildContext context) {
    final populated = SpriteCategory.values
        .where((c) => predefinedSprites.values.any((s) => s.category == c))
        .toList();
    final isCompact = AppResponsive.isCompact(context);

    final filtered = predefinedSprites.values
        .where((s) => s.category == _activeCategory)
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.4,
      maxChildSize: 0.95,
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
            // Category tabs — only shown when more than one category has sprites
            if (populated.length > 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    for (int i = 0; i < populated.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      _CategoryTab(
                        label: _categoryLabels[populated[i]]!,
                        active: _activeCategory == populated[i],
                        onTap: () =>
                            setState(() => _activeCategory = populated[i]),
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 12),
            // Sprite grid
            Expanded(
              child: GridView.builder(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isCompact ? 3 : 4,
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
                                color: const Color(0xFF22C55E),
                                width: 2.5,
                              )
                            : Border.all(
                                color: const Color(0xFFE5E7EB),
                                width: 1,
                              ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          PixelSprite(
                            sprite: sprite,
                            state: SpriteState.idle,
                            scale: AppResponsive.spriteScale(context) * 0.5,
                          ),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
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
