import 'package:uuid/uuid.dart';

import 'package:submersion/features/universal_import/data/csv/extractors/entity_extractor.dart';

/// Extracts dive centre records from the 'diveCenter' field of transformed
/// CSV rows, deduplicated by name across all rows (#3629).
class DiveCenterExtractor implements EntityExtractor<Map<String, dynamic>> {
  final Uuid _uuid;

  /// Map from dive centre name to generated UUID, populated during
  /// extraction.
  Map<String, String> _nameToId = const {};

  DiveCenterExtractor({Uuid uuid = const Uuid()}) : _uuid = uuid;

  @override
  List<Map<String, dynamic>> extractFromRows(List<Map<String, dynamic>> rows) {
    final centers = <Map<String, dynamic>>[];
    final nameToId = <String, String>{};

    for (final row in rows) {
      final name = row['diveCenter']?.toString().trim() ?? '';
      if (name.isEmpty || nameToId.containsKey(name)) continue;
      final id = _uuid.v4();
      nameToId[name] = id;
      centers.add({'id': id, 'uddfId': id, 'name': name});
    }

    _nameToId = nameToId;
    return centers;
  }

  /// The generated UUID of the dive centre on [row], or null if it has none.
  String? centerIdForRow(Map<String, dynamic> row) =>
      _nameToId[row['diveCenter']?.toString().trim() ?? ''];
}
