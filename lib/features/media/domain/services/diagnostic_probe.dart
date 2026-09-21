import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';

/// A reachability verdict that costs a stat rather than a read.
///
/// `MediaSourceResolver.verify` is written for the verification sweep, which
/// must know the bytes are really reachable, so some resolvers answer it by
/// resolving the item: `LocalFileResolver` reads the whole file on its
/// bookmark path. That is the right trade for a sweep and the wrong one for
/// a report, which asks about every row in the library at once and only
/// needs to know whether the pointer still leads somewhere.
///
/// A resolver implements this when it can answer more cheaply than its own
/// verify. Callers that cannot afford verify prefer it and fall back.
abstract interface class DiagnosticProbe {
  /// The verdict for [item] without reading its bytes, or null when this
  /// source genuinely cannot answer without a read. A null is reported as
  /// "not probed" rather than guessed at, because the alternative is
  /// claiming a file is present on the strength of a pointer to it.
  Future<VerifyResult?> probe(MediaItem item);
}
