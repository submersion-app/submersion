import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// One selectable sort field in a sort sheet: icon, label and a check mark on
/// the current choice.
///
/// Shared by [SortBottomSheet] and the gear sort sheets so every sort control
/// in the app reads the same way.
class SortOptionTile extends StatelessWidget {
  const SortOptionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: isSelected,
      label: isSelected
          ? context.l10n.accessibility_sort_selectedLabel(label)
          : context.l10n.accessibility_sort_unselectedLabel(label),
      child: ListTile(
        leading: Icon(icon, color: isSelected ? colorScheme.primary : null),
        title: Text(
          label,
          style: TextStyle(
            color: isSelected ? colorScheme.primary : null,
            fontWeight: isSelected ? FontWeight.w600 : null,
          ),
        ),
        trailing: isSelected
            ? Icon(Icons.check, color: colorScheme.primary)
            : null,
        onTap: onTap,
      ),
    );
  }
}
