import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/universal_import/data/csv/extractors/entity_extractor.dart';
import 'package:submersion/features/universal_import/data/services/suit_classifier.dart';

/// Extracts gear/equipment records from transformed CSV rows.
///
/// Currently extracts suit information from the 'suit' field. A suit the
/// text names as a wetsuit or drysuit gets that type, and a wetsuit with one
/// stated thickness carries it under 'thickness' (see [classifySuit]); any
/// other suit is typed `other`, which is what the importer always stored for
/// it. Gear items are deduplicated by name.
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
      final suit = classifySuit(name);
      gear.add({
        'id': id,
        'uddfId': id,
        'name': name,
        'type': (suit?.type ?? EquipmentType.other).name,
        'thickness': ?suit?.thickness,
      });
    }

    _gearNameToId = nameToId;
    return gear;
  }

  /// Returns the generated UUID for a gear item name, or null if not seen.
  String? gearIdForName(String name) => _gearNameToId[name];
}
