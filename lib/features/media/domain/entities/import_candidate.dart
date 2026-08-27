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

/// What confirming did, for the result snackbar.
class ImportReviewResult {
  const ImportReviewResult({
    required this.linked,
    required this.skipped,
    this.failures = const {},
  });

  final int linked;
  final int skipped;
  final Map<String, String> failures;
}
