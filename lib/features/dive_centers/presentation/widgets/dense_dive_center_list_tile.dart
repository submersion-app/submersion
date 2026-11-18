import 'package:flutter/material.dart';

import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_closed_tag.dart';
import 'package:submersion/shared/selection/selection_checkbox_slot.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_avatar.dart';
import 'package:submersion/shared/widgets/record_list_chevron.dart';

/// Single-row flat tile for the dive center list (maximum density).
///
/// Row: Center name (expanded) | Location (truncated, ~100px) | Dive count (~40px) | Chevron
class DenseDiveCenterListTile extends StatelessWidget {
  final DiveCenter center;
  final int diveCount;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool isSelectionMode;
  final bool isChecked;
  final ValueChanged<bool>? onCheckChanged;

  const DenseDiveCenterListTile({
    super.key,
    required this.center,
    required this.diveCount,
    this.isSelected = false,
    this.onTap,
    this.isSelectionMode = false,
    this.isChecked = false,
    this.onCheckChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final rowColor = isSelected
        ? colorScheme.primaryContainer.withValues(alpha: 0.5)
        : null;
    final secondaryTextColor = colorScheme.onSurfaceVariant;
    final locationString = center.fullLocationString;

    final row = Semantics(
      button: true,
      label: center.name,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: rowColor,
          border: Border(
            bottom: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: kRecordRowDenseHorizontalPadding,
              vertical: 10,
            ),
            child: Row(
              children: [
                SelectionCheckboxSlot(
                  isSelectionMode: isSelectionMode,
                  isChecked: isChecked,
                  onChanged: onCheckChanged,
                  gap: 8,
                ),
                // A logo only when the center has one; the dense row has no
                // store icon to replace (#4460).
                if (center.logo != null) ...[
                  DiveCenterAvatar(
                    logo: center.logo,
                    radius: 10,
                    shape: DiveCenterAvatarShape.roundedSquare,
                    cornerRadius: 4,
                  ),
                  const SizedBox(width: 8),
                ],
                // Center name (expanded)
                Expanded(
                  child: DiveCenterNameWithTag(
                    closed: center.isPermanentlyClosed,
                    gap: 6,
                    name: Text(
                      center.name,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Location (truncated, ~100px width)
                if (locationString != null)
                  SizedBox(
                    width: 100,
                    child: Text(
                      locationString,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: secondaryTextColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                    ),
                  ),
                const SizedBox(width: 8),
                // Dive count (~40px)
                SizedBox(
                  width: 40,
                  child: Text(
                    '$diveCount',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: secondaryTextColor),
                    textAlign: TextAlign.right,
                  ),
                ),
                RecordListChevron(
                  size: RecordListChevron.denseSize,
                  color: secondaryTextColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    // A permanently closed center stays listed, greyed (#3379).
    return greyIfClosed(closed: center.isPermanentlyClosed, child: row);
  }
}
