import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/services/avelo_summary.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_buoyancy_line.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// What an Avelo dive's computer recorded (issue #4664), shown in the
/// Cylinders card under the Hydrotank: gas remaining from start to end, the
/// buoyancy range and average, the computer's own RMV range, and the highest
/// Hydrotank pressure, in the diver's units. A line with no value is left
/// out.
class AveloSummaryBlock extends StatelessWidget {
  const AveloSummaryBlock({
    super.key,
    required this.summary,
    required this.units,
  });

  final AveloSummary summary;
  final UnitFormatter units;

  /// A buoyancy weight with its sign, as the chart's buoyancy readout
  /// writes it: negative is heavy, positive light.
  String _signedWeight(double kg, TextDirection direction) =>
      formatSignedBuoyancy(kg, units, direction: direction);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final s = summary;
    final direction = Directionality.of(context);
    final lines = [
      if ((s.gasRemainingStart, s.gasRemainingEnd) case (
        final start?,
        final end?,
      ))
        l10n.diveLog_cylinders_aveloGasRemaining(start, end),
      if ((s.minBuoyancyKg, s.maxBuoyancyKg, s.meanBuoyancyKg) case (
        final min?,
        final max?,
        final mean?,
      ))
        l10n.diveLog_cylinders_aveloBuoyancy(
          _signedWeight(min, direction),
          _signedWeight(max, direction),
          _signedWeight(mean, direction),
        ),
      if ((s.minRmv, s.maxRmv) case (final min?, final max?))
        l10n.diveLog_cylinders_aveloRmv(
          units.formatRmv(min),
          units.formatRmv(max),
        ),
      if (s.maxPressureBar case final pressure?)
        l10n.diveLog_cylinders_aveloMaxPressure(units.formatPressure(pressure)),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.diveLog_cylinders_aveloTitle,
            style: theme.textTheme.labelLarge,
          ),
          for (final line in lines) Text(line),
        ],
      ),
    );
  }
}
