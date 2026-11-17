import 'package:flutter/material.dart';

import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_closed_tag.dart';
import 'package:submersion/shared/selection/selection_checkbox_slot.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_avatar.dart';
import 'package:submersion/shared/widgets/record_list_chevron.dart';

/// Two-line compact card tile for the dive center list.
///
/// Line 1: Center name (expanded) | Dive count text
/// Line 2: Location string (secondary text color)
/// A chevron centred on both lines follows them at the card's end.
class CompactDiveCenterListTile extends StatelessWidget {
  final DiveCenter center;
  final int diveCount;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool isSelectionMode;
  final bool isChecked;
  final ValueChanged<bool>? onCheckChanged;

  const CompactDiveCenterListTile({
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
    final cardColor = isSelected
        ? colorScheme.primaryContainer.withValues(alpha: 0.5)
        : null;
    final secondaryTextColor = colorScheme.onSurfaceVariant;

    final card = Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      color: cardColor,
      child: Semantics(
        button: true,
        label: center.name,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(kRecordCardCompactPadding),
            child: RecordListChevronRow(
              chevronSize: RecordListChevron.compactSize,
              chevronColor: secondaryTextColor,
              child: Row(
                children: [
                  // The checkbox sits beside the whole two-line block rather
                  // than on line 1, so it stays vertically centred against it.
                  SelectionCheckboxSlot(
                    isSelectionMode: isSelectionMode,
                    isChecked: isChecked,
                    onChanged: onCheckChanged,
                  ),
                  // A logo only when the center has one; the compact row has
                  // no store icon to replace (#4460).
                  if (center.logo != null) ...[
                    DiveCenterAvatar(
                      logo: center.logo,
                      radius: 16,
                      shape: DiveCenterAvatarShape.roundedSquare,
                      cornerRadius: 6,
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Line 1: center name, dive count
                        Row(
                          children: [
                            Expanded(
                              child: DiveCenterNameWithTag(
                                closed: center.isPermanentlyClosed,
                                gap: 6,
                                name: Text(
                                  center.name,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$diveCount dives',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: secondaryTextColor),
                            ),
                          ],
                        ),
                        // Line 2: location
                        if (center.fullLocationString != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            center.fullLocationString!,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: secondaryTextColor),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    // A permanently closed center stays listed, greyed (#3379).
    return greyIfClosed(closed: center.isPermanentlyClosed, child: card);
  }
}
