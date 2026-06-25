import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/audio_card.dart';
import '../db/database_service.dart';
import '../services/library_import_service.dart';
import '../services/analytics_service.dart';

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

  Future<void> addCards(List<AudioCard> cards) async {
    await DatabaseService.instance.createCards(cards);
    await loadCards();
  }

  Future<void> updateCard(AudioCard card) async {
    await DatabaseService.instance.updateCard(card);
    await loadCards();
  }

  Future<void> replaceCards(List<AudioCard> cards) async {
    await DatabaseService.instance.replaceCards(cards);
    await loadCards();
  }

  Future<void> deleteCard(String id) async {
    AudioCard? deletedCard;
    final cards = state.value;
    if (cards != null) {
      for (final card in cards) {
        if (card.id == id) {
          deletedCard = card;
          break;
        }
      }
    }

    if (deletedCard == null) {
      try {
        deletedCard = await DatabaseService.instance.readCard(id);
      } catch (_) {}
    }
    await DatabaseService.instance.deleteCard(id);
    AnalyticsService.instance.logCardDeleted();

    if (deletedCard != null) {
      final mediaPath = deletedCard.mediaPath;
      final remainingReferences = await DatabaseService.instance
          .countCardsWithMediaPath(mediaPath);
      if (remainingReferences == 0) {
        await LibraryImportService.deleteImportedMedia(mediaPath);
      }
    }

    await loadCards();
  }
}

final cardsProvider =
    StateNotifierProvider<CardsNotifier, AsyncValue<List<AudioCard>>>((ref) {
      return CardsNotifier();
    });
