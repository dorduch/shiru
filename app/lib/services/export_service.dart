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
  /// Shares the media file for [card] via the native OS share sheet.
  ///
  /// The file is copied to a temporary location with the card title as the
  /// filename (e.g. "Old MacDonald.mp3") so the recipient sees a readable name.
  /// The temp copy is deleted after the share sheet is dismissed.
  ///
  /// Throws [ExportException] if the media file does not exist or cannot be copied.
  static Future<void> shareCard(AudioCard card) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final normalizedMediaPath = path.normalize(card.mediaPath);
    if (!path.isWithin(path.normalize(docsDir.path), normalizedMediaPath)) {
      throw const ExportException('Media file path is outside the app library');
    }
    final sourceFile = File(card.mediaPath);
    if (!await sourceFile.exists()) {
      throw const ExportException('Could not find media file');
    }

    final sanitized = sanitizeTitle(
      card.title,
      fallback: card.mediaType == CardMediaType.video ? 'video' : 'audio',
    );
    final ext = path.extension(card.mediaPath); // e.g. ".mp3" or ".mp4"
    final filename = '$sanitized$ext';

    final tempDir = await getTemporaryDirectory();
    final tempPath = path.join(tempDir.path, '${card.id}_$filename');

    try {
      await sourceFile.copy(tempPath);
    } catch (e) {
      throw ExportException('Could not prepare file for export: $e');
    }

    try {
      await Share.shareXFiles([
        XFile(tempPath, mimeType: mimeTypeForCard(card), name: filename),
      ], subject: card.title);
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
  static String sanitizeTitle(String title, {String fallback = 'audio'}) {
    final sanitized = title
        .replaceAll(RegExp(r'[/\\:*?"<>|\x00]'), '')
        .trim()
        .replaceAll(RegExp(r' +'), ' ');
    return sanitized.isEmpty ? fallback : sanitized;
  }

  static String mimeTypeForCard(AudioCard card) {
    final extension = path.extension(card.mediaPath).toLowerCase();
    const exactTypes = <String, String>{
      '.mp3': 'audio/mpeg',
      '.wav': 'audio/wav',
      '.m4a': 'audio/mp4',
      '.aac': 'audio/aac',
      '.mp4': 'video/mp4',
      '.mov': 'video/quicktime',
      '.m4v': 'video/x-m4v',
    };
    return exactTypes[extension] ??
        (card.mediaType == CardMediaType.video ? 'video/*' : 'audio/*');
  }
}
