import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../models/audio_card.dart';
import '../models/sprites.dart';
import '../models/storytime_models.dart';
import '../providers/add_audio_provider.dart';
import '../providers/cards_provider.dart';
import '../services/library_import_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import 'concept_icons.dart';
import 'pixel_sprite.dart';
import 'widgets/audio_recorder_widget.dart';
import 'widgets/storytime/storytime.dart';

/// Swatches offered for the card color (warm storytime palette).
const _swatches = <String>[
  'E6A487', 'F2C84B', '8B7CF6', '7FB5A6', 'E2885A', 'D98C9B', '6FA8D6', '9CC97B',
];

class AddAudioCaptureScreen extends ConsumerStatefulWidget {
  const AddAudioCaptureScreen({super.key, this.editingCardId});
  final String? editingCardId;

  @override
  ConsumerState<AddAudioCaptureScreen> createState() =>
      _AddAudioCaptureScreenState();
}

class _AddAudioCaptureScreenState extends ConsumerState<AddAudioCaptureScreen> {
  MediaSelection? _selection;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<StorytimeTokens>()!;
    return Scaffold(
      backgroundColor: tokens.cream,
      appBar: AppBar(
        backgroundColor: tokens.cream,
        title: Text('Add your own audio',
            style: AppTypography.headlineSmall.copyWith(color: tokens.ink)),
        leading: BackButton(onPressed: () => context.go('/parent')),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SvgPicture.string(addAudioIconSvg, width: 96, height: 96),
              const SizedBox(height: 12),
              const StSectionHeader(
                title: 'Record or upload',
                sub: 'Record a voice now, or pick an audio file.',
              ),
              const SizedBox(height: 16),
              AudioRecorderWidget(
                currentSelection: _selection,
                onMediaSelected: (sel) => setState(() => _selection = sel),
              ),
              const Spacer(),
              StButton(
                label: 'Next',
                onTap: _selection == null
                    ? null
                    : () {
                        ref.read(addAudioDraftProvider.notifier).state =
                            _selection;
                        final id = widget.editingCardId;
                        context.go(id == null
                            ? '/parent/add-audio/details'
                            : '/parent/edit-audio/$id');
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AddAudioDetailsScreen extends ConsumerStatefulWidget {
  const AddAudioDetailsScreen({super.key, this.editingCardId});
  final String? editingCardId;

  @override
  ConsumerState<AddAudioDetailsScreen> createState() =>
      _AddAudioDetailsScreenState();
}

class _AddAudioDetailsScreenState extends ConsumerState<AddAudioDetailsScreen> {
  late final TextEditingController _title;
  String _color = _swatches.first;
  AudioCard? _editing;

  @override
  void initState() {
    super.initState();
    final id = widget.editingCardId;
    if (id != null) {
      final list = ref.read(cardsProvider).valueOrNull ?? const <AudioCard>[];
      _editing = list.cast<AudioCard?>().firstWhere(
          (c) => c?.id == id, orElse: () => null);
    }
    _title = TextEditingController(text: _editing?.title ?? _defaultTitle());
    if (_editing != null) _color = _editing!.color;
  }

  String _defaultTitle() {
    final sel = ref.read(addAudioDraftProvider);
    return sel?.sourceName?.trim().isNotEmpty == true
        ? sel!.sourceName!
        : 'My recording';
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim().isEmpty ? 'My recording' : _title.text.trim();
    final cards = ref.read(cardsProvider.notifier);
    final replacement = ref.read(addAudioDraftProvider); // non-null only if audio replaced

    if (_editing != null) {
      final old = _editing!;
      final newPath = replacement?.path ?? old.audioPath;
      final updated = old.copyWith(
        title: title,
        color: _color,
        audioPath: newPath,
        durationMs: replacement?.duration?.inMilliseconds ?? old.durationMs,
        playbackPosition: replacement != null ? 0 : old.playbackPosition,
      );
      await cards.updateCard(updated);
      if (replacement != null && replacement.path != old.audioPath) {
        await LibraryImportService.deleteImportedMedia(old.audioPath);
      }
      ref.read(addAudioDraftProvider.notifier).state = null;
      if (mounted) context.go('/parent/stories');
      return;
    }

    // Create path: draft required
    final draft = replacement;
    if (draft == null) {
      context.go('/parent/add-audio');
      return;
    }
    final existing = ref.read(cardsProvider).valueOrNull ?? const <AudioCard>[];
    final card = AudioCard(
      id: const Uuid().v4(),
      title: title,
      color: _color,
      audioPath: draft.path,
      mediaType: CardMediaType.audio,
      storyOrigin: StoryOrigin.uploaded,
      durationMs: draft.duration?.inMilliseconds ?? 0,
      position: existing.length,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await cards.addCard(card);
    ref.read(addAudioDraftProvider.notifier).state = null;
    if (mounted) context.go('/parent/stories');
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<StorytimeTokens>()!;
    return Scaffold(
      backgroundColor: tokens.cream,
      appBar: AppBar(
        backgroundColor: tokens.cream,
        title: Text('Card details',
            style: AppTypography.headlineSmall.copyWith(color: tokens.ink)),
        leading: BackButton(onPressed: () => context.go('/parent/add-audio')),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: hexOrFallback(_color),
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: PixelSprite(
                  sprite: autoAssignSprite(_title.text.trim().isEmpty
                      ? 'My recording'
                      : _title.text.trim()),
                  scale: 4,
                ),
              ),
            ),
            const SizedBox(height: 20),
            StTextField(
              controller: _title,
              hint: 'Card title',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),
            Text('Color', style: AppTypography.labelLarge.copyWith(color: tokens.ink2)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final hex in _swatches)
                  GestureDetector(
                    onTap: () => setState(() => _color = hex),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: hexOrFallback(hex),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _color == hex ? tokens.ink : tokens.line,
                          width: _color == hex ? 3 : 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 28),
            if (_editing != null) ...[
              StButton(
                label: 'Replace audio',
                onTap: () => context.go('/parent/add-audio'),
              ),
              const SizedBox(height: 12),
            ],
            StButton(label: 'Save', onTap: _save),
          ],
        ),
      ),
    );
  }
}
