/// One fix as it came out of a file, before any timezone reinterpretation.
typedef ParsedFix = ({DateTime utc, double lat, double lon, double? accuracy});

/// A track as parsed from a file.
///
/// When [timesAreWallClock] is false, [ParsedFix.utc] is REAL UTC and the
/// import service converts it using the resolved recording offset.
///
/// When it is true the source carried no zone designator at all, so the
/// value written in the file already IS the recording device's wall clock -
/// exactly what this app stores - and the offset must NOT be applied again.
/// Parsing a naive timestamp with DateTime.parse yields a LOCAL DateTime, so
/// treating it as real UTC folds in the importing machine's offset and the
/// same file produces two different tracks on two computers.
class ParsedTrack {
  final String? name;
  final List<ParsedFix> fixes;
  final bool timesAreWallClock;

  const ParsedTrack({
    this.name,
    required this.fixes,
    this.timesAreWallClock = false,
  });
}

/// True when [text] ends in a UTC designator or a numeric offset.
///
/// `2026-05-22T13:00:00Z` and `...+02:00` are zoned; a bare
/// `2026-05-22 13:00:00`, which is what most consumer GPS loggers emit, is
/// not.
bool hasExplicitZone(String text) =>
    RegExp(r'(?:Z|z|[+-]\d{2}:?\d{2})$').hasMatch(text.trim());

/// Parses a timestamp, reporting whether it carried a zone.
///
/// A naive value is parsed as if UTC so the result is identical on every
/// machine; the caller then knows not to shift it again.
({DateTime time, bool zoned})? parseFixTime(String text) {
  final trimmed = text.trim();
  final zoned = hasExplicitZone(trimmed);
  final parsed = DateTime.tryParse(zoned ? trimmed : '${trimmed}Z');
  if (parsed == null) return null;
  return (time: parsed.toUtc(), zoned: zoned);
}

/// Why a file could not be read as a track, in terms a diver can act on.
///
/// The parsers throw with an English [TrackParseException.message] naming the
/// offending element, row, or value. That detail belongs in the log, not in a
/// SnackBar it would be shipped to eleven locales untranslated - so each throw
/// also carries one of these, and the UI localizes the reason.
enum TrackParseReason {
  /// The extension is not one this app reads.
  unsupportedFormat,

  /// Structurally unreadable: malformed XML, broken CSV, corrupt FIT.
  unreadable,

  /// Read fine, but contains no GPS positions.
  noPositions,

  /// Has positions, but a coordinate or timestamp in them is unusable.
  badData,
}

/// A file could not be understood as a track.
class TrackParseException implements Exception {
  /// Technical detail, English. For the log and for tests, not for the UI.
  final String message;

  /// The localizable category. Defaults to [TrackParseReason.unreadable].
  final TrackParseReason reason;

  const TrackParseException(
    this.message, {
    this.reason = TrackParseReason.unreadable,
  });

  @override
  String toString() => 'TrackParseException: $message';
}

/// Rejects coordinates outside the valid range.
void validateCoordinate(double lat, double lon) {
  if (lat < -90 || lat > 90 || lon < -180 || lon > 180) {
    throw TrackParseException(
      'Coordinate out of range: $lat, $lon',
      reason: TrackParseReason.badData,
    );
  }
}
