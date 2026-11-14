import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_tank.dart';
import 'package:submersion/features/equipment/domain/entities/set_bundle.dart';
import 'package:submersion/features/weight_planner/presentation/widgets/weight_enum_display.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The pre-dive checks for what a set carries besides gear (issue #4525):
/// one for the lead, with its total and each weight, and one per cylinder,
/// by its label or its size, with its mix. In the diver's units and
/// language; the text is fixed once a session starts.
List<String> setCheckTitles(
  AppLocalizations l10n,
  UnitFormatter units,
  SetBundle bundle,
) => [
  if (bundle.weights.isNotEmpty)
    l10n.preDive_setChecks_weights(
      units.formatWeight(bundle.totalWeightKg),
      [
        for (final w in bundle.weights)
          '${w.label.trim().isNotEmpty ? w.label.trim() : w.weightType.localizedName(l10n)} '
              '${units.formatWeight(w.amountKg)}',
      ].join(', '),
    ),
  for (final cylinder in bundle.cylinders)
    [
      switch (cylinder.label?.trim()) {
        final label? when label.isNotEmpty => label,
        _ => units.formatTankVolume(
          cylinder.volumeL,
          cylinder.workingPressureBar,
        ),
      },
      GasMix(o2: cylinder.o2Percent, he: cylinder.hePercent).name,
    ].join(' · '),
];
