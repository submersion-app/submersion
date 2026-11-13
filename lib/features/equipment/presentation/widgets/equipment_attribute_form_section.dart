import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/constants/focal_length.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/figure/domain/figure_inputs.dart';
import 'package:submersion/features/equipment/figure/domain/figure_position.dart';
import 'package:submersion/features/equipment/figure/domain/figure_zone.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_attribute_l10n.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_attribute_units.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_color_field.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/app_date_picker.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';

/// Renders one input per catalog definition for [type] in [group]. Values are
/// keyed by attrKey in [values]; edits emit whole EquipmentAttribute objects
/// through [onChanged]; emptied inputs call [onCleared] (unset = no row).
///
/// The edit page mounts one instance per group, so the physical specs and the
/// purchase record land in their own blocks of the form.
class EquipmentAttributeFormSection extends StatelessWidget {
  final EquipmentType type;
  final Map<String, EquipmentAttribute> values;
  final UnitFormatter units;
  final void Function(EquipmentAttribute) onChanged;
  final void Function(String key) onCleared;

  /// Which catalog group to render. Defaults to the physical specification.
  final AttributeGroup group;

  const EquipmentAttributeFormSection({
    super.key,
    required this.type,
    required this.values,
    required this.units,
    required this.onChanged,
    required this.onCleared,
    this.group = AttributeGroup.spec,
  });

  EquipmentAttribute _base(String key) =>
      values[key] ?? EquipmentAttribute.curated(equipmentId: '', key: key);

  @override
  Widget build(BuildContext context) {
    final defs = EquipmentAttributeCatalog.attributesFor(
      type,
    ).where((d) => d.group == group).toList();
    // The spots this item can be moved to on the figure, from the values
    // being edited: a computer's mount, say, decides whether there is a
    // choice at all (issue #4493).
    final positions = group == AttributeGroup.appearance
        ? pickableFigureZones(type, figureAttributesFrom(values.values))
        : const <FigureZone>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final def in defs)
          if (def.key != EquipmentAttrKeys.figurePosition) ...[
            _buildField(context, def),
            const SizedBox(height: 16),
          ] else if (positions.isNotEmpty) ...[
            _buildFigurePositionField(context, def, positions),
            const SizedBox(height: 16),
          ],
      ],
    );
  }

  /// Where the item is drawn on the diver figure: Automatic, or one of the
  /// spots that draw it differently. A stored spot this item no longer has
  /// artwork for (its mount changed) reads as Automatic, which is what the
  /// figure does with it.
  Widget _buildFigurePositionField(
    BuildContext context,
    EquipmentAttributeDef def,
    List<FigureZone> zones,
  ) {
    final l10n = context.l10n;
    final options = [for (final zone in zones) figurePositionKeys[zone]!];
    final stored = values[def.key]?.valueText;
    return DropdownButtonFormField<String?>(
      // Keyed by the options as well: a dropdown whose value stops being
      // offered throws, and a change of mount or style changes them.
      key: ValueKey('attr-field-${def.key}:${options.join(',')}'),
      initialValue: options.contains(stored) ? stored : null,
      decoration: InputDecoration(labelText: attributeLabel(l10n, def.key)),
      items: [
        DropdownMenuItem<String?>(
          value: null,
          child: Text(l10n.attr_figurePosition_automatic),
        ),
        for (final option in options)
          DropdownMenuItem(
            value: option,
            child: Text(attributeChoiceLabel(l10n, def.key, option)),
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
          // Helper rather than hint text: a hint only shows once the field
          // is focused, so it would not explain the label up front. It may
          // wrap, or a phone would cut off the part that matters.
          decoration: InputDecoration(
            labelText: label,
            helperText: attributeHelperText(context.l10n, def.key),
            helperMaxLines: 3,
          ),
          onChanged: (text) {
            final trimmed = text.trim();
            if (trimmed.isEmpty) {
              onCleared(def.key);
            } else {
              onChanged(_base(def.key).copyWith(valueText: trimmed));
            }
          },
        );

      case AttributeKind.url:
        return TextFormField(
          key: fieldKey,
          initialValue: current?.valueText ?? '',
          decoration: InputDecoration(
            labelText: label,
            hintText: context.l10n.equipment_edit_webLinkHint,
          ),
          keyboardType: TextInputType.url,
          autocorrect: false,
          // Stored as typed; the scheme is only assumed at launch time so a
          // diver who pasted a full URL sees exactly what they pasted.
          validator: (text) =>
              (text == null ||
                  text.trim().isEmpty ||
                  parseWebLink(text) != null)
              ? null
              : context.l10n.equipment_edit_invalidWebLink,
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

      // A prime's figure or a zoom's range (issue #3050). Seeded from the
      // number alone for a lens saved before ranges existed.
      case AttributeKind.focalLength:
        return TextFormField(
          key: fieldKey,
          initialValue: focalLengthEditText(
            valueText: current?.valueText,
            valueNum: current?.valueNum,
          ),
          decoration: InputDecoration(
            labelText: label,
            hintText: context.l10n.equipment_edit_focalLengthHint,
          ),
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: (text) => isValidFocalLength(text ?? '')
              ? null
              : context.l10n.equipment_edit_invalidFocalLength,
          onChanged: (text) {
            final trimmed = text.trim();
            if (trimmed.isEmpty) {
              onCleared(def.key);
            } else {
              final wideEnd = parseFocalLengthWideEnd(trimmed);
              onChanged(
                _base(def.key).copyWith(
                  valueText: trimmed,
                  valueNum: wideEnd,
                  clearValueNum: wideEnd == null,
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
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: numberValidator(context),
          onChanged: (text) {
            final trimmed = text.trim();
            if (trimmed.isEmpty) {
              onCleared(def.key);
              return;
            }
            // Read in the diver's locale, matching how the field is seeded by
            // formatAttributeNumberForEditing. A blanket replaceAll(',', '.')
            // would misread the en_US thousands separator, turning "1,250"
            // into 1.25.
            final parsed = switch (readNumber(trimmed)) {
              NumberValue(:final value) => value,
              NumberBlank() || NumberInvalid() => null,
            };
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
            // Non-empty but unreadable (transient like "-", or invalid): keep
            // the last pending value rather than dropping the field; the
            // validator shows why (#1900).
          },
        );

      case AttributeKind.choice:
        return DropdownButtonFormField<String?>(
          key: fieldKey,
          initialValue: current?.valueText,
          decoration: InputDecoration(labelText: label),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text(context.l10n.common_placeholder_noValue),
            ),
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

      case AttributeKind.color:
        return EquipmentColorField(
          key: fieldKey,
          label: label,
          hex: current?.valueText,
          onChanged: (hex) =>
              onChanged(_base(def.key).copyWith(valueText: hex)),
          onCleared: () => onCleared(def.key),
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
            final picked = await showAppDatePicker(
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
