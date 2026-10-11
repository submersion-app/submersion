import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/formatters/visibility_display.dart';
import 'package:submersion/features/dive_log/presentation/widgets/environment_enum_display.dart';
import 'package:submersion/features/trips/domain/services/day_conditions.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One muted line: water temperature, visibility and current for a day, each
/// part only when some dive logged it, each a range when the dives differ.
/// Values follow the diver's unit settings; nothing renders when no dive
/// logged any of the three.
class DayConditionsLine extends StatelessWidget {
  final DayConditions conditions;
  final UnitFormatter units;

  const DayConditionsLine({
    super.key,
    required this.conditions,
    required this.units,
  });

  @override
  Widget build(BuildContext context) {
    if (conditions.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final c = conditions;
    final minVis = c.minVisibilityMeters;
    final maxVis = c.maxVisibilityMeters;
    final legacyVis = c.legacyVisibility;
    final minCurrent = c.minCurrent;
    final maxCurrent = c.maxCurrent;
    final parts = <String>[
      if (c.minWaterTemp != null)
        l10n.trips_day_conditionWater(
          _range(
            l10n,
            units.formatTemperature(c.minWaterTemp, decimals: 0),
            units.formatTemperature(c.maxWaterTemp, decimals: 0),
          ),
        ),
      if (minVis != null && maxVis != null)
        l10n.trips_day_conditionVisibility(
          _range(
            l10n,
            units.formatDistance(minVis),
            units.formatDistance(maxVis),
          ),
        )
      else if (legacyVis != null)
        l10n.trips_day_conditionVisibility(visibilityBandName(legacyVis, l10n)),
      if (minCurrent != null && maxCurrent != null)
        l10n.trips_day_conditionCurrent(
          _range(
            l10n,
            minCurrent.localizedName(l10n),
            maxCurrent.localizedName(l10n),
          ),
        ),
    ];
    final theme = Theme.of(context);
    return Text(
      parts.join(' · '),
      key: const Key('day-conditions-line'),
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// One value when both ends read the same once formatted, so 26.2 and 26.4
  /// at whole degrees do not print "26 to 26".
  static String _range(AppLocalizations l10n, String from, String to) =>
      from == to ? from : l10n.trips_day_valueRange(from, to);
}
