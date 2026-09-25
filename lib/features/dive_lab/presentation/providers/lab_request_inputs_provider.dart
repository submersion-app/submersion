import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/entities/gradient_factor_source.dart';
import 'package:submersion/core/deco/entities/profile_gas_segment.dart';
import 'package:submersion/core/deco/entities/tissue_compartment.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_lab/domain/entities/dive_scenario.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_request.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_settings.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Everything the lab needs about a dive, assembled from the same providers
/// the dive detail analysis uses, minus the scenario itself.
class LabRequestInputs {
  const LabRequestInputs({
    required this.dive,
    required this.profile,
    required this.depths,
    required this.timestamps,
    required this.diveMode,
    required this.tanks,
    required this.gasSwitches,
    required this.tankPressures,
    this.loopGasSegments,
    this.rebreatherPpO2Curve,
    this.setpointHigh,
    this.setpointLow,
    this.startCompartments,
    required this.startCns,
    required this.startOtu,
    this.fallbackSacLpm,
    required this.settings,
  });

  final Dive dive;
  final List<DiveProfilePoint> profile;
  final List<double> depths;
  final List<int> timestamps;
  final DiveMode diveMode;
  final List<DiveTank> tanks;
  final List<ScenarioGasSwitch> gasSwitches;
  final Map<String, List<TankPressureSample>> tankPressures;
  final List<ProfileGasSegment>? loopGasSegments;
  final List<double>? rebreatherPpO2Curve;
  final double? setpointHigh;
  final double? setpointLow;
  final List<TissueCompartment>? startCompartments;
  final double startCns;
  final double startOtu;
  final double? fallbackSacLpm;
  final ScenarioSettings settings;

  int get durationSeconds =>
      timestamps.isEmpty ? 0 : timestamps.last - timestamps.first;

  ScenarioRequest toRequest(DiveScenario scenario) => ScenarioRequest(
    diveId: dive.id,
    depths: depths,
    timestamps: timestamps,
    diveMode: diveMode,
    tanks: tanks,
    gasSwitches: gasSwitches,
    tankPressures: tankPressures,
    loopGasSegments: loopGasSegments,
    rebreatherPpO2Curve: rebreatherPpO2Curve,
    setpointHigh: setpointHigh,
    setpointLow: setpointLow,
    startCompartments: startCompartments,
    startCns: startCns,
    startOtu: startOtu,
    fallbackSacLpm: fallbackSacLpm,
    settings: settings,
    scenario: scenario,
  );
}

/// Null when the dive is ineligible: gauge mode, or fewer than two primary
/// profile samples.
final labRequestInputsProvider =
    FutureProvider.family<LabRequestInputs?, String>((ref, diveId) async {
      final dive = await ref.watch(diveProvider(diveId).future);
      if (dive == null || dive.isGauge) return null;
      final profile = await ref.watch(diveProfileProvider(diveId).future);
      if (profile.length < 2) return null;

      final switches = await ref.watch(gasSwitchesProvider(diveId).future);
      final pressures = await ref.watch(tankPressuresProvider(diveId).future);
      final startCompartments = await ref.watch(
        residualTissueStateProvider(diveId).future,
      );
      final startCns = await ref.watch(residualCnsProvider(diveId).future);
      final startOtu = await ref.watch(residualOtuProvider(diveId).future);
      final fallbackSac = await ref.watch(loggedAverageSacProvider.future);

      final gf = GradientFactorSource.resolve(
        diveGfLow: dive.gradientFactorLow,
        diveGfHigh: dive.gradientFactorHigh,
        settingsGfLow: ref.watch(gfLowProvider),
        settingsGfHigh: ref.watch(gfHighProvider),
        recordedAlgorithm: dive.decoAlgorithm,
      );
      final engineConfig = ref.watch(planEngineConfigProvider);
      final settings = ScenarioSettings(
        gfLow: gf.lowFraction,
        gfHigh: gf.highFraction,
        ppO2Working: ref.watch(ppO2MaxWorkingProvider),
        ppO2Deco: ref.watch(ppO2MaxDecoProvider),
        cnsWarningThreshold: ref.watch(cnsWarningThresholdProvider),
        ascentRateWarning: ref.watch(ascentRateWarningProvider),
        ascentRateCritical: ref.watch(ascentRateCriticalProvider),
        lastStopDepth: ref.watch(lastStopDepthProvider),
        stopIncrement: ref.watch(decoStopIncrementProvider),
        altitudeMeters: dive.altitude,
        waterType: dive.waterType,
        surfacePressureBar: dive.surfacePressure,
        cnsMethod: ref.watch(cnsCalculationMethodProvider),
        gasModel: ref.watch(gasModelProvider),
        o2Narcotic: ref.watch(settingsProvider.select((s) => s.o2Narcotic)),
        buddyFactor: engineConfig.buddyFactor,
      );

      final timestamps = [for (final p in profile) p.timestamp];
      final depths = [for (final p in profile) p.depth];
      final rebreather = dive.diveMode == DiveMode.oc
          ? null
          : resolveRebreatherPpO2(profile);
      final loopGas = dive.diveMode == DiveMode.ccr
          ? buildCcrProfileGasSegments(
              timestamps: timestamps,
              loopPpO2Curve: rebreather?.curve,
              diluentMix: resolveCcrDiluentMix(dive),
              fallbackSetpoint: dive.setpointHigh ?? dive.setpointLow,
            )
          : null;

      return LabRequestInputs(
        dive: dive,
        profile: profile,
        depths: depths,
        timestamps: timestamps,
        diveMode: dive.diveMode,
        tanks: dive.tanks,
        gasSwitches: [
          for (final s in switches)
            ScenarioGasSwitch(timestamp: s.timestamp, tankId: s.tankId),
        ],
        tankPressures: {
          for (final entry in pressures.entries)
            entry.key: [
              for (final p in entry.value)
                TankPressureSample(
                  timestamp: p.timestamp,
                  pressureBar: p.pressure,
                ),
            ],
        },
        loopGasSegments: loopGas,
        rebreatherPpO2Curve: rebreather?.curve,
        setpointHigh: dive.setpointHigh,
        setpointLow: dive.setpointLow,
        startCompartments: startCompartments,
        startCns: startCns,
        startOtu: startOtu,
        fallbackSacLpm: fallbackSac,
        settings: settings,
      );
    });
