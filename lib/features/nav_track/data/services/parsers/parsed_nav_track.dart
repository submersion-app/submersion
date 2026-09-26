import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';
import 'package:submersion/features/nav_track/domain/nav_track_point_codec.dart'
    show kMaxNavTrackPointCount;

/// A route as parsed from a file, before a dive link, an anchor, or a
/// drift correction has been applied. Everything downstream of this type
/// (the matcher, the georeferencer, the corrector) reads it and produces
/// new values; nothing writes back into it.
class ParsedNavTrack {
  final List<NavTrackPoint> points;

  const ParsedNavTrack({required this.points});
}

/// Why a file could not be understood as a navigation route, in terms a
/// diver can act on.
///
/// The parsers throw with an English [NavTrackParseException.message]
/// naming the offending row or value, for the log and for tests. That
/// detail is not fit for a SnackBar shipped to eleven locales untranslated,
/// so each throw also carries one of these, and the UI localises the
/// reason. Mirrors `TrackParseReason` in the GPS logger.
enum NavTrackParseReason {
  /// The extension or content is not one this app reads as a route.
  unsupportedFormat,

  /// Structurally unreadable: malformed CSV, missing required columns.
  unreadable,

  /// Read fine, but has fewer samples than a route needs to be useful.
  tooShort,

  /// Has samples, but a value in them is unusable (a bad timestamp, a
  /// timestamp that goes backwards, an implausible depth).
  badData,

  /// Readable, but with more samples than a route can store.
  tooLarge,
}

/// A file could not be understood as a navigation route.
class NavTrackParseException implements Exception {
  /// Technical detail, English. For the log and for tests, not for the UI.
  final String message;

  /// The localizable category. Defaults to [NavTrackParseReason.unreadable].
  final NavTrackParseReason reason;

  const NavTrackParseException(
    this.message, {
    this.reason = NavTrackParseReason.unreadable,
  });

  @override
  String toString() => 'NavTrackParseException: $message';
}

/// Rejects a parsed sample count over [kMaxNavTrackPointCount] (defined by
/// `nav_track_point_codec.dart`, which enforces the same cap on encode and
/// decode; this is the parse-time half of that guarantee), with a
/// message a diver can act on, raised while they still have the file in
/// front of them.
void validateNavTrackPointCount(int count) {
  if (count > kMaxNavTrackPointCount) {
    throw NavTrackParseException(
      'file has $count sample(s), over the $kMaxNavTrackPointCount '
      'a route can store',
      reason: NavTrackParseReason.tooLarge,
    );
  }
}
