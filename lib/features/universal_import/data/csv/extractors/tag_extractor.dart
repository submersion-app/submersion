import 'package:uuid/uuid.dart';

import 'package:submersion/features/universal_import/data/csv/extractors/entity_extractor.dart';

/// Extracts tag records from transformed CSV rows.
///
/// The 'tags' field may contain multiple tag names separated by commas.
/// Tags are deduplicated by name across all rows.
class TagExtractor implements EntityExtractor<Map<String, dynamic>> {
  final Uuid _uuid;

  /// Internal map from tag name to generated UUID.
  final Map<String, String> _tagNameToId = {};

  TagExtractor({Uuid uuid = const Uuid()}) : _uuid = uuid;

  @override
  List<Map<String, dynamic>> extractFromRows(List<Map<String, dynamic>> rows) {
    final tags = <Map<String, dynamic>>[];

    for (final row in rows) {
      final raw = row['tags'];
      if (raw == null) continue;
      final names = _splitNames(raw.toString());

      for (final name in names) {
        if (_tagNameToId.containsKey(name)) continue;
        final id = _uuid.v4();
        _tagNameToId[name] = id;
        tags.add({'id': id, 'name': name});
      }
    }

    return tags;
  }

  /// Returns the generated UUID for a tag name, or null if not seen.
  String? tagIdForName(String name) => _tagNameToId[name];

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  List<String> _splitNames(String raw) {
    return raw
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }
}
