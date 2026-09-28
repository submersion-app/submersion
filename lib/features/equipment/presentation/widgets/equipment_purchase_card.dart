import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/currency.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_attribute_form_section.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';

/// The equipment edit page's Purchase Information card: the purchase date,
/// price and currency, then the purchase-record attributes. The page owns
/// every value; this card only draws them and reports edits.
class EquipmentPurchaseCard extends StatelessWidget {
  final DateTime? purchaseDate;
  final VoidCallback onPickDate;
  final VoidCallback onClearDate;
  final TextEditingController priceController;
  final TextEditingController currencyController;

  /// The code the form opened with, offered in the currency list even when
  /// it is outside the presets.
  final String initialCurrencyCode;

  final EquipmentType type;
  final Map<String, EquipmentAttribute> attrValues;
  final UnitFormatter units;
  final void Function(EquipmentAttribute attr) onAttrChanged;
  final void Function(String key) onAttrCleared;

  const EquipmentPurchaseCard({
    super.key,
    required this.purchaseDate,
    required this.onPickDate,
    required this.onClearDate,
    required this.priceController,
    required this.currencyController,
    required this.initialCurrencyCode,
    required this.type,
    required this.attrValues,
    required this.units,
    required this.onAttrChanged,
    required this.onAttrCleared,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.equipment_edit_purchaseInfoTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.equipment_edit_purchaseDateLabel,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onPickDate,
              icon: const Icon(Icons.calendar_today),
              label: Text(
                // #1512: hand-rolled M/D/YYYY ignored the diver's preference,
                // which the detail page for the same field already honours.
                purchaseDate != null
                    ? units.formatDate(purchaseDate)
                    : context.l10n.equipment_edit_selectDate,
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
            if (purchaseDate != null)
              TextButton(
                onPressed: onClearDate,
                child: Text(context.l10n.equipment_edit_clearDate),
              ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  // Rebuild the price field when the currency changes so its
                  // prefix shows the right symbol (€, $, £ ...).
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: currencyController,
                    builder: (context, value, _) {
                      final symbol = currencySymbol(value.text);
                      return TextFormField(
                        key: const ValueKey('equipment-purchase-price'),
                        controller: priceController,
                        decoration: InputDecoration(
                          labelText:
                              context.l10n.equipment_edit_purchasePriceLabel,
                          prefixText: symbol.isEmpty ? null : '$symbol ',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        // A price that cannot be read has to be reported. The
                        // repository writes Value(null) rather than
                        // Value.absent(), so accepting the save would erase
                        // the stored price instead of leaving it alone.
                        validator: numberValidator(context),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  // Editable dropdown: common currencies as presets, but any
                  // ISO code can still be typed.
                  child: DropdownMenu<String>(
                    controller: currencyController,
                    expandedInsets: EdgeInsets.zero,
                    requestFocusOnTap: true,
                    enableFilter: true,
                    label: Text(context.l10n.equipment_edit_currencyLabel),
                    dropdownMenuEntries: [
                      // The stored code leads the list when it is outside the
                      // presets, so an item priced in, say, ISK stays visible
                      // and re-selectable.
                      for (final code in currencyCodesWith(initialCurrencyCode))
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
            // Purchase record (issue #1517): SKU, retailer and the product
            // listing, kept with the date and price because they are all
            // parts of the same receipt an insurer asks for.
            EquipmentAttributeFormSection(
              key: ValueKey('purchase-attrs-${type.name}'),
              type: type,
              group: AttributeGroup.purchase,
              values: attrValues,
              units: units,
              onChanged: onAttrChanged,
              onCleared: onAttrCleared,
            ),
          ],
        ),
      ),
    );
  }
}
