import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/features/media/domain/value_objects/extracted_file.dart';
import 'package:submersion/features/media/domain/value_objects/taken_at_source.dart';
import 'package:submersion/features/media/domain/value_objects/unmatched_diagnostic.dart';
import 'package:submersion/features/media/presentation/providers/files_tab_providers.dart';
import 'package:submersion/features/media/presentation/utils/capture_time_offset_format.dart';
import 'package:submersion/features/media/presentation/widgets/dive_picker_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A single row in the [FileReviewPane], representing one [ExtractedFile]
/// staged for commit.
///
/// Shows a thumbnail (via [Image.file]), the file's basename, the capture time
/// with the source it was read from, and a Remove action that calls
/// [FilesTabNotifier.removeFile]. For a file the matcher rejected, a second
/// subtitle line says why.
///
/// Only files sitting in a dive group reach [FilesTabNotifier.commit], so an
/// unmatched file needs a manual route into the database. When
/// [assignableDiveId] is supplied (the picker was opened from a dive) the
/// assign action routes straight there. Otherwise it opens
/// [showDivePickerSheet] so a file whose timestamp is unrecoverable is still
/// linkable rather than a dead end (issue #312).
class FileReviewCard extends ConsumerWidget {
  final ExtractedFile file;
  final String? targetDiveId;

  /// The dive this card can be manually routed to, or null when the picker
  /// was opened outside a dive context.
  final String? assignableDiveId;

  /// Why this file matched no dive, when it is sitting in the unmatched
  /// bucket. Null for a file already in a dive group.
  final UnmatchedDiagnostic? diagnostic;

  /// The session's capture-time correction, so the card can show the corrected
  /// time next to the one actually read from the file.
  final Duration captureTimeOffset;

  /// Whether this file can be routed to a dive at all.
  ///
  /// False for a site session, where [FilesTabNotifier.commit] persists every
  /// staged file against the site id and ignores dive grouping outright. A
  /// dive-assignment action there would appear to do something and in fact do
  /// nothing.
  final bool allowDiveAssignment;

  const FileReviewCard({
    super.key,
    required this.file,
    required this.targetDiveId,
    this.assignableDiveId,
    this.diagnostic,
    this.captureTimeOffset = Duration.zero,
    this.allowDiveAssignment = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final assignTo = assignableDiveId;
    final canAssign =
        allowDiveAssignment && assignTo != null && assignTo != targetDiveId;
    final reason = diagnostic;

    return ListTile(
      isThreeLine: reason != null,
      leading: _buildLeading(),
      title: Text(
        p.basename(file.sourcePath),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_timeLine(context)),
          if (reason != null)
            Text(
              _reasonLine(context, reason),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canAssign)
            IconButton(
              icon: const Icon(Icons.add_link),
              tooltip: l10n.media_photoPicker_files_addToDiveTooltip,
              onPressed: () => ref
                  .read(filesTabNotifierProvider.notifier)
                  .assignToDive(file.sourcePath, assignTo),
            )
          else if (allowDiveAssignment && targetDiveId == null)
            IconButton(
              icon: const Icon(Icons.add_link),
              tooltip: l10n.media_photoPicker_files_chooseDiveTooltip,
              onPressed: () => _chooseDive(context, ref),
            ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: l10n.media_photoPicker_files_removeTooltip,
            onPressed: () => ref
                .read(filesTabNotifierProvider.notifier)
                .removeFile(file.sourcePath),
          ),
        ],
      ),
    );
  }

  /// Routes a file the matcher rejected into a dive the diver picks by hand.
  ///
  /// The notifier is read before the await so no [BuildContext] crosses an
  /// async gap.
  Future<void> _chooseDive(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(filesTabNotifierProvider.notifier);
    final diveId = await showDivePickerSheet(context);
    if (diveId == null) return;
    notifier.assignToDive(file.sourcePath, diveId);
  }

  /// The capture time plus where it was read from.
  ///
  /// When a session offset is in effect the corrected time leads and the value
  /// actually read from the file follows in parentheses, so a diver can see
  /// what was changed on their behalf before committing.
  String _timeLine(BuildContext context) {
    final l10n = context.l10n;
    final source = switch (file.metadata.takenAtSource) {
      TakenAtSource.nativeExif => l10n.media_photoPicker_files_sourceExif,
      TakenAtSource.containerMetadata =>
        l10n.media_photoPicker_files_sourceContainer,
      TakenAtSource.fileModifiedTime =>
        l10n.media_photoPicker_files_sourceFileDate,
      TakenAtSource.none => l10n.media_photoPicker_files_sourceNone,
    };

    final takenAt = file.metadata.takenAt;
    if (takenAt == null) return source;

    final original = _format(takenAt);
    if (captureTimeOffset == Duration.zero) return '$original ($source)';
    final shifted = _format(takenAt.add(captureTimeOffset));
    return '${l10n.media_photoPicker_files_shiftedTime(shifted, original)} '
        '($source)';
  }

  String _reasonLine(BuildContext context, UnmatchedDiagnostic diagnostic) {
    final l10n = context.l10n;
    switch (diagnostic.reason) {
      case UnmatchedReason.noTimestamp:
        return l10n.media_photoPicker_files_reasonNoTimestamp;
      case UnmatchedReason.outsideAllWindows:
        final gap = diagnostic.gapToNearest;
        if (gap == null) return l10n.media_photoPicker_files_reasonNoDives;
        final magnitude = formatOffsetMagnitude(gap);
        return gap.isNegative
            ? l10n.media_photoPicker_files_reasonBeforeDive(magnitude)
            : l10n.media_photoPicker_files_reasonAfterDive(magnitude);
    }
  }

  /// `takenAt` is wall-clock-UTC by codebase convention, so format its UTC
  /// components directly. Running it through a local-timezone formatter would
  /// re-introduce the host-offset skew the convention exists to avoid.
  String _format(DateTime value) =>
      DateFormat('yyyy-MM-dd HH:mm').format(value.toUtc());

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
