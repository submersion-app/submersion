import 'package:flutter/material.dart';

import 'package:submersion/core/theme/app_colors.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_delta.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_intervention.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_outcome.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Runtime seconds as `M:SS`.
String formatLabTime(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// Whole minutes (rounded up) with the planner's prime mark.
String formatLabMinutes(int seconds) => '${(seconds / 60).ceil()}′';

/// A tank's display name: its name, else its mix, else the id.
String labTankName(List<DiveTank> tanks, String tankId) {
  for (final t in tanks) {
    if (t.id == tankId) return t.name ?? t.gasMix.name;
  }
  return tankId;
}

String labMetricLabel(
  AppLocalizations l10n,
  ScenarioDelta d,
  String Function(String tankId) tankName,
) {
  final tank = d.tankId == null ? '' : tankName(d.tankId!);
  return switch (d.metric) {
    DeltaMetric.runtime => l10n.diveLab_metric_runtime,
    DeltaMetric.ttsAtBranch => l10n.diveLab_metric_ttsAtBranch,
    DeltaMetric.decoTimeAfterBranch => l10n.diveLab_metric_decoTimeAfterBranch,
    DeltaMetric.deepestStopAfterBranch =>
      l10n.diveLab_metric_deepestStopAfterBranch,
    DeltaMetric.surfaceGf => l10n.diveLab_metric_surfaceGf,
    DeltaMetric.peakGf99AfterBranch => l10n.diveLab_metric_peakGf99AfterBranch,
    DeltaMetric.cnsEnd => l10n.diveLab_metric_cnsEnd,
    DeltaMetric.otuEnd => l10n.diveLab_metric_otuEnd,
    DeltaMetric.maxPpO2AfterBranch => l10n.diveLab_metric_maxPpO2AfterBranch,
    DeltaMetric.tankEndPressure => l10n.diveLab_metric_tankEndPressure(tank),
    DeltaMetric.gasOutTime => l10n.diveLab_metric_gasOutTime(tank),
    DeltaMetric.minGasMarginAtBranch =>
      l10n.diveLab_metric_minGasMarginAtBranch,
    DeltaMetric.ceilingViolations => l10n.diveLab_metric_ceilingViolations,
    DeltaMetric.worstCeilingViolation =>
      l10n.diveLab_metric_worstCeilingViolation,
  };
}

/// One side of a comparison, in the diver's units.
String labMetricValue(
  AppLocalizations l10n,
  UnitFormatter units,
  DeltaMetric m,
  double? v,
) {
  if (v == null) return l10n.diveLab_value_none;
  switch (m) {
    case DeltaMetric.gasOutTime:
      return formatLabTime(v.round());
    case DeltaMetric.maxPpO2AfterBranch:
      return '${v.toStringAsFixed(2)} bar';
    case DeltaMetric.tankEndPressure:
    case DeltaMetric.minGasMarginAtBranch:
      return units.formatPressure(v);
    case DeltaMetric.runtime:
    case DeltaMetric.ttsAtBranch:
    case DeltaMetric.decoTimeAfterBranch:
      return formatLabMinutes(v.round());
    case DeltaMetric.deepestStopAfterBranch:
    case DeltaMetric.worstCeilingViolation:
      return units.formatDepth(v);
    case DeltaMetric.surfaceGf:
    case DeltaMetric.peakGf99AfterBranch:
    case DeltaMetric.cnsEnd:
      return '${v.toStringAsFixed(0)}%';
    case DeltaMetric.otuEnd:
    case DeltaMetric.ceilingViolations:
      return v.toStringAsFixed(0);
  }
}

/// The signed difference, in the diver's units.
String labDeltaValue(
  AppLocalizations l10n,
  UnitFormatter units,
  ScenarioDelta d,
) {
  final delta = d.delta;
  if (delta == null) return l10n.diveLab_value_none;
  final sign = delta > 1e-9 ? '+' : (delta < -1e-9 ? '-' : '');
  final a = delta.abs();
  return switch (d.metric.unit) {
    DeltaUnit.seconds => '$sign${formatLabTime(a.round())}',
    DeltaUnit.meters => '$sign${units.formatDepth(a)}',
    DeltaUnit.percent => '$sign${a.toStringAsFixed(1)}%',
    DeltaUnit.bar =>
      d.metric == DeltaMetric.maxPpO2AfterBranch
          ? '$sign${a.toStringAsFixed(2)} bar'
          : '$sign${units.formatPressure(a)}',
    DeltaUnit.count => '$sign${a.toStringAsFixed(0)}',
  };
}

/// Green when the change is better, error when worse; null when neutral or
/// unchanged.
Color? labDeltaColor(ColorScheme scheme, ScenarioDelta d) {
  final delta = d.delta;
  if (delta == null || delta.abs() < 1e-9) return null;
  switch (d.betterWhen) {
    case BetterWhen.neutral:
      return null;
    case BetterWhen.lower:
      return delta < 0 ? AppColors.success : scheme.error;
    case BetterWhen.higher:
      return delta > 0 ? AppColors.success : scheme.error;
  }
}

String labInterventionChipLabel(
  AppLocalizations l10n,
  UnitFormatter units,
  ScenarioIntervention i,
  String Function(String tankId) tankName,
) {
  return switch (i) {
    SwitchGasIntervention(:final tank) => l10n.diveLab_chip_switchGas(
      switch (tank) {
        ExistingTankRef(:final tankId) => tankName(tankId),
        HypotheticalTankRef(:final gasMix) => gasMix.name,
      },
    ),
    LoseTankIntervention(:final tankId) => l10n.diveLab_chip_loseTank(
      tankName(tankId),
    ),
    ShiftAscentIntervention(:final deltaSeconds) =>
      l10n.diveLab_chip_shiftAscent(
        '${deltaSeconds < 0 ? '-' : '+'}${formatLabMinutes(deltaSeconds.abs())}',
      ),
    AscendNowIntervention() => l10n.diveLab_chip_ascendNow,
    ChangeGfIntervention(:final gfLow, :final gfHigh) =>
      l10n.diveLab_chip_changeGf(gfLow, gfHigh),
    ShareGasIntervention(:final buddyFactor) => l10n.diveLab_chip_shareGas(
      (buddyFactor ?? 2.0).toStringAsFixed(1),
    ),
    BailOutIntervention() => l10n.diveLab_chip_bailOut,
    AscentPolicyIntervention() => l10n.diveLab_chip_ascentPolicy,
  };
}

String labKindName(AppLocalizations l10n, InterventionKind kind) =>
    switch (kind) {
      InterventionKind.switchGas => l10n.diveLab_kind_switchGas,
      InterventionKind.loseTank => l10n.diveLab_kind_loseTank,
      InterventionKind.shiftAscent => l10n.diveLab_kind_shiftAscent,
      InterventionKind.ascendNow => l10n.diveLab_kind_ascendNow,
      InterventionKind.changeGf => l10n.diveLab_kind_changeGf,
      InterventionKind.shareGas => l10n.diveLab_kind_shareGas,
      InterventionKind.bailOut => l10n.diveLab_kind_bailOut,
      InterventionKind.ascentPolicy => l10n.diveLab_kind_ascentPolicy,
    };

String labKindDescription(AppLocalizations l10n, InterventionKind kind) =>
    switch (kind) {
      InterventionKind.switchGas => l10n.diveLab_kindDesc_switchGas,
      InterventionKind.loseTank => l10n.diveLab_kindDesc_loseTank,
      InterventionKind.shiftAscent => l10n.diveLab_kindDesc_shiftAscent,
      InterventionKind.ascendNow => l10n.diveLab_kindDesc_ascendNow,
      InterventionKind.changeGf => l10n.diveLab_kindDesc_changeGf,
      InterventionKind.shareGas => l10n.diveLab_kindDesc_shareGas,
      InterventionKind.bailOut => l10n.diveLab_kindDesc_bailOut,
      InterventionKind.ascentPolicy => l10n.diveLab_kindDesc_ascentPolicy,
    };

String labFlagText(
  AppLocalizations l10n,
  ScenarioFlag f,
  String Function(String tankId) tankName,
) {
  final tank = f.tankId == null ? '' : tankName(f.tankId!);
  return switch (f.kind) {
    ScenarioFlagKind.sacEstimated => l10n.diveLab_flag_sacEstimated,
    ScenarioFlagKind.pressureEstimated => l10n.diveLab_flag_pressureEstimated(
      tank,
    ),
    ScenarioFlagKind.pressureUnknown => l10n.diveLab_flag_pressureUnknown(tank),
    ScenarioFlagKind.tankVolumeAssumed => l10n.diveLab_flag_tankVolumeAssumed(
      tank,
    ),
    ScenarioFlagKind.noBottomRemaining => l10n.diveLab_flag_noBottomRemaining,
    ScenarioFlagKind.replanNotCompletable =>
      l10n.diveLab_flag_replanNotCompletable,
    ScenarioFlagKind.loopGasMissing => l10n.diveLab_flag_loopGasMissing,
  };
}
