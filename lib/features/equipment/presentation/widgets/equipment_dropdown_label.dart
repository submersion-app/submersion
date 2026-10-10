import 'package:flutter/material.dart';

import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_row_label.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_status_indicator.dart';

/// One gear option in a dropdown: its service dot, its name, and the details
/// of its [label] muted on the same line, so items sharing a name can be told
/// apart in the menu and in the closed field alike (#3191).
///
/// [label] comes from `equipmentRowLabelsOf`, computed over every option the
/// dropdown offers: whether two items collide is a property of the whole
/// list, not of one row.
class EquipmentDropdownLabel extends StatelessWidget {
  final EquipmentItem item;
  final EquipmentRowLabel? label;

  const EquipmentDropdownLabel({super.key, required this.item, this.label});

  @override
  Widget build(BuildContext context) {
    final details = _detailsOf(item, label);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ServiceStatusIndicatorFor(
          equipmentId: item.id,
          density: ServiceIndicatorDensity.dot,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text.rich(
            TextSpan(
              text: item.name,
              children: [
                if (details != null)
                  TextSpan(
                    text: ' · $details',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// The label's details with brand and model moved to the end. A dropdown
/// cuts a long label off at its end, and the ID and the tie-breaking details
/// are what tell same-named options apart, so they must not be the part that
/// goes. The shared row label leads with brand and model, which suits a list
/// row with room for a full subtitle.
String? _detailsOf(EquipmentItem item, EquipmentRowLabel? label) {
  final parts = label?.subtitleParts ?? const <String>[];
  if (parts.isEmpty) return null;
  // The row label puts brand and model first, and only when they differ from
  // the name.
  final leadsWithBrandModel =
      item.fullName != item.name && parts.first == item.fullName;
  final ordered = leadsWithBrandModel ? [...parts.skip(1), parts.first] : parts;
  return ordered.join(' · ');
}
