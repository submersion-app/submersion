import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/entities/profile_gas_segment.dart';
import 'package:submersion/core/deco/entities/tissue_compartment.dart';
import 'package:submersion/features/dive_lab/domain/entities/dive_scenario.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_settings.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// A recorded gas switch on the primary profile: from [timestamp] the diver
/// breathed [tankId].
class ScenarioGasSwitch extends Equatable {
  const ScenarioGasSwitch({required this.timestamp, required this.tankId});
  final int timestamp;
  final String tankId;
  @override
  List<Object?> get props => [timestamp, tankId];
}

/// One point of a tank's recorded pressure series.
class TankPressureSample extends Equatable {
  const TankPressureSample({
    required this.timestamp,
    required this.pressureBar,
  });
  final int timestamp;
  final double pressureBar;
  @override
  List<Object?> get props => [timestamp, pressureBar];
}

/// Everything the engine needs, isolate-safe, assembled by the provider layer.
class ScenarioRequest extends Equatable {
  const ScenarioRequest({
    required this.diveId,
    required this.depths,
    required this.timestamps,
    this.diveMode = DiveMode.oc,
    this.tanks = const [],
    this.gasSwitches = const [],
    this.tankPressures = const {},
    this.loopGasSegments,
    this.rebreatherPpO2Curve,
    this.setpointHigh,
    this.setpointLow,
    this.startCompartments,
    this.startCns = 0.0,
    this.startOtu = 0.0,
    this.fallbackSacLpm,
    this.settings = const ScenarioSettings(),
    required this.scenario,
  });

  final String diveId;
  final List<double> depths;
  final List<int> timestamps;
  final DiveMode diveMode;
  final List<DiveTank> tanks;
  final List<ScenarioGasSwitch> gasSwitches;
  final Map<String, List<TankPressureSample>> tankPressures;

  /// CCR/SCR: diluent + setpoint segments built by the provider (the engine
  /// does not derive loop gas itself in Phase 1).
  final List<ProfileGasSegment>? loopGasSegments;
  final List<double>? rebreatherPpO2Curve;
  final double? setpointHigh;
  final double? setpointLow;

  /// Repetitive-dive seeds, mirroring the dive detail page.
  final List<TissueCompartment>? startCompartments;
  final double startCns;
  final double startOtu;

  /// The diver's logged average SAC (L/min), used when the dive has none.
  final double? fallbackSacLpm;
  final ScenarioSettings settings;
  final DiveScenario scenario;

  int get sampleCount => depths.length;

  @override
  List<Object?> get props => [
    diveId,
    depths,
    timestamps,
    diveMode,
    tanks,
    gasSwitches,
    tankPressures,
    loopGasSegments,
    rebreatherPpO2Curve,
    setpointHigh,
    setpointLow,
    startCompartments,
    startCns,
    startOtu,
    fallbackSacLpm,
    settings,
    scenario,
  ];
}
