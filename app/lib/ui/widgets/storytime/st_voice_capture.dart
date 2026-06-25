import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_radius.dart';
import '../../../theme/app_typography.dart';
import '../../../theme/app_shadows.dart';

// ─── StCaptureRing ────────────────────────────────────────────────────────────

/// Circular progress ring with a centred mic icon and status text below.
///
/// [progress] ∈ [0, 1]. [status] is the line shown under the ring
/// (e.g. "Recording…", "Done!").
class StCaptureRing extends StatelessWidget {
  const StCaptureRing({
    super.key,
    required this.progress,
    this.status = '',
    this.size = 120,
  });

  final double progress;
  final String status;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<StorytimeTokens>()!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _RingPainter(
              progress: progress,
              trackColor: tokens.cream.withValues(alpha: 0.18),
              fillColor: tokens.gold,
              strokeWidth: 6,
            ),
            child: Center(
              child: Icon(
                Icons.mic_rounded,
                color: tokens.gold,
                size: size * 0.36,
              ),
            ),
          ),
        ),
        if (status.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            status,
            style:
                AppTypography.labelLarge.copyWith(color: tokens.cream.withValues(alpha: 0.7)),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.trackColor,
    required this.fillColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color trackColor;
  final Color fillColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final paint = Paint()
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Track
    paint.color = trackColor;
    canvas.drawCircle(center, radius, paint);

    // Fill
    paint.color = fillColor;
    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.fillColor != fillColor;
}

// ─── StPrompt ────────────────────────────────────────────────────────────────

/// A voice-capture prompt: a label line + the text the user should read.
class StPrompt extends StatelessWidget {
  const StPrompt({
    super.key,
    required this.promptText,
    this.label = 'Read aloud:',
  });

  final String promptText;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<StorytimeTokens>()!;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.night3.withValues(alpha: 0.4),
        borderRadius: AppRadius.medium,
        border:
            Border.all(color: tokens.cream.withValues(alpha: 0.15), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTypography.labelLarge.copyWith(
              color: tokens.cream.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            promptText,
            style: AppTypography.storyBody.copyWith(color: tokens.cream),
          ),
        ],
      ),
    );
  }
}

// ─── StRecordButton ───────────────────────────────────────────────────────────

/// Round ember record button with an animated halo ring.
class StRecordButton extends StatefulWidget {
  const StRecordButton({
    super.key,
    required this.isRecording,
    this.onTap,
    this.size = 72,
  });

  final bool isRecording;
  final VoidCallback? onTap;
  final double size;

  @override
  State<StRecordButton> createState() => _StRecordButtonState();
}

class _StRecordButtonState extends State<StRecordButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _halo;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _halo = Tween<double>(begin: 1.0, end: 1.22).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<StorytimeTokens>()!;

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _halo,
        builder: (context, child) {
          final haloSize = widget.isRecording
              ? widget.size * _halo.value
              : widget.size;
          return SizedBox(
            width: widget.size * 1.4,
            height: widget.size * 1.4,
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (widget.isRecording)
                    Container(
                      width: haloSize,
                      height: haloSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: tokens.ember.withValues(alpha: 0.22),
                      ),
                    ),
                  Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: tokens.ctaGradient,
                      boxShadow: AppShadows.primaryGlow,
                    ),
                    child: Icon(
                      widget.isRecording
                          ? Icons.stop_rounded
                          : Icons.mic_rounded,
                      color: Colors.white,
                      size: widget.size * 0.44,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── StVoiceWave ──────────────────────────────────────────────────────────────

/// Animated wave bars representing voice activity.
///
/// [active] controls whether bars animate. [barCount] defaults to 5.
class StVoiceWave extends StatefulWidget {
  const StVoiceWave({
    super.key,
    this.active = true,
    this.barCount = 5,
    this.color,
    this.height = 40,
  });

  final bool active;
  final int barCount;
  final Color? color;
  final double height;

  @override
  State<StVoiceWave> createState() => _StVoiceWaveState();
}

class _StVoiceWaveState extends State<StVoiceWave>
    with TickerProviderStateMixin {
  late List<AnimationController> _ctrls;
  late List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _ctrls = List.generate(widget.barCount, (i) {
      return AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 400 + i * 80),
      )..repeat(reverse: true);
    });
    _anims = List.generate(widget.barCount, (i) {
      return Tween<double>(begin: 0.15, end: 1.0).animate(
        CurvedAnimation(parent: _ctrls[i], curve: Curves.easeInOut),
      );
    });
  }

  @override
  void didUpdateWidget(StVoiceWave old) {
    super.didUpdateWidget(old);
    if (widget.active != old.active) {
      for (final c in _ctrls) {
        if (widget.active) {
          c.repeat(reverse: true);
        } else {
          c.stop();
        }
      }
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<StorytimeTokens>()!;
    final barColor = widget.color ?? tokens.gold;

    return SizedBox(
      height: widget.height,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(widget.barCount, (i) {
          return AnimatedBuilder(
            animation: _anims[i],
            builder: (context, _) {
              final h = widget.active
                  ? widget.height * _anims[i].value
                  : widget.height * 0.15;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                width: 4,
                height: h,
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
