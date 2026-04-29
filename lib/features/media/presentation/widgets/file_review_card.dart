import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/features/media/domain/value_objects/extracted_file.dart';
import 'package:submersion/features/media/presentation/providers/files_tab_providers.dart';

/// A single row in the [FileReviewPane], representing one [ExtractedFile]
/// staged for commit.
///
/// Phase 2 / Task 11: shows a thumbnail (via [Image.file]), the file's
/// basename, the EXIF taken-at timestamp, and a Remove action that calls
/// [FilesTabNotifier.removeFile]. Reassign UI is deferred to Phase 3 polish
/// — for now the user can remove and re-add to change a file's grouping.
class FileReviewCard extends ConsumerWidget {
  final ExtractedFile file;
  final String? targetDiveId;

  const FileReviewCard({
    super.key,
    required this.file,
    required this.targetDiveId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO(media): l10n
    return ListTile(
      leading: Image.file(
        file.file,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        // coverage:ignore-start
        // FileImage failure is dispatched on the async decoder isolate and
        // doesn't fire deterministically under `flutter test` without a real
        // image-decoding pipeline. Exercised by manual desktop smoke tests.
        errorBuilder: (_, _, _) =>
            const Icon(Icons.broken_image_outlined, size: 32),
        // coverage:ignore-end
      ),
      title: Text(
        p.basename(file.sourcePath),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        file.metadata.takenAt?.toIso8601String() ?? 'No EXIF date',
      ),
      trailing: IconButton(
        icon: const Icon(Icons.close),
        tooltip: 'Remove from selection',
        onPressed: () => ref
            .read(filesTabNotifierProvider.notifier)
            .removeFile(file.sourcePath),
      ),
    );
  }
}
