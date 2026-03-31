import 'dart:async';
import 'package:flutter/material.dart';
import '../models/sprites.dart';

enum SpriteState { idle, active, tap }

class PixelSprite extends StatefulWidget {
  final SpriteDef sprite;
  final SpriteState state;
  final double scale;

  const PixelSprite({
    Key? key,
    required this.sprite,
    this.state = SpriteState.idle,
    this.scale = 6.0,
  }) : super(key: key);

  @override
  _PixelSpriteState createState() => _PixelSpriteState();
}

class _PixelSpriteState extends State<PixelSprite> {
  int _currentFrame = 0;
  Timer? _timer;
  SpriteState _currentState = SpriteState.idle;

  @override
  void initState() {
    super.initState();
    _currentState = widget.state;
    _startAnimation();
  }

  @override
  void didUpdateWidget(PixelSprite oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state ||
        oldWidget.sprite.id != widget.sprite.id) {
      if (widget.state == SpriteState.tap) {
        _triggerTap();
      } else {
        _currentState = widget.state;
        _startAnimation();
      }
    }
  }

  void _triggerTap() {
    _currentState = SpriteState.tap;
    _currentFrame = 0;
    _startAnimation();
  }

  void _startAnimation() {
    _timer?.cancel();
    final stateKey = _currentState.name;
    final frames =
        widget.sprite.frames[stateKey] ?? widget.sprite.frames['idle']!;
    if (frames.isEmpty) return;

    final fps = widget.sprite.fps[stateKey] ?? 6;
    final duration = Duration(milliseconds: 1000 ~/ fps);

    _timer = Timer.periodic(duration, (timer) {
      if (!mounted) return;
      setState(() {
        _currentFrame++;
        if (_currentFrame >= frames.length) {
          if (_currentState == SpriteState.tap) {
            _currentState = widget.state == SpriteState.tap
                ? SpriteState.active
                : widget.state;
            _startAnimation(); // restart with new state
            return;
          }
          _currentFrame = 0;
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stateKey = _currentState.name;
    final frames =
        widget.sprite.frames[stateKey] ?? widget.sprite.frames['idle']!;
    final frameData = frames.isNotEmpty
        ? frames[_currentFrame % frames.length]
        : <List<int>>[];

    return CustomPaint(
      size: Size(16 * widget.scale, 16 * widget.scale),
      painter: PixelPainter(
        frame: frameData,
        palette: widget.sprite.palette,
        scale: widget.scale,
      ),
    );
  }
}

class PixelPainter extends CustomPainter {
  final List<List<int>> frame;
  final List<String> palette;
  final double scale;

  PixelPainter({
    required this.frame,
    required this.palette,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = false;

    for (int y = 0; y < frame.length; y++) {
      final row = frame[y];
      for (int x = 0; x < row.length; x++) {
        final colorIndex = row[x];
        if (colorIndex > 0 && colorIndex < palette.length) {
          paint.color = hexOrFallback(palette[colorIndex]);
          canvas.drawRect(
            Rect.fromLTWH(x * scale, y * scale, scale, scale),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant PixelPainter oldDelegate) {
    return true; // We animate frequently
  }
}
