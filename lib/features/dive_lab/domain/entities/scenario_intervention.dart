import 'package:equatable/equatable.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// The kinds of "one changed decision" a scenario can apply from the branch
/// point onward. Stable names: they are the JSON `kind` discriminator.
enum InterventionKind {
  switchGas,
  loseTank,
  shiftAscent,
  ascendNow,
  changeGf,
  shareGas,
  bailOut,
  ascentPolicy,
}

/// A cylinder an intervention refers to: one the dive carried, or a
/// hypothetical cylinder the diver did not have.
sealed class TankRef extends Equatable {
  const TankRef();

  /// The id the compiled plan and the consumption pass use for this tank.
  String get tankId;
}

class ExistingTankRef extends TankRef {
  const ExistingTankRef(this.tankId);

  @override
  final String tankId;

  @override
  List<Object?> get props => [tankId];
}

class HypotheticalTankRef extends TankRef {
  const HypotheticalTankRef({
    required this.gasMix,
    required this.volumeLiters,
    required this.startPressureBar,
  });

  final GasMix gasMix;
  final double volumeLiters;
  final double startPressureBar;

  /// Deterministic so the same hypothetical tank gets the same id across
  /// recomputes and in saved scenarios.
  @override
  String get tankId =>
      'lab-hypothetical-${gasMix.roundedO2}-${gasMix.roundedHe}-'
      '${volumeLiters.round()}-${startPressureBar.round()}';

  @override
  List<Object?> get props => [gasMix, volumeLiters, startPressureBar];
}

/// One changed decision applied from the branch point onward.
sealed class ScenarioIntervention extends Equatable {
  const ScenarioIntervention();

  InterventionKind get kind;

  /// Path-changing kinds can only be evaluated by re-planning the remainder.
  bool get requiresReplan => false;

  /// Kinds that abort the dive at the branch point in re-plan mode.
  bool get impliesAscendNow => false;
}

class SwitchGasIntervention extends ScenarioIntervention {
  const SwitchGasIntervention({required this.tank});
  final TankRef tank;
  @override
  InterventionKind get kind => InterventionKind.switchGas;
  @override
  List<Object?> get props => [tank];
}

class LoseTankIntervention extends ScenarioIntervention {
  const LoseTankIntervention({required this.tankId});
  final String tankId;
  @override
  InterventionKind get kind => InterventionKind.loseTank;
  @override
  List<Object?> get props => [tankId];
}

class ShiftAscentIntervention extends ScenarioIntervention {
  const ShiftAscentIntervention({required this.deltaSeconds});

  /// Negative = begin the ascent earlier.
  final int deltaSeconds;
  @override
  InterventionKind get kind => InterventionKind.shiftAscent;
  @override
  bool get requiresReplan => true;
  @override
  List<Object?> get props => [deltaSeconds];
}

class AscendNowIntervention extends ScenarioIntervention {
  const AscendNowIntervention();
  @override
  InterventionKind get kind => InterventionKind.ascendNow;
  @override
  bool get requiresReplan => true;
  @override
  bool get impliesAscendNow => true;
  @override
  List<Object?> get props => const [];
}

class ChangeGfIntervention extends ScenarioIntervention {
  const ChangeGfIntervention({required this.gfLow, required this.gfHigh});

  /// Percent (0-100).
  final int gfLow;
  final int gfHigh;
  @override
  InterventionKind get kind => InterventionKind.changeGf;
  @override
  List<Object?> get props => [gfLow, gfHigh];
}

class ShareGasIntervention extends ScenarioIntervention {
  const ShareGasIntervention({this.buddyFactor});

  /// Null = the engine's configured buddy factor.
  final double? buddyFactor;
  @override
  InterventionKind get kind => InterventionKind.shareGas;
  @override
  bool get impliesAscendNow => true;
  @override
  List<Object?> get props => [buddyFactor];
}

class BailOutIntervention extends ScenarioIntervention {
  const BailOutIntervention({this.tank});

  /// Null = every bailout-role tank the dive carried.
  final TankRef? tank;
  @override
  InterventionKind get kind => InterventionKind.bailOut;
  @override
  bool get impliesAscendNow => true;
  @override
  List<Object?> get props => [tank];
}

class AscentPolicyIntervention extends ScenarioIntervention {
  const AscentPolicyIntervention({
    this.ascentRate,
    this.lastStopDepth,
    this.extraLastStopSeconds,
    this.gasSwitchStopSeconds,
  });

  final double? ascentRate;
  final double? lastStopDepth;
  final int? extraLastStopSeconds;
  final int? gasSwitchStopSeconds;
  @override
  InterventionKind get kind => InterventionKind.ascentPolicy;
  @override
  bool get requiresReplan => true;
  @override
  List<Object?> get props => [
    ascentRate,
    lastStopDepth,
    extraLastStopSeconds,
    gasSwitchStopSeconds,
  ];
}
