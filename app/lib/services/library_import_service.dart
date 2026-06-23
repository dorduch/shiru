import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';

import '../models/audio_card.dart';

typedef VideoMetadataProbe = Future<Duration> Function(String sourcePath);

/// A media file that has been validated and copied into the app library.
class MediaSelection {
  const MediaSelection({
    required this.path,
    required this.mediaType,
    this.duration,
    this.sourceName,
  });

  final String path;
  final CardMediaType mediaType;
  final Duration? duration;
  final String? sourceName;

  String get mediaPath => path;
}

class LibraryImportService {
  LibraryImportService._();

  static const List<String> supportedAudioExtensions = [
    'mp3',
    'wav',
    'm4a',
    'aac',
  ];

  static const List<String> supportedVideoExtensions = ['mp4', 'mov', 'm4v'];

  static const int maxAudioBytes = 200 * 1024 * 1024;
  static const int maxVideoBytes = 1024 * 1024 * 1024;
  static const Duration maxVideoDuration = Duration(minutes: 15);

  static bool isManagedLibraryPath({
    required String filePath,
    required String libraryDirPath,
  }) {
    final normalizedFilePath = path.normalize(filePath);
    final normalizedLibraryDir = path.normalize(libraryDirPath);
    return path.isWithin(normalizedLibraryDir, normalizedFilePath);
  }

  static Future<bool> isImportedLibraryPath(String filePath) async {
    final docsDir = await getApplicationDocumentsDirectory();
    return isManagedLibraryPath(
      filePath: filePath,
      libraryDirPath: docsDir.path,
    );
  }

  static String deriveTitleFromSourcePath(String sourcePath) {
    final rawTitle = path.basenameWithoutExtension(sourcePath).trim();
    if (rawTitle.isEmpty || rawTitle.startsWith('.')) return 'New Card';

    final normalizedTitle = rawTitle
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return normalizedTitle.isEmpty ? 'New Card' : normalizedTitle;
  }

  /// Infers the media type from a supported filename extension.
  /// Returns `null` when the extension is not supported.
  static CardMediaType? inferMediaType(String sourcePath) {
    final extension = _extension(sourcePath);
    if (supportedAudioExtensions.contains(extension)) {
      return CardMediaType.audio;
    }
    if (supportedVideoExtensions.contains(extension)) {
      return CardMediaType.video;
    }
    return null;
  }

  static String? validateMediaSelection({
    required String sourcePath,
    required int sizeBytes,
    CardMediaType? mediaType,
    Duration? duration,
  }) {
    final resolvedType = mediaType ?? inferMediaType(sourcePath);
    if (resolvedType == null) {
      return 'This file type isn\'t supported. Try MP3, M4A, WAV, AAC, MP4, MOV, or M4V.';
    }

    switch (resolvedType) {
      case CardMediaType.audio:
        return validateAudioSelection(
          sourcePath: sourcePath,
          sizeBytes: sizeBytes,
        );
      case CardMediaType.video:
        return validateVideoSelection(
          sourcePath: sourcePath,
          sizeBytes: sizeBytes,
          duration: duration,
        );
    }
  }

  static String? validateAudioSelection({
    required String sourcePath,
    required int sizeBytes,
  }) {
    if (!supportedAudioExtensions.contains(_extension(sourcePath))) {
      return 'This file type isn\'t supported. Try MP3, M4A, WAV, or AAC.';
    }

    if (sizeBytes <= 0) {
      return 'This file appears to be empty.';
    }

    if (sizeBytes > maxAudioBytes) {
      return 'This file is too large (200 MB max).';
    }

    return null;
  }

  static String? validateVideoSelection({
    required String sourcePath,
    required int sizeBytes,
    Duration? duration,
  }) {
    if (!supportedVideoExtensions.contains(_extension(sourcePath))) {
      return 'This file type isn\'t supported. Try MP4, MOV, or M4V.';
    }

    if (sizeBytes <= 0) {
      return 'This file appears to be empty.';
    }

    if (sizeBytes > maxVideoBytes) {
      return 'This video is too large (1 GB max).';
    }

    if (duration != null && duration <= Duration.zero) {
      return 'This video couldn\'t be read or isn\'t supported on this device.';
    }

    if (duration != null && duration > maxVideoDuration) {
      return 'This video is too long (15 minutes max).';
    }

    return null;
  }

  /// Validates and copies audio or video into the app-managed library.
  ///
  /// Video callers should probe native playback first and pass its [duration]
  /// so the 15-minute limit can be enforced before the source is committed.
  static Future<MediaSelection> importMediaToLibrary(
    String sourcePath, {
    CardMediaType? mediaType,
    Duration? duration,
    VideoMetadataProbe? probeVideo,
  }) async {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw Exception('This file isn\'t available anymore.');
    }

    final sourceSize = await sourceFile.length();
    final resolvedType = mediaType ?? inferMediaType(sourcePath);
    final basicValidationError = validateMediaSelection(
      sourcePath: sourcePath,
      sizeBytes: sourceSize,
      mediaType: resolvedType,
    );
    if (basicValidationError != null) {
      throw Exception(basicValidationError);
    }

    var resolvedDuration = duration;
    if (resolvedType == CardMediaType.video && resolvedDuration == null) {
      try {
        resolvedDuration = await probeVideoDuration(
          sourcePath,
          probe: probeVideo,
        );
      } catch (_) {
        throw Exception(
          'This video couldn\'t be read or isn\'t supported on this device.',
        );
      }
    }

    final validationError = validateMediaSelection(
      sourcePath: sourcePath,
      sizeBytes: sourceSize,
      mediaType: resolvedType,
      duration: resolvedDuration,
    );
    if (validationError != null) {
      throw Exception(validationError);
    }

    final docsDir = await getApplicationDocumentsDirectory();
    if (isManagedLibraryPath(
      filePath: sourcePath,
      libraryDirPath: docsDir.path,
    )) {
      return MediaSelection(
        path: sourcePath,
        mediaType: resolvedType!,
        duration: resolvedDuration,
        sourceName: path.basename(sourcePath),
      );
    }

    final uuid = const Uuid().v4();
    final extension = path.extension(sourcePath).toLowerCase();
    final importedFile = File(path.join(docsDir.path, '$uuid$extension'));

    try {
      await sourceFile.copy(importedFile.path);
      final importedSize = await importedFile.length();
      if (importedSize != sourceSize || importedSize == 0) {
        throw const FileSystemException('The copied file is incomplete.');
      }
    } catch (_) {
      try {
        if (await importedFile.exists()) await importedFile.delete();
      } catch (_) {}
      final kind = resolvedType == CardMediaType.video ? 'video' : 'audio';
      throw Exception(
        'Couldn\'t import this $kind file. Check available storage and try again.',
      );
    }

    final tempDir = await getTemporaryDirectory();
    if (isManagedLibraryPath(
      filePath: sourcePath,
      libraryDirPath: tempDir.path,
    )) {
      try {
        await sourceFile.delete();
      } catch (_) {}
    }

    return MediaSelection(
      path: importedFile.path,
      mediaType: resolvedType!,
      duration: resolvedDuration,
      sourceName: path.basename(sourcePath),
    );
  }

  /// Backwards-compatible audio-only import API.
  static Future<String> importAudioToLibrary(String sourcePath) async {
    final selection = await importMediaToLibrary(
      sourcePath,
      mediaType: CardMediaType.audio,
    );
    return selection.path;
  }

  /// Best-effort cleanup for an imported file that was staged but not saved.
  /// Files outside the app-managed library are never deleted.
  static Future<void> deleteImportedMedia(String filePath) async {
    if (!await isImportedLibraryPath(filePath)) return;
    final file = File(filePath);
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  static String _extension(String sourcePath) =>
      path.extension(sourcePath).replaceFirst('.', '').toLowerCase();

  static Future<Duration> probeVideoDuration(
    String sourcePath, {
    VideoMetadataProbe? probe,
  }) {
    return (probe ?? _probeNativeVideo)(sourcePath);
  }

  static Future<Duration> _probeNativeVideo(String sourcePath) async {
    final controller = VideoPlayerController.file(File(sourcePath));
    try {
      await controller.initialize();
      return controller.value.duration;
    } finally {
      await controller.dispose();
    }
  }
}
