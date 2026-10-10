import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/dive_computer_gear_identity.dart';
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
    final computers = _computerNames(book);
    final out = <String, Map<String, dynamic>>{};
    for (final item in book.equipmentById.values) {
      if (!_isImportable(item)) continue;
      final name = _nameOf(item)!;
      final key = _uddfId(item.id);
      // DiveMate names the item and keeps the model in `Object`; Diving Log
      // has only `Object`, so the model is read out of the name.
      final model = _diveMateModel(item) ?? _modelFrom(name, item.manufacturer);
      final isComputer = computers.any(
        (c) => computerNamesAgree(
          brandA: null,
          modelA: c,
          brandB: item.manufacturer,
          modelB: model,
        ),
      );
      final read = isComputer ? null : _typeOf(item, name);
      final map = <String, dynamic>{
        'name': name,
        'uddfId': key,
        'type': isComputer
            ? EquipmentType.computer.name
            : (read?.type ?? EquipmentType.other).name,
      };
      if (isComputer || _diveMateModel(item) != null) map['model'] = model;
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

  /// Every distinct `Logbook.Computer` value, the names the import
  /// registers dive computers under.
  ///
  /// A registered computer mints its own gear twin unless it finds active
  /// `computer` gear with the same identity (#2299). Diving Log's Equipment
  /// table has no type column, so the row for that same computer would
  /// import as `other` with no model, invisible to that search, and the
  /// logbook would list the computer twice. Matching the row against these
  /// names is what lets the twin adopt it instead. The logbook naming the
  /// row as the computer outranks anything its name suggests: "Scubapro G2
  /// Console" reads as an instrument.
  static Set<String> _computerNames(DivingLogLogbook book) => {
    for (final dive in book.dives)
      if (dive.computer?.trim() case final name? when name.isNotEmpty) name,
  };

  /// The model an item's [name] carries once the [manufacturer] it repeats
  /// is dropped, so "Shearwater Teric" from "Shearwater" is model "Teric".
  static String _modelFrom(String name, String? manufacturer) {
    final brand = manufacturer?.trim() ?? '';
    if (brand.isEmpty ||
        !name.toLowerCase().startsWith('${brand.toLowerCase()} ')) {
      return name;
    }
    final rest = name.substring(brand.length).trim();
    return rest.isEmpty ? name : rest;
  }

  /// The item's display name: DiveMate's `Name`, else Diving Log's
  /// `Object`. Null when both are blank.
  static String? _nameOf(DivingLogRawEquipment item) {
    for (final candidate in [item.name, item.object]) {
      final trimmed = candidate?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }

  /// DiveMate's model: `Object` when the row also has a `Name` that differs
  /// from it. Null for a Diving Log row, whose `Object` is the name.
  static String? _diveMateModel(DivingLogRawEquipment item) {
    final name = item.name?.trim();
    final object = item.object?.trim();
    if (name == null || name.isEmpty) return null;
    if (object == null || object.isEmpty || object == name) return null;
    return object;
  }

  /// The type read from the name, then from DiveMate's category when the
  /// name says nothing: an item called "Main" filed under "Regulators".
  static TypeFromName? _typeOf(DivingLogRawEquipment item, String name) {
    final category = item.category?.trim();
    return typeFromName(name) ??
        (category == null || category.isEmpty ? null : typeFromName(category));
  }

  /// Whether [item] becomes an entity, which is also what decides whether a
  /// dive may reference it. [entities] drops a row with a blank name, so a
  /// ref to one would dangle: the importer skips it in silence and the
  /// unresolved count never sees it. A DiveMate set is not gear; a dive's
  /// ref to one is expanded to its members by [_expand].
  static bool _isImportable(DivingLogRawEquipment item) =>
      item.setMemberIds == null && _nameOf(item) != null;

  /// [dive]'s equipment ids with every DiveMate set replaced by its members,
  /// in order, each id once.
  static List<int> _expand(DivingLogLogbook book, DivingLogRawDive dive) {
    final out = <int>[];
    for (final id in dive.equipmentIds) {
      final members = book.equipmentById[id]?.setMemberIds;
      for (final member in members ?? [id]) {
        if (!out.contains(member)) out.add(member);
      }
    }
    return out;
  }

  /// The `equipmentRefs` for [dive], in the order the source listed them.
  /// An id with no importable row is skipped and counted by
  /// [unresolvedCount].
  static List<String> refsFor(DivingLogLogbook book, DivingLogRawDive dive) => [
    for (final id in _expand(book, dive))
      if (book.equipmentById[id] case final item? when _isImportable(item))
        _uddfId(id),
  ];

  /// How many of [dive]'s equipment ids reach no importable row.
  ///
  /// Counted per id against the same predicate [refsFor] uses, rather than
  /// by subtracting the number of refs: the two must agree, and a count
  /// derived from list lengths would also report deduplication as a gap.
  static int unresolvedCount(DivingLogLogbook book, DivingLogRawDive dive) =>
      _expand(book, dive).where((id) {
        final item = book.equipmentById[id];
        return item == null || !_isImportable(item);
      }).length;
}
