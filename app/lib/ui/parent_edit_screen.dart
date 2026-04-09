import 'dart:async';
import 'dart:io';
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
import '../theme/app_responsive.dart';
import 'pixel_sprite.dart';

class ParentEditScreen extends ConsumerStatefulWidget {
  final String? cardId;
  const ParentEditScreen({Key? key, this.cardId}) : super(key: key);

  @override
  _ParentEditScreenState createState() => _ParentEditScreenState();
}

class _ParentEditScreenState extends ConsumerState<ParentEditScreen> {
  final _titleController = TextEditingController();
  AudioCard? _existingCard;
  String? _audioPath;
  String _color = '#F0FDF4';
  String? _selectedCategoryId;
  bool _isLoading = false;
  String? _selectedSpriteKey;
  Timer? _debounce;

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
    _audioPath = card.audioPath;
    _color = card.color;
    _selectedCategoryId = card.collectionId;
    _selectedSpriteKey = card.spriteKey;
    setState(() {});
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final selectedAudioPath = _audioPath;
    if (title.isEmpty || selectedAudioPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a title and an audio file to save.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final existingCard = widget.cardId == null
          ? null
          : (_existingCard ??
                await DatabaseService.instance.readCard(widget.cardId!));

      var finalAudioPath = selectedAudioPath;
      final audioChanged =
          existingCard != null && selectedAudioPath != existingCard.audioPath;
      if (existingCard == null || audioChanged) {
        finalAudioPath = await LibraryImportService.importAudioToLibrary(
          selectedAudioPath,
        );
      }

      final cardsList = ref.read(cardsProvider).value ?? [];

      final card = AudioCard(
        id: existingCard?.id ?? const Uuid().v4(),
        collectionId: _selectedCategoryId,
        title: title,
        color: _color,
        spriteKey: _selectedSpriteKey ?? autoAssignSprite(title).id,
        audioPath: finalAudioPath,
        position: existingCard?.position ?? cardsList.length,
        createdAt:
            existingCard?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
      );

      if (existingCard == null) {
        await ref.read(cardsProvider.notifier).addCard(card);
        AnalyticsService.instance.logCardCreated(method: 'single');
      } else {
        await DatabaseService.instance.updateCard(card);
        await ref.read(cardsProvider.notifier).loadCards();

        if (audioChanged) {
          final oldAudioPath = existingCard.audioPath;
          final oldAudioStillReferenced = await DatabaseService.instance
              .countCardsWithAudioPath(oldAudioPath);
          final oldAudioManaged =
              await LibraryImportService.isImportedLibraryPath(oldAudioPath);

          if (oldAudioManaged &&
              oldAudioStillReferenced == 0 &&
              oldAudioPath != finalAudioPath) {
            final oldAudioFile = File(oldAudioPath);
            if (await oldAudioFile.exists()) {
              await oldAudioFile.delete();
            }
          }
        }
      }

      if (!mounted) return;
      context.pop();
    } catch (e) {
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
    _debounce?.cancel();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isPortrait = AppResponsive.isPortrait(context);
    final isCompact = AppResponsive.isCompact(context);
    final isCompactPortrait = isCompact && isPortrait;
    final isShortLandscape =
        !isPortrait && MediaQuery.sizeOf(context).height < 500;
    final basePadding = AppResponsive.basePadding(context);
    final sectionSpacing = isCompactPortrait
        ? 18.0
        : isShortLandscape
        ? 12.0
        : AppResponsive.spacing(context, 32);
    final buttonHeight = AppResponsive.buttonSize(context);
    final headingSize = isCompact ? 28.0 : AppResponsive.fontSize(context, 32);
    final saveLabelSize = isCompact
        ? 16.0
        : AppResponsive.fontSize(context, 18);
    final spriteDef = _selectedSpriteKey != null
        ? (predefinedSprites[_selectedSpriteKey!] ??
              autoAssignSprite(_titleController.text))
        : autoAssignSprite(_titleController.text);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isShortLandscape ? 10.0 : basePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Semantics(
                        label: 'Go back',
                        button: true,
                        child: IconButton(
                          icon: Icon(
                            Icons.arrow_back_ios_new,
                            size: isCompactPortrait
                                ? 26.0
                                : isShortLandscape
                                ? 24.0
                                : AppResponsive.iconSize(context, 32),
                          ),
                          onPressed: () => context.pop(),
                        ),
                      ),
                      SizedBox(
                        width: isCompactPortrait
                            ? 8.0
                            : isShortLandscape
                            ? 12.0
                            : AppResponsive.spacing(context, 16),
                      ),
                      Text(
                        widget.cardId == null ? 'New Card' : 'Edit Card',
                        style: TextStyle(
                          fontSize: isCompactPortrait
                              ? 24.0
                              : isShortLandscape
                              ? 20.0
                              : headingSize,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  Semantics(
                    label: 'Save card',
                    button: true,
                    child: GestureDetector(
                      onTap: _save,
                      child: Container(
                        height: buttonHeight,
                        padding: EdgeInsets.symmetric(
                          horizontal: AppResponsive.spacing(context, 24),
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E),
                          borderRadius: BorderRadius.circular(buttonHeight / 2),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x4022C55E),
                              blurRadius: 16,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check,
                              color: Colors.white,
                              size: AppResponsive.iconSize(context, 20),
                            ),
                            SizedBox(width: AppResponsive.spacing(context, 8)),
                            Text(
                              'Save',
                              style: TextStyle(
                                fontSize: saveLabelSize,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: sectionSpacing),
              if (isPortrait) ...[
                _buildPreview(context, spriteDef),
                SizedBox(height: sectionSpacing),
                _buildFormPanel(context),
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPreview(context, spriteDef),
                    SizedBox(width: sectionSpacing),
                    Expanded(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: _buildFormPanel(context),
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

  Widget _buildFormPanel(BuildContext context) {
    final isCompact = AppResponsive.isCompact(context);
    final isCompactPortrait = isCompact && AppResponsive.isPortrait(context);
    final isShortLandscape =
        !AppResponsive.isPortrait(context) &&
        MediaQuery.sizeOf(context).height < 500;
    final sectionLabelSize = isCompact
        ? 15.0
        : AppResponsive.fontSize(context, 16);
    final fieldTextSize = isCompact
        ? 16.0
        : AppResponsive.fontSize(context, 18);
    final helperTextSize = isCompact
        ? 13.0
        : AppResponsive.fontSize(context, 14);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Title',
          style: TextStyle(
            fontSize: sectionLabelSize,
            fontWeight: FontWeight.bold,
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
              fillColor: Colors.white,
              contentPadding: EdgeInsets.all(
                AppResponsive.spacing(context, 16),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Color(0xFFE5E7EB),
                  width: 2,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Color(0xFF3B82F6),
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
          style: TextStyle(
            fontSize: sectionLabelSize,
            fontWeight: FontWeight.bold,
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFE5E7EB),
                      width: 2,
                    ),
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
                GestureDetector(
                  onTap: _showNewCategoryDialog,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_circle_outline,
                        size: AppResponsive.iconSize(context, 16),
                        color: const Color(0xFF3B82F6),
                      ),
                      SizedBox(width: AppResponsive.spacing(context, 6)),
                      Text(
                        'New Category',
                        style: TextStyle(
                          fontSize: helperTextSize,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF3B82F6),
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
          'Audio',
          style: TextStyle(
            fontSize: sectionLabelSize,
            fontWeight: FontWeight.bold,
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
          currentAudioPath: _audioPath,
          onAudioSelected: (selectedPath) {
            setState(() {
              if (selectedPath.isEmpty) {
                _audioPath = null;
              } else {
                _audioPath = selectedPath;
              }
            });
          },
        ),
      ],
    );
  }

  Widget _buildPreview(BuildContext context, SpriteDef sprite) {
    final isCompact = AppResponsive.isCompact(context);
    final isCompactPortrait = isCompact && AppResponsive.isPortrait(context);
    final isShortLandscape =
        !AppResponsive.isPortrait(context) &&
        MediaQuery.sizeOf(context).height < 500;
    final previewWidth = AppResponsive.isPortrait(context)
        ? double.infinity
        : isShortLandscape
        ? 184.0
        : AppResponsive.spacing(context, 220);
    final artworkHeight = isCompactPortrait
        ? 132.0
        : isShortLandscape
        ? 104.0
        : AppResponsive.isPortrait(context)
        ? AppResponsive.spacing(context, 220)
        : AppResponsive.spacing(context, 180);
    final previewLabelSize = isCompact
        ? 16.0
        : AppResponsive.fontSize(context, 18);
    final chipLabelSize = isCompact
        ? 12.0
        : AppResponsive.fontSize(context, 13);
    final previewTitleSize = isCompact
        ? 18.0
        : AppResponsive.fontSize(context, 20);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: AppResponsive.isPortrait(context)
            ? 360
            : isShortLandscape
            ? 198.0
            : AppResponsive.spacing(context, 260),
      ),
      child: Column(
        children: [
          if (!isShortLandscape) ...[
            Text(
              'Preview',
              style: TextStyle(
                fontSize: previewLabelSize,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF6B7280),
              ),
            ),
            SizedBox(height: AppResponsive.spacing(context, 16)),
          ],
          Container(
            width: previewWidth,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            padding: EdgeInsets.all(
              isCompactPortrait
                  ? 12.0
                  : isShortLandscape
                  ? 10.0
                  : AppResponsive.spacing(context, 16),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: artworkHeight,
                  decoration: BoxDecoration(
                    color: hexOrFallback(_color),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: FittedBox(
                    child: Padding(
                      padding: EdgeInsets.all(
                        isCompactPortrait
                            ? 12.0
                            : isShortLandscape
                            ? 10.0
                            : AppResponsive.spacing(context, 16),
                      ),
                      child: PixelSprite(
                        sprite: sprite,
                        state: SpriteState.active,
                        scale: isCompactPortrait
                            ? 4.6
                            : isShortLandscape
                            ? 4.4
                            : AppResponsive.spriteScale(context),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: isCompactPortrait
                      ? 10.0
                      : isShortLandscape
                      ? 6.0
                      : AppResponsive.spacing(context, 16),
                ),
                GestureDetector(
                  onTap: _showSpritePicker,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompactPortrait
                          ? 12.0
                          : isShortLandscape
                          ? 8.0
                          : AppResponsive.spacing(context, 16),
                      vertical: isCompactPortrait
                          ? 6.0
                          : isShortLandscape
                          ? 4.0
                          : AppResponsive.spacing(context, 8),
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFE5E7EB),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.shuffle_rounded,
                          size: AppResponsive.iconSize(context, 16),
                          color: const Color(0xFF6B7280),
                        ),
                        SizedBox(width: AppResponsive.spacing(context, 6)),
                        Text(
                          'Change Creature',
                          style: TextStyle(
                            fontSize: isCompactPortrait
                                ? 11.0
                                : isShortLandscape
                                ? 9.0
                                : chipLabelSize,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!isShortLandscape) ...[
                  SizedBox(
                    height: isCompactPortrait
                        ? 6.0
                        : AppResponsive.spacing(context, 8),
                  ),
                  Text(
                    _titleController.text.isEmpty
                        ? 'New Card'
                        : _titleController.text,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isCompactPortrait ? 16.0 : previewTitleSize,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1A1A1A),
                    ),
                    textDirection:
                        intl.Bidi.detectRtlDirectionality(_titleController.text)
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
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
