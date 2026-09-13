import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/universal_import/data/csv/extractors/entity_extractor.dart';
import 'package:submersion/features/universal_import/data/services/macdive_value_mapper.dart';
import 'package:submersion/features/universal_import/data/services/suit_classifier.dart';

/// Extracts gear/equipment records from transformed CSV rows.
///
/// Currently extracts suit information from the 'suit' field, typed from its
/// name and emitted under the [EquipmentType] name, which is what the
/// importer parses and the duplicate checker keys on:
///
/// - a wetsuit or drysuit comes from [classifySuit], and a wetsuit with one
///   stated thickness carries it under 'thickness' (#1824);
/// - a layer that names itself (undersuit, base layer, rash guard) takes
///   that type from the free-text mapper (#1885).
///
/// A suit the name does not identify creates no gear: it stays in the dive
/// notes only (DiveExtractor), as in the Subsurface XML import. Gear items
/// are deduplicated by name.
class GearExtractor implements EntityExtractor<Map<String, dynamic>> {
  /// Layers a suit name may claim through the free-text mapper. The column
  /// is known to hold a suit, so any other reading of the mapper (it sees
  /// fins in the "fin" of "Definition") is not trusted here.
  static const _layerTypes = {
    EquipmentType.undersuit,
    EquipmentType.baselayer,
    EquipmentType.rashGuard,
  };

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

      final suit = _suit(name);
      if (suit == null) continue;

      final id = _uuid.v4();
      nameToId[name] = id;
      gear.add({
        'id': id,
        'uddfId': id,
        'name': name,
        'type': suit.type.name,
        'thickness': ?suit.thickness,
      });
    }

    _gearNameToId = nameToId;
    return gear;
  }

  /// What the suit [name] says it is, or null when it does not say.
  static SuitClassification? _suit(String name) {
    final classified = classifySuit(name);
    if (classified != null) return classified;
    final mapped = MacDiveValueMapper.equipmentType(name);
    return mapped != null && _layerTypes.contains(mapped)
        ? (type: mapped, thickness: null)
        : null;
  }

  /// Returns the generated UUID for a gear item name, or null if not seen.
  String? gearIdForName(String name) => _gearNameToId[name];
}
