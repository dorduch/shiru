import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' as intl;
import '../providers/cards_provider.dart';
import '../models/sprites.dart';
import 'pixel_sprite.dart';

class ParentListScreen extends ConsumerWidget {
  const ParentListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardsAsync = ref.watch(cardsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(icon: const Icon(Icons.arrow_back_ios, size: 28), onPressed: () => context.go('/')),
                      const SizedBox(width: 8),
                      const Text('Library', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
                    ]
                  ),
                  GestureDetector(
                    onTap: () => context.go('/parent/edit'),
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B6B),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [BoxShadow(color: Color(0x40FF6B6B), blurRadius: 12, offset: Offset(0, 4))]
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.add, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text('Add Card', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white))
                        ]
                      )
                    )
                  )
                ]
              ),
              const SizedBox(height: 24),
              Expanded(
                child: cardsAsync.when(
                  data: (cards) {
                    if (cards.isEmpty) {
                      return const Center(child: Text("Library is empty.", style: TextStyle(fontSize: 24, color: Colors.black54)));
                    }
                    return ListView.separated(
                      itemCount: cards.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final card = cards[index];
                        final spriteDef = autoAssignSprite(card.title);
                        return Container(
                          height: 100,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 4))]
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 68, height: 68,
                                decoration: BoxDecoration(color: hexOrFallback(card.color), borderRadius: BorderRadius.circular(12)),
                                alignment: Alignment.center,
                                child: PixelSprite(sprite: spriteDef, state: SpriteState.idle, scale: 2.5),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                child: Text(
                                  card.title, 
                                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                                  textDirection: intl.Bidi.detectRtlDirectionality(card.title) ? TextDirection.rtl : TextDirection.ltr,
                                )
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.grey),
                                onPressed: () => context.go('/parent/edit', extra: card.id)
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.redAccent),
                                onPressed: () {
                                  ref.read(cardsProvider.notifier).deleteCard(card.id);
                                }
                              )
                            ],
                          )
                        );
                      }
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Center(child: Text(e.toString())),
                )
              )
            ]
          )
        )
      )
    );
  }
}
