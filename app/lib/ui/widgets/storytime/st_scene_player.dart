import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_radius.dart';
import '../../../theme/app_typography.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_shadows.dart';

/// Dark bedtime story player widget.
///
/// Layout:
///  - Art panel (top half) — any widget, usually a colored container / image.
///  - Follow-along read text with gold-highlighted current word.
///  - Bottom transport row: play/pause + elapsed/total time + progress bar.
///
/// [highlightedWordIndex] is the zero-based word index within [bodyText] to
/// highlight in gold. Real audio sync is NOT wired here — the parameter is
/// kept external so the parent can drive it from any source.
class StScenePlayer extends StatelessWidget {
  const StScenePlayer({
    super.key,
    required this.title,
    required this.bodyText,
    required this.isPlaying,
    required this.progress,
    this.highlightedWordIndex,
    this.artPanel,
    this.elapsed = '0:00',
    this.total = '0:00',
    this.onPlayPause,
    this.onSeek,
  });

  final String title;

  /// Full story body text (space-separated words).
  final String bodyText;

  final bool isPlaying;

  /// Playback progress ∈ [0, 1].
  final double progress;

  /// Zero-based word index to highlight. Null means no highlight.
  final int? highlightedWordIndex;

  /// Widget rendered in the art panel at the top.
  final Widget? artPanel;

  final String elapsed;
  final String total;
  final VoidCallback? onPlayPause;

  /// Called with a value ∈ [0, 1] when the user drags the progress bar.
  final ValueChanged<double>? onSeek;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<StorytimeTokens>()!;

    return Container(
      decoration: BoxDecoration(
        gradient: tokens.nightGradient,
        borderRadius: AppRadius.sheet,
        boxShadow: AppShadows.bedtimeDepth,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Art panel
          AspectRatio(
            aspectRatio: 16 / 9,
            child: artPanel ??
                Container(
                  color: tokens.night3,
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: tokens.gold.withValues(alpha: 0.4),
                    size: 64,
                  ),
                ),
          ),

          // Read text
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: _HighlightText(
                text: bodyText,
                highlightedIndex: highlightedWordIndex,
                baseStyle: AppTypography.storyBody.copyWith(
                  color: tokens.cream.withValues(alpha: 0.85),
                ),
                highlightStyle: AppTypography.storyBody.copyWith(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          // Transport row
          _Transport(
            title: title,
            isPlaying: isPlaying,
            progress: progress,
            elapsed: elapsed,
            total: total,
            onPlayPause: onPlayPause,
            onSeek: onSeek,
            tokens: tokens,
          ),
        ],
      ),
    );
  }
}

// ─── Highlight text ───────────────────────────────────────────────────────────

class _HighlightText extends StatelessWidget {
  const _HighlightText({
    required this.text,
    required this.baseStyle,
    required this.highlightStyle,
    this.highlightedIndex,
  });

  final String text;
  final TextStyle baseStyle;
  final TextStyle highlightStyle;
  final int? highlightedIndex;

  @override
  Widget build(BuildContext context) {
    if (highlightedIndex == null) {
      return Text(text, style: baseStyle);
    }

    final words = text.split(' ');
    final spans = <TextSpan>[];

    for (var i = 0; i < words.length; i++) {
      final isHighlighted = i == highlightedIndex;
      spans.add(TextSpan(
        text: i < words.length - 1 ? '${words[i]} ' : words[i],
        style: isHighlighted ? highlightStyle : baseStyle,
      ));
    }

    return RichText(text: TextSpan(children: spans));
  }
}

// ─── Transport row ────────────────────────────────────────────────────────────

class _Transport extends StatelessWidget {
  const _Transport({
    required this.title,
    required this.isPlaying,
    required this.progress,
    required this.elapsed,
    required this.total,
    required this.tokens,
    this.onPlayPause,
    this.onSeek,
  });

  final String title;
  final bool isPlaying;
  final double progress;
  final String elapsed;
  final String total;
  final StorytimeTokens tokens;
  final VoidCallback? onPlayPause;
  final ValueChanged<double>? onSeek;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            title,
            style: AppTypography.headlineSmall.copyWith(color: tokens.cream),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          // Progress bar
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: tokens.gold,
              inactiveTrackColor: tokens.cream.withValues(alpha: 0.18),
              thumbColor: tokens.gold,
              overlayColor: tokens.gold.withValues(alpha: 0.18),
            ),
            child: Slider(
              value: progress.clamp(0.0, 1.0),
              onChanged: onSeek,
            ),
          ),
          // Time row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                elapsed,
                style: AppTypography.labelSmall.copyWith(
                  color: tokens.cream.withValues(alpha: 0.55),
                ),
              ),
              // Play/pause button
              GestureDetector(
                onTap: onPlayPause,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: tokens.ember,
                    boxShadow: AppShadows.primaryGlow,
                  ),
                  child: Icon(
                    isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
              Text(
                total,
                style: AppTypography.labelSmall.copyWith(
                  color: tokens.cream.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
