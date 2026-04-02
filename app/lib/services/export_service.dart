import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/audio_card.dart';

class ExportException implements Exception {
  final String message;
  const ExportException(this.message);
}

class ExportService {
  /// Shares the audio file for [card] via the native OS share sheet.
  ///
  /// The file is copied to a temporary location with the card title as the
  /// filename (e.g. "Old MacDonald.mp3") so the recipient sees a readable name.
  /// The temp copy is deleted after the share sheet is dismissed.
  ///
  /// Throws [ExportException] if the audio file does not exist or cannot be copied.
  static Future<void> shareCard(AudioCard card) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final normalizedAudioPath = path.normalize(card.audioPath);
    if (!path.isWithin(path.normalize(docsDir.path), normalizedAudioPath)) {
      throw const ExportException('Audio file path is outside the app library');
    }
    final sourceFile = File(card.audioPath);
    if (!await sourceFile.exists()) {
      throw const ExportException('Could not find audio file');
    }

    final sanitized = sanitizeTitle(card.title);
    final ext = path.extension(card.audioPath); // e.g. ".mp3"
    final filename = '$sanitized$ext';

    final tempDir = await getTemporaryDirectory();
    final tempPath = path.join(tempDir.path, '${card.id}_$filename');

    try {
      await sourceFile.copy(tempPath);
    } catch (e) {
      throw ExportException('Could not prepare file for export: $e');
    }

    try {
      await Share.shareXFiles(
        [XFile(tempPath, mimeType: 'audio/*', name: filename)],
        subject: card.title,
      );
    } finally {
      // Best-effort cleanup — ignore errors if the file was already removed.
      try {
        await File(tempPath).delete();
      } catch (_) {}
    }
  }

  /// Sanitizes [title] so it is safe to use as a filename.
  ///
  /// Removes the characters forbidden on Windows/macOS/iOS/Android file systems
  /// (/ \ : * ? " < > |), trims whitespace, collapses internal runs of spaces,
  /// and falls back to "audio" if the result is empty.
  static String sanitizeTitle(String title) {
    final sanitized = title
        .replaceAll(RegExp(r'[/\\:*?"<>|\x00]'), '')
        .trim()
        .replaceAll(RegExp(r' +'), ' ');
    return sanitized.isEmpty ? 'audio' : sanitized;
  }
}
