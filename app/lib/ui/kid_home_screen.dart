import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' as intl;
import '../models/audio_card.dart';
import '../models/sprites.dart';
import 'package:flutter/services.dart';
import '../services/audio_service.dart';
import '../theme/app_responsive.dart';
import 'pixel_sprite.dart';

class AudioCardTile extends ConsumerStatefulWidget {
  final AudioCard card;
  final bool isPlayingThis;
  final bool isPlayingGlobal;
  final bool isAnotherPlaying;

  const AudioCardTile({
    Key? key,
    required this.card,
    required this.isPlayingThis,
    required this.isPlayingGlobal,
    required this.isAnotherPlaying,
  }) : super(key: key);

  @override
  ConsumerState<AudioCardTile> createState() => _AudioCardTileState();
}

class _AudioCardTileState extends ConsumerState<AudioCardTile>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.isPlayingThis && widget.isPlayingGlobal) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant AudioCardTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlayingThis && widget.isPlayingGlobal) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      _pulseController.stop();
      _pulseController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 200),
      );
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spriteDef = widget.card.spriteKey != null
        ? (predefinedSprites[widget.card.spriteKey!] ??
              autoAssignSprite(widget.card.title))
        : autoAssignSprite(widget.card.title);
    final state = widget.isPlayingThis
        ? (widget.isPlayingGlobal ? SpriteState.active : SpriteState.idle)
        : SpriteState.idle;

    final scale = _isPressed ? 0.93 : 1.0;
    final opacity = widget.isAnotherPlaying ? 0.6 : 1.0;
    final isCompactPortrait =
        AppResponsive.isCompact(context) && AppResponsive.isPortrait(context);
    final titleFontSize = AppResponsive.fontSize(context, 20);
    final titleLineHeight = isCompactPortrait ? 1.15 : 1.0;
    final titleMaxLines = isCompactPortrait ? 2 : 1;

    final isVideo = widget.card.mediaType == CardMediaType.video;

    return Semantics(
      label: isVideo
          ? '${widget.card.title}, video, tap to watch'
          : '${widget.card.title}, audio, tap to play',
      button: true,
      enabled: !widget.isAnotherPlaying,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: opacity,
        child: GestureDetector(
          onTapDown: (_) {
            HapticFeedback.lightImpact();
            setState(() => _isPressed = true);
          },
          onTapUp: (_) {
            setState(() => _isPressed = false);
          },
          onTapCancel: () {
            setState(() => _isPressed = false);
          },
          onTap: () {
            HapticFeedback.mediumImpact();
            if (isVideo) {
              context.push('/video/${Uri.encodeComponent(widget.card.id)}');
            } else {
              ref.read(audioServiceProvider).playCard(widget.card);
            }
          },
          child: AnimatedScale(
            scale: scale,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutBack,
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: widget.isPlayingThis ? _pulseAnimation.value : 1.0,
                  child: child,
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: widget.isPlayingThis
                      ? Border.all(color: const Color(0xFFFF6B6B), width: 4)
                      : Border.all(color: Colors.transparent, width: 4),
                  boxShadow: widget.isPlayingThis
                      ? const [
                          BoxShadow(
                            color: Color(0x66FF6B6B),
                            blurRadius: 24,
                            spreadRadius: 4,
                          ),
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 24,
                            offset: Offset(0, 12),
                          ),
                        ]
                      : const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 24,
                            offset: Offset(0, 12),
                          ),
                        ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: hexOrFallback(widget.card.color),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            alignment: Alignment.center,
                            child: FittedBox(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: PixelSprite(
                                  sprite: spriteDef,
                                  state: state,
                                  scale: AppResponsive.spriteScale(context),
                                ),
                              ),
                            ),
                          ),
                          if (isVideo)
                            const PositionedDirectional(
                              top: 8,
                              end: 8,
                              child: ExcludeSemantics(child: _VideoBadge()),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: titleFontSize * titleLineHeight * titleMaxLines,
                      child: Center(
                        child: Text(
                          widget.card.title,
                          textAlign: TextAlign.center,
                          maxLines: titleMaxLines,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: titleFontSize,
                            height: titleLineHeight,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1A1A1A),
                          ),
                          textDirection:
                              intl.Bidi.detectRtlDirectionality(
                                widget.card.title,
                              )
                              ? TextDirection.rtl
                              : TextDirection.ltr,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VideoBadge extends StatelessWidget {
  const _VideoBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xE6111827),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.videocam_rounded, size: 15, color: Color(0xFFF8FAFC)),
          SizedBox(width: 4),
          Text(
            'VIDEO',
            style: TextStyle(
              color: Color(0xFFF8FAFC),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
