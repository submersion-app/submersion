import 'package:flutter/material.dart';

import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_number_badge.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_palette_theme.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_type_icon.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_status_indicator.dart';

/// One gear row of the set editor's picker: a checkbox tile for [item].
///
/// While the figure shows, every row leads with a slot [badgeSlot] wide (the
/// widest badge at the diver's text size) holding the [number] badge, which
/// reveals the figure, or nothing. [badgeSlot] is null when the figure is
/// off. [flashing] paints the row as the figure's selected item.
class SetEquipmentCheckboxRow extends StatelessWidget {
  const SetEquipmentCheckboxRow({
    super.key,
    required this.item,
    required this.detail,
    required this.isSelected,
    required this.number,
    required this.badgeSlot,
    required this.flashing,
    required this.onChanged,
    required this.onBadgeTap,
  });

  final EquipmentItem item;

  /// The row's second line, when the item has one.
  final String? detail;
  final bool isSelected;
  final int? number;
  final double? badgeSlot;
  final bool flashing;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onBadgeTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final highlight = flashing ? figureHighlightFor(scheme) : null;
    final icon = Icon(
      equipmentTypeIcon(item.type),
      color: highlight?.onFill ?? scheme.onSurfaceVariant,
    );

    return ListTileTheme.merge(
      textColor: highlight?.onFill,
      iconColor: highlight?.onFill,
      child: CheckboxListTile(
        tileColor: highlight?.fill,
        value: isSelected,
        onChanged: onChanged,
        title: Text(item.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            switch (detail) {
              final detail? => Text(detail),
              null => const SizedBox.shrink(),
            },
            ServiceStatusIndicatorFor(
              equipmentId: item.id,
              density: ServiceIndicatorDensity.compact,
            ),
          ],
        ),
        secondary: badgeSlot == null
            ? icon
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: badgeSlot,
                    child: number == null
                        ? null
                        : Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: FigureNumberBadge(
                              number: number!,
                              selected: flashing,
                              onTap: onBadgeTap,
                            ),
                          ),
                  ),
                  const SizedBox(width: 8),
                  icon,
                ],
              ),
        controlAffinity: ListTileControlAffinity.trailing,
      ),
    );
  }
}
