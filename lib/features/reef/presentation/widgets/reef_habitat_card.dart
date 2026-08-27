import 'package:flutter/material.dart';

import 'package:submersion/features/reef/domain/entities/reef_data_status.dart';
import 'package:submersion/features/reef/domain/entities/reef_habitat.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One row of the reef section: reef presence and threat classification.
class ReefHabitatCard extends StatelessWidget {
  final ReefPart<ReefHabitat> part;

  const ReefHabitatCard({super.key, required this.part});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final String text;
    switch (part.status) {
      case ReefDataStatus.ok:
        final threat = part.value!.threatLevel;
        text = threat == null
            ? context.l10n.reef_habitat_onReef
            : context.l10n.reef_habitat_onReefWithThreat(threat);
      case ReefDataStatus.empty:
        text = context.l10n.reef_habitat_noReef;
      case ReefDataStatus.unavailable:
        text = context.l10n.reef_habitat_unavailable;
    }

    return ListTile(
      leading: Icon(Icons.waves, color: scheme.primary),
      title: Text(
        context.l10n.reef_habitat_title,
        style: theme.textTheme.titleSmall,
      ),
      subtitle: Text(text),
      dense: true,
    );
  }
}
