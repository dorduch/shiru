import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'widgets/audio_recorder_widget.dart';
import 'package:uuid/uuid.dart';

import '../db/database_service.dart';
import 'package:intl/intl.dart' as intl;
import '../models/audio_card.dart';
import '../providers/cards_provider.dart';
import '../providers/categories_provider.dart';
import '../models/sprites.dart';
import 'pixel_sprite.dart';
import 'giphy_sprite.dart';

class ParentEditScreen extends ConsumerStatefulWidget {
  final String? cardId;
  const ParentEditScreen({Key? key, this.cardId}) : super(key: key);

  @override
  _ParentEditScreenState createState() => _ParentEditScreenState();
}

class _ParentEditScreenState extends ConsumerState<ParentEditScreen> {
  final _titleController = TextEditingController();
  final _spriteKeyController = TextEditingController();
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
    final cardsAsync = ref.read(cardsProvider);
    final card = cardsAsync.value?.firstWhere((c) => c.id == id);
    if (card != null) {
      _titleController.text = card.title;
      _spriteKeyController.text = card.spriteKey ?? '';
      _audioPath = card.audioPath;
      _color = card.color;
      _selectedCategoryId = card.collectionId;
      setState((){});
    }
  }

  Future<void> _save() async {
    if (_titleController.text.isEmpty || _audioPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please provide a title and audio file.')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final String finalAudioPath;

      if (!_audioPath!.startsWith(docsDir.path)) {
         final uuidStr = const Uuid().v4();
         final extStr = path.extension(_audioPath!);
         final newFile = File(path.join(docsDir.path, '$uuidStr$extStr'));
         await File(_audioPath!).copy(newFile.path);
         finalAudioPath = newFile.path;

         // Clean up temp file if it came from recording
         final tempDir = await getTemporaryDirectory();
         if (_audioPath!.startsWith(tempDir.path)) {
           try { await File(_audioPath!).delete(); } catch (_) {}
         }
      } else {
         finalAudioPath = _audioPath!;
      }

      final cardsList = ref.read(cardsProvider).value ?? [];

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

      if (widget.cardId == null) {
        await ref.read(cardsProvider.notifier).addCard(card);
      } else {
        await DatabaseService.instance.updateCard(card);
        await ref.read(cardsProvider.notifier).loadCards();
      }

      if (mounted) context.pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: \$e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _titleController.dispose();
    _spriteKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

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
                      IconButton(icon: const Icon(Icons.arrow_back_ios, size: 32), onPressed: () => context.pop()),
                      const SizedBox(width: 16),
                      Text(widget.cardId == null ? 'Create Card' : 'Edit Card', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
                    ]
                  ),
                  GestureDetector(
                    onTap: _save,
                    child: Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: const [BoxShadow(color: Color(0x4022C55E), blurRadius: 16, offset: Offset(0, 8))]
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check, color: Colors.white),
                          SizedBox(width: 8),
                          Text('Save', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white))
                        ]
                      )
                    )
                  )
                ]
              ),
              const SizedBox(height: 32),
              Wrap(
                spacing: 32,
                runSpacing: 32,
                children: [
                  _buildPreview(spriteDef),
                  Container(
                    width: 400,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Card Title', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _titleController,
                          onChanged: (v) {
                            if (_debounce?.isActive ?? false) _debounce!.cancel();
                            _debounce = Timer(const Duration(milliseconds: 700), () {
                              if (mounted) setState(() {});
                            });
                          },
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                          textDirection: intl.Bidi.detectRtlDirectionality(_titleController.text) ? TextDirection.rtl : TextDirection.ltr,
                          textAlign: intl.Bidi.detectRtlDirectionality(_titleController.text) ? TextAlign.right : TextAlign.left,
                          decoration: InputDecoration(
                            filled: true, fillColor: Colors.white,
                            contentPadding: const EdgeInsets.all(16),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 2)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 2)),
                          ),
                        ),
                        const SizedBox(height: 24),
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
                        const Text('Custom GIF Search (Optional)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _spriteKeyController,
                          onChanged: (v) {
                            if (_debounce?.isActive ?? false) _debounce!.cancel();
                            _debounce = Timer(const Duration(milliseconds: 700), () {
                              if (mounted) setState(() {});
                            });
                          },
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                          textDirection: intl.Bidi.detectRtlDirectionality(_spriteKeyController.text) ? TextDirection.rtl : TextDirection.ltr,
                          textAlign: intl.Bidi.detectRtlDirectionality(_titleController.text) ? TextAlign.right : TextAlign.left,
                          decoration: InputDecoration(
                            hintText: 'e.g. running cat',
                            hintStyle: const TextStyle(color: Colors.black38),
                            filled: true, fillColor: Colors.white,
                            contentPadding: const EdgeInsets.all(16),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 2)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 2)),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text('Audio', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                        )
                      ]
                    )
                  )
                ]
              )
            ]
          )
        )
      )
    );
  }

  Widget _buildPreview(SpriteDef sprite) {
    return Column(
      children: [
        const Text("Preview", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
        const SizedBox(height: 16),
        Container(
          width: 220,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 24, offset: Offset(0, 12))]
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
                        child: GiphySprite(title: _spriteKeyController.text.isNotEmpty ? _spriteKeyController.text : _titleController.text, fallbackSprite: sprite, state: SpriteState.active, scale: 6.0)
                    )
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _titleController.text.isEmpty ? "New Story" : _titleController.text,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A)),
                textDirection: intl.Bidi.detectRtlDirectionality(_titleController.text) ? TextDirection.rtl : TextDirection.ltr,
              )
            ],
          )
        )
      ]
    );
  }
}
