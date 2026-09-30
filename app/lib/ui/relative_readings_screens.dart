import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';

import '../models/relative_reading.dart';
import '../providers/cards_provider.dart';
import '../providers/relative_readings_provider.dart';
import '../theme/app_typography.dart';
import '../theme/lantern_tokens.dart';
import 'widgets/lantern/glow_button.dart';
import 'widgets/lantern/lantern_outline_button.dart';
import 'widgets/lantern/lantern_row.dart';
import 'widgets/lantern/lantern_section_header.dart';

/// Parent pending queue for relative readings (approve / reject → library).
class RelativeReadingsPendingScreen extends ConsumerWidget {
  const RelativeReadingsPendingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<LanternTokens>()!;
    final pending = ref.watch(pendingRelativeReadingsProvider);

    return Scaffold(
      backgroundColor: tokens.nightMid,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: tokens.moon,
        title: Text('Pending readings', style: TextStyle(color: tokens.moon)),
        leading: IconButton(
          onPressed: () => context.go('/parent'),
          icon: Icon(Icons.arrow_back, color: tokens.moon),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: tokens.nightGradient),
        child: SafeArea(
          child: pending.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load pending readings. Try again while online.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyLarge.copyWith(color: tokens.moonDim),
                ),
              ),
            ),
            data: (items) {
              if (items.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.mark_email_read_outlined,
                            size: 56, color: tokens.moonFaint),
                        const SizedBox(height: 16),
                        Text(
                          'No readings waiting yet',
                          style: AppTypography.headlineSmall
                              .copyWith(color: tokens.moon),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'When someone records a reading for your family, it will show up here for you to approve.',
                          style: AppTypography.bodyMedium
                              .copyWith(color: tokens.moonDim),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const LanternSectionHeader(title: 'Review before the library'),
                  const SizedBox(height: 14),
                  for (final item in items) ...[
                    LanternRow(
                      leading: CircleAvatar(
                        radius: 22,
                        backgroundColor: tokens.lantern.withValues(alpha: 0.12),
                        child: Icon(Icons.graphic_eq, color: tokens.lantern, size: 20),
                      ),
                      title: item.displayName,
                      subtitle: item.subtitle,
                      trailing: Icon(Icons.chevron_right, color: tokens.moonFaint),
                      onTap: () => context.go('/parent/pending-readings/${item.id}'),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class RelativeReadingReviewScreen extends ConsumerStatefulWidget {
  const RelativeReadingReviewScreen({super.key, required this.readingId});

  final String readingId;

  @override
  ConsumerState<RelativeReadingReviewScreen> createState() =>
      _RelativeReadingReviewScreenState();
}

class _RelativeReadingReviewScreenState
    extends ConsumerState<RelativeReadingReviewScreen> {
  AudioPlayer? _previewPlayer;
  bool _previewLoading = false;
  bool _previewPlaying = false;
  String? _previewError;
  bool _busy = false;
  String? _actionError;

  @override
  void dispose() {
    _previewPlayer?.dispose();
    super.dispose();
  }

  RelativeReading? _find(List<RelativeReading>? items) {
    if (items == null) return null;
    for (final item in items) {
      if (item.id == widget.readingId) return item;
    }
    return null;
  }

  Future<void> _togglePreview() async {
    if (_busy) return;
    setState(() {
      _previewError = null;
      _previewLoading = true;
    });
    try {
      final player = _previewPlayer ??= AudioPlayer();
      if (_previewPlaying) {
        await player.pause();
        if (mounted) setState(() => _previewPlaying = false);
        return;
      }
      if (player.playing || (player.duration != null && player.position > Duration.zero)) {
        await player.play();
        if (mounted) setState(() => _previewPlaying = true);
        return;
      }
      final preview = await ref
          .read(relativeReadingRepositoryProvider)
          .getPreviewUrl(widget.readingId);
      await player.setUrl(preview.downloadUrl);
      await player.play();
      player.playerStateStream.listen((state) {
        if (!mounted) return;
        if (state.processingState == ProcessingState.completed) {
          setState(() => _previewPlaying = false);
        }
      });
      if (mounted) setState(() => _previewPlaying = true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _previewError = 'Could not play this reading right now.';
          _previewPlaying = false;
        });
      }
    } finally {
      if (mounted) setState(() => _previewLoading = false);
    }
  }

  Future<void> _approve(RelativeReading reading) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _actionError = null;
    });
    await _previewPlayer?.stop();
    try {
      final cards = ref.read(cardsProvider).valueOrNull ?? const [];
      await ref.read(relativeReadingRepositoryProvider).approveAndImport(
            readingId: reading.id,
            reading: reading,
            existingCards: cards,
            addCard: (card) => ref.read(cardsProvider.notifier).addCard(card),
          );
      if (!mounted) return;
      context.go('/parent/stories');
    } catch (_) {
      if (mounted) {
        setState(() {
          _actionError =
              'Could not add this reading to the library. Try again while online.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject(RelativeReading reading) async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final tokens = Theme.of(context).extension<LanternTokens>()!;
        return AlertDialog(
          backgroundColor: tokens.nightCard,
          title: Text('Not approve this reading?',
              style: TextStyle(color: tokens.moon)),
          content: Text(
            'They will see "Not approved" if they reopen their invite link. It will not be added to the library.',
            style: TextStyle(color: tokens.moonDim),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Keep', style: TextStyle(color: tokens.moon)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Not approve', style: TextStyle(color: tokens.hueCoral)),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _busy = true;
      _actionError = null;
    });
    await _previewPlayer?.stop();
    try {
      await ref.read(relativeReadingRepositoryProvider).reject(reading.id);
      if (!mounted) return;
      context.go('/parent/pending-readings');
    } catch (_) {
      if (mounted) {
        setState(() {
          _actionError = 'Could not update this reading. Try again while online.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<LanternTokens>()!;
    final pending = ref.watch(pendingRelativeReadingsProvider);
    final reading = _find(pending.valueOrNull);

    return Scaffold(
      backgroundColor: tokens.nightMid,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: tokens.moon,
        title: Text('Review reading', style: TextStyle(color: tokens.moon)),
        leading: IconButton(
          onPressed: () => context.go('/parent/pending-readings'),
          icon: Icon(Icons.arrow_back, color: tokens.moon),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: tokens.nightGradient),
        child: SafeArea(
          child: pending.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => Center(
              child: Text(
                'Could not load this reading.',
                style: AppTypography.bodyLarge.copyWith(color: tokens.moonDim),
              ),
            ),
            data: (_) {
              if (reading == null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'This reading is no longer waiting for review.',
                      textAlign: TextAlign.center,
                      style:
                          AppTypography.bodyLarge.copyWith(color: tokens.moonDim),
                    ),
                  ),
                );
              }
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    reading.displayName,
                    style: AppTypography.headlineSmall.copyWith(color: tokens.moon),
                  ),
                  if (reading.relationship.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      reading.relationship.trim(),
                      style:
                          AppTypography.bodyMedium.copyWith(color: tokens.moonDim),
                    ),
                  ],
                  const SizedBox(height: 24),
                  LanternOutlineButton(
                    label: _previewLoading
                        ? 'Loading…'
                        : _previewPlaying
                            ? 'Pause preview'
                            : 'Play preview',
                    onTap: _previewLoading || _busy ? null : _togglePreview,
                  ),
                  if (_previewError != null) ...[
                    const SizedBox(height: 10),
                    Text(_previewError!,
                        style: AppTypography.bodyMedium
                            .copyWith(color: tokens.hueCoral)),
                  ],
                  const SizedBox(height: 28),
                  GlowButton(
                    label: _busy ? 'Working…' : 'Approve for library',
                    onTap: _busy ? null : () => _approve(reading),
                  ),
                  const SizedBox(height: 12),
                  LanternOutlineButton(
                    label: 'Not approve',
                    onTap: _busy ? null : () => _reject(reading),
                  ),
                  if (_actionError != null) ...[
                    const SizedBox(height: 14),
                    Text(_actionError!,
                        style: AppTypography.bodyMedium
                            .copyWith(color: tokens.hueCoral)),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
