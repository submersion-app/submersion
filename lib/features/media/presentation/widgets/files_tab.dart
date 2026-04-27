import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/media/domain/value_objects/extracted_file.dart';
import 'package:submersion/features/media/domain/value_objects/matched_selection.dart';
import 'package:submersion/features/media/presentation/providers/files_tab_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';

/// Files tab in the photo picker.
///
/// Phase 2 / Task 9: minimal skeleton with a "Pick files…" action that
/// runs EXIF extraction and stashes results in [filesTabNotifierProvider].
/// Auto-match wiring (Task 10), review pane (Task 11), and commit flow
/// (Task 13) layer on top.
class FilesTab extends ConsumerWidget {
  const FilesTab({super.key});

  Future<void> _pickFiles(WidgetRef ref) async {
    final result = await FilePicker.pickFiles(
      type: FileType.media,
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

    // Auto-match wiring lands in Task 10 — for now stash with empty match.
    notifier.setFiles(extracted, match: MatchedSelection.empty());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(filesTabNotifierProvider);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // TODO(media): l10n
          FilledButton.icon(
            icon: const Icon(Icons.upload_file),
            label: const Text('Pick files…'),
            onPressed: () => _pickFiles(ref),
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
                : Center(
                    child: Text(
                      '${state.files.length} files staged.'
                      ' Review pane lands in Task 11.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
