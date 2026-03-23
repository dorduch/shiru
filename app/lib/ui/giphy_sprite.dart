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
  bool _isLoading = true;

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
        setState(() => _isLoading = true);
        _fetchGif();
      }
    }
  }

  Future<void> _fetchGif() async {
    final url = await GiphyService.fetchPixelArtGif(widget.title);
    if (mounted) {
      setState(() {
        _gifUrl = url;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return SizedBox(
        width: 16 * widget.scale,
        height: 16 * widget.scale,
        child: const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (_gifUrl != null) {
      return SizedBox(
        width: 16 * widget.scale,
        height: 16 * widget.scale,
        child: Image.network(
          _gifUrl!,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            // Fallback to our generated pixel art if loading fails
            return PixelSprite(
              sprite: widget.fallbackSprite,
              state: widget.state,
              scale: widget.scale,
            );
          },
        ),
      );
    }

    // Fallback if no GIF was found
    return PixelSprite(
      sprite: widget.fallbackSprite,
      state: widget.state,
      scale: widget.scale,
    );
  }
}
