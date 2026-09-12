import 'package:flutter/material.dart';

import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/constants/sort_options_display.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_grouping_controls.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/sort_option_tile.dart';

/// The layout every gear sort sheet shares: a titled header carrying the item
/// direction, the type-axis grouping controls, then the item sort fields as
/// check-mark rows.
///
/// The dive surfaces and the Equipment page sort by different fields (only
/// the page has Service Due), so the fields are generic; everything else is
/// fixed here, which is what keeps the two sheets looking the same.
///
/// Unlike `SortBottomSheet`, a pick does not close the sheet: it carries
/// several axes, and closing on the first change would make the rest
/// unreachable without reopening it. The header therefore carries a close
/// button: the sheet opens near full height and its scroll view takes the
/// downward drag, so on a phone with no back key it is the way out.
class EquipmentSortSheetLayout<T extends Enum> extends StatelessWidget {
  const EquipmentSortSheetLayout({
    super.key,
    required this.direction,
    required this.onDirectionChanged,
    required this.fieldsLabel,
    required this.fields,
    required this.selectedField,
    required this.fieldLabel,
    required this.fieldIcon,
    required this.onFieldSelected,
    this.showGrouping = true,
    this.footer,
  });

  final SortDirection direction;
  final ValueChanged<SortDirection> onDirectionChanged;

  /// "Then by" when something orders the list first, "Sort by" otherwise.
  final String fieldsLabel;
  final List<T> fields;
  final T selectedField;
  final String Function(T) fieldLabel;
  final IconData Function(T) fieldIcon;
  final ValueChanged<T> onFieldSelected;

  /// False where the list never groups (the Equipment table), so the sheet
  /// does not offer controls that change nothing on screen.
  final bool showGrouping;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // Expanded with an ellipsis rather than a bare Text: the
                    // title shares the row with the direction toggle and the
                    // close button, and a long translation overflows a
                    // narrow phone.
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          l10n.equipment_list_sortTitle,
                          style: textTheme.titleLarge,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    SegmentedButton<SortDirection>(
                      segments: [
                        for (final value in SortDirection.values)
                          ButtonSegment(
                            value: value,
                            icon: Icon(value.icon, size: 18),
                            tooltip: value.localizedName(l10n),
                          ),
                      ],
                      selected: {direction},
                      showSelectedIcon: false,
                      onSelectionChanged: (selected) =>
                          onDirectionChanged(selected.first),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: l10n.common_action_close,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              if (showGrouping) ...[
                const EquipmentGroupingControls(),
                const Divider(height: 1),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(fieldsLabel, style: textTheme.labelLarge),
              ),
              for (final field in fields)
                SortOptionTile(
                  icon: fieldIcon(field),
                  label: fieldLabel(field),
                  isSelected: field == selectedField,
                  onTap: () => onFieldSelected(field),
                ),
              if (footer != null) ...[const Divider(height: 1), footer!],
            ],
          ),
        ),
      ),
    );
  }
}
