import 'package:flutter/material.dart';
import 'pixel_sprite.dart';
import '../models/sprites.dart';
import '../services/giphy_service.dart';

class GiphySprite extends StatefulWidget {
  final String title;
  final SpriteDef fallbackSprite;
  final SpriteState state;
  final double scale;

  const GiphySprite({
    Key? key,
    required this.title,
    required this.fallbackSprite,
    this.state = SpriteState.idle,
    this.scale = 6.0,
  }) : super(key: key);

  @override
  _GiphySpriteState createState() => _GiphySpriteState();
}

class _GiphySpriteState extends State<GiphySprite> {
  String? _gifUrl;

  @override
  void initState() {
    super.initState();
    _fetchGif();
  }

  @override
  void didUpdateWidget(GiphySprite oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title) {
      if (mounted) {
        setState(() => _gifUrl = null);
        _fetchGif();
      }
    }
  }

  Future<void> _fetchGif() async {
    final url = await GiphyService.fetchPixelArtGif(widget.title);
    if (mounted && url != null) {
      setState(() => _gifUrl = url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16 * widget.scale,
      height: 16 * widget.scale,
      child: Stack(
        children: [
          PixelSprite(
            sprite: widget.fallbackSprite,
            state: widget.state,
            scale: widget.scale,
          ),
          if (_gifUrl != null)
            Image.network(
              _gifUrl!,
              width: 16 * widget.scale,
              height: 16 * widget.scale,
              fit: BoxFit.contain,
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (frame == null) return const SizedBox.shrink();
                return child;
              },
              errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }
}
