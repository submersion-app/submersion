import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/currency.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_fitting.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_edit_fields.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_owned_for.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_attribute_form_section.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_custom_fields_section.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_dive_time_row.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_sharing_row.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_status_indicator.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/app_date_picker.dart';
import 'package:submersion/shared/widgets/detail_row/detail_row.dart';
import 'package:submersion/shared/widgets/detail_row/detail_row_group.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/field_text_binding.dart';

/// Notes the price field leaves for the card's check: unreadable text in
/// it, which a Save must not take as no price.
const String _priceUnreadableKey = 'equipment.priceUnreadable';

/// Whether the Details card can be saved: its price is readable.
bool gearDetailsValid(EditSession<EquipmentItem> session) =>
    session.recall<bool>(_priceUnreadableKey) != true;

/// The Details card's editor: status, what the item is fitted to, brand,
/// model, serial, its specification and appearance, its purchase, its
/// custom fields and who it is shared with. The counts and the time owned
/// are calculated, shown read only.
class GearItemDetailsEditor extends ConsumerStatefulWidget {
  const GearItemDetailsEditor({super.key, required this.session});

  final EditSession<EquipmentItem> session;

  @override
  ConsumerState<GearItemDetailsEditor> createState() =>
      _GearItemDetailsEditorState();
}

class _GearItemDetailsEditorState extends ConsumerState<GearItemDetailsEditor> {
  EditSession<EquipmentItem> get _session => widget.session;

  late final _brand = _bind(gearBrandField);
  late final _model = _bind(gearModelField);
  late final _serial = _bind(gearSerialField);
  late final TextEditingController _price;
  late final TextEditingController _currency;

  /// The currency the item had when the editor opened, kept at the top of
  /// the list when it is not a preset.
  late final String _initialCurrency;

  FieldTextBinding<EquipmentItem, String?> _bind(
    EditField<EquipmentItem, String?> field,
  ) => FieldTextBinding<EquipmentItem, String?>.plain(
    session: _session,
    field: field,
    format: (v) => v ?? '',
  );

  @override
  void initState() {
    super.initState();
    final price = _session.valueOf(gearPriceField);
    _initialCurrency = price.currency;
    // The field opens on the last readable price, so nothing unreadable is
    // left in it: a flag left by an earlier opening would block the Save
    // with no error to see.
    _session.remember(_priceUnreadableKey, null);
    // Seeded in the diver's decimal convention, read back the same way, so
    // an untouched price is not misread (#1091).
    _price = TextEditingController(
      text: price.price == null ? '' : formatDecimalForInput(price.price!),
    )..addListener(_priceTyped);
    _currency = TextEditingController(text: price.currency)
      ..addListener(_currencyTyped);
  }

  @override
  void dispose() {
    _brand.dispose();
    _model.dispose();
    _serial.dispose();
    _price.dispose();
    _currency.dispose();
    super.dispose();
  }

  /// The diver's default currency, for a currency left blank.
  String get _fallbackCurrency =>
      normalizeCurrencyCode(ref.read(defaultCurrencyProvider), fallback: 'USD');

  /// A readable price is the item's; blank is none; unreadable text keeps
  /// the last readable one and blocks the Save until it is fixed.
  void _priceTyped() {
    final now = _session.valueOf(gearPriceField);
    switch (readNumber(_price.text)) {
      case NumberValue(:final value):
        _session
          ..remember(_priceUnreadableKey, null)
          ..set(gearPriceField, (price: value, currency: now.currency));
      case NumberBlank():
        _session
          ..remember(_priceUnreadableKey, null)
          ..set(gearPriceField, (price: null, currency: now.currency));
      case NumberInvalid():
        _session.remember(_priceUnreadableKey, true);
    }
    setState(() {});
  }

  void _currencyTyped() {
    final now = _session.valueOf(gearPriceField);
    _session.set(gearPriceField, (
      price: now.price,
      currency: gearCurrencyOrDefault(_currency.text, _fallbackCurrency),
    ));
  }

  Future<void> _pickPurchaseDate() async {
    final date = await showAppDatePicker(
      context: context,
      initialDate: _session.valueOf(gearPurchaseDateField) ?? DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (date != null) _session.set(gearPurchaseDateField, date);
  }

  /// The catalogue attributes the sitting holds, by key, for the item's
  /// type.
  Map<String, EquipmentAttribute> _attributes(EquipmentType type) => {
    for (final def in EquipmentAttributeCatalog.attributesFor(type))
      def.key: ?_session.valueOf(gearAttributeField(def.key)),
  };

  void _attributeChanged(EquipmentAttribute attr) =>
      _session.set(gearAttributeField(attr.key), attr);

  void _attributeCleared(String key) =>
      _session.set(gearAttributeField(key), null);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);
    return ListenableBuilder(
      listenable: _session,
      builder: (context, _) {
        final working = _session.working;
        final type = working.type;
        final wanted = working.isWanted;
        final attributes = _attributes(type);
        final purchaseDate = _session.valueOf(gearPurchaseDateField);
        Widget attributeSection(AttributeGroup group) =>
            EquipmentAttributeFormSection(
              key: ValueKey('gear-attrs-${group.name}-${type.name}'),
              type: type,
              group: group,
              values: attributes,
              units: units,
              onChanged: _attributeChanged,
              onCleared: _attributeCleared,
            );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CalculatedRows(item: working, counted: !_session.isNew),
            const SizedBox(height: 8),
            DropdownButtonFormField<EquipmentStatus>(
              key: const ValueKey('gear-edit-status'),
              initialValue: _session.valueOf(gearStatusField),
              decoration: InputDecoration(
                labelText: l10n.equipment_edit_statusLabel,
                prefixIcon: const Icon(Icons.flag),
              ),
              items: [
                for (final status in EquipmentStatus.values)
                  DropdownMenuItem(
                    value: status,
                    child: Text(status.localizedName(l10n)),
                  ),
              ],
              onChanged: (value) {
                if (value != null) _session.set(gearStatusField, value);
              },
            ),
            const SizedBox(height: 16),
            // What the item is fitted to, for the child types only (v202).
            // Wishlist gear (#2025) cannot be fitted into anything yet.
            if (!wanted && parentTypesFor(type).isNotEmpty) ...[
              _ParentPicker(session: _session, type: type),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('gear-edit-brand'),
                    controller: _brand.controller,
                    decoration: InputDecoration(
                      labelText: l10n.equipment_edit_brandLabel,
                      prefixIcon: const Icon(Icons.business),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    key: const ValueKey('gear-edit-model'),
                    controller: _model.controller,
                    decoration: InputDecoration(
                      labelText: l10n.equipment_edit_modelLabel,
                      prefixIcon: const Icon(Icons.info_outline),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            attributeSection(AttributeGroup.spec),
            // The item's colour and its place on the figure (#2326, #4493).
            attributeSection(AttributeGroup.appearance),
            // A serial once the gear is in hand (#2025).
            if (!wanted)
              TextField(
                key: const ValueKey('gear-edit-serial'),
                controller: _serial.controller,
                decoration: InputDecoration(
                  labelText: l10n.equipment_edit_serialNumberLabel,
                  prefixIcon: const Icon(Icons.numbers),
                ),
              ),
            const SizedBox(height: 24),
            Text(
              l10n.equipment_edit_purchaseInfoTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            // A purchase date waits for the purchase (#2025); a date set
            // stays and comes back when the status changes.
            if (!wanted) ...[
              OutlinedButton.icon(
                key: const ValueKey('gear-edit-purchase-date'),
                onPressed: _pickPurchaseDate,
                icon: const Icon(Icons.calendar_today),
                label: Text(
                  purchaseDate != null
                      ? units.formatDate(purchaseDate)
                      : l10n.equipment_edit_selectDate,
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
              if (purchaseDate != null)
                TextButton(
                  onPressed: () => _session.set(gearPurchaseDateField, null),
                  child: Text(l10n.equipment_edit_clearDate),
                ),
              const SizedBox(height: 16),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _currency,
                    builder: (context, value, _) {
                      final symbol = currencySymbol(value.text);
                      return TextField(
                        key: const ValueKey('equipment-purchase-price'),
                        controller: _price,
                        decoration: InputDecoration(
                          labelText: wanted
                              ? l10n.equipment_edit_expectedPriceLabel
                              : l10n.equipment_edit_purchasePriceLabel,
                          prefixText: symbol.isEmpty ? null : '$symbol ',
                          errorText: invalidNumberText(context, _price.text),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  // Common currencies as presets; any ISO code can still be
                  // typed.
                  child: DropdownMenu<String>(
                    controller: _currency,
                    expandedInsets: EdgeInsets.zero,
                    requestFocusOnTap: true,
                    enableFilter: true,
                    label: Text(l10n.equipment_edit_currencyLabel),
                    dropdownMenuEntries: [
                      for (final code in currencyCodesWith(_initialCurrency))
                        DropdownMenuEntry(
                          value: code,
                          label: code,
                          leadingIcon: SizedBox(
                            width: 28,
                            child: Center(child: Text(currencySymbol(code))),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // The receipt trail (#1517), kept with the date and price.
            attributeSection(AttributeGroup.purchase),
            const SizedBox(height: 16),
            EquipmentCustomFieldsSection(
              fields: _session.valueOf(gearCustomFieldsField),
              onChanged: (fields) =>
                  _session.set(gearCustomFieldsField, fields),
            ),
            EquipmentSharingRow(equipment: working, editing: _session),
          ],
        );
      },
    );
  }
}

/// The item it is fitted to, among the active items whose type can hold
/// one of [type]. The stored parent stays while they load.
class _ParentPicker extends ConsumerWidget {
  const _ParentPicker({required this.session, required this.type});

  final EditSession<EquipmentItem> session;
  final EquipmentType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final parentId = session.valueOf(gearParentField);
    final candidates = [
      for (final e
          in ref.watch(activeEquipmentProvider).valueOrNull ??
              const <EquipmentItem>[])
        if (e.id != session.stored.id && parentTypesFor(type).contains(e.type))
          e,
    ];
    final known = candidates.any((e) => e.id == parentId);
    return DropdownButtonFormField<String?>(
      key: const Key('equipment-parent-picker'),
      initialValue: known ? parentId : null,
      decoration: InputDecoration(
        labelText: l10n.equipment_edit_parentLabel,
        prefixIcon: const Icon(Icons.account_tree_outlined),
      ),
      items: [
        DropdownMenuItem<String?>(
          value: null,
          child: Text(l10n.equipment_edit_parentNone),
        ),
        for (final e in candidates)
          DropdownMenuItem<String?>(
            value: e.id,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ServiceStatusIndicatorFor(
                  equipmentId: e.id,
                  density: ServiceIndicatorDensity.dot,
                ),
                const SizedBox(width: 6),
                Flexible(child: Text(e.name, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
      ],
      onChanged: (value) => session.set(gearParentField, value),
    );
  }
}

/// The card's calculated rows, read only: the dives, time and trips the
/// item has been on, unless it is not [counted] (a new item, which nothing
/// is stored under yet), and how long it has been owned.
class _CalculatedRows extends ConsumerWidget {
  const _CalculatedRows({required this.item, required this.counted});

  final EquipmentItem item;
  final bool counted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final dives = counted
        ? ref.watch(equipmentDiveCountProvider(item.id)).value
        : null;
    final trips = counted
        ? ref.watch(equipmentTripCountProvider(item.id)).value
        : null;
    final owned = item.ownershipDuration;
    return DetailRowGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (dives != null)
            DetailRow.text(
              label: l10n.equipment_detail_divesLabel,
              value: dives == 1
                  ? l10n.equipment_detail_divesCountSingular(dives)
                  : l10n.equipment_detail_divesCountPlural(dives),
            ),
          if (counted) EquipmentDiveTimeRow(equipmentId: item.id),
          if (trips != null)
            DetailRow.text(
              label: l10n.equipment_detail_tripsLabel,
              value: trips == 1
                  ? l10n.equipment_detail_tripsCountSingular(trips)
                  : l10n.equipment_detail_tripsCountPlural(trips),
            ),
          if (owned != null)
            DetailRow.text(
              label: l10n.equipment_detail_ownedForLabel,
              value: equipmentOwnedForText(l10n, owned),
            ),
        ],
      ),
    );
  }
}
