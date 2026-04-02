import 'package:flutter_test/flutter_test.dart';
import 'package:shiru/services/library_import_service.dart';

void main() {
  group('LibraryImportService', () {
    test(
      'deriveTitleFromSourcePath removes extension and normalizes spaces',
      () {
        expect(
          LibraryImportService.deriveTitleFromSourcePath(
            '/tmp/The_great-story 01.mp3',
          ),
          'The great story 01',
        );
      },
    );

    test('deriveTitleFromSourcePath falls back for blank basename', () {
      expect(
        LibraryImportService.deriveTitleFromSourcePath('/tmp/.mp3'),
        'New Card',
      );
    });

    test('validateAudioSelection rejects unsupported extensions', () {
      expect(
        LibraryImportService.validateAudioSelection(
          sourcePath: '/tmp/story.ogg',
          sizeBytes: 1024,
        ),
        'This file type isn\'t supported. Try MP3, M4A, WAV, or AAC.',
      );
    });

    test('validateAudioSelection rejects oversized files', () {
      expect(
        LibraryImportService.validateAudioSelection(
          sourcePath: '/tmp/story.mp3',
          sizeBytes: LibraryImportService.maxAudioBytes + 1,
        ),
        'This file is too large (200 MB max).',
      );
    });

    test('validateAudioSelection accepts supported files in range', () {
      expect(
        LibraryImportService.validateAudioSelection(
          sourcePath: '/tmp/story.m4a',
          sizeBytes: 1024,
        ),
        isNull,
      );
    });

    test(
      'isManagedLibraryPath matches files stored in the library directory',
      () {
        expect(
          LibraryImportService.isManagedLibraryPath(
            filePath: '/app/docs/audio/story.mp3',
            libraryDirPath: '/app/docs',
          ),
          isTrue,
        );
      },
    );

    test(
      'isManagedLibraryPath rejects files outside the library directory',
      () {
        expect(
          LibraryImportService.isManagedLibraryPath(
            filePath: '/tmp/story.mp3',
            libraryDirPath: '/app/docs',
          ),
          isFalse,
        );
      },
    );
  });
}
