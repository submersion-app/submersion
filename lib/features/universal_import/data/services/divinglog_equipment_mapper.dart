import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/services/equipment_type_from_name.dart';
import 'package:submersion/features/universal_import/data/services/divinglog_raw_types.dart';
import 'package:submersion/features/universal_import/data/services/divinglog_row_values.dart';

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
      // EquipmentItem has no weight field. The importer builds it from the
      // direct keys plus `attributes`, so a top-level `weight` would be
      // read by nobody and the value would be lost on the way in.
      // A zero here is the format's "not recorded", and a dry weight of
      // zero is not harmless: it feeds the buoyancy maths as a real value.
      final weight = positiveOrNull(item.weightKg);
      if (weight != null) {
        map['attributes'] = <Map<String, dynamic>>[
          {'key': EquipmentAttrKeys.dryWeightKg, 'valueNum': weight},
        ];
      }
      // The importer reads `purchasePrice`; `price` is silently dropped. A
      // zero is this format's "not recorded", and a purchase price of zero
      // would import the item as free and skew any gear cost total.
      final price = positiveOrNull(item.price);
      if (price != null) map['purchasePrice'] = price;
      if (item.purchaseDate != null) map['purchaseDate'] = item.purchaseDate;
      // Diving Log's inactive gear is retired gear, and the importer reads
      // `status` and `isActive`, not `isRetired`. Both markers, as MacDive
      // sets them, or every retired item imports as active.
      if (item.inactive) {
        map['status'] = EquipmentStatus.retired.name;
        map['isActive'] = false;
      }
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

  /// Whether [item] becomes an entity, which is also what decides whether a
  /// dive may reference it. [entities] drops a row with a blank name, so a
  /// ref to one would dangle: the importer skips it in silence and the
  /// unresolved count never sees it.
  static bool _isImportable(DivingLogRawEquipment item) =>
      (item.object?.trim().isNotEmpty) ?? false;

  /// The `equipmentRefs` for [dive], in the order the source listed them.
  /// An id with no importable row is skipped and counted by
  /// [unresolvedCount].
  static List<String> refsFor(DivingLogLogbook book, DivingLogRawDive dive) => [
    for (final id in dive.equipmentIds)
      if (book.equipmentById[id] case final item? when _isImportable(item))
        _uddfId(id),
  ];

  /// How many of [dive]'s equipment ids reach no importable row.
  ///
  /// Counted per id against the same predicate [refsFor] uses, rather than
  /// by subtracting the number of refs: the two must agree, and a count
  /// derived from list lengths would also report deduplication as a gap.
  static int unresolvedCount(DivingLogLogbook book, DivingLogRawDive dive) =>
      dive.equipmentIds.where((id) {
        final item = book.equipmentById[id];
        return item == null || !_isImportable(item);
      }).length;
}
