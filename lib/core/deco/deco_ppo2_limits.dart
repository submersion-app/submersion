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
