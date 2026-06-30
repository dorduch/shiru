import 'package:flutter/material.dart';
import '../../../logic/story_tokenizer.dart';
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

          // Title — sits directly under the hero art so the reading order is
          // title → story → controls (not story → title).
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Text(
              title,
              style: AppTypography.titleLarge.copyWith(color: tokens.cream),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Read text — auto-follows the highlighted word as it is narrated.
          Expanded(
            child: _ReadAlongText(
              text: bodyText,
              highlightedIndex: highlightedWordIndex,
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              baseStyle: AppTypography.storyBody.copyWith(
                color: tokens.cream.withValues(alpha: 0.85),
              ),
              highlightStyle: AppTypography.storyBody.copyWith(
                color: AppColors.gold,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // Transport row
          _Transport(
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

// ─── Read-along (auto-scrolling) text ─────────────────────────────────────────

/// Scrollable story text that keeps the highlighted word in a comfortable
/// reading band. It only scrolls when the active word drifts out of that band,
/// so the text glides paragraph-by-paragraph rather than jittering on every
/// word. Position is computed with a [TextPainter] laid out at the content
/// width, so it tracks the real line of the highlighted character.
class _ReadAlongText extends StatefulWidget {
  const _ReadAlongText({
    required this.text,
    required this.highlightedIndex,
    required this.baseStyle,
    required this.highlightStyle,
    required this.padding,
  });

  final String text;
  final int? highlightedIndex;
  final TextStyle baseStyle;
  final TextStyle highlightStyle;
  final EdgeInsets padding;

  @override
  State<_ReadAlongText> createState() => _ReadAlongTextState();
}

class _ReadAlongTextState extends State<_ReadAlongText> {
  final ScrollController _controller = ScrollController();

  @override
  void didUpdateWidget(_ReadAlongText old) {
    super.didUpdateWidget(old);
    if (widget.highlightedIndex != old.highlightedIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _follow());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _follow() {
    final index = widget.highlightedIndex;
    if (index == null || !mounted || !_controller.hasClients) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;

    final words = tokenizeStory(widget.text);
    if (index < 0 || index >= words.length) return;

    final contentWidth = box.size.width - widget.padding.horizontal;
    if (contentWidth <= 0) return;

    final painter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.baseStyle),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: contentWidth);

    // Top of the line holding the highlighted word, in scroll-content coords.
    final caret = painter.getOffsetForCaret(
      TextPosition(offset: words[index].start),
      Rect.zero,
    );
    final wordTop = caret.dy + widget.padding.top;
    final lineHeight = painter.preferredLineHeight;

    final position = _controller.position;
    final viewport = position.viewportDimension;
    final current = position.pixels;

    // Comfortable band: scroll only when the word leaves the [15%, 70%] window.
    final bandTop = current + viewport * 0.15;
    final bandBottom = current + viewport * 0.70 - lineHeight;
    if (wordTop >= bandTop && wordTop <= bandBottom) return;

    final target = (wordTop - viewport * 0.35).clamp(0.0, position.maxScrollExtent);
    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _controller,
      padding: widget.padding,
      child: _HighlightText(
        text: widget.text,
        highlightedIndex: widget.highlightedIndex,
        baseStyle: widget.baseStyle,
        highlightStyle: widget.highlightStyle,
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

    // Walk the canonical word ranges, emitting the inter-word whitespace
    // (including `\n\n` paragraph breaks) verbatim so the layout is unchanged
    // while word [highlightedIndex] is the only span styled gold. The rendered
    // word-span count equals tokenizeStory(text).length, which matches the
    // timing array — so the highlight never drifts.
    final words = tokenizeStory(text);
    final spans = <TextSpan>[];
    var cursor = 0;

    for (var i = 0; i < words.length; i++) {
      final (:start, :end) = words[i];
      if (start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, start), style: baseStyle));
      }
      spans.add(TextSpan(
        text: text.substring(start, end),
        style: i == highlightedIndex ? highlightStyle : baseStyle,
      ));
      cursor = end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor), style: baseStyle));
    }

    return RichText(text: TextSpan(children: spans));
  }
}

// ─── Transport row ────────────────────────────────────────────────────────────

class _Transport extends StatelessWidget {
  const _Transport({
    required this.isPlaying,
    required this.progress,
    required this.elapsed,
    required this.total,
    required this.tokens,
    this.onPlayPause,
    this.onSeek,
  });

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
          // Progress bar
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: tokens.gold,
              inactiveTrackColor: tokens.trackInactive,
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
                    color: tokens.onAccent,
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
