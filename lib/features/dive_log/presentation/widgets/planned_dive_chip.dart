import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// The "Planned" marker on a dive list tile (issue #2002): the dive awaits
/// its dive computer data and holds no number yet.
class PlannedDiveChip extends StatelessWidget {
  const PlannedDiveChip({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Container(
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
      ),
    );
  }
}
