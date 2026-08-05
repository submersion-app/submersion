import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_attribute_l10n.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_attribute_units.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Renders one input per catalog definition for [type]. Values are keyed by
/// attrKey in [values]; edits emit whole EquipmentAttribute objects through
/// [onChanged]; emptied inputs call [onCleared] (unset = no row).
class EquipmentAttributeFormSection extends StatelessWidget {
  final EquipmentType type;
  final Map<String, EquipmentAttribute> values;
  final UnitFormatter units;
  final void Function(EquipmentAttribute) onChanged;
  final void Function(String key) onCleared;

  const EquipmentAttributeFormSection({
    super.key,
    required this.type,
    required this.values,
    required this.units,
    required this.onChanged,
    required this.onCleared,
  });

  EquipmentAttribute _base(String key) =>
      values[key] ?? EquipmentAttribute.curated(equipmentId: '', key: key);

  @override
  Widget build(BuildContext context) {
    final defs = EquipmentAttributeCatalog.attributesFor(type);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final def in defs) ...[
          _buildField(context, def),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildField(BuildContext context, EquipmentAttributeDef def) {
    final label = attributeLabel(context.l10n, def.key);
    final fieldKey = ValueKey('attr-field-${def.key}');
    final current = values[def.key];

    switch (def.kind) {
      case AttributeKind.text:
        return TextFormField(
          key: fieldKey,
          initialValue: current?.valueText ?? '',
          decoration: InputDecoration(labelText: label),
          onChanged: (text) {
            final trimmed = text.trim();
            if (trimmed.isEmpty) {
              onCleared(def.key);
            } else {
              onChanged(_base(def.key).copyWith(valueText: trimmed));
            }
          },
        );

      case AttributeKind.thickness:
        return TextFormField(
          key: fieldKey,
          initialValue: current?.valueText ?? '',
          decoration: InputDecoration(
            labelText: label,
            hintText: context.l10n.equipment_edit_thicknessDesignationHint,
          ),
          validator: (text) => isValidThicknessDesignation(text ?? '')
              ? null
              : context.l10n.equipment_edit_invalidThickness,
          onChanged: (text) {
            final trimmed = text.trim();
            if (trimmed.isEmpty) {
              onCleared(def.key);
            } else {
              final parsed = parsePrimaryThickness(trimmed);
              onChanged(
                _base(def.key).copyWith(
                  valueText: trimmed,
                  valueNum: parsed,
                  clearValueNum: parsed == null,
                ),
              );
            }
          },
        );

      case AttributeKind.number:
        final symbol = attributeUnitSymbol(def.dimension, units);
        return TextFormField(
          key: fieldKey,
          initialValue: current?.valueNum == null
              ? ''
              : formatAttributeNumberForEditing(
                  def.dimension,
                  units,
                  current!.valueNum!,
                ),
          decoration: InputDecoration(
            labelText: symbol.isEmpty ? label : '$label ($symbol)',
          ),
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          onChanged: (text) {
            final trimmed = text.trim();
            if (trimmed.isEmpty) {
              onCleared(def.key);
              return;
            }
            // Tolerate a comma decimal separator (many locales' numeric
            // keyboards produce "7,5"), like the suit-thickness filter bounds.
            final parsed = double.tryParse(trimmed.replaceAll(',', '.'));
            if (parsed != null) {
              onChanged(
                _base(def.key).copyWith(
                  valueNum: attributeMetricFromDisplay(
                    def.dimension,
                    units,
                    parsed,
                  ),
                ),
              );
            }
            // Non-empty but unparseable (transient like "-", or invalid): keep
            // the last pending value rather than silently dropping the field.
          },
        );

      case AttributeKind.choice:
        return DropdownButtonFormField<String?>(
          key: fieldKey,
          initialValue: current?.valueText,
          decoration: InputDecoration(labelText: label),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('--')),
            for (final option in def.choiceKeys)
              DropdownMenuItem(
                value: option,
                child: Text(
                  attributeChoiceLabel(context.l10n, def.key, option),
                ),
              ),
          ],
          onChanged: (option) {
            if (option == null) {
              onCleared(def.key);
            } else {
              onChanged(_base(def.key).copyWith(valueText: option));
            }
          },
        );

      case AttributeKind.flag:
        return SwitchListTile(
          key: fieldKey,
          title: Text(label),
          contentPadding: EdgeInsets.zero,
          value: current?.valueNum == 1,
          onChanged: (on) =>
              onChanged(_base(def.key).copyWith(valueNum: on ? 1.0 : 0.0)),
        );

      case AttributeKind.date:
        final date = current?.valueNum == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(current!.valueNum!.toInt());
        return InkWell(
          key: fieldKey,
          onTap: () async {
            // Catalog date attributes (last visual inspection / hydro test)
            // record past events, so cap at today. Clamp initialDate too: a
            // stored future date would otherwise trip showDatePicker's
            // initialDate <= lastDate assertion.
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: (date == null || date.isAfter(now)) ? now : date,
              firstDate: DateTime(1970),
              lastDate: now,
            );
            if (picked != null) {
              onChanged(
                _base(
                  def.key,
                ).copyWith(valueNum: picked.millisecondsSinceEpoch.toDouble()),
              );
            }
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              suffixIcon: date == null
                  ? const Icon(Icons.calendar_today)
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => onCleared(def.key),
                    ),
            ),
            child: Text(date == null ? '--' : units.formatDate(date)),
          ),
        );
    }
  }
}
