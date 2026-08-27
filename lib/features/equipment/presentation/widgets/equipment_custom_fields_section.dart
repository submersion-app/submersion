import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Editable list of user-defined attributes (label + value + delete),
/// mirroring the dive custom-fields editor.
class EquipmentCustomFieldsSection extends StatelessWidget {
  final List<EquipmentAttribute> fields;
  final void Function(List<EquipmentAttribute>) onChanged;

  const EquipmentCustomFieldsSection({
    super.key,
    required this.fields,
    required this.onChanged,
  });

  /// Stable widget-key seed for a row: prefer the field's own id so the
  /// TextFormFields keep their FormFieldState when other rows are deleted
  /// (index-based keys would shift and reuse the wrong state). Falls back to
  /// the index only for the (unexpected) case of an id-less field.
  String _rowKey(int index) {
    final id = fields[index].id;
    return id.isNotEmpty ? id : 'idx-$index';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.equipment_edit_customFieldsTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < fields.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: TextFormField(
                    key: ValueKey('custom-key-${_rowKey(i)}'),
                    initialValue: fields[i].key,
                    decoration: InputDecoration(
                      labelText: context.l10n.diveLog_edit_customFieldKey,
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (text) =>
                        _update(i, fields[i].copyWith(key: text)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 6,
                  child: TextFormField(
                    key: ValueKey('custom-value-${_rowKey(i)}'),
                    initialValue: fields[i].valueText ?? '',
                    decoration: InputDecoration(
                      labelText: context.l10n.diveLog_edit_customFieldValue,
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (text) =>
                        _update(i, fields[i].copyWith(valueText: text)),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  iconSize: 20,
                  tooltip: context.l10n.common_action_delete,
                  onPressed: () => onChanged([
                    for (var j = 0; j < fields.length; j++)
                      if (j != i) fields[j],
                  ]),
                ),
              ],
            ),
          ),
        TextButton.icon(
          onPressed: () => onChanged([
            ...fields,
            EquipmentAttribute(
              // Assign a stable client-side id up front so the row keeps its
              // widget identity across edits/removals; saveAttributes keeps
              // the id for custom rows.
              id: const Uuid().v4(),
              equipmentId: '',
              key: '',
              isCustom: true,
              sortOrder: fields.length,
            ),
          ]),
          icon: const Icon(Icons.add),
          label: Text(context.l10n.equipment_edit_addCustomField),
        ),
      ],
    );
  }

  void _update(int index, EquipmentAttribute updated) => onChanged([
    for (var j = 0; j < fields.length; j++) j == index ? updated : fields[j],
  ]);
}
