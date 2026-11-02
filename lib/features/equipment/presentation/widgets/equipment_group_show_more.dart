import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Stands in for the items a capped type group hides (#3993).
///
/// Kept out of the focus order like every other row of the list: the list is
/// one focus stop whose arrow keys walk into the hidden items, and it answers
/// Enter itself, so a focusable button here would be a Tab stop that opens the
/// cursor's row instead of expanding the group.
class EquipmentGroupShowMore extends StatelessWidget {
  const EquipmentGroupShowMore({
    super.key,
    required this.remainingCount,
    required this.onPressed,
  });

  /// How many items the group hides.
  final int remainingCount;

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: ExcludeFocus(
          child: TextButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.expand_more, size: 20),
            label: Text(
              context.l10n.equipment_service_showMore(remainingCount),
            ),
          ),
        ),
      ),
    );
  }
}
