import 'package:flutter/material.dart';

import 'package:submersion/features/reef/presentation/widgets/water_conditions_lines.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Environment card's satellite water conditions subsection.
///
/// Laid out like the card's Weather and Dive Conditions subsections: a
/// primary-coloured heading, then one line per reading on the same vertical
/// rhythm as [DiveDetailRow]. The readings carry their own labels ("Sea
/// surface 30.1°C"), so they are not split into label/value rows. The
/// observation date qualifies the readings rather than adding one, so it is
/// muted the way the card's weather-source note is.
class EnvironmentWaterConditions extends StatelessWidget {
  final WaterConditionsLines lines;

  const EnvironmentWaterConditions({super.key, required this.lines});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.l10n.water_conditions_title,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        for (final reading in lines.readings)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(reading, style: theme.textTheme.bodyMedium),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            lines.observedOn,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }
}
