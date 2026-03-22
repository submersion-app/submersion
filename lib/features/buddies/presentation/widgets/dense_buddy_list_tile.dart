import 'package:flutter/material.dart';

import 'package:submersion/features/buddies/domain/entities/buddy.dart';

/// Single-row flat tile for the buddy list (maximum density).
///
/// Row: Buddy name (expanded) | Cert level (~100px) | Dive count (~40px) | Chevron
/// No avatar, no agency. Uses a bottom border divider instead of a card wrapper.
class DenseBuddyListTile extends StatelessWidget {
  final Buddy buddy;
  final int? diveCount;
  final bool isSelected;
  final VoidCallback? onTap;

  const DenseBuddyListTile({
    super.key,
    required this.buddy,
    this.diveCount,
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

    return Semantics(
      button: true,
      label: buddy.name,
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
                // Buddy name (expanded)
                Expanded(
                  child: Text(
                    buddy.name,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                // Cert level (~100px)
                if (buddy.certificationLevel != null)
                  SizedBox(
                    width: 100,
                    child: Text(
                      buddy.certificationLevel!.displayName,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: secondaryTextColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                    ),
                  )
                else
                  const SizedBox(width: 100),
                const SizedBox(width: 8),
                // Dive count (~40px)
                SizedBox(
                  width: 40,
                  child: diveCount != null
                      ? Text(
                          '$diveCount',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: secondaryTextColor),
                          textAlign: TextAlign.right,
                          overflow: TextOverflow.ellipsis,
                        )
                      : null,
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
