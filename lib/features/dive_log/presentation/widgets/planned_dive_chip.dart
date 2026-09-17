import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// The "Planned" marker on a dive list tile (issue #2002): the dive awaits
/// its dive computer data and holds no number yet. The text stays in the
/// semantics tree on purpose: the tile's own label says only "Dive N at
/// site", so without it a screen reader could not tell planned from logged.
class PlannedDiveChip extends StatelessWidget {
  const PlannedDiveChip({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        context.l10n.diveLog_planned_chip,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: scheme.onTertiaryContainer),
      ),
    );
  }
}
