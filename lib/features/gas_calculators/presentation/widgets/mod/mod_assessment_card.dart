import 'package:flutter/material.dart';

import 'package:submersion/core/deco/gas_density.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/number_display.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/gas_calculators/domain/gas_density_calculator.dart';
import 'package:submersion/features/gas_calculators/domain/gas_limits.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/mod_calculator_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

enum ModAssessmentSeverity { ok, info, warning, danger }

typedef ModAssessment = ({ModAssessmentSeverity severity, String text});

/// What the numbers mean, in words (issue #2342).
///
/// Replaces the old status icon, which warned on pure oxygen at 6 m and gave
/// air at 56.7 m a green check. Rec judges the MOD against the recreational
/// limit; the Tec modes judge narcosis and density at the depths checked.
List<ModAssessment> modAssessments(
  GasLimitsResult result, {
  required AppLocalizations l10n,
  required UnitFormatter units,
  required double endLimitMeters,
}) {
  final items = <ModAssessment>[];
  void add(ModAssessmentSeverity severity, String text) =>
      items.add((severity: severity, text: text));
  String ppO2(double bar) => formatFixedForDisplay(bar, 2);

  final target = result.atTarget;
  if (target != null && result.targetBeyondMod) {
    // On CCR the target lies past the diluent MOD: the loop still holds the
    // setpoint there, but a flush would give the diluent's own ppO2.
    final flushPpO2 = result.flushPpO2AtTarget;
    add(
      ModAssessmentSeverity.danger,
      flushPpO2 != null
          ? l10n.gasCalculators_mod_targetBeyondDiluentMod(ppO2(flushPpO2))
          : l10n.gasCalculators_mod_targetBeyondMod(ppO2(target.pO2Bar)),
    );
  }
  if (result.targetShallowerThanMinDepth) {
    add(
      ModAssessmentSeverity.danger,
      l10n.gasCalculators_mod_targetAboveMinDepth,
    );
  }

  if (result.mode == ModCalculatorMode.rec) {
    final limit = units.formatDepth(recreationalDepthLimitMeters, decimals: 0);
    add(
      result.beyondRecreationalLimit
          ? ModAssessmentSeverity.warning
          : ModAssessmentSeverity.ok,
      result.beyondRecreationalLimit
          ? l10n.gasCalculators_mod_recBeyondLimit(limit)
          : l10n.gasCalculators_mod_recWithinLimit(limit),
    );
    return items;
  }

  final minDepth = result.minDepthMeters ?? 0;
  if (minDepth > 0) {
    add(
      ModAssessmentSeverity.info,
      l10n.gasCalculators_mod_hypoxic(units.formatDepthCeil(minDepth)),
    );
  }

  final checked = [
    (l10n.gasCalculators_mod_atMod, result.atMod, false),
    if (target != null) (l10n.gasCalculators_mod_atTarget, target, true),
  ];
  for (final (where, a, isTarget) in checked) {
    if (a.exceedsEndLimit) {
      add(
        ModAssessmentSeverity.warning,
        l10n.gasCalculators_mod_narcosisExceeded(
          where,
          units.formatDepth(a.narcoticDepthMeters, decimals: 1),
          units.formatDepth(endLimitMeters, decimals: 0),
        ),
      );
    }
    final density = formatFixedForDisplay(a.densityGPerL ?? 0, 2);
    switch (a.densityLevel) {
      case GasDensityLevel.warn:
        add(
          ModAssessmentSeverity.warning,
          l10n.gasCalculators_mod_densityWarn(
            where,
            density,
            formatFixedForDisplay(gasDensityWarnGPerL, 1),
          ),
        );
      case GasDensityLevel.critical:
        add(
          ModAssessmentSeverity.danger,
          l10n.gasCalculators_mod_densityCritical(
            where,
            density,
            formatFixedForDisplay(gasDensityCriticalGPerL, 1),
          ),
        );
      case GasDensityLevel.ok || null:
        break;
    }
    // At the diluent MOD the loop is always pure diluent, by definition, so
    // these loop notes are only news at a target depth.
    if (isTarget && a.setpointCapped) {
      add(
        ModAssessmentSeverity.info,
        l10n.gasCalculators_mod_setpointCapped(where),
      );
    }
    if (isTarget && a.diluentAboveSetpoint) {
      add(
        ModAssessmentSeverity.info,
        l10n.gasCalculators_mod_diluentAboveSetpoint(where, ppO2(a.pO2Bar)),
      );
    }
  }

  final blocking = items.any(
    (i) =>
        i.severity == ModAssessmentSeverity.warning ||
        i.severity == ModAssessmentSeverity.danger,
  );
  if (!blocking) {
    add(ModAssessmentSeverity.ok, l10n.gasCalculators_mod_allClear);
  }
  return items;
}

class ModAssessmentCard extends ConsumerWidget {
  const ModAssessmentCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final settings = ref.watch(settingsProvider);
    final items = modAssessments(
      ref.watch(modCalculatorResultProvider),
      l10n: l10n,
      units: UnitFormatter(settings),
      endLimitMeters: settings.endLimit,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.gasCalculators_mod_assessmentTitle,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _icon(item.severity),
                      size: 20,
                      color: _color(item.severity, colorScheme),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(item.text, style: textTheme.bodyMedium),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  static IconData _icon(ModAssessmentSeverity severity) => switch (severity) {
    ModAssessmentSeverity.ok => Icons.check_circle,
    ModAssessmentSeverity.info => Icons.info_outline,
    ModAssessmentSeverity.warning => Icons.warning_amber,
    ModAssessmentSeverity.danger => Icons.error,
  };

  static Color _color(ModAssessmentSeverity severity, ColorScheme scheme) =>
      switch (severity) {
        ModAssessmentSeverity.ok => Colors.green,
        ModAssessmentSeverity.info => scheme.primary,
        ModAssessmentSeverity.warning => Colors.orange,
        ModAssessmentSeverity.danger => scheme.error,
      };
}
