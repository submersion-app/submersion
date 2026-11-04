import 'dart:convert';

import 'package:submersion/core/constants/enums.dart'
    show EquipmentStatus, EquipmentType;
import 'package:submersion/features/agent_access/data/documents/document_dates.dart';
import 'package:submersion/features/agent_access/data/writes/families/write_reach.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/object_list_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_fitting.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/services/attribute_service_baselines.dart';

/// An item's attributes as one list: built-in ones by key, custom ones in
/// the order given, which is the order the diver sees them in.
final FieldCodec attributeListCodec = _AttributeListCodec();

class _AttributeListCodec extends ObjectListCodec {
  _AttributeListCodec()
    : super(
        const {
          'key': FieldCodec.text(maxLength: 100, trim: true),
          'is_custom': FieldCodec.flag(),
          'value_text': FieldCodec.text(maxLength: 500, nullable: true),
          'value_num': FieldCodec.number(nullable: true),
        },
        defaults: const {'is_custom': false},
        maxItems: 60,
      );

  @override
  Object parseValue(Object raw) =>
      jsonEncode(_ordered(ObjectListCodec.items(super.parseValue(raw))));
}

List<Map<String, Object?>> _ordered(List<Map<String, Object?>> items) => [
  ...[
    for (final item in items)
      if (item['is_custom'] != true) item,
  ]..sort((a, b) => '${a['key']}'.compareTo('${b['key']}')),
  for (final item in items)
    if (item['is_custom'] == true) item,
];

/// [item]'s attributes as the plan compares them: the app's own system keys
/// left out, since a save keeps them whatever it is sent.
List<Map<String, Object?>> attributeDocuments(EquipmentItem item) => _ordered([
  for (final a in [
    ...item.attributes,
  ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)))
    if (a.isCustom || !EquipmentAttributeCatalog.isSystemKey(a.key))
      {
        'key': a.key,
        'is_custom': a.isCustom,
        'value_text': a.valueText,
        'value_num': a.valueNum,
      },
]);

/// Why [parsed] attributes cannot go on an item of [type], or null.
String? attributeProblem(Object parsed, EquipmentType type) {
  final ofType = EquipmentAttributeCatalog.attributesFor(type);
  final seen = <String>{};
  for (final item in ObjectListCodec.items(parsed)) {
    final key = item['key']! as String;
    final custom = item['is_custom'] == true;
    if (!seen.add('$custom:${key.toLowerCase()}')) {
      return 'attributes: $key is listed more than once.';
    }
    final text = item['value_text'] as String?;
    if ((text == null || text.trim().isEmpty) && item['value_num'] == null) {
      return 'attributes: $key has no value; leave it out to clear it.';
    }
    if (custom) continue;
    final def = EquipmentAttributeCatalog.defFor(key);
    if (def != null && EquipmentAttributeCatalog.isSystemKey(key)) {
      return 'attributes: $key is the app\'s own and cannot be written.';
    }
    if (def == null || !ofType.any((d) => d.key == key)) {
      return 'attributes: $key is not an attribute of a ${type.name}; '
          'write it with is_custom true to keep it as your own.';
    }
    if (def.kind == AttributeKind.choice && !def.choiceKeys.contains(text)) {
      return 'attributes: $key takes one of ${def.choiceKeys.join(', ')}.';
    }
  }
  return null;
}

/// Why an item of [type] cannot be fitted to [parent], or null. The app
/// fits an O2 cell to a rebreather and a battery to a host, nothing else,
/// so a parent is never itself a part and no chain of parts can loop.
PlanBlock? parentProblem(
  EquipmentType type,
  EquipmentItem? parent,
  String? id,
) {
  final allowed = parentTypesFor(type);
  if (allowed.isEmpty) {
    return PlanBlock(
      BlockReason.invalidValue,
      'parent_equipment_id: a ${type.name} is not fitted to another item.',
    );
  }
  if (parent == null) return null;
  if (parent.id == id || !allowed.contains(parent.type)) {
    return PlanBlock(
      BlockReason.invalidValue,
      'parent_equipment_id: a ${type.name} fits only a '
      '${allowed.map((t) => t.name).join(' or ')}.',
    );
  }
  if (!parent.isActive) {
    return const PlanBlock(
      BlockReason.invalidValue,
      'parent_equipment_id: a part is fitted to an item in the kit.',
    );
  }
  return null;
}

/// [current] with [values] applied as the edit page saves an item: status
/// decides whether it is in the kit, taking it out of wanted fills an empty
/// purchase date as Mark purchased does, and a type change drops the
/// built-in attributes and the fitting the new type has no place for.
EquipmentItem nextItem(EquipmentItem current, Map<String, Object?> values) {
  T? kept<T>(String key, T? now) =>
      values.containsKey(key) ? values[key] as T? : now;
  final type = values['type'] == null
      ? current.type
      : EquipmentType.values.byName(values['type']! as String);
  final status = values['status'] == null
      ? current.status
      : EquipmentStatus.values.byName(values['status']! as String);
  final purchased =
      current.id.isNotEmpty &&
      current.status == EquipmentStatus.wanted &&
      status != EquipmentStatus.wanted &&
      current.purchaseDate == null &&
      !values.containsKey('purchase_date');
  final ofType = {
    for (final def in EquipmentAttributeCatalog.attributesFor(type)) def.key,
  };
  final attributes = [
    for (final a
        in values.containsKey('attributes')
            ? _attributes(current, values['attributes'])
            : current.attributes)
      if (a.isCustom ||
          ofType.contains(a.key) ||
          EquipmentAttributeCatalog.isSystemKey(a.key))
        a,
  ];
  final enabled = kept(
    'custom_reminder_enabled',
    current.customReminderEnabled,
  );
  return EquipmentItem(
    id: current.id,
    diverId: current.diverId,
    name: values['name'] as String? ?? current.name,
    type: type,
    brand: kept('brand', current.brand),
    model: kept('model', current.model),
    serialNumber: kept('serial_number', current.serialNumber),
    status: status,
    purchaseDate: purchased
        ? _day(DateTime.now())
        : values.containsKey('purchase_date')
        ? _date(values['purchase_date'] as String?)
        : current.purchaseDate,
    purchasePrice: kept('purchase_price', current.purchasePrice),
    purchaseCurrency:
        values['purchase_currency'] as String? ?? current.purchaseCurrency,
    lastServiceDate: current.lastServiceDate,
    serviceIntervalDays: current.serviceIntervalDays,
    notes: values['notes'] as String? ?? current.notes,
    isActive:
        status != EquipmentStatus.retired &&
        status != EquipmentStatus.sold &&
        status != EquipmentStatus.wanted,
    attributes: attributes,
    customReminderEnabled: enabled,
    customReminderDays: enabled == true
        ? (values['custom_reminder_days'] == null
              ? current.customReminderDays
              : [
                  for (final day
                      in const FieldCodec.integerList().wire(
                            values['custom_reminder_days'],
                          )!
                          as List)
                    day as int,
                ])
        : null,
    parentEquipmentId: parentTypesFor(type).isEmpty
        ? null
        : kept('parent_equipment_id', current.parentEquipmentId),
    createdAt: current.createdAt,
  );
}

/// The document values a save of [next] changes that [values] did not name.
Map<String, Object?> derivedFields(
  EquipmentItem current,
  EquipmentItem next,
  Map<String, Object?> values,
) => {
  if (next.isActive != current.isActive) 'is_active': next.isActive,
  if (!values.containsKey('purchase_date') &&
      next.purchaseDate != current.purchaseDate)
    'purchase_date': calendarDate(next.purchaseDate),
  if (!values.containsKey('attributes') &&
      next.attributes.length != current.attributes.length)
    'attributes': attributeDocuments(next),
  if (!values.containsKey('parent_equipment_id') &&
      next.parentEquipmentId != current.parentEquipmentId)
    'parent_equipment_id': next.parentEquipmentId,
};

/// Rows of other records a save of [next] over [current] rewrites: the
/// dive computer and transmitter rows whose name follows the item's, and
/// the service clocks an inspection date anchors.
Future<Map<String, int>> touchedBy(
  EquipmentItem current,
  EquipmentItem next,
) async {
  final id = current.id;
  final computers = next.name == current.name && next.notes == current.notes
      ? 0
      : await countRows(
          'dive_computers',
          'equipment_id = ?1 AND (name IS NOT ?2 OR notes IS NOT ?3)',
          id,
          [next.name, next.notes],
        );
  final keys = next.name == current.name
      ? 0
      : await countRows(
          'transmitters',
          'transmitter_equipment_id = ?1 AND label IS NOT ?2',
          id,
          [next.name],
        );
  final baselines = attributeServiceBaselines(
    current: next.attributes,
    previous: current.attributes,
  );
  final cleared = clearedServiceBaselines(
    current: next.attributes,
    previous: current.attributes,
  );
  var clocks = 0;
  if (baselines.isNotEmpty || cleared.isNotEmpty) {
    for (final s in await ServiceScheduleRepository().getSchedulesForEquipment(
      id,
    )) {
      final kind = s.serviceKindId;
      if (baselines.containsKey(kind) ||
          (cleared.containsKey(kind) && s.anchorDate == cleared[kind])) {
        clocks++;
      }
    }
  }
  return {
    if (computers > 0) 'dive_computers': computers,
    if (keys > 0) 'transmitters': keys,
    if (clocks > 0) 'service_schedules': clocks,
  };
}

/// The attributes [parsed] lists, a custom one keeping the id of the one
/// [current] holds under its key, in the order given.
List<EquipmentAttribute> _attributes(EquipmentItem current, Object? parsed) {
  final customIds = {
    for (final a in current.attributes)
      if (a.isCustom) a.key: a.id,
  };
  final items = ObjectListCodec.items(parsed);
  return [
    for (final (index, item) in items.indexed)
      if (item['is_custom'] == true)
        EquipmentAttribute(
          id: customIds[item['key']] ?? '',
          equipmentId: current.id,
          key: item['key']! as String,
          isCustom: true,
          valueText: item['value_text'] as String?,
          valueNum: (item['value_num'] as num?)?.toDouble(),
          sortOrder: index,
        )
      else
        EquipmentAttribute.curated(
          equipmentId: current.id,
          key: item['key']! as String,
          valueText: item['value_text'] as String?,
          valueNum: (item['value_num'] as num?)?.toDouble(),
        ),
  ];
}

DateTime? _date(String? day) => day == null ? null : _day(DateTime.parse(day));

DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);
