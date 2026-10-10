import 'package:flutter/material.dart';

import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_status_indicator.dart';

/// One gear option in a dropdown: its service dot, its name, and [details]
/// muted on the same line, so items sharing a name can be told apart in the
/// menu and in the closed field alike (#3191).
///
/// [details] is the row's subtitle from `equipmentRowLabelsOf`, computed over
/// every option the dropdown offers: whether two items collide is a property
/// of the whole list, not of one row.
class EquipmentDropdownLabel extends StatelessWidget {
  final EquipmentItem item;
  final String? details;

  const EquipmentDropdownLabel({super.key, required this.item, this.details});

  @override
  Widget build(BuildContext context) {
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
                if (details case final details?)
                  TextSpan(
                    text: ' · $details',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
