import 'package:submersion/features/dive_log/domain/entities/dive_custom_field.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';

/// Equipment attribute rows from an import map's `attributes` list. Input
/// is untrusted: entries that are not maps, have a blank key, carry no
/// value, or repeat a key already taken are skipped rather than aborting the
/// import. Curated keys are unique per item ([takenKeys] holds those already
/// set); custom keys are tracked apart, since a custom "size" may sit beside
/// the curated one. Curated rows get their deterministic id; custom rows get
/// [newId].
List<EquipmentAttribute> equipmentAttributesFromImport(
  Object? raw, {
  required String equipmentId,
  required String Function() newId,
  Set<String> takenKeys = const {},
}) {
  if (raw is! List) return const [];
  final takenCurated = {...takenKeys};
  final takenCustom = <String>{};
  final result = <EquipmentAttribute>[];
  for (final entry in raw) {
    if (entry is! Map) continue;
    final key = entry['key'];
    final isCustom = entry['isCustom'] == true;
    final taken = isCustom ? takenCustom : takenCurated;
    if (key is! String || key.trim().isEmpty || taken.contains(key)) continue;
    final text = entry['valueText'] is String
        ? entry['valueText'] as String
        : null;
    final number = entry['valueNum'] is num
        ? (entry['valueNum'] as num).toDouble()
        : null;
    if ((text == null || text.trim().isEmpty) && number == null) continue;
    result.add(
      isCustom
          ? EquipmentAttribute(
              id: newId(),
              equipmentId: equipmentId,
              key: key,
              isCustom: true,
              valueText: text,
              valueNum: number,
              sortOrder: result.length,
            )
          : EquipmentAttribute.curated(
              equipmentId: equipmentId,
              key: key,
              valueText: text,
              valueNum: number,
            ),
    );
    taken.add(key);
  }
  return result;
}

/// Dive custom fields from an import map's `customFields` list of
/// `{key, value}` maps, in order. Ids are left empty for the repository to
/// assign.
List<DiveCustomField> diveCustomFieldsFromImport(Object? raw) {
  if (raw is! List) return const [];
  final result = <DiveCustomField>[];
  for (final entry in raw) {
    if (entry is! Map) continue;
    final key = entry['key'];
    final value = entry['value'];
    if (key is! String || key.trim().isEmpty) continue;
    result.add(
      DiveCustomField(
        id: '',
        key: key,
        value: value is String ? value : '',
        sortOrder: result.length,
      ),
    );
  }
  return result;
}
