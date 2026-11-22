import 'package:collection/collection.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_colors.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_fitting.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_card_ids.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';

/// The gear item page's values a sitting edits, and the rules its form
/// keeps (issue #4527, phase 3, plan 6).

final String _header = GearItemCardId.header.name;
final String _details = GearItemCardId.details.name;
final String _serviceClocks = GearItemCardId.serviceClocks.name;
final String _photos = GearItemCardId.photos.name;
final String _notes = GearItemCardId.notes.name;

const Object _keep = Object();

T? _or<T>(Object? value, T? kept) =>
    identical(value, _keep) ? kept : value as T?;

/// [e] with the given values, every other one kept. [EquipmentItem.copyWith]
/// cannot clear most values, so the fields build the item whole, as the
/// old edit form's save did.
EquipmentItem _with(
  EquipmentItem e, {
  String? name,
  EquipmentType? type,
  Object? brand = _keep,
  Object? model = _keep,
  Object? serialNumber = _keep,
  EquipmentStatus? status,
  bool? isActive,
  Object? purchaseDate = _keep,
  Object? purchasePrice = _keep,
  String? purchaseCurrency,
  String? notes,
  List<EquipmentAttribute>? attributes,
  Object? customReminderEnabled = _keep,
  Object? customReminderDays = _keep,
  Object? parentEquipmentId = _keep,
  Object? coverMediaId = _keep,
}) => EquipmentItem(
  id: e.id,
  diverId: e.diverId,
  name: name ?? e.name,
  type: type ?? e.type,
  brand: _or<String>(brand, e.brand),
  model: _or<String>(model, e.model),
  serialNumber: _or<String>(serialNumber, e.serialNumber),
  status: status ?? e.status,
  purchaseDate: _or<DateTime>(purchaseDate, e.purchaseDate),
  purchasePrice: _or<double>(purchasePrice, e.purchasePrice),
  purchaseCurrency: purchaseCurrency ?? e.purchaseCurrency,
  lastServiceDate: e.lastServiceDate,
  serviceIntervalDays: e.serviceIntervalDays,
  notes: notes ?? e.notes,
  isActive: isActive ?? e.isActive,
  attributes: attributes ?? e.attributes,
  customReminderEnabled: _or<bool>(
    customReminderEnabled,
    e.customReminderEnabled,
  ),
  customReminderDays: _or<List<int>>(customReminderDays, e.customReminderDays),
  parentEquipmentId: _or<String>(parentEquipmentId, e.parentEquipmentId),
  coverMediaId: _or<String>(coverMediaId, e.coverMediaId),
  createdAt: e.createdAt,
);

/// A blank optional value is stored as none, as the form stored it.
String? _orNone(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

bool _sameText(String? a, String? b) => _orNone(a) == _orNone(b);

EditField<EquipmentItem, String?> _optionalText(
  String id,
  String? Function(EquipmentItem e) read,
  EquipmentItem Function(EquipmentItem e, String? v) write,
) => EditField<EquipmentItem, String?>(
  id: id,
  cardId: _details,
  read: read,
  write: (e, v) => write(e, _orNone(v)),
  equals: _sameText,
);

/// The item's name, required, shown in the bar and edited on the header.
final gearNameField = EditField<EquipmentItem, String>(
  id: 'name',
  cardId: _header,
  read: (e) => e.name,
  write: (e, v) => _with(e, name: v.trim()),
  equals: (a, b) => a.trim() == b.trim(),
);

/// The item's type. Picking one also sets the parent, through
/// [gearParentAfterType], in the header's editor.
final gearTypeField = EditField<EquipmentItem, EquipmentType>(
  id: 'type',
  cardId: _header,
  read: (e) => e.type,
  write: (e, v) => _with(e, type: v),
);

/// The item's status. Setting it also sets whether the item is in the kit:
/// retired, sold and wanted gear is out of it (#636, #2025). Read as the
/// item page shows it ([gearShownStatus]), so an untouched legacy row is not
/// written.
final gearStatusField = EditField<EquipmentItem, EquipmentStatus>(
  id: 'status',
  cardId: _details,
  read: gearShownStatus,
  write: (e, v) => _with(e, status: v, isActive: gearIsActive(v)),
);

/// The item this one is installed in.
final gearParentField = EditField<EquipmentItem, String?>(
  id: 'parent',
  cardId: _details,
  read: (e) => e.parentEquipmentId,
  write: (e, v) => _with(e, parentEquipmentId: v),
);

final gearBrandField = _optionalText(
  'brand',
  (e) => e.brand,
  (e, v) => _with(e, brand: v),
);

final gearModelField = _optionalText(
  'model',
  (e) => e.model,
  (e, v) => _with(e, model: v),
);

final gearSerialField = _optionalText(
  'serial',
  (e) => e.serialNumber,
  (e, v) => _with(e, serialNumber: v),
);

final Map<String, EditField<EquipmentItem, EquipmentAttribute?>>
_attributeFields = {};

bool _sameAttributeValue(EquipmentAttribute? a, EquipmentAttribute? b) {
  final aHas = a != null && a.hasContent;
  final bHas = b != null && b.hasContent;
  if (!aHas || !bHas) return aHas == bHas;
  return a.valueText == b.valueText &&
      a.valueNum == b.valueNum &&
      a.valueUnit == b.valueUnit;
}

/// The catalogue attribute [key] of the item: one field per key, so a
/// sitting that sets one leaves every other as stored at Save. Null, or an
/// attribute with no content, removes it.
EditField<EquipmentItem, EquipmentAttribute?> gearAttributeField(String key) =>
    _attributeFields.putIfAbsent(
      key,
      () => EditField<EquipmentItem, EquipmentAttribute?>(
        id: 'attr:$key',
        cardId: _details,
        read: (e) =>
            e.attributes.firstWhereOrNull((a) => !a.isCustom && a.key == key),
        write: (e, v) => _with(
          e,
          attributes: [
            for (final a in e.attributes)
              if (a.isCustom || a.key != key) a,
            if (v != null && v.hasContent)
              v.copyWith(equipmentId: e.id, key: key, isCustom: false),
          ],
        ),
        equals: _sameAttributeValue,
      ),
    );

/// The item's custom fields in their order, a colour on a type without one
/// among them (#2520), as the form loaded them.
final gearCustomFieldsField =
    EditField<EquipmentItem, List<EquipmentAttribute>>(
      id: 'customFields',
      cardId: _details,
      read: (e) =>
          keepStrayColorAsCustom(
              e.type,
              e.attributes,
            ).where((a) => a.isCustom).toList()
            ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
      write: (e, v) => _with(
        e,
        attributes: [
          for (final a in keepStrayColorAsCustom(e.type, e.attributes))
            if (!a.isCustom) a,
          ...v,
        ],
      ),
      equals: const ListEquality<EquipmentAttribute>().equals,
    );

final gearPurchaseDateField = EditField<EquipmentItem, DateTime?>(
  id: 'purchaseDate',
  cardId: _details,
  read: (e) => e.purchaseDate,
  write: (e, v) => _with(e, purchaseDate: v),
);

/// The price paid (or expected, for wanted gear) and its currency: one
/// value, so the pair is one change.
typedef GearPrice = ({double? price, String currency});

final gearPriceField = EditField<EquipmentItem, GearPrice>(
  id: 'price',
  cardId: _details,
  read: (e) => (price: e.purchasePrice, currency: e.purchaseCurrency),
  write: (e, v) =>
      _with(e, purchasePrice: v.price, purchaseCurrency: v.currency.trim()),
  equals: (a, b) =>
      a.price == b.price && a.currency.trim() == b.currency.trim(),
);

/// Whether the item's service reminders follow the diver's settings (null),
/// its own days (true) or none (false), and those days.
typedef GearCustomReminder = ({bool? enabled, List<int>? days});

final gearCustomReminderField = EditField<EquipmentItem, GearCustomReminder>(
  id: 'customReminder',
  cardId: _serviceClocks,
  read: (e) => (enabled: e.customReminderEnabled, days: e.customReminderDays),
  // Days are kept only while the item has its own, as the form saved them.
  write: (e, v) => _with(
    e,
    customReminderEnabled: v.enabled,
    customReminderDays: v.enabled == true ? v.days : null,
  ),
  // The days are a set: the same days in another order are no change.
  equals: (a, b) =>
      a.enabled == b.enabled &&
      (a.enabled != true ||
          const SetEquality<int>().equals(a.days?.toSet(), b.days?.toSet())),
);

/// The photo that stands for the item, chosen on the Photos card.
final gearCoverField = EditField<EquipmentItem, String?>(
  id: 'cover',
  cardId: _photos,
  read: (e) => e.coverMediaId,
  write: (e, v) => _with(e, coverMediaId: v),
);

final gearNotesField = EditField<EquipmentItem, String>(
  id: 'notes',
  cardId: _notes,
  read: (e) => e.notes,
  write: (e, v) => _with(e, notes: v.trim()),
  equals: (a, b) => a.trim() == b.trim(),
);

/// Whether [name] can be saved: something other than spaces.
bool gearNameValid(String name) => name.trim().isNotEmpty;

/// Whether gear of [status] is in the kit. Retired, sold and wanted gear is
/// not, so it leaves the active pickers (#636, #2025).
bool gearIsActive(EquipmentStatus status) =>
    status != EquipmentStatus.retired &&
    status != EquipmentStatus.sold &&
    status != EquipmentStatus.wanted;

/// The status the item is shown with: a legacy row out of the kit with a
/// status that does not say so shows as Retired, so saving it does not
/// bring it back (#636). Sold and wanted keep their own.
EquipmentStatus gearShownStatus(EquipmentItem item) =>
    !item.isActive &&
        item.status != EquipmentStatus.sold &&
        item.status != EquipmentStatus.wanted
    ? EquipmentStatus.retired
    : item.status;

/// The parent to keep once the type is [type]: [parentId] only when it
/// names one of [candidates], the active items, whose type can hold [type].
/// While [candidates] are still loading (null) the id is kept, as the form
/// kept it: a quick change must not drop a link never checked. A type that
/// is fitted to nothing keeps none.
String? gearParentAfterType(
  EquipmentType type,
  String? parentId,
  List<EquipmentItem>? candidates,
) {
  if (parentId == null) return null;
  final allowed = parentTypesFor(type);
  if (allowed.isEmpty) return null;
  if (candidates == null) return parentId;
  return candidates.any((e) => e.id == parentId && allowed.contains(e.type))
      ? parentId
      : null;
}

/// The attributes an item of [type] is saved with: the type's
/// catalogue attributes with content, in catalogue order, then the custom
/// fields de-duplicated by their trimmed key (the first wins, since the
/// schema allows one per key) with their order re-packed.
List<EquipmentAttribute> gearAttributesToSave(
  EquipmentType type,
  List<EquipmentAttribute> catalogue,
  List<EquipmentAttribute> custom,
) {
  final byKey = {
    for (final a in catalogue)
      if (!a.isCustom) a.key: a,
  };
  final seen = <String>{};
  final kept = <EquipmentAttribute>[];
  for (final field in custom) {
    final key = field.key.trim();
    if (key.isEmpty || !field.hasValue || !seen.add(key)) continue;
    kept.add(field.copyWith(key: key, sortOrder: kept.length));
  }
  return [
    for (final def in EquipmentAttributeCatalog.attributesFor(type))
      if (byKey[def.key] case final attr? when attr.hasContent) attr,
    ...kept,
  ];
}

/// [merged], the sitting's item, as the form would have saved it, touching only
/// what the sitting changed: a new type keeps only its catalogue attributes
/// (a colour on a type without one kept as a custom field), and edited
/// custom fields are de-duplicated by key with their order re-packed
/// ([gearAttributesToSave]). An attribute the sitting never touched is
/// written as stored, a key this build's catalogue lacks included. [stored]
/// itself when the sitting changed nothing on the row.
EquipmentItem gearItemToSave(EquipmentItem stored, EquipmentItem merged) {
  if (merged == stored) return stored;
  List<EquipmentAttribute> customOf(EquipmentItem e) =>
      e.attributes.where((a) => a.isCustom).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  final typeChanged = merged.type != stored.type;
  final customChanged = !const ListEquality<EquipmentAttribute>().equals(
    customOf(merged),
    customOf(stored),
  );
  if (!typeChanged && !customChanged) return merged;
  final attributes = typeChanged
      ? keepStrayColorAsCustom(merged.type, merged.attributes)
      : merged.attributes;
  final curated = attributes.where((a) => !a.isCustom).toList();
  final custom = attributes.where((a) => a.isCustom).toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  if (typeChanged) {
    return _with(
      merged,
      attributes: gearAttributesToSave(merged.type, curated, custom),
    );
  }
  // Only the custom fields changed: the curated ones go as they are.
  return _with(
    merged,
    attributes: [
      ...curated,
      ...gearAttributesToSave(merged.type, const [], custom),
    ],
  );
}

/// [days] with [day] switched: added, or removed unless it is the last.
/// In ascending order, as the chips show them.
List<int> gearReminderDaysToggled(List<int> days, int day) {
  if (!days.contains(day)) return [...days, day]..sort();
  if (days.length == 1) return days;
  return [
    for (final d in days)
      if (d != day) d,
  ]..sort();
}

/// The currency typed, or [fallback] when it is blank, as the form saved it.
String gearCurrencyOrDefault(String typed, String fallback) {
  final code = typed.trim();
  return code.isEmpty ? fallback : code;
}
