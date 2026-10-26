import 'package:uuid/uuid.dart';

import 'package:submersion/features/universal_import/data/csv/extractors/entity_extractor.dart';

/// Extracts buddy records from transformed CSV rows.
///
/// The 'buddy' and 'instructor' fields may each contain multiple names
/// separated by commas. Buddies are deduplicated by name across all rows,
/// whichever field names them.
///
/// Handles the Subsurface leading-comma format where the field value starts
/// with ", " (e.g., ", Kiyan Griffin").
class BuddyExtractor implements EntityExtractor<Map<String, dynamic>> {
  final Uuid _uuid;

  /// Map from buddy name to generated UUID, populated during extraction.
  Map<String, String> _buddyNameToId = const {};

  BuddyExtractor({Uuid uuid = const Uuid()}) : _uuid = uuid;

  @override
  List<Map<String, dynamic>> extractFromRows(List<Map<String, dynamic>> rows) {
    final buddies = <Map<String, dynamic>>[];
    final nameToId = <String, String>{};

    for (final row in rows) {
      for (final field in const ['buddy', 'instructor']) {
        final raw = row[field];
        if (raw == null) continue;
        for (final name in splitNames(raw)) {
          if (nameToId.containsKey(name)) continue;
          final id = _uuid.v4();
          nameToId[name] = id;
          buddies.add({'id': id, 'uddfId': id, 'name': name});
        }
      }
    }

    _buddyNameToId = nameToId;
    return buddies;
  }

  /// Returns the generated UUID for a buddy name, or null if not seen.
  String? buddyIdForName(String name) => _buddyNameToId[name];

  /// The comma-separated names in a raw people field, trimmed, without
  /// empty entries.
  static List<String> splitNames(Object? raw) => (raw?.toString() ?? '')
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
}
