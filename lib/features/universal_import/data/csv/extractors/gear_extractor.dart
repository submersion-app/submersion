import 'package:uuid/uuid.dart';

import 'package:submersion/features/universal_import/data/csv/extractors/entity_extractor.dart';

/// Extracts gear/equipment records from transformed CSV rows.
///
/// Currently extracts suit information from the 'suit' field, categorised
/// with type 'exposure_suit'. Gear items are deduplicated by name.
class GearExtractor implements EntityExtractor<Map<String, dynamic>> {
  final Uuid _uuid;

  /// Map from gear name to generated UUID, populated during extraction.
  Map<String, String> _gearNameToId = const {};

  GearExtractor({Uuid uuid = const Uuid()}) : _uuid = uuid;

  @override
  List<Map<String, dynamic>> extractFromRows(List<Map<String, dynamic>> rows) {
    final gear = <Map<String, dynamic>>[];
    final nameToId = <String, String>{};

    for (final row in rows) {
      final rawSuit = row['suit'];
      if (rawSuit == null) continue;
      final name = rawSuit.toString().trim();
      if (name.isEmpty) continue;

      if (nameToId.containsKey(name)) continue;

      final id = _uuid.v4();
      nameToId[name] = id;
      gear.add({'id': id, 'uddfId': id, 'name': name, 'type': 'exposure_suit'});
    }

    _gearNameToId = nameToId;
    return gear;
  }

  /// Returns the generated UUID for a gear item name, or null if not seen.
  String? gearIdForName(String name) => _gearNameToId[name];
}
