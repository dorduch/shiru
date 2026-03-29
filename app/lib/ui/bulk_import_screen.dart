import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../models/audio_card.dart';
import '../models/category.dart';
import '../providers/cards_provider.dart';
import '../providers/categories_provider.dart';
import '../services/library_import_service.dart';

class BulkImportScreen extends ConsumerStatefulWidget {
  const BulkImportScreen({super.key});

  @override
  ConsumerState<BulkImportScreen> createState() => _BulkImportScreenState();
}

class _BulkImportScreenState extends ConsumerState<BulkImportScreen> {
  final List<_BulkImportDraft> _drafts = [];

  String? _selectedCategoryId;
  bool _isPickingFiles = false;
  bool _isImporting = false;
  _BulkImportSummary? _summary;

  @override
  void dispose() {
    for (final draft in _drafts) {
      draft.dispose();
    }
    super.dispose();
  }

  int get _importableCount => _drafts
      .where(
        (draft) =>
            draft.status == _BulkImportStatus.ready ||
            draft.status == _BulkImportStatus.failed,
      )
      .length;

  int get _failedCount => _drafts
      .where(
        (draft) =>
            draft.status == _BulkImportStatus.failed ||
            draft.status == _BulkImportStatus.invalid,
      )
      .length;

  Future<void> _pickFiles() async {
    if (_isPickingFiles || _isImporting) return;

    setState(() {
      _isPickingFiles = true;
      _summary = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowMultiple: true,
        allowedExtensions: LibraryImportService.supportedAudioExtensions,
      );

      if (result == null || result.files.isEmpty) return;

      final drafts = <_BulkImportDraft>[];
      for (final file in result.files) {
        final sourcePath = file.path;
        if (sourcePath == null) {
          drafts.add(
            _BulkImportDraft.invalid(
              fileName: file.name,
              errorMessage: 'File path unavailable on this device.',
            ),
          );
          continue;
        }

        final validationError = LibraryImportService.validateAudioSelection(
          sourcePath: sourcePath,
          sizeBytes: file.size,
        );

        drafts.add(
          _BulkImportDraft(
            sourcePath: sourcePath,
            fileName: file.name,
            titleController: TextEditingController(
              text: LibraryImportService.deriveTitleFromSourcePath(sourcePath),
            ),
            status: validationError == null
                ? _BulkImportStatus.ready
                : _BulkImportStatus.invalid,
            errorMessage: validationError,
          ),
        );
      }

      for (final draft in _drafts) {
        draft.dispose();
      }

      if (!mounted) return;
      setState(() {
        _drafts
          ..clear()
          ..addAll(drafts);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking files: $e')));
    } finally {
      if (mounted) {
        setState(() => _isPickingFiles = false);
      }
    }
  }

  Future<void> _importAll() async {
    if (_isImporting || _importableCount == 0) return;

    final existingCards = ref.read(cardsProvider).value ?? const <AudioCard>[];
    final basePosition = existingCards.isEmpty
        ? 0
        : existingCards
                  .map((card) => card.position)
                  .reduce((current, next) => current > next ? current : next) +
              1;

    setState(() {
      _isImporting = true;
      _summary = null;
    });

    final preparedImports = <_PreparedImport>[];
    var nextPosition = basePosition;

    for (final draft in _drafts) {
      if (draft.status == _BulkImportStatus.invalid ||
          draft.status == _BulkImportStatus.imported) {
        continue;
      }

      setState(() {
        draft.status = _BulkImportStatus.importing;
        draft.errorMessage = null;
      });

      try {
        final importedPath = await LibraryImportService.importAudioToLibrary(
          draft.sourcePath!,
        );
        final rawTitle = draft.titleController.text.trim();
        final title = rawTitle.isEmpty
            ? LibraryImportService.deriveTitleFromSourcePath(draft.sourcePath!)
            : rawTitle;

        preparedImports.add(
          _PreparedImport(
            draft: draft,
            importedPath: importedPath,
            card: AudioCard(
              id: const Uuid().v4(),
              collectionId: _selectedCategoryId,
              title: title,
              color: '#F0FDF4',
              audioPath: importedPath,
              position: nextPosition,
              createdAt: DateTime.now().millisecondsSinceEpoch,
            ),
          ),
        );
        nextPosition += 1;

        if (!mounted) return;
        setState(() => draft.status = _BulkImportStatus.ready);
      } catch (e) {
        if (!mounted) return;
        setState(() {
          draft.status = _BulkImportStatus.failed;
          draft.errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }

    if (preparedImports.isNotEmpty) {
      try {
        await ref
            .read(cardsProvider.notifier)
            .addCards(preparedImports.map((entry) => entry.card).toList());

        if (!mounted) return;
        setState(() {
          for (final entry in preparedImports) {
            entry.draft.status = _BulkImportStatus.imported;
            entry.draft.errorMessage = null;
          }
        });
      } catch (_) {
        for (final entry in preparedImports) {
          try {
            await File(entry.importedPath).delete();
          } catch (_) {}
        }

        if (!mounted) return;
        setState(() {
          for (final entry in preparedImports) {
            entry.draft.status = _BulkImportStatus.failed;
            entry.draft.errorMessage = 'Failed to save imported cards.';
          }
        });
      }
    }

    if (!mounted) return;
    setState(() {
      _isImporting = false;
      _summary = _BulkImportSummary(
        importedCount: _drafts
            .where((draft) => draft.status == _BulkImportStatus.imported)
            .length,
        failedCount: _failedCount,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider).value ?? <Category>[];

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 28),
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Bulk Import',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: _drafts.isEmpty
                    ? _buildEmptyState(context)
                    : _buildReviewState(context, categories),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x120F172A),
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.folder_copy_outlined,
                  size: 36,
                  color: Color(0xFFF97316),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Import multiple stories at once',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Select several audio files, review the generated card titles, optionally apply one shared category, and save the batch in one pass.',
                style: TextStyle(
                  fontSize: 18,
                  height: 1.45,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 20),
              const _ChecklistRow(
                icon: Icons.check_circle_outline,
                text: 'Select multiple files from the device',
              ),
              const SizedBox(height: 12),
              const _ChecklistRow(
                icon: Icons.check_circle_outline,
                text: 'Review and rename each generated title',
              ),
              const SizedBox(height: 12),
              const _ChecklistRow(
                icon: Icons.check_circle_outline,
                text: 'Apply one shared category to the batch',
              ),
              const SizedBox(height: 28),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ElevatedButton.icon(
                    onPressed: _isPickingFiles ? null : _pickFiles,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B6B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 18,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    icon: _isPickingFiles
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(Icons.upload_file_outlined),
                    label: Text(
                      _isPickingFiles
                          ? 'Choosing Files...'
                          : 'Choose Audio Files',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/parent/edit'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF374151),
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 18,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text(
                      'Add One Story Instead',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF374151),
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 18,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text(
                      'Back to Library',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReviewState(BuildContext context, List<Category> categories) {
    final storyLabel = _importableCount == 1 ? 'Story' : 'Stories';
    final importButtonLabel = _isImporting
        ? 'Importing...'
        : 'Import $_importableCount $storyLabel';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_summary != null) ...[
              _ImportSummaryBanner(summary: _summary!),
              const SizedBox(height: 16),
            ],
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x120F172A),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 280,
                    child: _CategoryDropdown(
                      categories: categories,
                      value: _selectedCategoryId,
                      onChanged: _isImporting
                          ? null
                          : (value) {
                              setState(() => _selectedCategoryId = value);
                            },
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _isImporting ? null : _pickFiles,
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Choose Again'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isImporting || _importableCount == 0
                        ? null
                        : _importAll,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B6B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    icon: _isImporting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(Icons.download_done_outlined),
                    label: Text(
                      importButtonLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (_summary != null && _summary!.importedCount > 0)
                    OutlinedButton.icon(
                      onPressed: _isImporting ? null : () => context.pop(),
                      icon: const Icon(Icons.library_music_outlined),
                      label: const Text('Back to Library'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: _drafts.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final draft = _drafts[index];
                  return _BulkImportRow(
                    draft: draft,
                    enabled:
                        !_isImporting &&
                        draft.status != _BulkImportStatus.imported &&
                        draft.status != _BulkImportStatus.invalid,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ChecklistRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF22C55E), size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
        ),
      ],
    );
  }
}

enum _BulkImportStatus { ready, invalid, importing, imported, failed }

class _BulkImportDraft {
  final String? sourcePath;
  final String fileName;
  final TextEditingController titleController;
  _BulkImportStatus status;
  String? errorMessage;

  _BulkImportDraft({
    required this.sourcePath,
    required this.fileName,
    required this.titleController,
    required this.status,
    this.errorMessage,
  });

  factory _BulkImportDraft.invalid({
    required String fileName,
    required String errorMessage,
  }) {
    return _BulkImportDraft(
      sourcePath: null,
      fileName: fileName,
      titleController: TextEditingController(text: 'New Story'),
      status: _BulkImportStatus.invalid,
      errorMessage: errorMessage,
    );
  }

  void dispose() {
    titleController.dispose();
  }
}

class _PreparedImport {
  final _BulkImportDraft draft;
  final AudioCard card;
  final String importedPath;

  _PreparedImport({
    required this.draft,
    required this.card,
    required this.importedPath,
  });
}

class _BulkImportSummary {
  final int importedCount;
  final int failedCount;

  const _BulkImportSummary({
    required this.importedCount,
    required this.failedCount,
  });
}

class _CategoryDropdown extends StatelessWidget {
  final List<Category> categories;
  final String? value;
  final ValueChanged<String?>? onChanged;

  const _CategoryDropdown({
    required this.categories,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 2),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          isExpanded: true,
          value: value,
          hint: const Text('Shared category'),
          onChanged: onChanged,
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('No category'),
            ),
            ...categories.map(
              (category) => DropdownMenuItem<String?>(
                value: category.id,
                child: Text('${category.emoji} ${category.name}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImportSummaryBanner extends StatelessWidget {
  final _BulkImportSummary summary;

  const _ImportSummaryBanner({required this.summary});

  @override
  Widget build(BuildContext context) {
    final hasFailures = summary.failedCount > 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: hasFailures ? const Color(0xFFFFF7ED) : const Color(0xFFECFDF3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasFailures
              ? const Color(0xFFFDBA74)
              : const Color(0xFF86EFAC),
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasFailures ? Icons.info_outline : Icons.check_circle_outline,
            color: hasFailures
                ? const Color(0xFFEA580C)
                : const Color(0xFF16A34A),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              hasFailures
                  ? 'Imported ${summary.importedCount} stories. ${summary.failedCount} still need attention.'
                  : 'Imported ${summary.importedCount} stories successfully.',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: hasFailures
                    ? const Color(0xFF9A3412)
                    : const Color(0xFF166534),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BulkImportRow extends StatelessWidget {
  final _BulkImportDraft draft;
  final bool enabled;

  const _BulkImportRow({required this.draft, required this.enabled});

  @override
  Widget build(BuildContext context) {
    final status = switch (draft.status) {
      _BulkImportStatus.ready => (
        label: 'Ready',
        background: const Color(0xFFF3F4F6),
        foreground: const Color(0xFF4B5563),
      ),
      _BulkImportStatus.invalid => (
        label: 'Invalid',
        background: const Color(0xFFFEF2F2),
        foreground: const Color(0xFFB91C1C),
      ),
      _BulkImportStatus.importing => (
        label: 'Importing',
        background: const Color(0xFFE0F2FE),
        foreground: const Color(0xFF0369A1),
      ),
      _BulkImportStatus.imported => (
        label: 'Imported',
        background: const Color(0xFFECFDF3),
        foreground: const Color(0xFF15803D),
      ),
      _BulkImportStatus.failed => (
        label: 'Failed',
        background: const Color(0xFFFFF7ED),
        foreground: const Color(0xFFEA580C),
      ),
    };

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  draft.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: status.background,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: status.foreground,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: draft.titleController,
            enabled: enabled,
            decoration: InputDecoration(
              labelText: 'Card title',
              filled: true,
              fillColor: enabled ? Colors.white : const Color(0xFFF9FAFB),
              contentPadding: const EdgeInsets.all(16),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Color(0xFFE5E7EB),
                  width: 2,
                ),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Color(0xFFE5E7EB),
                  width: 2,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Color(0xFF3B82F6),
                  width: 2,
                ),
              ),
            ),
          ),
          if (draft.errorMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              draft.errorMessage!,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFFB45309),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
