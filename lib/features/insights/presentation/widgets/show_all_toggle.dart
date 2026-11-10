import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// How many rows a long Insights section shows before "Show all".
const showAllRowLimit = 10;

/// The rows a section shows: all of them once [expanded], else the first
/// [showAllRowLimit].
List<T> showAllSlice<T>(List<T> items, {required bool expanded}) =>
    expanded || items.length <= showAllRowLimit
    ? items
    : items.sublist(0, showAllRowLimit);

/// The "Show all" and "Show less" control under a long section. Draws nothing
/// when every row already fits.
class ShowAllToggle extends StatelessWidget {
  const ShowAllToggle({
    super.key,
    required this.itemCount,
    required this.expanded,
    required this.onChanged,
  });

  final int itemCount;
  final bool expanded;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    if (itemCount <= showAllRowLimit) return const SizedBox.shrink();
    final l10n = context.l10n;
    return Center(
      child: TextButton(
        onPressed: () => onChanged(!expanded),
        child: Text(
          expanded
              ? l10n.insights_equipment_showLess
              : l10n.insights_equipment_showAll,
        ),
      ),
    );
  }
}
