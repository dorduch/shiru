import 'package:flutter/material.dart';
import '../../../logic/story_tokenizer.dart';
import '../../../services/key_value_store.dart';
import '../../../theme/app_radius.dart';
import '../../../theme/app_typography.dart';
import '../../../theme/app_shadows.dart';
import '../../../theme/lantern_tokens.dart';

/// Persisted key for the read-along text-size preference (`'1.0'` or
/// `'1.25'`). Stored via the same secure key-value store the PIN gate uses
/// for its lockout counters — there's no dedicated "app settings" store yet,
/// so this reuses that existing pattern rather than introducing a new one.
const _kTextScaleKey = 'storytime_text_scale';

/// The enlarged ("A+") read-along text scale multiplier, applied on top of
/// `AppTypography.storyBody`.
const double _kLargeTextScale = 1.25;

/// Dark bedtime story player widget.
///
/// Layout:
///  - Art panel (top half) — any widget, usually a colored container / image.
///  - Follow-along read text with lantern-highlighted current word.
///  - Bottom transport row: play/pause + elapsed/total time + progress bar.
///
/// [highlightedWordIndex] is the zero-based word index within [bodyText] to
/// highlight in the lantern accent color. Real audio sync is NOT wired here —
/// the parameter is kept external so the parent can drive it from any source.
class StScenePlayer extends StatefulWidget {
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
  State<StScenePlayer> createState() => _StScenePlayerState();
}

class _StScenePlayerState extends State<StScenePlayer> {
  // Direct instantiation (rather than reading `keyValueStoreProvider` via
  // Riverpod) so this widget stays a plain `StatefulWidget` — it's mounted
  // in tests without a `ProviderScope` ancestor. Same secure-storage backend
  // `PinGateScreen` uses for its lockout counters, just without the DI layer.
  final KeyValueStore _store = SecureKeyValueStore();
  double _textScale = 1.0;

  @override
  void initState() {
    super.initState();
    _loadTextScale();
  }

  Future<void> _loadTextScale() async {
    final saved = await _store.read(key: _kTextScaleKey);
    final scale = double.tryParse(saved ?? '');
    if (mounted && scale != null) {
      setState(() => _textScale = scale);
    }
  }

  Future<void> _toggleTextScale() async {
    final next = _textScale == 1.0 ? _kLargeTextScale : 1.0;
    setState(() => _textScale = next);
    await _store.write(key: _kTextScaleKey, value: next.toString());
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<LanternTokens>()!;
    final isLarge = _textScale != 1.0;

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
            child: widget.artPanel ??
                Container(
                  color: tokens.nightCard,
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: tokens.lantern.withValues(alpha: 0.4),
                    size: 64,
                  ),
                ),
          ),

          // Title — sits directly under the hero art so the reading order is
          // title → story → controls (not story → title).
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: AppTypography.titleLarge.copyWith(color: tokens.moon),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                _TextSizeToggle(
                  isLarge: isLarge,
                  tokens: tokens,
                  onTap: _toggleTextScale,
                ),
              ],
            ),
          ),

          // Read text — auto-follows the highlighted word as it is narrated.
          Expanded(
            child: _ReadAlongText(
              text: widget.bodyText,
              highlightedIndex: widget.highlightedWordIndex,
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              baseStyle: AppTypography.storyBody.copyWith(
                fontSize: (AppTypography.storyBody.fontSize ?? 20) * _textScale,
                color: tokens.moon.withValues(alpha: 0.85),
              ),
              highlightStyle: AppTypography.storyBody.copyWith(
                fontSize: (AppTypography.storyBody.fontSize ?? 20) * _textScale,
                color: tokens.lantern,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // Transport row
          _Transport(
            isPlaying: widget.isPlaying,
            progress: widget.progress,
            elapsed: widget.elapsed,
            total: widget.total,
            onPlayPause: widget.onPlayPause,
            onSeek: widget.onSeek,
            tokens: tokens,
          ),
        ],
      ),
    );
  }
}

/// Small "A / A+" segmented control that scales the read-along text.
/// Persisted per device via [keyValueStoreProvider] (see [_kTextScaleKey]).
class _TextSizeToggle extends StatelessWidget {
  const _TextSizeToggle({
    required this.isLarge,
    required this.tokens,
    required this.onTap,
  });

  final bool isLarge;
  final LanternTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: isLarge ? 'Text size: large. Switch to normal.' : 'Text size: normal. Switch to large.',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: tokens.nightCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: tokens.hush),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'A',
                style: AppTypography.labelSmall.copyWith(
                  color: isLarge ? tokens.moonFaint : tokens.lantern,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                'A+',
                style: AppTypography.labelSmall.copyWith(
                  color: isLarge ? tokens.lantern : tokens.moonFaint,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
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
    // Re-sync on a highlight change (normal narration tick) or a text-size
    // change (the A/A+ toggle) — the latter shifts line heights enough that
    // the current word can fall outside the comfort band even though its
    // index didn't move.
    if (widget.highlightedIndex != old.highlightedIndex ||
        widget.baseStyle.fontSize != old.baseStyle.fontSize) {
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
  final LanternTokens tokens;
  final VoidCallback? onPlayPause;
  final ValueChanged<double>? onSeek;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Vertical insets trimmed from the original (8, 20) to fund the
      // slider→row gap below without growing the transport row's total
      // height — see the SizedBox between the slider and the time row.
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress bar
          Semantics(
            label: 'Story progress',
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 14),
                activeTrackColor: tokens.lantern,
                // LanternTokens has no direct `trackInactive` equivalent (that
                // field was mode-aware on StorytimeTokens — day vs bedtime);
                // `hush` is the single dim/inactive hairline token that plays
                // the same "the rest of the track" role on the one permanent
                // dark ground.
                inactiveTrackColor: tokens.hush,
                thumbColor: tokens.lantern,
                overlayColor: tokens.lantern.withValues(alpha: 0.18),
              ),
              child: Slider(
                value: progress.clamp(0.0, 1.0),
                onChanged: onSeek,
                semanticFormatterCallback: (value) =>
                    '${(value * 100).round()} percent',
              ),
            ),
          ),
          // Slack between the slider's touch target and the transport row
          // below — small fingers were catching the seek track while
          // reaching for play/pause.
          const SizedBox(height: 10),
          // Time row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                elapsed,
                style: AppTypography.labelSmall.copyWith(
                  color: tokens.moon.withValues(alpha: 0.55),
                ),
              ),
              // Play/pause button
              Semantics(
                button: true,
                label: isPlaying ? 'Pause story' : 'Play story',
                child: GestureDetector(
                  onTap: onPlayPause,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: tokens.lantern,
                      boxShadow: AppShadows.primaryGlow,
                    ),
                    child: Icon(
                      isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      // nightDeep: same on-accent contrast convention GlowButton
                      // uses for its label/icon on the lantern/ctaGradient fill.
                      color: tokens.nightDeep,
                      size: 26,
                    ),
                  ),
                ),
              ),
              Text(
                total,
                style: AppTypography.labelSmall.copyWith(
                  color: tokens.moon.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
