/// The deco ppO2 ceiling for a gas, by O2 percentage band, plus an
/// explicit depth override for pure O2 (issue #3580).
///
/// Dive Planner only: the standalone MOD and Best Mix calculators keep a
/// single flat ppO2 value and never construct one of these.
library;

import 'package:equatable/equatable.dart';

/// O2 percentage above which a gas is treated as pure O2 for
/// [DecoPpO2Limits.usesExplicitO2Depth] - just above band 3's stated
/// "45-99%" so a mix a shade under 100% (e.g. 99.5% from a blend
/// tolerance) still counts as pure O2 once the explicit-depth setting is
/// on, while 99% itself stays in band 3.
const double pureO2ThresholdPercent = 99.0;

/// Whether an optional deco-ppO2 layer (per-O2-band limits, or the
/// explicit MOD for 100% O2) is enabled for a specific plan (issue #3580
/// follow-up, caught by a Copilot review): the diver's [settingsEnabled]
/// toggle on its own, or this plan's own Custom override value set
/// ([hasCustomValue]) - "Custom" is a per-plan opt-in, not something the
/// global switch can silently veto. [explicitlyOff] (the plan's own "Off"
/// choice) always wins regardless of either. Shared by
/// `PlanEngineConfig.resolvedFor`, `PlanCalculatorService` and the Gas
/// options UI so the three never disagree about when a plan's own Custom
/// values actually take effect.
bool resolveDecoLayerEnabled({
  required bool settingsEnabled,
  required bool explicitlyOff,
  required bool hasCustomValue,
}) => !explicitlyOff && (settingsEnabled || hasCustomValue);

/// Whether a plan has its own Custom per-O2-band values: any one band set
/// counts, since the rest then fall back to the diver's Settings bands.
bool hasCustomDecoBands(double? band1, double? band2, double? band3) =>
    band1 != null || band2 != null || band3 != null;

class DecoPpO2Limits extends Equatable {
  const DecoPpO2Limits({
    required this.flat,
    this.bandsEnabled = false,
    this.band1 = 1.6,
    this.band2 = 1.6,
    this.band3 = 1.6,
    this.explicitO2DepthEnabled = false,
    this.explicitO2DepthMeters = 6.0,
  });

  /// A plan's limits: the diver's Settings layers with this plan's own
  /// overrides merged in, each layer switched on or off through
  /// [resolveDecoLayerEnabled]. The one place that rule is applied, so every
  /// caller resolves limits the same way; with no plan overrides passed it
  /// is the diver's Settings alone (the saved-cylinder editor).
  factory DecoPpO2Limits.forPlan({
    required double flat,
    required bool settingsBandsEnabled,
    required double settingsBand1,
    required double settingsBand2,
    required double settingsBand3,
    required bool settingsMaxO2DepthEnabled,
    required double settingsMaxO2DepthMeters,
    double? band1,
    double? band2,
    double? band3,
    bool bandsExplicitlyOff = false,
    double? maxO2DepthMeters,
    bool maxO2DepthExplicitlyOff = false,
  }) => DecoPpO2Limits(
    flat: flat,
    bandsEnabled: resolveDecoLayerEnabled(
      settingsEnabled: settingsBandsEnabled,
      explicitlyOff: bandsExplicitlyOff,
      hasCustomValue: hasCustomDecoBands(band1, band2, band3),
    ),
    band1: band1 ?? settingsBand1,
    band2: band2 ?? settingsBand2,
    band3: band3 ?? settingsBand3,
    explicitO2DepthEnabled: resolveDecoLayerEnabled(
      settingsEnabled: settingsMaxO2DepthEnabled,
      explicitlyOff: maxO2DepthExplicitlyOff,
      hasCustomValue: maxO2DepthMeters != null,
    ),
    explicitO2DepthMeters: maxO2DepthMeters ?? settingsMaxO2DepthMeters,
  );

  /// The single ppO2 value every deco gas uses when [bandsEnabled] is off -
  /// the diver's existing ppO2MaxDeco/plan ppO2Deco.
  final double flat;

  final bool bandsEnabled;

  /// Deco ppO2 ceiling for a gas up to 28% O2.
  final double band1;

  /// Deco ppO2 ceiling for a gas from 28% up to 45% O2.
  final double band2;

  /// Deco ppO2 ceiling for a gas above 45% O2 - including above
  /// [pureO2ThresholdPercent] while [explicitO2DepthEnabled] is off, so
  /// pure O2 is never left without a limit.
  final double band3;

  final bool explicitO2DepthEnabled;

  /// MOD in meters for pure O2, used directly instead of a ppO2 limit:
  /// never run through the ppO2 formula or an environment's pressure
  /// model, so it reads back exactly as set regardless of water density
  /// or altitude.
  final double explicitO2DepthMeters;

  /// Whether a gas with [o2Percent] O2 uses [explicitO2DepthMeters]
  /// directly as its MOD instead of a ppO2 limit. Callers that resolve a
  /// MOD or a switch depth must check this BEFORE calling [ppO2For] -
  /// [ppO2For] does not know about the explicit-depth setting.
  bool usesExplicitO2Depth(double o2Percent) =>
      explicitO2DepthEnabled && o2Percent > pureO2ThresholdPercent;

  /// The deco ppO2 ceiling for a gas with [o2Percent] O2. Meaningless for a
  /// gas where [usesExplicitO2Depth] is true - check that first.
  double ppO2For(double o2Percent) {
    if (!bandsEnabled) return flat;
    if (o2Percent <= 28) return band1;
    if (o2Percent <= 45) return band2;
    return band3;
  }

  @override
  List<Object?> get props => [
    flat,
    bandsEnabled,
    band1,
    band2,
    band3,
    explicitO2DepthEnabled,
    explicitO2DepthMeters,
  ];
}
