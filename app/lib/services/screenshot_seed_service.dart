import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../db/database_service.dart';
import '../models/audio_card.dart';
import '../models/sprites.dart';
import 'library_import_service.dart';

class ScreenshotSeedService {
  ScreenshotSeedService._();

  static const _marketingTitles = <String>[
    'Bedtime Stories',
    'Sing-Along Favorites',
    'Little Adventures',
    'Goodnight Wind-Down',
    'Morning Music',
    'Storybook Classics',
    'Rainy Day Tales',
    'Animal Parade',
    'Calm Time',
    'Family Favorites',
  ];

  static const _marketingColors = <String>[
    '#FFF1F2',
    '#F5F3FF',
    '#EFF6FF',
    '#E0F2FE',
    '#FEF3C7',
    '#ECFEFF',
    '#FCE7F3',
    '#ECFCCB',
    '#F0FDF4',
    '#FAE8FF',
  ];

  static Future<void> ensureSeeded() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final existingCards = await DatabaseService.instance.readAllCards();
    final existingByAudioPath = {
      for (final card in existingCards) path.normalize(card.audioPath): card,
    };

    final audioFiles = await docsDir
        .list()
        .where((entity) => entity is File)
        .cast<File>()
        .where((file) {
          final extension = path
              .extension(file.path)
              .replaceFirst('.', '')
              .toLowerCase();
          return LibraryImportService.supportedAudioExtensions.contains(
            extension,
          );
        })
        .toList();

    audioFiles.sort((a, b) => a.path.compareTo(b.path));

    if (audioFiles.isEmpty) {
      return;
    }

    final createdAtBase = DateTime.now().millisecondsSinceEpoch;
    final marketingCards = <AudioCard>[];

    for (var index = 0; index < audioFiles.length; index++) {
      final file = audioFiles[index];
      final normalizedPath = path.normalize(file.path);
      final existingCard = existingByAudioPath[normalizedPath];
      final title = _marketingTitle(index);

      marketingCards.add(
        AudioCard(
          id: existingCard?.id ?? const Uuid().v4(),
          collectionId: null,
          title: title,
          color: _marketingColors[index % _marketingColors.length],
          spriteKey: existingCard?.spriteKey ?? autoAssignSprite(title).id,
          customImagePath: existingCard?.customImagePath,
          audioPath: file.path,
          playbackPosition: 0,
          position: index,
          createdAt: existingCard?.createdAt ?? (createdAtBase + index),
        ),
      );
    }

    await DatabaseService.instance.replaceCards(marketingCards);
  }

  static String _marketingTitle(int index) {
    if (index < _marketingTitles.length) {
      return _marketingTitles[index];
    }

    return 'Story Pick ${index + 1}';
  }
}
