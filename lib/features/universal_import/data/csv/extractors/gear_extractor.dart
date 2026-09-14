import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/universal_import/data/csv/extractors/entity_extractor.dart';
import 'package:submersion/features/universal_import/data/services/macdive_value_mapper.dart';

/// Extracts gear/equipment records from transformed CSV rows.
///
/// Currently extracts suit information from the 'suit' field. Each suit is
/// typed from its name and emitted under the [EquipmentType] name, which is
/// what the importer parses and the duplicate checker keys on. Gear items are
/// deduplicated by name.
class GearExtractor implements EntityExtractor<Map<String, dynamic>> {
  /// Types a suit name may claim. The column is known to hold a suit, so any
  /// other reading of the free-text mapper (it sees fins in the "fin" of
  /// "Definition") is not trusted here.
  static const _garmentTypes = {
    EquipmentType.wetsuit,
    EquipmentType.drysuit,
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

      final id = _uuid.v4();
      nameToId[name] = id;
      gear.add({
        'id': id,
        'uddfId': id,
        'name': name,
        'type': _suitType(name).name,
      });
    }

    _gearNameToId = nameToId;
    return gear;
  }

  /// A suit whose name does not say what it is is taken to be a wetsuit, the
  /// suit most divers own; a semi-dry is one too.
  static EquipmentType _suitType(String name) {
    final mapped = MacDiveValueMapper.equipmentType(name);
    return mapped != null && _garmentTypes.contains(mapped)
        ? mapped
        : EquipmentType.wetsuit;
  }

  /// Returns the generated UUID for a gear item name, or null if not seen.
  String? gearIdForName(String name) => _gearNameToId[name];
}
