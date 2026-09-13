import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/models/equipment_attr_condition.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_attribute_l10n.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Multi-select chips for every choice field of [type] (issue #1805), shared
/// by the equipment filter panel and the dive filter sheet.
///
/// Each field with at least one chip selected is one condition in
/// [conditions] (its key, the selected options, `types: {type}`), in catalog
/// order; deselecting a field's last chip removes its condition. Fields come
/// from the catalog, so a new choice field appears here with no change to
/// this widget. A type with no choice fields renders nothing.
class EquipmentChoiceAttributeFilter extends StatelessWidget {
  final EquipmentType type;
  final List<EquipmentAttrCondition> conditions;
  final ValueChanged<List<EquipmentAttrCondition>> onChanged;

  const EquipmentChoiceAttributeFilter({
    super.key,
    required this.type,
    required this.conditions,
    required this.onChanged,
  });

  /// The fields offered for [type]: its choice attributes in the spec group.
  static List<EquipmentAttributeDef> choiceDefsFor(EquipmentType type) => [
    for (final def in EquipmentAttributeCatalog.attributesFor(type))
      if (def.kind == AttributeKind.choice && def.group == AttributeGroup.spec)
        def,
  ];

  @override
  Widget build(BuildContext context) {
    final defs = choiceDefsFor(type);
    if (defs.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final def in defs) ...[
          const SizedBox(height: 12),
          Text(
            attributeLabel(l10n, def.key),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in def.choiceKeys)
                FilterChip(
                  key: ValueKey('equipment_filter_attr_${def.key}_$option'),
                  label: Text(attributeChoiceLabel(l10n, def.key, option)),
                  selected: _selectedFor(def.key).contains(option),
                  onSelected: (selected) => _toggle(def.key, option, selected),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Set<String> _selectedFor(String key) {
    for (final condition in conditions) {
      if (condition.key == key) return condition.choices;
    }
    return const {};
  }

  void _toggle(String key, String option, bool selected) {
    final choices = {..._selectedFor(key)};
    if (selected) {
      choices.add(option);
    } else {
      choices.remove(option);
    }
    onChanged([
      for (final def in choiceDefsFor(type))
        if (def.key == key) ...[
          if (choices.isNotEmpty)
            EquipmentAttrCondition(
              key: key,
              choices: Set.unmodifiable(choices),
              types: {type},
            ),
        ] else
          ...conditions.where((c) => c.key == def.key),
    ]);
  }
}
