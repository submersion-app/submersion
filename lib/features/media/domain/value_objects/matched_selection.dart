import 'package:equatable/equatable.dart';

import 'package:submersion/features/media/domain/value_objects/extracted_file.dart';
import 'package:submersion/features/media/domain/value_objects/unmatched_diagnostic.dart';

/// Result of [DivePhotoMatcher.match]: files routed to dives by EXIF
/// `takenAt`, plus the bucket of files that didn't match any dive.
class MatchedSelection extends Equatable {
  final Map<String, List<ExtractedFile>> matched;
  final List<ExtractedFile> unmatched;

  /// Why each unmatched file failed, keyed by [ExtractedFile.sourcePath].
  ///
  /// Optional and empty by default so callers that build a selection by hand
  /// (the Files tab's manual-assignment branches, TripMediaScanner's merge)
  /// keep compiling. Entries for files that later move into a dive group are
  /// left in place and simply go unread: the review card only consults a
  /// diagnostic for a file sitting in [unmatched].
  final Map<String, UnmatchedDiagnostic> diagnostics;

  const MatchedSelection({
    required this.matched,
    required this.unmatched,
    this.diagnostics = const {},
  });

  factory MatchedSelection.empty() =>
      const MatchedSelection(matched: {}, unmatched: []);

  /// Rebuilds the selection with new buckets while carrying the diagnostics
  /// forward.
  ///
  /// The manual-assignment mutators move files between buckets and would
  /// otherwise reconstruct this object from scratch, silently discarding every
  /// diagnostic the matcher produced.
  MatchedSelection copyWith({
    Map<String, List<ExtractedFile>>? matched,
    List<ExtractedFile>? unmatched,
    Map<String, UnmatchedDiagnostic>? diagnostics,
  }) => MatchedSelection(
    matched: matched ?? this.matched,
    unmatched: unmatched ?? this.unmatched,
    diagnostics: diagnostics ?? this.diagnostics,
  );

  int get totalFiles =>
      matched.values.fold<int>(0, (a, list) => a + list.length) +
      unmatched.length;

  int get diveCount => matched.length;

  @override
  List<Object?> get props => [matched, unmatched, diagnostics];
}
