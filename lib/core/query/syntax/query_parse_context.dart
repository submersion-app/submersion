import 'package:meta/meta.dart';

import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/domain/query_value.dart';
import 'package:submersion/core/query/syntax/query_suggestions.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';

/// Resolves a typed name to a row of [kind]. `NameIndex` in
/// lib/core/query/names/ implements this (#2365).
abstract class NameResolver {
  RefValue? resolve(QuerySubject kind, String text);
  List<String> candidates(QuerySubject kind, String text);
}

/// Implemented by resolvers that can list every row of a subject, which
/// the editor's completions and ref pickers use; the parser itself needs
/// only [NameResolver]. Rows, not labels: two sites can share a name
/// ("Blue Hole"), and each must stay pickable by its own id.
abstract class NameEntries {
  Iterable<RefValue> refEntries(QuerySubject kind);
}

/// Exact, case-insensitive label lookup over an in-memory map. For tests
/// and for callers that already hold the labels.
class MapNameResolver implements NameResolver, NameEntries {
  final Map<QuerySubject, Map<String, String>> labelsToIds;
  const MapNameResolver(this.labelsToIds);

  @override
  Iterable<RefValue> refEntries(QuerySubject kind) => [
    for (final e in (labelsToIds[kind] ?? const <String, String>{}).entries)
      RefValue(e.value, e.key),
  ];

  @override
  RefValue? resolve(QuerySubject kind, String text) {
    final labels = labelsToIds[kind] ?? const {};
    for (final e in labels.entries) {
      if (e.key.toLowerCase() == text.toLowerCase()) {
        return RefValue(e.value, e.key);
      }
    }
    return null;
  }

  @override
  List<String> candidates(QuerySubject kind, String text) =>
      suggestNames(text, (labelsToIds[kind] ?? const {}).keys);
}

@immutable
class ParseContext {
  final UnitPrefs prefs;
  final DateTime now;
  final NameResolver names;

  /// The app's language code, for the filler words and month names of a
  /// sentence typed in plain words. Null reads English only.
  final String? language;
  const ParseContext({
    required this.prefs,
    required this.now,
    required this.names,
    this.language,
  });
}
