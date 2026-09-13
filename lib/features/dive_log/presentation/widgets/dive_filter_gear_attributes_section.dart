import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/models/equipment_attr_condition.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_choice_attribute_filter.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The dive filter's gear-attribute section (issue #1805): pick one gear
/// category the diver owns, then narrow by its choice fields with the same
/// chips the equipment filter panel uses. Suit thickness keeps its own
/// section; its condition and these combine with AND.
///
/// Renders nothing when the diver owns no category with a choice field.
class DiveFilterGearAttributesSection extends ConsumerWidget {
  final EquipmentType? category;
  final List<EquipmentAttrCondition> conditions;
  final void Function(
    EquipmentType? category,
    List<EquipmentAttrCondition> conditions,
  )
  onChanged;

  const DiveFilterGearAttributesSection({
    super.key,
    required this.category,
    required this.conditions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owned = ref.watch(ownedEquipmentTypesProvider);
    final categories = [
      for (final type in EquipmentType.values)
        if ((owned.contains(type) || type == category) &&
            EquipmentChoiceAttributeFilter.choiceDefsFor(type).isNotEmpty)
          type,
    ];
    if (categories.isEmpty) return const SizedBox.shrink();

    final selected = category;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.diveLog_filter_sectionGearAttributes,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<EquipmentType?>(
          key: const ValueKey('diveFilter_gearCategory'),
          initialValue: selected,
          decoration: InputDecoration(
            labelText: context.l10n.diveLog_filter_gearCategory,
          ),
          items: [
            DropdownMenuItem<EquipmentType?>(
              value: null,
              child: Text(context.l10n.diveLog_filter_gearCategoryAny),
            ),
            for (final type in categories)
              DropdownMenuItem<EquipmentType?>(
                value: type,
                child: Text(type.localizedName(context.l10n)),
              ),
          ],
          // A new category starts with no chips: conditions belong to one.
          onChanged: (type) => onChanged(type, const []),
        ),
        if (selected != null)
          EquipmentChoiceAttributeFilter(
            type: selected,
            conditions: conditions,
            onChanged: (next) => onChanged(selected, next),
          ),
        const SizedBox(height: 24),
      ],
    );
  }
}
