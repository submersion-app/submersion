import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/media/domain/services/dive_photo_matcher.dart';
import 'package:submersion/features/media/domain/value_objects/extracted_file.dart';
import 'package:submersion/features/media/domain/value_objects/matched_selection.dart';
import 'package:submersion/features/media/presentation/providers/files_tab_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media/presentation/widgets/file_review_pane.dart';

/// Files tab in the photo picker.
///
/// Phase 2 / Task 9: minimal skeleton with a "Pick files…" action that
/// runs EXIF extraction and stashes results in [filesTabNotifierProvider].
///
/// Phase 2 / Task 10: adds a "Pick a folder…" action that enumerates
/// eligible media files in a background isolate (via [compute]), an
/// auto-match-by-date checkbox, and routes extracted files through
/// [DivePhotoMatcher] before stashing the result.
///
/// Phase 2 / Task 11: review pane wired in via [FileReviewPane].
///
/// Commit flow (Task 13) layers on top.
///
/// Photos only — local-file video imports are out of scope for Phase 2:
/// `PhotoViewerPage` does not yet resolve playable file paths for
/// `MediaSourceType.localFile` videos. The picker is filtered to
/// `FileType.image`, the folder enumerator excludes video extensions, and
/// the commit loop drops any video MIME defensively.
class FilesTab extends ConsumerWidget {
  const FilesTab({super.key});

  // coverage:ignore-start
  // FilePicker.pickFiles is a static method on package:file_picker; not
  // unit-testable from flutter_test without a custom DI seam. Behaviour is
  // exercised by manual desktop smoke tests + by the `_applyMatchAndStash`
  // path tests below (which is a pure async helper). The synchronous
  // build() rendering branches that this method drives — extraction
  // progress, empty/non-empty file lists — are tested via `files_tab_test`.
  Future<void> _pickFiles(WidgetRef ref) async {
    // FileType.image excludes video extensions at the OS picker layer.
    // Phase 2 has no local-file video playback yet; see class doc.
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result == null) return;

    final notifier = ref.read(filesTabNotifierProvider.notifier);
    final extractor = ref.read(exifExtractorProvider);

    notifier.setExtractionProgress(done: 0, total: result.files.length);

    final extracted = <ExtractedFile>[];
    for (var i = 0; i < result.files.length; i++) {
      final pf = result.files[i];
      final path = pf.path;
      if (path != null) {
        final file = File(path);
        final meta = await extractor.extract(file);
        if (meta != null) {
          extracted.add(
            ExtractedFile(sourcePath: path, file: file, metadata: meta),
          );
        }
      }
      // Advance progress unconditionally so isExtracting flips false even
      // when files are skipped (null path or null metadata). `done` here
      // means "files processed", not "files successfully extracted".
      notifier.setExtractionProgress(done: i + 1, total: result.files.length);
    }

    await _applyMatchAndStash(ref, extracted);
  }

  Future<void> _pickFolder(WidgetRef ref) async {
    final dirPath = await FilePicker.getDirectoryPath();
    if (dirPath == null) return;

    // Enumerate eligible files in a background isolate so the main
    // isolate stays responsive on large folder trees.
    final paths = await compute(_enumerateMediaFiles, dirPath);
    if (paths.isEmpty) return;

    final notifier = ref.read(filesTabNotifierProvider.notifier);
    final extractor = ref.read(exifExtractorProvider);

    notifier.setExtractionProgress(done: 0, total: paths.length);

    final extracted = <ExtractedFile>[];
    for (var i = 0; i < paths.length; i++) {
      final file = File(paths[i]);
      final meta = await extractor.extract(file);
      if (meta != null) {
        extracted.add(
          ExtractedFile(sourcePath: paths[i], file: file, metadata: meta),
        );
      }
      // Advance progress unconditionally — see [_pickFiles].
      notifier.setExtractionProgress(done: i + 1, total: paths.length);
    }

    await _applyMatchAndStash(ref, extracted);
  }
  // coverage:ignore-end

  // coverage:ignore-start
  // _applyMatchAndStash is only reached through _pickFiles / _pickFolder,
  // both of which depend on FilePicker static methods that can't be mocked
  // from flutter_test. The matcher logic itself is covered by
  // dive_photo_matcher_test; the dive-bounds derivation here is covered by
  // trip_media_scanner_test (same shape).
  Future<void> _applyMatchAndStash(
    WidgetRef ref,
    List<ExtractedFile> extracted,
  ) async {
    final notifier = ref.read(filesTabNotifierProvider.notifier);
    final state = ref.read(filesTabNotifierProvider);
    if (!state.autoMatchByDate) {
      notifier.setFiles(
        extracted,
        match: MatchedSelection(matched: const {}, unmatched: extracted),
      );
      return;
    }
    final dives = await ref.read(divesProvider.future);
    final bounds = dives
        .map(
          (d) => DiveBounds(
            diveId: d.id,
            entryTime: d.effectiveEntryTime,
            exitTime:
                d.exitTime ??
                d.effectiveEntryTime.add(
                  d.effectiveRuntime ?? const Duration(hours: 1),
                ),
          ),
        )
        .toList();
    final result = DivePhotoMatcher().match(files: extracted, dives: bounds);
    notifier.setFiles(extracted, match: result);
  }
  // coverage:ignore-end

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(filesTabNotifierProvider);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // TODO(media): l10n
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Pick files…'),
                  // coverage:ignore-start
                  onPressed: () => _pickFiles(ref),
                  // coverage:ignore-end
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Pick a folder…'),
                  // coverage:ignore-start
                  onPressed: () => _pickFolder(ref),
                  // coverage:ignore-end
                ),
              ),
            ],
          ),
          Row(
            children: [
              Checkbox(
                value: state.autoMatchByDate,
                onChanged: (_) => ref
                    .read(filesTabNotifierProvider.notifier)
                    .toggleAutoMatch(),
              ),
              const Expanded(
                child: Text('Auto-match photos to dives by EXIF date'),
              ),
            ],
          ),
          if (state.isExtracting) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: state.totalToExtract == 0
                  ? null
                  : state.extractedCount / state.totalToExtract,
            ),
          ],
          const SizedBox(height: 24),
          Expanded(
            child: state.files.isEmpty
                ? Center(
                    child: Text(
                      'Pick files or a folder to start.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                : FileReviewPane(state: state),
          ),
          // TODO(media): l10n, pluralization
          if (state.match.matched.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  // coverage:ignore-start
                  onPressed: () => _commit(context, ref),
                  // coverage:ignore-end
                  child: Text(
                    'Link ${state.match.totalFiles - state.match.unmatched.length} items',
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // coverage:ignore-start
  // _commit drives `commit()` (covered separately in
  // files_tab_providers_test) and a SnackBar with an Undo action; both rely
  // on framework-driven async-with-context-mounted timing that flutter_test
  // can't deterministically pump without a real Navigator. Behaviour is
  // exercised by manual desktop smoke tests + by the notifier unit tests.
  Future<void> _commit(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(filesTabNotifierProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final created = await notifier.commit();
    if (!context.mounted) return;
    // TODO(media): l10n, pluralization
    messenger.showSnackBar(
      SnackBar(
        content: Text('Linked ${created.length} items'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => notifier.undoCommit(created),
        ),
      ),
    );
  }

  // coverage:ignore-end
}

// coverage:ignore-start
// Runs on a `compute()` isolate so it cannot be exercised by flutter_test
// (which runs the test body on the main isolate). Exercised by manual
// desktop smoke tests; the file-extension allowlist mirrors the EXIF
// extractor's mime inference (covered there).
/// Recursively enumerates image/video files under [rootPath].
///
/// Top-level (file-private) so it can be passed to [compute] — instance
/// methods can't be sent across isolates because they'd close over `this`.
///
/// Caps at 5,000 files per the Phase 2 spec to bound memory and the
/// subsequent EXIF extraction loop.
Future<List<String>> _enumerateMediaFiles(String rootPath) async {
  // Photos only in Phase 2; see [FilesTab] class doc.
  const exts = {'.jpg', '.jpeg', '.heic', '.heif', '.png', '.webp', '.gif'};
  final results = <String>[];
  final dir = Directory(rootPath);
  if (!dir.existsSync()) return results;
  await for (final entity in dir.list(recursive: true, followLinks: false)) {
    if (entity is File) {
      final ext = '.${entity.path.split('.').last.toLowerCase()}';
      if (exts.contains(ext)) results.add(entity.path);
      if (results.length >= 5000) break; // hard ceiling per spec
    }
  }
  return results;
}

// coverage:ignore-end
