import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' as intl;
import '../providers/cards_provider.dart';
import '../models/sprites.dart';
import 'pixel_sprite.dart';
import 'giphy_sprite.dart';

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
                      IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 28), onPressed: () => context.go('/')),
                      const SizedBox(width: 8),
                      const Text('Library', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
                    ]
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.push('/parent/change-pin'),
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: const Color(0xFFE5E7EB), width: 2),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.lock_outline, color: Color(0xFF6B7280), size: 20),
                              SizedBox(width: 8),
                              Text('Change PIN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => context.push('/parent/categories'),
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: const Color(0xFFE5E7EB), width: 2),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.category, color: Color(0xFF6B7280), size: 20),
                              SizedBox(width: 8),
                              Text('Categories', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => context.push('/story-builder'),
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: const [BoxShadow(color: Color(0x408B5CF6), blurRadius: 12, offset: Offset(0, 4))],
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text('Story Builder', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
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
                      ),
                    ],
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
                                child: GiphySprite(title: card.spriteKey != null && card.spriteKey!.isNotEmpty ? card.spriteKey! : card.title, fallbackSprite: spriteDef, state: SpriteState.idle, scale: 2.5),
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
