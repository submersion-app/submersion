import 'package:flutter/material.dart';

import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';

/// Single-row flat tile for the dive center list (maximum density).
///
/// Row: Center name (expanded) | Location (truncated, ~100px) | Dive count (~40px) | Chevron
class DenseDiveCenterListTile extends StatelessWidget {
  final DiveCenter center;
  final int diveCount;
  final bool isSelected;
  final VoidCallback? onTap;

  const DenseDiveCenterListTile({
    super.key,
    required this.center,
    required this.diveCount,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final rowColor = isSelected
        ? colorScheme.primaryContainer.withValues(alpha: 0.3)
        : null;
    final secondaryTextColor = colorScheme.onSurfaceVariant;
    final locationString = center.fullLocationString;

    return Semantics(
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                // Center name (expanded)
                Expanded(
                  child: Text(
                    center.name,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
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
                ExcludeSemantics(
                  child: Icon(
                    Icons.chevron_right,
                    color: secondaryTextColor,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
