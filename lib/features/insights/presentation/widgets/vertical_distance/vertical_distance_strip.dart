import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Height of the readout strip.
const double kVerticalStripHeight = 48;

/// The readout under the scale (issue #4569). Always present and always the
/// same height, so selecting a level never moves the page under the
/// pointer. [onOpen] is null when the level has no dive behind it.
class VerticalDistanceStrip extends StatelessWidget {
  const VerticalDistanceStrip({
    super.key,
    required this.text,
    required this.selected,
    required this.pinned,
    this.onOpen,
  });

  final String text;
  final bool selected;
  final bool pinned;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 400;
        return Container(
          // A minimum, not a fixed height: at a large text size the two
          // lines grow the strip instead of overflowing it.
          constraints: const BoxConstraints(minHeight: kVerticalStripHeight),
          padding: const EdgeInsetsDirectional.only(start: 12, end: 4),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: pinned ? scheme.primary : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: selected
                        ? scheme.onSurface
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ),
              // Below 400 px the border alone marks the pin, so the chip does not
              // take the room the date needs.
              if (pinned && wide)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      context.l10n.insights_profile_verticalDistance_pinned,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
              if (onOpen != null)
                if (wide)
                  TextButton(
                    key: const Key('verticalOpenDive'),
                    onPressed: onOpen,
                    child: Text(
                      context.l10n.insights_profile_verticalDistance_openDive,
                    ),
                  )
                else
                  IconButton(
                    key: const Key('verticalOpenDive'),
                    onPressed: onOpen,
                    tooltip:
                        context.l10n.insights_profile_verticalDistance_openDive,
                    icon: const Icon(Icons.open_in_new, size: 20),
                  ),
            ],
          ),
        );
      },
    );
  }
}
