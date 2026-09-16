import 'package:uuid/uuid.dart';

import 'package:submersion/features/universal_import/data/csv/extractors/entity_extractor.dart';

/// Extracts tag records from transformed CSV rows.
///
/// The 'tags' field may contain multiple tag names separated by commas.
/// Tags are deduplicated by name across all rows.
class TagExtractor implements EntityExtractor<Map<String, dynamic>> {
  final Uuid _uuid;

  /// Map from tag name to generated UUID, populated during extraction.
  Map<String, String> _tagNameToId = const {};

  TagExtractor({Uuid uuid = const Uuid()}) : _uuid = uuid;

  @override
  List<Map<String, dynamic>> extractFromRows(List<Map<String, dynamic>> rows) {
    final tags = <Map<String, dynamic>>[];
    final nameToId = <String, String>{};

    for (final row in rows) {
      final raw = row['tags'];
      if (raw == null) continue;
      final names = _splitNames(raw.toString());

      for (final name in names) {
        if (nameToId.containsKey(name)) continue;
        final id = _uuid.v4();
        nameToId[name] = id;
        tags.add({'id': id, 'uddfId': id, 'name': name});
      }
    }

    _tagNameToId = nameToId;
    return tags;
  }

  /// Returns the generated UUID for a tag name, or null if not seen.
  String? tagIdForName(String name) => _tagNameToId[name];

  /// Returns the generated UUIDs of the tags named in [row]'s 'tags' field,
  /// in order and without repeats, so the row's dive can link to them.
  List<String> tagIdsForRow(Map<String, dynamic> row) {
    final raw = row['tags'];
    if (raw == null) return const [];
    return {
      for (final name in _splitNames(raw.toString())) ?_tagNameToId[name],
    }.toList();
  }

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
