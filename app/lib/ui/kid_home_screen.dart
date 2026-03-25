import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' as intl;
import '../models/audio_card.dart';
import '../models/sprites.dart';
import '../providers/cards_provider.dart';
import '../providers/audio_player_provider.dart';
import '../providers/categories_provider.dart';
import '../models/category.dart' as cat_model;
import 'package:flutter/services.dart';
import '../services/audio_service.dart';
import 'pixel_sprite.dart';
import 'giphy_sprite.dart';

class KidHomeScreen extends ConsumerStatefulWidget {
  const KidHomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<KidHomeScreen> createState() => _KidHomeScreenState();
}

class _KidHomeScreenState extends ConsumerState<KidHomeScreen> {
  String? _selectedCategoryId; // null means "All"

  @override
  Widget build(BuildContext context) {
    final cardsAsync = ref.watch(cardsProvider);
    final currentlyPlayingId = ref.watch(currentPlayingCardIdProvider);
    final isPlaying = ref.watch(isPlayingProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final categories = categoriesAsync.value ?? [];

    // Reset to "All" if selected category was deleted
    if (_selectedCategoryId != null &&
        categories.every((c) => c.id != _selectedCategoryId)) {
      _selectedCategoryId = null;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFFBEB),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header (unchanged)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          'assets/images/app_icon.png',
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'שירו',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF222f3e),
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () => context.push('/pin'),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          )
                        ],
                      ),
                      child: const Icon(Icons.lock, color: Colors.grey),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 16),

              // Category tabs (only shown if categories exist)
              if (categories.isNotEmpty) ...[
                _buildCategoryTabs(categories),
                const SizedBox(height: 16),
              ],

              Expanded(
                child: cardsAsync.when(
                  data: (cards) {
                    // Filter by selected category
                    final filtered = _selectedCategoryId == null
                        ? cards
                        : cards.where((c) => c.collectionId == _selectedCategoryId).toList();

                    if (filtered.isEmpty) {
                      return Center(
                        child: Text(
                          _selectedCategoryId == null
                              ? "בקשו מההורים להוסיף כרטיסים!"
                              : "אין כרטיסים בקטגוריה הזו!",
                          style: const TextStyle(fontSize: 24, color: Colors.black54),
                        ),
                      );
                    }
                    return GridView.builder(
                      padding: const EdgeInsets.only(bottom: 24),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 240,
                        crossAxisSpacing: 24,
                        mainAxisSpacing: 24,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final card = filtered[index];
                        final isPlayingThis = currentlyPlayingId == card.id;
                        final isAnotherPlaying = currentlyPlayingId != null && currentlyPlayingId != card.id;
                        return AudioCardTile(
                          card: card,
                          isPlayingThis: isPlayingThis,
                          isPlayingGlobal: isPlaying,
                          isAnotherPlaying: isAnotherPlaying,
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text('שגיאה: $err')),
                )
              ),

              const SizedBox(height: 24),
              if (currentlyPlayingId != null)
                 _buildPlayerPill(ref, currentlyPlayingId, isPlaying)
            ]
          )
        )
      )
    );
  }

  Widget _buildCategoryTabs(List<cat_model.Category> categories) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildTab(label: 'הכל', isActive: _selectedCategoryId == null, onTap: () {
            setState(() => _selectedCategoryId = null);
          }),
          const SizedBox(width: 8),
          ...categories.map((cat) => Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: _buildTab(
              label: '${cat.emoji} ${cat.name}',
              isActive: _selectedCategoryId == cat.id,
              onTap: () {
                setState(() => _selectedCategoryId = cat.id);
              },
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildTab({required String label, required bool isActive, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF22C55E) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isActive ? Colors.white : const Color(0xFF6B7280),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerPill(WidgetRef ref, String playingId, bool isPlayingGlobal) {
    final cardsAsync = ref.read(cardsProvider);
    final card = cardsAsync.value?.firstWhere((c) => c.id == playingId);
    if (card == null) return const SizedBox.shrink();

    final spriteDef = autoAssignSprite(card.title);

    return Container(
      height: 88,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(44),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 24, offset: Offset(0, 12))]
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
              child: Row(
                children: [
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(color: hexOrFallback(card.color), shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: FittedBox(
                        child: GiphySprite(title: card.spriteKey != null && card.spriteKey!.isNotEmpty ? card.spriteKey! : card.title, fallbackSprite: spriteDef, state: isPlayingGlobal ? SpriteState.active : SpriteState.idle, scale: 3.5)
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            card.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A)),
                            textDirection: intl.Bidi.detectRtlDirectionality(card.title) ? TextDirection.rtl : TextDirection.ltr,
                          ),
                          const SizedBox(height: 2),
                          Text(isPlayingGlobal ? "מתנגן כעת" : "מושהה", maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isPlayingGlobal ? const Color(0xFF22C55E) : const Color(0xFF6B7280))),
                        ],
                      )
                  )
                ],
              ),
          ),
          const SizedBox(width: 8),
          Row(
            children: [
              GestureDetector(
                onTap: () => ref.read(audioServiceProvider).stop(),
                child: Container(
                  width: 56, height: 56,
                  decoration: const BoxDecoration(color: Color(0xFFF6F7F8), shape: BoxShape.circle),
                  child: const Icon(Icons.stop_rounded, size: 28, color: Color(0xFF1A1A1A)),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => ref.read(audioServiceProvider).playCard(card),
                child: Container(
                  width: 64, height: 64,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF6B6B),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Color(0x40FF6B6B), blurRadius: 12, offset: Offset(0, 4))]
                  ),
                  child: Icon(isPlayingGlobal ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 36, color: Colors.white),
                ),
              )
            ],
          )
        ],
      )
    );
  }
}

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

class _AudioCardTileState extends ConsumerState<AudioCardTile> with SingleTickerProviderStateMixin {
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
      _pulseController.animateTo(0.0, duration: const Duration(milliseconds: 200));
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spriteDef = autoAssignSprite(widget.card.title);
    final state = widget.isPlayingThis
        ? (widget.isPlayingGlobal ? SpriteState.active : SpriteState.idle)
        : SpriteState.idle;

    final scale = _isPressed ? 0.93 : 1.0;
    final opacity = widget.isAnotherPlaying ? 0.6 : 1.0;
    
    return AnimatedOpacity(
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
          ref.read(audioServiceProvider).playCard(widget.card);
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
                        BoxShadow(color: Color(0x66FF6B6B), blurRadius: 24, spreadRadius: 4),
                        BoxShadow(color: Colors.black12, blurRadius: 24, offset: Offset(0, 12))
                      ]
                    : const [BoxShadow(color: Colors.black12, blurRadius: 24, offset: Offset(0, 12))],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: hexOrFallback(widget.card.color),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: FittedBox(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: GiphySprite(title: widget.card.spriteKey != null && widget.card.spriteKey!.isNotEmpty ? widget.card.spriteKey! : widget.card.title, fallbackSprite: spriteDef, state: state, scale: 6.0),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.card.title,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A)),
                    textDirection: intl.Bidi.detectRtlDirectionality(widget.card.title) ? TextDirection.rtl : TextDirection.ltr,
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

