import 'dart:convert';

import 'package:submersion/core/constants/enums.dart'
    show EquipmentStatus, EquipmentType;
import 'package:submersion/features/agent_access/data/documents/document_dates.dart';
import 'package:submersion/features/agent_access/data/writes/families/service_ledger_rules.dart';
import 'package:submersion/features/agent_access/data/writes/families/write_reach.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/object_list_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_colors.dart';
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
    ...keepStrayColorAsCustom(item.type, item.attributes),
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

/// The day chips the edit page offers for custom reminders, all of them
/// picked when the switch first goes on.
const reminderDayChoices = [7, 14, 30];

/// A block for reminders the edit page's switch cannot set: off (false) is
/// not one of its states, and days mean nothing while custom reminders are
/// not on.
PlanBlock? reminderProblem(WriteCheck check) {
  final v = check.values;
  if (v.containsKey('custom_reminder_enabled') &&
      v['custom_reminder_enabled'] == false) {
    return const PlanBlock(
      BlockReason.invalidValue,
      'custom_reminder_enabled: true uses custom days, null the app\'s '
      'default reminders; the app has no setting that turns an item\'s '
      'reminders off.',
    );
  }
  if (!v.containsKey('custom_reminder_days')) return null;
  final enabled = v.containsKey('custom_reminder_enabled')
      ? v['custom_reminder_enabled']
      : check.document?['custom_reminder_enabled'];
  if (enabled != true) {
    return const PlanBlock(
      BlockReason.invalidValue,
      'custom_reminder_days: set custom_reminder_enabled true to use them.',
    );
  }
  final days = [
    for (final day
        in const FieldCodec.integerList().wire(v['custom_reminder_days'])!
            as List)
      day as int,
  ];
  if (days.isEmpty ||
      days.toSet().length != days.length ||
      days.any((day) => !reminderDayChoices.contains(day))) {
    return PlanBlock(
      BlockReason.invalidValue,
      'custom_reminder_days: one or more of '
      '${reminderDayChoices.join(', ')}, each once.',
    );
  }
  return null;
}

/// Why an item of [type] cannot be fitted to [parent], or null. The app
/// fits an O2 cell to a rebreather and a battery to a host, nothing else,
/// so a parent is never itself a part and no chain of parts can loop.
PlanBlock? parentProblem(
  EquipmentType type,
  EquipmentItem? parent,
  String? id, {
  bool wanted = false,
}) {
  if (wanted) {
    return const PlanBlock(
      BlockReason.invalidValue,
      'parent_equipment_id: an item not bought yet is fitted to nothing.',
    );
  }
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
///
/// [parent] is the item the result is fitted to, read by the caller; a part
/// keeps it only while its type can hold the part and it is in the kit, as
/// the edit page's save keeps it.
EquipmentItem nextItem(
  EquipmentItem current,
  Map<String, Object?> values, {
  EquipmentItem? parent,
}) {
  T? kept<T>(String key, T? now) =>
      values.containsKey(key) ? values[key] as T? : now;
  final type = values['type'] == null
      ? current.type
      : EquipmentType.values.byName(values['type']! as String);
  final status = values['status'] == null
      ? seededStatus(current)
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
            : keepStrayColorAsCustom(type, current.attributes))
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
        ? today()
        : values.containsKey('purchase_date')
        ? calendarDay(values['purchase_date'])
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
              ? current.customReminderDays ?? reminderDayChoices
              : [
                  for (final day
                      in const FieldCodec.integerList().wire(
                            values['custom_reminder_days'],
                          )!
                          as List)
                    day as int,
                ])
        : null,
    parentEquipmentId:
        parent != null &&
            parent.id ==
                kept('parent_equipment_id', current.parentEquipmentId) &&
            parent.isActive &&
            parentTypesFor(type).contains(parent.type)
        ? parent.id
        : null,
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
  if (!values.containsKey('status') && next.status != current.status)
    'status': next.status.name,
  if (!values.containsKey('purchase_date') &&
      next.purchaseDate != current.purchaseDate)
    'purchase_date': calendarDate(next.purchaseDate),
  if (!values.containsKey('attributes') &&
      jsonEncode(attributeDocuments(next)) !=
          jsonEncode(attributeDocuments(current)))
    'attributes': attributeDocuments(next),
  if (!values.containsKey('custom_reminder_days') &&
      !_sameDays(next.customReminderDays, current.customReminderDays))
    'custom_reminder_days': next.customReminderDays,
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
  // Every save mirrors the name, so a device already named apart from its
  // item is rewritten even when the name stays.
  final computers = await countRows(
    'dive_computers',
    'equipment_id = ?1 AND (name IS NOT ?2 OR notes IS NOT ?3)',
    id,
    [next.name, next.notes],
  );
  final keys = await countRows(
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
  final customs = [
    for (final item in items)
      if (item['is_custom'] == true) item,
  ];
  return [
    for (final item in items)
      if (item['is_custom'] == true)
        EquipmentAttribute(
          id: customIds[item['key']] ?? '',
          equipmentId: current.id,
          key: item['key']! as String,
          isCustom: true,
          valueText: item['value_text'] as String?,
          valueNum: (item['value_num'] as num?)?.toDouble(),
          sortOrder: customs.indexOf(item),
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

bool _sameDays(List<int>? a, List<int>? b) =>
    a == null || b == null ? a == b : a.join(',') == b.join(',');

/// Whether item [id] is in the kit once the changes earlier in the set
/// apply: a status an earlier update writes decides, else [stored].
bool inKitSoFar(SetSoFar soFar, String id, {required bool stored}) =>
    switch (soFar.values[('equipment', id)]?['status']) {
      final String status => !const {
        'retired',
        'sold',
        'wanted',
      }.contains(status),
      _ => stored,
    };

/// [item]'s status as the edit page shows it: a legacy row out of the kit
/// with an in-kit status reads as retired, so a save does not quietly put it
/// back (#636).
EquipmentStatus seededStatus(EquipmentItem item) =>
    !item.isActive &&
        item.status != EquipmentStatus.sold &&
        item.status != EquipmentStatus.wanted
    ? EquipmentStatus.retired
    : item.status;
