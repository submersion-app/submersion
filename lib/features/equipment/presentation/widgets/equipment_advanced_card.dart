import 'package:flutter/material.dart';

import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_custom_fields_section.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The equipment edit page's Advanced card, holding the item's custom
/// fields.
class EquipmentAdvancedCard extends StatelessWidget {
  final List<EquipmentAttribute> fields;
  final void Function(List<EquipmentAttribute> fields) onChanged;

  const EquipmentAdvancedCard({
    super.key,
    required this.fields,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  context.l10n.equipment_edit_advanced_title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            EquipmentCustomFieldsSection(fields: fields, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}
