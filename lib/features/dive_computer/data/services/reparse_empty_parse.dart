import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;

/// Whether [parsed] carries no dive to apply: no samples, or no duration.
///
/// A re-parse reads the exact raw bytes the original download did, so a parse
/// that comes back empty means the parser produced less than it once did
/// from those same bytes, never that the dive itself is gone. Applying it
/// would zero the depth and runtime and delete the profile with nothing to
/// put back (issue #3368), the same reasoning as the tank guard for #1853.
bool isEmptyParse(pigeon.ParsedDive parsed) =>
    parsed.samples.isEmpty || parsed.durationSeconds <= 0;

/// Thrown by `ReparseService.applyParsedUpdate` for a parse [isEmptyParse]
/// rejects, before anything is written. The bulk re-parse counts it as a
/// failed dive and the single-dive re-parse reports it as an error.
class EmptyParseException implements Exception {
  const EmptyParseException();

  @override
  String toString() =>
      'The parser returned no dive data (no samples or zero duration); '
      'the dive was left unchanged';
}
