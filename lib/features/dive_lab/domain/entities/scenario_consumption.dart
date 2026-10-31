import 'package:equatable/equatable.dart';

import 'package:submersion/features/dive_lab/domain/entities/branch_state.dart';

/// One tank's gas over one timeline.
class TankConsumption extends Equatable {
  const TankConsumption({
    required this.tankId,
    required this.startPressureBar,
    required this.endPressureBar,
    required this.litersUsed,
    this.reserveReachedAtSeconds,
    this.emptyAtSeconds,
    required this.source,
  });
  final String tankId;
  final double? startPressureBar;
  final double? endPressureBar;
  final double litersUsed;
  final int? reserveReachedAtSeconds;
  final int? emptyAtSeconds;
  final PressureSource source;
  @override
  List<Object?> get props => [
    tankId,
    startPressureBar,
    endPressureBar,
    litersUsed,
    reserveReachedAtSeconds,
    emptyAtSeconds,
    source,
  ];
}

class ScenarioConsumption extends Equatable {
  const ScenarioConsumption({
    required this.actual,
    required this.counterfactual,
    required this.reservePressureBar,
  });
  final List<TankConsumption> actual;
  final List<TankConsumption> counterfactual;
  final double reservePressureBar;

  TankConsumption? actualFor(String tankId) => _find(actual, tankId);
  TankConsumption? counterfactualFor(String tankId) =>
      _find(counterfactual, tankId);

  static TankConsumption? _find(List<TankConsumption> list, String id) {
    for (final t in list) {
      if (t.tankId == id) return t;
    }
    return null;
  }

  @override
  List<Object?> get props => [actual, counterfactual, reservePressureBar];
}
