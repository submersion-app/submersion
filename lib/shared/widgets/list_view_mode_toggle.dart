import 'package:flutter/material.dart';

import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Popup menu button for switching between list view modes.
///
/// Shows the icon of the current mode; tapping reveals available options.
class ListViewModeToggle extends StatelessWidget {
  final ListViewMode currentMode;
  final ValueChanged<ListViewMode> onModeChanged;

  /// Which modes to show in the popup. Defaults to all three.
  final List<ListViewMode> availableModes;

  /// Icon size (default 20 for compact app bars).
  final double iconSize;

  const ListViewModeToggle({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
    this.availableModes = ListViewMode.values,
    this.iconSize = 20,
  });

  IconData _iconForMode(ListViewMode mode) {
    return switch (mode) {
      ListViewMode.detailed => Icons.view_agenda,
      ListViewMode.compact => Icons.view_list,
      ListViewMode.dense => Icons.list,
      ListViewMode.table => Icons.table_rows,
    };
  }

  String _labelForMode(ListViewMode mode, AppLocalizations l10n) {
    return switch (mode) {
      ListViewMode.detailed => l10n.enum_listViewMode_detailed,
      ListViewMode.compact => l10n.enum_listViewMode_compact,
      ListViewMode.dense => l10n.enum_listViewMode_dense,
      ListViewMode.table => l10n.enum_listViewMode_table,
    };
  }

  /// Build PopupMenuItems for use in overflow menus.
  /// Values are prefixed with 'view_' (e.g. 'view_detailed').
  static List<PopupMenuEntry<String>> menuItems(
    BuildContext context, {
    required ListViewMode currentMode,
    List<ListViewMode> modes = ListViewMode.values,
  }) {
    final l10n = context.l10n;
    final primary = Theme.of(context).colorScheme.primary;
    return modes.map((mode) {
      final isCurrent = mode == currentMode;
      return PopupMenuItem<String>(
        value: 'view_${mode.name}',
        child: Row(
          children: [
            Icon(
              _iconForModeStatic(mode),
              size: 20,
              color: isCurrent ? primary : null,
            ),
            const SizedBox(width: 12),
            Text(
              _labelForModeStatic(mode, l10n),
              style: isCurrent
                  ? TextStyle(color: primary, fontWeight: FontWeight.w600)
                  : null,
            ),
          ],
        ),
      );
    }).toList();
  }

  static IconData _iconForModeStatic(ListViewMode mode) {
    return switch (mode) {
      ListViewMode.detailed => Icons.view_agenda,
      ListViewMode.compact => Icons.view_list,
      ListViewMode.dense => Icons.list,
      ListViewMode.table => Icons.table_rows,
    };
  }

  static String _labelForModeStatic(ListViewMode mode, AppLocalizations l10n) {
    return switch (mode) {
      ListViewMode.detailed => l10n.enum_listViewMode_detailed,
      ListViewMode.compact => l10n.enum_listViewMode_compact,
      ListViewMode.dense => l10n.enum_listViewMode_dense,
      ListViewMode.table => l10n.enum_listViewMode_table,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopupMenuButton<ListViewMode>(
      icon: Icon(_iconForMode(currentMode), size: iconSize),
      tooltip: l10n.listViewMode_tooltip,
      onSelected: onModeChanged,
      itemBuilder: (context) => availableModes.map((mode) {
        return PopupMenuItem(
          value: mode,
          child: Row(
            children: [
              Icon(
                _iconForMode(mode),
                size: 20,
                color: mode == currentMode
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              const SizedBox(width: 12),
              Text(
                _labelForMode(mode, l10n),
                style: mode == currentMode
                    ? TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      )
                    : null,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
