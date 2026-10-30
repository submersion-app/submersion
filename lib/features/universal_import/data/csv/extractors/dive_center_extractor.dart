import 'package:uuid/uuid.dart';

import 'package:submersion/features/universal_import/data/csv/extractors/entity_extractor.dart';

/// Extracts dive centre records from the 'diveCenter' field of transformed
/// CSV rows, deduplicated by name across all rows (#3629). Names that differ
/// only in case or spacing are one centre, named as first written.
class DiveCenterExtractor implements EntityExtractor<Map<String, dynamic>> {
  final Uuid _uuid;

  /// Map from dive centre name key ([_key]) to generated UUID, populated
  /// during extraction.
  Map<String, String> _nameToId = const {};

  DiveCenterExtractor({Uuid uuid = const Uuid()}) : _uuid = uuid;

  @override
  List<Map<String, dynamic>> extractFromRows(List<Map<String, dynamic>> rows) {
    final centers = <Map<String, dynamic>>[];
    final nameToId = <String, String>{};

    for (final row in rows) {
      final name = _name(row);
      final key = _key(name);
      if (key.isEmpty || nameToId.containsKey(key)) continue;
      final id = _uuid.v4();
      nameToId[key] = id;
      centers.add({'id': id, 'uddfId': id, 'name': name});
    }

    _nameToId = nameToId;
    return centers;
  }

  /// The generated UUID of the dive centre on [row], or null if it has none.
  String? centerIdForRow(Map<String, dynamic> row) =>
      _nameToId[_key(_name(row))];

  static String _name(Map<String, dynamic> row) =>
      (row['diveCenter']?.toString() ?? '').trim().replaceAll(_spaces, ' ');

  static String _key(String name) => name.toLowerCase();

  static final _spaces = RegExp(r'\s+');
}
