import 'package:submersion/features/media/domain/value_objects/import_preview.dart';

/// One thing the user is about to import, before any row exists for it.
class ImportCandidate {
  const ImportCandidate({
    required this.key,
    required this.title,
    this.takenAt,
    this.error,
    this.preview,
  });

  /// Caller-defined identity (asset id, URL, manifest entry key).
  final String key;
  final String title;

  /// Capture timestamp as wall-clock UTC; null when unknown.
  final DateTime? takenAt;

  /// Why the candidate could not be examined (a failed fetch). Such a
  /// candidate can still be imported against an explicit target.
  final String? error;

  /// Where to find this candidate's thumbnail, or null when the caller has
  /// no art for it and the row should render text-only.
  final ImportPreview? preview;
}

/// What confirming did, for the result snackbar and for callers that need
/// the rows themselves (a species import tags what was created).
class ImportReviewResult {
  const ImportReviewResult({
    required this.linked,
    required this.skipped,
    this.failures = const {},
    this.linkedDiveIds = const [],
    this.importedIds = const [],
  });

  final int linked;
  final int skipped;
  final Map<String, String> failures;

  /// Dives that received at least one attach target in this import, for the
  /// post-import site suggestion prompt.
  final List<String> linkedDiveIds;

  /// Ids of the media rows the import created, in import order.
  final List<String> importedIds;
}
