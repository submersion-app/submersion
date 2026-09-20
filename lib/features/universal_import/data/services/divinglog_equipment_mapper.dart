import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/services/equipment_type_from_name.dart';
import 'package:submersion/features/universal_import/data/services/divinglog_raw_types.dart';

/// Maps Diving Log's `Equipment` table.
///
/// The table has no type column: `Object` is a free-text name like "Go Sport
/// Fins" or "Wet Suit (5mm full body)". [typeFromName] is the reader the
/// MacDive and CSV importers already use, so gear from any source is typed
/// the same way, and an item whose name says nothing lands on
/// [EquipmentType.other] where the Data Tools retype page can reach it.
class DivingLogEquipmentMapper {
  const DivingLogEquipmentMapper._();

  static String _uddfId(int id) => 'divinglog_gear_$id';

  static Map<String, Map<String, dynamic>> entities(DivingLogLogbook book) {
    final out = <String, Map<String, dynamic>>{};
    for (final item in book.equipmentById.values) {
      final name = item.object?.trim();
      if (name == null || name.isEmpty) continue;
      final key = _uddfId(item.id);
      final read = typeFromName(name);
      final map = <String, dynamic>{
        'name': name,
        'uddfId': key,
        'type': (read?.type ?? EquipmentType.other).name,
      };
      if (read?.thickness != null) map['thickness'] = read!.thickness;
      if (item.manufacturer != null) map['brand'] = item.manufacturer;
      if (item.serial != null) map['serialNumber'] = item.serial;
      if (item.weightKg != null) map['weight'] = item.weightKg;
      // The importer reads `purchasePrice`; `price` is silently dropped.
      if (item.price != null) map['purchasePrice'] = item.price;
      if (item.purchaseDate != null) map['purchaseDate'] = item.purchaseDate;
      if (item.inactive) map['isRetired'] = true;
      final notes = [
        if (item.o2ServiceDate != null)
          'O2 service: '
              '${item.o2ServiceDate!.toIso8601String().substring(0, 10)}',
        if (item.comments != null) item.comments!,
      ].join('\n');
      if (notes.isNotEmpty) map['notes'] = notes;
      out[key] = map;
    }
    return out;
  }

  /// The `equipmentRefs` for [dive], in the order the source listed them.
  /// An id with no matching row is skipped rather than producing a ref the
  /// importer cannot resolve.
  static List<String> refsFor(DivingLogLogbook book, DivingLogRawDive dive) => [
    for (final id in dive.equipmentIds)
      if (book.equipmentById.containsKey(id)) _uddfId(id),
  ];
}
