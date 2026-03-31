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
import '../providers/cards_provider.dart';
import '../providers/categories_provider.dart';
import '../models/sprites.dart';
import '../services/library_import_service.dart';
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
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    if (widget.cardId != null) {
      _loadCard(widget.cardId!);
    } else {
      _titleController.text = "New Story";
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
    setState(() {});
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final selectedAudioPath = _audioPath;
    if (title.isEmpty || selectedAudioPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in title and add an audio file.'),
        ),
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
        spriteKey: null,
        audioPath: finalAudioPath,
        position: existingCard?.position ?? cardsList.length,
        createdAt:
            existingCard?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
      );

      if (existingCard == null) {
        await ref.read(cardsProvider.notifier).addCard(card);
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final spriteDef = autoAssignSprite(_titleController.text);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
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
                          icon: const Icon(Icons.arrow_back_ios_new, size: 32),
                          onPressed: () => context.pop(),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        widget.cardId == null ? 'New Card' : 'Edit Card',
                        style: const TextStyle(
                          fontSize: 32,
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
                        height: 56,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x4022C55E),
                              blurRadius: 16,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'Save',
                              style: TextStyle(
                                fontSize: 18,
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
              const SizedBox(height: 32),
              Wrap(
                spacing: 32,
                runSpacing: 32,
                children: [
                  _buildPreview(spriteDef),
                  Builder(
                    builder: (context) {
                      final screenWidth = MediaQuery.of(context).size.width;
                      final formWidth = AppResponsive.isTablet(context)
                          ? 500.0
                          : screenWidth * 0.55;
                      return Container(
                        width: formWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Title',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Semantics(
                              label: 'Card title',
                              child: TextField(
                                controller: _titleController,
                                onChanged: (v) {
                                  if (_debounce?.isActive ?? false)
                                    _debounce!.cancel();
                                  _debounce = Timer(
                                    const Duration(milliseconds: 700),
                                    () {
                                      if (mounted) setState(() {});
                                    },
                                  );
                                },
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                                textDirection:
                                    intl.Bidi.detectRtlDirectionality(
                                      _titleController.text,
                                    )
                                    ? TextDirection.rtl
                                    : TextDirection.ltr,
                                textAlign:
                                    intl.Bidi.detectRtlDirectionality(
                                      _titleController.text,
                                    )
                                    ? TextAlign.right
                                    : TextAlign.left,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.all(16),
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
                            const SizedBox(height: 24),
                            const Text(
                              'Category',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Consumer(
                              builder: (context, ref, _) {
                                final categoriesAsync = ref.watch(
                                  categoriesProvider,
                                );
                                final categories = categoriesAsync.value ?? [];
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
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
                                              '${c.emoji} ${c.name}',
                                              style: const TextStyle(
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        setState(
                                          () => _selectedCategoryId = value,
                                        );
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Audio',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
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
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreview(SpriteDef sprite) {
    return Column(
      children: [
        const Text(
          "Preview",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: 220,
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
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: double.infinity,
                height: 180,
                decoration: BoxDecoration(
                  color: hexOrFallback(_color),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: FittedBox(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: PixelSprite(
                      sprite: sprite,
                      state: SpriteState.active,
                      scale: 6.0,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _titleController.text.isEmpty
                    ? "New Story"
                    : _titleController.text,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A1A),
                ),
                textDirection:
                    intl.Bidi.detectRtlDirectionality(_titleController.text)
                    ? TextDirection.rtl
                    : TextDirection.ltr,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
