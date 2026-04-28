import 'package:equatable/equatable.dart';

import 'package:submersion/features/media/domain/value_objects/extracted_file.dart';

/// Result of [DivePhotoMatcher.match]: files routed to dives by EXIF
/// `takenAt`, plus the bucket of files that didn't match any dive.
class MatchedSelection extends Equatable {
  final Map<String, List<ExtractedFile>> matched;
  final List<ExtractedFile> unmatched;

  const MatchedSelection({required this.matched, required this.unmatched});

  factory MatchedSelection.empty() =>
      const MatchedSelection(matched: {}, unmatched: []);

  int get totalFiles =>
      matched.values.fold<int>(0, (a, list) => a + list.length) +
      unmatched.length;

  int get diveCount => matched.length;

  @override
  List<Object?> get props => [matched, unmatched];
}
