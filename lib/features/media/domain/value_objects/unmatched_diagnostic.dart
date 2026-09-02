import 'package:equatable/equatable.dart';

/// Why one file matched no dive.
enum UnmatchedReason {
  /// No capture time could be read at all, so the matcher had nothing to
  /// compare. Shifting capture times cannot rescue these; they need to be
  /// assigned to a dive by hand.
  noTimestamp,

  /// A capture time exists but falls outside every dive's match window. A
  /// constant offset correction may rescue these, since a camera clock set to
  /// the wrong timezone puts the same error on every file from the card.
  outsideAllWindows,
}

/// The matcher's explanation for a single unmatched file.
///
/// Produced by `DivePhotoMatcher.match` and carried on
/// `MatchedSelection.diagnostics`, keyed by `ExtractedFile.sourcePath`.
class UnmatchedDiagnostic extends Equatable {
  final UnmatchedReason reason;

  /// The dive whose match window this file came closest to. Null when [reason]
  /// is [UnmatchedReason.noTimestamp], and when there are no dives at all.
  final String? nearestDiveId;

  /// Signed distance from the file's capture time to the nearest dive's match
  /// window: negative when the file is before the window, positive when after.
  ///
  /// Shifting capture times by the negation of this value brings the file to
  /// the window edge, which is what makes it useful to show next to the offset
  /// control.
  final Duration? gapToNearest;

  const UnmatchedDiagnostic({
    required this.reason,
    this.nearestDiveId,
    this.gapToNearest,
  });

  @override
  List<Object?> get props => [reason, nearestDiveId, gapToNearest];
}
