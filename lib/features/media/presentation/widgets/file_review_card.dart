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
/// [FilesTabNotifier.removeFile].
///
/// When [assignableDiveId] is supplied (the picker was opened from a dive)
/// and this card is not already in that dive's group, an assign action calls
/// [FilesTabNotifier.assignToDive]. Only files in a dive group reach
/// [FilesTabNotifier.commit], so for an unmatched file this is the sole route
/// into the database.
class FileReviewCard extends ConsumerWidget {
  final ExtractedFile file;
  final String? targetDiveId;

  /// The dive this card can be manually routed to, or null when the picker
  /// was opened outside a dive context.
  final String? assignableDiveId;

  const FileReviewCard({
    super.key,
    required this.file,
    required this.targetDiveId,
    this.assignableDiveId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignTo = assignableDiveId;
    final canAssign = assignTo != null && assignTo != targetDiveId;
    // TODO(media): l10n
    return ListTile(
      leading: _buildLeading(),
      title: Text(
        p.basename(file.sourcePath),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        file.metadata.takenAt?.toIso8601String() ?? 'No EXIF date',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canAssign)
            IconButton(
              icon: const Icon(Icons.add_link),
              tooltip: 'Add to this dive',
              onPressed: () => ref
                  .read(filesTabNotifierProvider.notifier)
                  .assignToDive(file.sourcePath, assignTo),
            ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Remove from selection',
            onPressed: () => ref
                .read(filesTabNotifierProvider.notifier)
                .removeFile(file.sourcePath),
          ),
        ],
      ),
    );
  }

  /// A 48x48 leading preview. Videos can't be decoded by [Image.file], so they
  /// get an explicit video icon rather than the broken-image error fallback.
  Widget _buildLeading() {
    if (file.metadata.mimeType.startsWith('video/')) {
      return const SizedBox(
        width: 48,
        height: 48,
        child: Center(child: Icon(Icons.movie_outlined, size: 32)),
      );
    }
    return Image.file(
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
    );
  }
}
