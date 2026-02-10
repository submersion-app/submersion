import 'package:flutter/material.dart';

import 'package:submersion/core/constants/sort_options.dart';

/// A reusable bottom sheet for selecting sort field and direction.
///
/// Generic type [T] is the enum type representing sortable fields
/// for a specific entity (e.g., DiveSortField, SiteSortField).
class SortBottomSheet<T extends Enum> extends StatefulWidget {
  /// Title displayed at the top of the sheet
  final String title;

  /// Currently selected sort field
  final T currentField;

  /// Current sort direction
  final SortDirection currentDirection;

  /// List of available sort fields
  final List<T> fields;

  /// Function to get display name for a field
  final String Function(T) getFieldDisplayName;

  /// Function to get icon for a field
  final IconData Function(T) getFieldIcon;

  /// Callback when sort selection changes
  final void Function(T field, SortDirection direction) onSortChanged;

  const SortBottomSheet({
    super.key,
    required this.title,
    required this.currentField,
    required this.currentDirection,
    required this.fields,
    required this.getFieldDisplayName,
    required this.getFieldIcon,
    required this.onSortChanged,
  });

  @override
  State<SortBottomSheet<T>> createState() => _SortBottomSheetState<T>();
}

class _SortBottomSheetState<T extends Enum> extends State<SortBottomSheet<T>> {
  late T _selectedField;
  late SortDirection _selectedDirection;

  @override
  void initState() {
    super.initState();
    _selectedField = widget.currentField;
    _selectedDirection = widget.currentDirection;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Semantics(
                    header: true,
                    child: Text(widget.title, style: textTheme.titleLarge),
                  ),
                  const Spacer(),
                  // Direction toggle
                  SegmentedButton<SortDirection>(
                    segments: [
                      ButtonSegment(
                        value: SortDirection.ascending,
                        icon: Icon(SortDirection.ascending.icon, size: 18),
                        tooltip: SortDirection.ascending.displayName,
                      ),
                      ButtonSegment(
                        value: SortDirection.descending,
                        icon: Icon(SortDirection.descending.icon, size: 18),
                        tooltip: SortDirection.descending.displayName,
                      ),
                    ],
                    selected: {_selectedDirection},
                    onSelectionChanged: (selected) {
                      setState(() {
                        _selectedDirection = selected.first;
                      });
                      widget.onSortChanged(_selectedField, _selectedDirection);
                    },
                    showSelectedIcon: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            // Sort field options
            ...widget.fields.map((field) {
              final isSelected = field == _selectedField;
              final displayName = widget.getFieldDisplayName(field);
              return Semantics(
                button: true,
                selected: isSelected,
                label: isSelected
                    ? 'Sort by $displayName, currently selected'
                    : 'Sort by $displayName',
                child: ListTile(
                  leading: Icon(
                    widget.getFieldIcon(field),
                    color: isSelected ? colorScheme.primary : null,
                  ),
                  title: Text(
                    displayName,
                    style: TextStyle(
                      color: isSelected ? colorScheme.primary : null,
                      fontWeight: isSelected ? FontWeight.w600 : null,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check, color: colorScheme.primary)
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedField = field;
                    });
                    widget.onSortChanged(_selectedField, _selectedDirection);
                  },
                ),
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Shows a sort bottom sheet and returns when closed.
///
/// This is a convenience function that wraps [SortBottomSheet] in a modal.
Future<void> showSortBottomSheet<T extends Enum>({
  required BuildContext context,
  required String title,
  required T currentField,
  required SortDirection currentDirection,
  required List<T> fields,
  required String Function(T) getFieldDisplayName,
  required IconData Function(T) getFieldIcon,
  required void Function(T field, SortDirection direction) onSortChanged,
}) {
  return showModalBottomSheet(
    context: context,
    builder: (context) => SortBottomSheet<T>(
      title: title,
      currentField: currentField,
      currentDirection: currentDirection,
      fields: fields,
      getFieldDisplayName: getFieldDisplayName,
      getFieldIcon: getFieldIcon,
      onSortChanged: (field, direction) {
        onSortChanged(field, direction);
        Navigator.pop(context);
      },
    ),
  );
}
