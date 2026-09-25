import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/deco/entities/cns_calculation_method.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/core/deco/schedule_policy.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

/// Everything the engine needs from diver settings and the dive, resolved by
/// the provider layer exactly as profile_analysis_provider does (per-dive GF
/// only when both values are present, else the diver settings).
class ScenarioSettings extends Equatable {
  const ScenarioSettings({
    this.gfLow = 0.30,
    this.gfHigh = 0.70,
    this.ppO2Working = 1.4,
    this.ppO2Deco = 1.6,
    this.cnsWarningThreshold = 80,
    this.ascentRateWarning = 9.0,
    this.ascentRateCritical = 12.0,
    this.lastStopDepth = 3.0,
    this.stopIncrement = 3.0,
    this.ascentRate = 9.0,
    this.descentRate = 18.0,
    this.gasSwitchStopSeconds = 0,
    this.airBreaks,
    this.altitudeMeters,
    this.waterType,
    this.surfacePressureBar,
    this.cnsMethod = CnsCalculationMethod.shearwater,
    this.gasModel = GasModel.real,
    this.o2Narcotic = true,
    this.defaultSacLpm = 15.0,
    this.buddyFactor = 2.0,
    this.reservePressureBar = 50.0,
  });

  /// Fractions (0-1).
  final double gfLow;
  final double gfHigh;
  final double ppO2Working;
  final double ppO2Deco;
  final int cnsWarningThreshold;
  final double ascentRateWarning;
  final double ascentRateCritical;
  final double lastStopDepth;
  final double stopIncrement;
  final double ascentRate;
  final double descentRate;
  final int gasSwitchStopSeconds;
  final AirBreakPolicy? airBreaks;
  final double? altitudeMeters;
  final WaterType? waterType;

  /// Measured surface pressure (bar); wins over [altitudeMeters] when set,
  /// exactly as the dive detail analysis resolves its environment.
  final double? surfacePressureBar;
  final CnsCalculationMethod cnsMethod;
  final GasModel gasModel;
  final bool o2Narcotic;

  /// Last-resort SAC (L/min) when the dive offers no measurement.
  final double defaultSacLpm;
  final double buddyFactor;
  final double reservePressureBar;

  /// Mirrors profile_analysis_provider: altitude, water type and surface
  /// pressure straight from the dive (PlanEngine applies its own "altitude
  /// <= 0 is unset" rule to the altitude it receives separately).
  DiveEnvironment get environment => DiveEnvironment.forConditions(
    altitudeMeters: altitudeMeters,
    waterType: waterType,
    surfacePressureBar: surfacePressureBar,
  );

  int get gfLowPercent => (gfLow * 100).round();
  int get gfHighPercent => (gfHigh * 100).round();

  ScenarioSettings withGf({required int low, required int high}) =>
      copyWith(gfLow: low / 100.0, gfHigh: high / 100.0);

  PlanEngineConfig get engineConfig => PlanEngineConfig(
    ppO2Working: ppO2Working,
    ppO2Deco: ppO2Deco,
    cnsWarningThreshold: cnsWarningThreshold,
    o2Narcotic: o2Narcotic,
    buddyFactor: buddyFactor,
    cnsMethod: cnsMethod,
    gasModel: gasModel,
  );

  ProfileAnalysisService buildAnalysisService() => ProfileAnalysisService(
    ascentRateWarning: ascentRateWarning,
    ascentRateCritical: ascentRateCritical,
    ppO2WarningThreshold: ppO2Working,
    ppO2CriticalThreshold: ppO2Deco,
    cnsWarningThreshold: cnsWarningThreshold,
    gfLow: gfLow,
    gfHigh: gfHigh,
    lastStopDepth: lastStopDepth,
    decoStopIncrement: stopIncrement,
    environment: environment,
    cnsCalculationMethod: cnsMethod,
  );

  ScenarioSettings copyWith({
    double? gfLow,
    double? gfHigh,
    double? ppO2Working,
    double? ppO2Deco,
    int? cnsWarningThreshold,
    double? ascentRateWarning,
    double? ascentRateCritical,
    double? lastStopDepth,
    double? stopIncrement,
    double? ascentRate,
    double? descentRate,
    int? gasSwitchStopSeconds,
    AirBreakPolicy? airBreaks,
    double? altitudeMeters,
    WaterType? waterType,
    double? surfacePressureBar,
    CnsCalculationMethod? cnsMethod,
    GasModel? gasModel,
    bool? o2Narcotic,
    double? defaultSacLpm,
    double? buddyFactor,
    double? reservePressureBar,
  }) {
    return ScenarioSettings(
      gfLow: gfLow ?? this.gfLow,
      gfHigh: gfHigh ?? this.gfHigh,
      ppO2Working: ppO2Working ?? this.ppO2Working,
      ppO2Deco: ppO2Deco ?? this.ppO2Deco,
      cnsWarningThreshold: cnsWarningThreshold ?? this.cnsWarningThreshold,
      ascentRateWarning: ascentRateWarning ?? this.ascentRateWarning,
      ascentRateCritical: ascentRateCritical ?? this.ascentRateCritical,
      lastStopDepth: lastStopDepth ?? this.lastStopDepth,
      stopIncrement: stopIncrement ?? this.stopIncrement,
      ascentRate: ascentRate ?? this.ascentRate,
      descentRate: descentRate ?? this.descentRate,
      gasSwitchStopSeconds: gasSwitchStopSeconds ?? this.gasSwitchStopSeconds,
      airBreaks: airBreaks ?? this.airBreaks,
      altitudeMeters: altitudeMeters ?? this.altitudeMeters,
      waterType: waterType ?? this.waterType,
      surfacePressureBar: surfacePressureBar ?? this.surfacePressureBar,
      cnsMethod: cnsMethod ?? this.cnsMethod,
      gasModel: gasModel ?? this.gasModel,
      o2Narcotic: o2Narcotic ?? this.o2Narcotic,
      defaultSacLpm: defaultSacLpm ?? this.defaultSacLpm,
      buddyFactor: buddyFactor ?? this.buddyFactor,
      reservePressureBar: reservePressureBar ?? this.reservePressureBar,
    );
  }

  @override
  List<Object?> get props => [
    gfLow,
    gfHigh,
    ppO2Working,
    ppO2Deco,
    cnsWarningThreshold,
    ascentRateWarning,
    ascentRateCritical,
    lastStopDepth,
    stopIncrement,
    ascentRate,
    descentRate,
    gasSwitchStopSeconds,
    airBreaks,
    altitudeMeters,
    waterType,
    surfacePressureBar,
    cnsMethod,
    gasModel,
    o2Narcotic,
    defaultSacLpm,
    buddyFactor,
    reservePressureBar,
  ];
}
