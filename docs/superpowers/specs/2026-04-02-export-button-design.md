# Export Button — Design Spec
**Date:** 2026-04-02
**Status:** Approved

## Context

Parents manage a library of audio cards in `ParentListScreen`. Each card tile has three action buttons: play preview, edit, and delete. There is currently no way to retrieve the underlying audio file — it's locked inside the app's sandboxed documents directory with a UUID filename.

Adding an export button lets parents share audio files (e.g., to send a recording to a grandparent via WhatsApp, back it up to Files, or archive it via email). The file is shared via the native OS share sheet with the card title as the filename, so it's immediately recognizable to the recipient.

## Scope

- One new Flutter service file
- One modified screen widget (`parent_list_screen.dart`)
- One new pub dependency (`share_plus`)
- No DB, router, or provider changes

---

## Components

### 1. `pubspec.yaml`
Add: `share_plus: ^10.1.2`

### 2. `lib/services/export_service.dart` (new file)

A stateless class with a single static method:

```dart
static Future<void> shareCard(AudioCard card) async {
  // 1. Validate source file exists
  final sourceFile = File(card.audioPath);
  if (!sourceFile.existsSync()) throw ExportException('Audio file not found');

  // 2. Sanitize title for use as filename
  final sanitized = card.title
    .replaceAll(RegExp(r'[/\\:*?"<>|]'), '')
    .trim()
    .replaceAll(RegExp(r'\s+'), ' ');
  final ext = path.extension(card.audioPath); // e.g. ".mp3"
  final filename = '$sanitized$ext';

  // 3. Copy to temp dir with human-readable name
  final tempDir = await getTemporaryDirectory();
  final tempPath = '${tempDir.path}/$filename';
  await sourceFile.copy(tempPath);

  // 4. Open native share sheet
  await Share.shareXFiles(
    [XFile(tempPath, mimeType: 'audio/*', name: filename)],
    subject: card.title,
  );

  // 5. Clean up temp file (best-effort)
  try { await File(tempPath).delete(); } catch (_) {}
}
```

Uses `path` (already in pubspec at `^1.9.1`), `path_provider` (already in pubspec), and `share_plus` (new).

### 3. `lib/ui/parent_list_screen.dart`

**`_LibraryCardTile`** — currently extends `ConsumerWidget`. Convert to `ConsumerStatefulWidget` + `ConsumerState<_LibraryCardTile>` to hold local UI state. Add:

```dart
bool _isExporting = false;
```

Add a 4th action button between play and edit:

```dart
_ActionButton(
  icon: _isExporting
    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
    : const Icon(Icons.share),
  color: Colors.blue.shade600,
  onTap: _isExporting ? null : () async {
    setState(() => _isExporting = true);
    try {
      await ExportService.shareCard(card);
    } on ExportException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export failed')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  },
)
```

**Button order in tile:**
```
[ artwork ] [ title / metadata ]  [ ▶ play ][ ↑ share ][ ✏ edit ][ 🗑 delete ]
```

---

## Error Handling

| Scenario | Behavior |
|----------|----------|
| Audio file missing from disk | SnackBar: "Could not find audio file" |
| File copy fails (disk full, etc.) | SnackBar: "Export failed" |
| User cancels share sheet | No error — normal flow, temp file cleaned up |
| `share_plus` throws unexpectedly | SnackBar: "Export failed" |

---

## Verification

1. `flutter pub get` — resolves `share_plus` with no conflicts
2. `flutter analyze` — no new warnings or errors
3. Run on iOS simulator: tap export button, verify spinner appears briefly, share sheet opens with filename `<card title>.mp3`
4. Run on Android emulator: same check
5. Cancel share sheet — verify button returns to normal (no stuck spinner)
6. Delete the audio file manually from disk, tap export — verify error SnackBar appears
