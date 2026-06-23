import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../models/audio_card.dart';
import '../models/category.dart';
import '../providers/auth_provider.dart';
import '../providers/cards_provider.dart';
import '../providers/categories_provider.dart';
import '../services/library_import_service.dart';
import '../services/analytics_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_responsive.dart';
import '../theme/app_typography.dart';

typedef BulkFilePicker = Future<FilePickerResult?> Function();
typedef BulkMediaImporter =
    Future<MediaSelection> Function(
      String path,
      CardMediaType mediaType,
      Duration? duration,
    );

class BulkImportScreen extends ConsumerStatefulWidget {
  const BulkImportScreen({super.key, this.pickFiles, this.importMedia});

  final BulkFilePicker? pickFiles;
  final BulkMediaImporter? importMedia;

  @override
  ConsumerState<BulkImportScreen> createState() => _BulkImportScreenState();
}

class _BulkImportScreenState extends ConsumerState<BulkImportScreen> {
  final List<_BulkImportDraft> _drafts = [];
  final Set<String> _pendingPersistencePaths = {};

  String? _selectedCategoryId;
  bool _isPickingFiles = false;
  bool _isImporting = false;
  _BulkImportSummary? _summary;

  Future<MediaSelection> _importMedia(
    String path,
    CardMediaType mediaType, [
    Duration? duration,
  ]) {
    if (widget.importMedia != null) {
      return widget.importMedia!(path, mediaType, duration);
    }
    return LibraryImportService.importMediaToLibrary(
      path,
      mediaType: mediaType,
      duration: duration,
    );
  }

  @override
  void dispose() {
    for (final draft in _drafts) {
      if (draft.isStagedCopy &&
          draft.status != _BulkImportStatus.imported &&
          !_pendingPersistencePaths.contains(draft.sourcePath)) {
        unawaited(LibraryImportService.deleteImportedMedia(draft.sourcePath!));
      }
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
      final result = await preserveParentAuthDuringExternalFileFlow(
        ref,
        widget.pickFiles ??
            () => FilePicker.platform.pickFiles(
              type: FileType.custom,
              allowMultiple: true,
              allowedExtensions: [
                ...LibraryImportService.supportedAudioExtensions,
                ...LibraryImportService.supportedVideoExtensions,
              ],
            ),
      );

      if (result == null || result.files.isEmpty) return;

      final drafts = <_BulkImportDraft>[];
      for (final file in result.files) {
        final sourcePath = file.path;
        if (sourcePath == null) {
          drafts.add(
            _BulkImportDraft.invalid(
              fileName: file.name,
              errorMessage: 'Can\'t access this file on your device.',
            ),
          );
          continue;
        }

        final mediaType = LibraryImportService.inferMediaType(sourcePath);
        final validationError = LibraryImportService.validateMediaSelection(
          sourcePath: sourcePath,
          sizeBytes: file.size,
          mediaType: mediaType,
        );
        if (validationError != null || mediaType == null) {
          drafts.add(
            _BulkImportDraft(
              sourcePath: sourcePath,
              fileName: file.name,
              mediaType: mediaType,
              titleController: TextEditingController(
                text: LibraryImportService.deriveTitleFromSourcePath(
                  sourcePath,
                ),
              ),
              status: _BulkImportStatus.invalid,
              errorMessage: validationError,
            ),
          );
          continue;
        }

        try {
          final selection = await _importMedia(sourcePath, mediaType);
          drafts.add(
            _BulkImportDraft(
              sourcePath: selection.path,
              fileName: file.name,
              mediaType: selection.mediaType,
              duration: selection.duration,
              isStagedCopy: selection.path != sourcePath,
              titleController: TextEditingController(
                text: LibraryImportService.deriveTitleFromSourcePath(
                  sourcePath,
                ),
              ),
              status: _BulkImportStatus.ready,
            ),
          );
        } catch (e) {
          drafts.add(
            _BulkImportDraft(
              sourcePath: sourcePath,
              fileName: file.name,
              mediaType: mediaType,
              titleController: TextEditingController(
                text: LibraryImportService.deriveTitleFromSourcePath(
                  sourcePath,
                ),
              ),
              status: _BulkImportStatus.invalid,
              errorMessage: e.toString().replaceFirst('Exception: ', ''),
            ),
          );
        }
      }

      for (final draft in _drafts) {
        if (draft.isStagedCopy && draft.status != _BulkImportStatus.imported) {
          unawaited(
            LibraryImportService.deleteImportedMedia(draft.sourcePath!),
          );
        }
        draft.dispose();
      }

      if (!mounted) {
        for (final draft in drafts) {
          if (draft.isStagedCopy) {
            await LibraryImportService.deleteImportedMedia(draft.sourcePath!);
          }
          draft.dispose();
        }
        return;
      }
      setState(() {
        _drafts
          ..clear()
          ..addAll(drafts);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Couldn\'t open those files. Please try again.'),
        ),
      );
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
    _pendingPersistencePaths.addAll(
      _drafts
          .where(
            (draft) =>
                draft.isStagedCopy &&
                (draft.status == _BulkImportStatus.ready ||
                    draft.status == _BulkImportStatus.failed),
          )
          .map((draft) => draft.sourcePath!),
    );

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
        final selection = await _importMedia(
          draft.sourcePath!,
          draft.mediaType!,
          draft.duration,
        );
        final rawTitle = draft.titleController.text.trim();
        final title = rawTitle.isEmpty
            ? LibraryImportService.deriveTitleFromSourcePath(draft.fileName)
            : rawTitle;

        preparedImports.add(
          _PreparedImport(
            draft: draft,
            importedPath: selection.path,
            card: AudioCard(
              id: const Uuid().v4(),
              collectionId: _selectedCategoryId,
              title: title,
              color: '#F0FDF4',
              audioPath: selection.path,
              mediaType: selection.mediaType,
              position: nextPosition,
              createdAt: DateTime.now().millisecondsSinceEpoch,
            ),
          ),
        );
        nextPosition += 1;

        if (!mounted) return;
        setState(() => draft.status = _BulkImportStatus.ready);
      } catch (e) {
        _pendingPersistencePaths.remove(draft.sourcePath);
        if (!mounted) {
          if (draft.isStagedCopy) {
            await LibraryImportService.deleteImportedMedia(draft.sourcePath!);
          }
          return;
        }
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

        for (final entry in preparedImports) {
          entry.draft.status = _BulkImportStatus.imported;
          entry.draft.errorMessage = null;
          _pendingPersistencePaths.remove(entry.importedPath);
        }
        if (mounted) setState(() {});
        AnalyticsService.instance.logBulkImport(count: preparedImports.length);
      } catch (_) {
        for (final entry in preparedImports) {
          if (entry.draft.isStagedCopy) {
            await LibraryImportService.deleteImportedMedia(entry.importedPath);
          }
          _pendingPersistencePaths.remove(entry.importedPath);
          entry.draft.status = entry.draft.isStagedCopy
              ? _BulkImportStatus.invalid
              : _BulkImportStatus.failed;
          entry.draft.errorMessage = 'Failed to save imported cards.';
        }

        if (!mounted) return;
        setState(() {});
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
    final basePadding = AppResponsive.basePadding(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundParent,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: basePadding,
            vertical: AppResponsive.spacing(context, 16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _ImportHeader(),
              SizedBox(height: AppResponsive.spacing(context, 20)),
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
    return _BulkImportEmptyState(
      isPickingFiles: _isPickingFiles,
      onPickFiles: _pickFiles,
      onAddOne: () => context.go('/parent/edit'),
    );
  }

  Widget _buildReviewState(BuildContext context, List<Category> categories) {
    final cardLabel = _importableCount == 1 ? 'card' : 'cards';
    final importButtonLabel = _isImporting
        ? 'Importing...'
        : 'Import $_importableCount $cardLabel';

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
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
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
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textMuted,
                      minimumSize: const Size(0, 52),
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Choose Again'),
                  ),
                  FilledButton.icon(
                    onPressed: _isImporting || _importableCount == 0
                        ? null
                        : _importAll,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryStrong,
                      foregroundColor: AppColors.surface,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: _isImporting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.surface,
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
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textMuted,
                        minimumSize: const Size(0, 52),
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
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

class _ImportHeader extends StatelessWidget {
  const _ImportHeader();

  @override
  Widget build(BuildContext context) {
    final buttonSize = AppResponsive.buttonSize(
      context,
    ).clamp(48.0, 64.0).toDouble();

    return Row(
      children: [
        IconButton(
          tooltip: 'Back to library',
          constraints: BoxConstraints.tightFor(
            width: buttonSize,
            height: buttonSize,
          ),
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: AppResponsive.iconSize(context, 24),
            color: AppColors.textMuted,
          ),
          onPressed: () => context.pop(),
        ),
        SizedBox(width: AppResponsive.spacing(context, 8)),
        Expanded(
          child: Text(
            'Import media',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.displayLarge.copyWith(
              fontSize: AppResponsive.fontSize(context, 32),
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _BulkImportEmptyState extends StatelessWidget {
  final bool isPickingFiles;
  final VoidCallback onPickFiles;
  final VoidCallback onAddOne;

  const _BulkImportEmptyState({
    required this.isPickingFiles,
    required this.onPickFiles,
    required this.onAddOne,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isWide =
        media.size.width >= 720 && media.orientation == Orientation.landscape;

    final intro = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.logoSurface,
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Icon(
            Icons.folder_copy_outlined,
            size: 34,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Add several cards at once',
          style: AppTypography.displayLarge.copyWith(
            fontSize: AppResponsive.fontSize(context, isWide ? 34 : 30),
            height: 1.12,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Choose audio and video files, review their titles, then import everything together.',
          style: AppTypography.bodySmall.copyWith(
            fontSize: AppResponsive.fontSize(
              context,
              17,
            ).clamp(14.0, 21.0).toDouble(),
            height: 1.45,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );

    final nextSteps = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
          ),
          child: const Column(
            children: [
              _ChecklistRow(
                icon: Icons.check_circle_outline,
                text: 'Choose audio and video files',
              ),
              SizedBox(height: 14),
              _ChecklistRow(
                icon: Icons.check_circle_outline,
                text: 'Review each card title',
              ),
              SizedBox(height: 14),
              _ChecklistRow(
                icon: Icons.check_circle_outline,
                text: 'Optionally add one shared category',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: isPickingFiles ? null : onPickFiles,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryStrong,
            foregroundColor: AppColors.surface,
            disabledBackgroundColor: AppColors.textDisabled,
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          icon: isPickingFiles
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.surface,
                  ),
                )
              : const Icon(Icons.folder_open_outlined),
          label: Text(isPickingFiles ? 'Choosing files...' : 'Choose files'),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: onAddOne,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textMuted,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add one card instead'),
        ),
      ],
    );

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        top: isWide ? 24 : (media.size.height * 0.05).clamp(16.0, 52.0),
        bottom: 24,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: intro),
                    const SizedBox(width: 56),
                    Expanded(child: nextSteps),
                  ],
                )
              : ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [intro, const SizedBox(height: 28), nextSteps],
                  ),
                ),
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
        Icon(icon, color: AppColors.primaryStrong, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
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
  final CardMediaType? mediaType;
  final Duration? duration;
  final bool isStagedCopy;
  final TextEditingController titleController;
  _BulkImportStatus status;
  String? errorMessage;

  _BulkImportDraft({
    required this.sourcePath,
    required this.fileName,
    required this.mediaType,
    this.duration,
    this.isStagedCopy = false,
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
      mediaType: null,
      titleController: TextEditingController(text: 'New Card'),
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
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
                child: Text(category.name),
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
                  ? 'Imported ${summary.importedCount} cards. ${summary.failedCount} still need attention.'
                  : 'Imported ${summary.importedCount} cards successfully.',
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                draft.mediaType == CardMediaType.video
                    ? Icons.video_file_outlined
                    : Icons.audio_file_outlined,
                color: AppColors.textSecondary,
                semanticLabel: draft.mediaType == CardMediaType.video
                    ? 'Video file'
                    : 'Audio file',
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  draft.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
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
              fillColor: enabled
                  ? AppColors.surface
                  : AppColors.backgroundMuted,
              contentPadding: const EdgeInsets.all(16),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: AppColors.primaryStrong,
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
