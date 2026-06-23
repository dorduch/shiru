import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiru/models/audio_card.dart';
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

    test('inferMediaType supports mixed audio and video selections', () {
      expect(
        LibraryImportService.inferMediaType('/tmp/story.MP3'),
        CardMediaType.audio,
      );
      expect(
        LibraryImportService.inferMediaType('/tmp/movie.MOV'),
        CardMediaType.video,
      );
      expect(LibraryImportService.inferMediaType('/tmp/unknown.ogg'), isNull);
    });

    test('validateVideoSelection accepts MP4, MOV, and M4V', () {
      for (final extension in LibraryImportService.supportedVideoExtensions) {
        expect(
          LibraryImportService.validateVideoSelection(
            sourcePath: '/tmp/movie.$extension',
            sizeBytes: 1024,
            duration: const Duration(minutes: 15),
          ),
          isNull,
        );
      }
    });

    test('validateVideoSelection rejects oversized video', () {
      expect(
        LibraryImportService.validateVideoSelection(
          sourcePath: '/tmp/movie.mp4',
          sizeBytes: LibraryImportService.maxVideoBytes + 1,
        ),
        'This video is too large (1 GB max).',
      );
    });

    test('validateVideoSelection rejects video over 15 minutes', () {
      expect(
        LibraryImportService.validateVideoSelection(
          sourcePath: '/tmp/movie.mp4',
          sizeBytes: 1024,
          duration:
              LibraryImportService.maxVideoDuration +
              const Duration(milliseconds: 1),
        ),
        'This video is too long (15 minutes max).',
      );
    });

    test('validateVideoSelection rejects an unreadable zero duration', () {
      expect(
        LibraryImportService.validateVideoSelection(
          sourcePath: '/tmp/movie.mp4',
          sizeBytes: 1024,
          duration: Duration.zero,
        ),
        'This video couldn\'t be read or isn\'t supported on this device.',
      );
    });

    test('probeVideoDuration uses an injected native metadata probe', () async {
      String? probedPath;

      final duration = await LibraryImportService.probeVideoDuration(
        '/tmp/movie.mp4',
        probe: (sourcePath) async {
          probedPath = sourcePath;
          return const Duration(minutes: 4);
        },
      );

      expect(probedPath, '/tmp/movie.mp4');
      expect(duration, const Duration(minutes: 4));
    });

    test('video import probes duration before accepting the file', () async {
      final tempDir = await Directory.systemTemp.createTemp('shiru-video-test');
      final source = File('${tempDir.path}/movie.mp4');
      await source.writeAsBytes([1, 2, 3]);
      addTearDown(() => tempDir.delete(recursive: true));

      expect(
        () => LibraryImportService.importMediaToLibrary(
          source.path,
          mediaType: CardMediaType.video,
          probeVideo: (_) async => const Duration(minutes: 16),
        ),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('This video is too long (15 minutes max).'),
          ),
        ),
      );
    });

    test('video import reports a failed native codec probe', () async {
      final tempDir = await Directory.systemTemp.createTemp('shiru-video-test');
      final source = File('${tempDir.path}/movie.mp4');
      await source.writeAsBytes([1, 2, 3]);
      addTearDown(() => tempDir.delete(recursive: true));

      expect(
        () => LibraryImportService.importMediaToLibrary(
          source.path,
          mediaType: CardMediaType.video,
          probeVideo: (_) async => throw StateError('unsupported codec'),
        ),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('isn\'t supported on this device'),
          ),
        ),
      );
    });

    test('validateMediaSelection rejects a type-extension mismatch', () {
      expect(
        LibraryImportService.validateMediaSelection(
          sourcePath: '/tmp/movie.mp4',
          sizeBytes: 1024,
          mediaType: CardMediaType.audio,
        ),
        'This file type isn\'t supported. Try MP3, M4A, WAV, or AAC.',
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
