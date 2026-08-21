import 'package:equatable/equatable.dart';

import 'package:submersion/core/deco/deco_model.dart';
import 'package:submersion/core/deco/entities/tissue_compartment.dart';

enum PressureSource { measured, estimated, unknown }

enum SacSource { measured, diveAverage, logAverage, defaultValue }

class TankPressureAtBranch extends Equatable {
  const TankPressureAtBranch({
    required this.tankId,
    required this.pressureBar,
    required this.source,
  });
  final String tankId;
  final double? pressureBar;
  final PressureSource source;
  @override
  List<Object?> get props => [tankId, pressureBar, source];
}

/// The complete state of the dive at the branch point.
class BranchState extends Equatable {
  const BranchState({
    required this.index,
    required this.runtimeSeconds,
    required this.depthMeters,
    required this.compartments,
    required this.gfLowCeilingAnchor,
    required this.cnsPercent,
    required this.otu,
    required this.activeTankId,
    required this.tankPressures,
    required this.sacLitersPerMin,
    required this.sacSource,
  });

  final int index;
  final int runtimeSeconds;
  final double depthMeters;
  final List<TissueCompartment> compartments;
  final double gfLowCeilingAnchor;
  final double cnsPercent;
  final double otu;
  final String? activeTankId;
  final List<TankPressureAtBranch> tankPressures;
  final double sacLitersPerMin;
  final SacSource sacSource;

  BuhlmannState get tissueState => BuhlmannState(
    compartments: compartments,
    gfLowCeilingAnchor: gfLowCeilingAnchor,
  );

  TankPressureAtBranch? _entry(String tankId) {
    for (final p in tankPressures) {
      if (p.tankId == tankId) return p;
    }
    return null;
  }

  double? pressureFor(String tankId) => _entry(tankId)?.pressureBar;

  PressureSource pressureSourceFor(String tankId) =>
      _entry(tankId)?.source ?? PressureSource.unknown;

  @override
  List<Object?> get props => [
    index,
    runtimeSeconds,
    depthMeters,
    compartments,
    gfLowCeilingAnchor,
    cnsPercent,
    otu,
    activeTankId,
    tankPressures,
    sacLitersPerMin,
    sacSource,
  ];
}
