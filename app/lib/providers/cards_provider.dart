import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/audio_card.dart';
import '../db/database_service.dart';

class CardsNotifier extends StateNotifier<AsyncValue<List<AudioCard>>> {
  CardsNotifier() : super(const AsyncValue.loading()) {
    loadCards();
  }

  Future<void> loadCards() async {
    try {
      final cards = await DatabaseService.instance.readAllCards();
      state = AsyncValue.data(cards);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> addCard(AudioCard card) async {
    await DatabaseService.instance.createCard(card);
    await loadCards();
  }

  Future<void> deleteCard(String id) async {
    await DatabaseService.instance.deleteCard(id);
    await loadCards();
  }
}

final cardsProvider = StateNotifierProvider<CardsNotifier, AsyncValue<List<AudioCard>>>((ref) {
  return CardsNotifier();
});
