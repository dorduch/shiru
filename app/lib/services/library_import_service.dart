import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class LibraryImportService {
  LibraryImportService._();

  static const List<String> supportedAudioExtensions = [
    'mp3',
    'wav',
    'm4a',
    'aac',
  ];

  static const int maxAudioBytes = 200 * 1024 * 1024;

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
    if (rawTitle.isEmpty || rawTitle.startsWith('.')) return 'New Story';

    final normalizedTitle = rawTitle
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return normalizedTitle.isEmpty ? 'New Story' : normalizedTitle;
  }

  static String? validateAudioSelection({
    required String sourcePath,
    required int sizeBytes,
  }) {
    final extension = path
        .extension(sourcePath)
        .replaceFirst('.', '')
        .toLowerCase();

    if (!supportedAudioExtensions.contains(extension)) {
      return 'Unsupported audio format. Use MP3, WAV, M4A, or AAC.';
    }

    if (sizeBytes <= 0) {
      return 'File is empty.';
    }

    if (sizeBytes > maxAudioBytes) {
      return 'File is too large. Maximum size is 200 MB.';
    }

    return null;
  }

  static Future<String> importAudioToLibrary(String sourcePath) async {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw Exception('Selected file is no longer available.');
    }

    final sourceSize = await sourceFile.length();
    final validationError = validateAudioSelection(
      sourcePath: sourcePath,
      sizeBytes: sourceSize,
    );
    if (validationError != null) {
      throw Exception(validationError);
    }

    final docsDir = await getApplicationDocumentsDirectory();
    if (isManagedLibraryPath(
      filePath: sourcePath,
      libraryDirPath: docsDir.path,
    )) {
      return sourcePath;
    }

    final uuid = const Uuid().v4();
    final extension = path.extension(sourcePath).toLowerCase();
    final importedFile = File(path.join(docsDir.path, '$uuid$extension'));

    await sourceFile.copy(importedFile.path);

    final importedSize = await importedFile.length();
    if (importedSize == 0) {
      try {
        await importedFile.delete();
      } catch (_) {}
      throw Exception('Audio file import failed. Please try again.');
    }

    final tempDir = await getTemporaryDirectory();
    if (sourcePath.startsWith(tempDir.path)) {
      try {
        await sourceFile.delete();
      } catch (_) {}
    }

    return importedFile.path;
  }
}
