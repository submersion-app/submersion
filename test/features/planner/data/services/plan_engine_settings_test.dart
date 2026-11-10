import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/deco/entities/cns_calculation_method.dart';
import 'package:submersion/core/deco/schedule_policy.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/planner/data/services/plan_engine_settings.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    show TurnPressureRule;
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier(super.state);

  void replace(AppSettings settings) => state = settings;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Every setting the planner reads, each away from its default.
const _changed = AppSettings(
  ppO2MaxWorking: 1.2,
  ppO2MaxDeco: 1.5,
  ppO2DecoBandsEnabled: true,
  ppO2DecoBand1: 1.45,
  ppO2DecoBand2: 1.4,
  ppO2DecoBand3: 1.35,
  maxO2DepthEnabled: true,
  maxO2DepthMeters: 4.5,
  plannerHypercapniaEnabled: true,
  plannerHypercapniaFactor: 3.0,
  plannerHypercapniaMinutes: 7,
  ccrDiluentModPpO2: 1.4,
  ccrSetpointLow: 0.6,
  ccrSetpointHigh: 1.2,
  cnsWarningThreshold: 70,
  o2Narcotic: false,
  endLimit: 36,
  pscrRatio: 90,
  cnsCalculationMethod: CnsCalculationMethod.classic,
  gasModel: GasModel.ideal,
  plannerDescentRate: 20,
  plannerAscentRate: 10,
  plannerIntermediateAscentRate: 5,
  plannerShallowAscentRate: 2,
  plannerFinalAscentRate: 0.5,
  lastStopDepth: 6,
  plannerGasSwitchStopSeconds: 60,
  plannerSacBottom: 18,
  plannerSacDeco: 14,
  plannerSacStressedFactor: 2,
  plannerProblemSolvingMinutes: 4,
  plannerBuddyFactor: 1.5,
  plannerBestMixEndMeters: 27,
  plannerDeviationDepthDelta: 3,
  plannerDeviationTimeMinutes: 4,
  plannerTurnPressureRule: TurnPressureRule.thirds,
  plannerTurnPressureFraction: 0.4,
  plannerAirBreakO2Seconds: 1200,
  plannerAirBreakBreakSeconds: 300,
  gfLow: 30,
  gfHigh: 70,
  plannerReservePressure: 70,
  plannerBatteryReserveFraction: 0.25,
  plannerWalkSpeedMps: 1.1,
);

void main() {
  group('planEngineConfigFromSettings', () {
    test('carries every planner setting', () {
      final c = planEngineConfigFromSettings(_changed);
      expect(c.ppO2Working, 1.2);
      expect(c.ppO2Deco, 1.5);
      expect(c.ppO2DecoBandsEnabled, isTrue);
      expect(c.ppO2DecoBand1, 1.45);
      expect(c.ppO2DecoBand2, 1.4);
      expect(c.ppO2DecoBand3, 1.35);
      expect(c.maxO2DepthEnabled, isTrue);
      expect(c.maxO2DepthMeters, 4.5);
      expect(c.hypercapniaEnabled, isTrue);
      expect(c.hypercapniaFactor, 3.0);
      expect(c.hypercapniaMinutes, 7);
      expect(c.ccrDiluentModPpO2, 1.4);
      expect(c.ccrSetpointLow, 0.6);
      expect(c.ccrSetpointHigh, 1.2);
      expect(c.cnsWarningThreshold, 70);
      expect(c.o2Narcotic, isFalse);
      expect(c.endLimitMeters, 36);
      expect(c.pscrRatio, 90);
      expect(c.cnsMethod, CnsCalculationMethod.classic);
      expect(c.gasModel, GasModel.ideal);
      expect(c.descentRate, 20);
      expect(c.ascentRate, 10);
      expect(c.intermediateAscentRate, 5);
      expect(c.shallowAscentRate, 2);
      expect(c.finalAscentRate, 0.5);
      expect(c.lastStopDepth, 6);
      expect(c.gasSwitchStopSeconds, 60);
      expect(c.sacBottom, 18);
      expect(c.sacDeco, 14);
      expect(c.sacStressedFactor, 2);
      expect(c.problemSolvingMinutes, 4);
      expect(c.buddyFactor, 1.5);
      expect(c.bestMixEndMeters, 27);
      expect(c.deviationDepthDelta, 3);
      expect(c.deviationTimeMinutes, 4);
      expect(c.turnPressureRule, TurnPressureRule.thirds);
      expect(c.turnPressureFraction, 0.4);
      expect(
        c.airBreakPolicy,
        const AirBreakPolicy(o2Seconds: 1200, breakSeconds: 300),
      );
      expect(c.gfLow, 30);
      expect(c.gfHigh, 70);
      expect(c.reservePressure, 70);
      expect(c.batteryReserveFraction, 0.25);
      expect(c.walkSpeedMps, 1.1);
    });

    test('default settings give the default config', () {
      expect(
        planEngineConfigFromSettings(const AppSettings()),
        const PlanEngineConfig(),
      );
    });

    test('no air breaks unless both air-break settings are set', () {
      expect(
        planEngineConfigFromSettings(
          const AppSettings(plannerAirBreakO2Seconds: 1200),
        ).airBreakPolicy,
        isNull,
      );
      expect(
        planEngineConfigFromSettings(
          const AppSettings(plannerAirBreakBreakSeconds: 300),
        ).airBreakPolicy,
        isNull,
      );
    });

    test('the same settings give equal configs', () {
      expect(
        planEngineConfigFromSettings(_changed),
        planEngineConfigFromSettings(_changed),
      );
    });
  });

  group('planEngineConfigProvider', () {
    ProviderContainer containerWith(_TestSettingsNotifier notifier) {
      final container = ProviderContainer(
        overrides: [settingsProvider.overrideWith((ref) => notifier)],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('is the config the active diver\'s settings give', () {
      final container = containerWith(_TestSettingsNotifier(_changed));
      expect(
        container.read(planEngineConfigProvider),
        planEngineConfigFromSettings(_changed),
      );
    });

    test('does not notify for a setting the planner does not read', () {
      final notifier = _TestSettingsNotifier(_changed);
      final container = containerWith(notifier);
      var notified = 0;
      container.listen(planEngineConfigProvider, (_, _) => notified++);

      notifier.replace(_changed.copyWith(depthUnit: DepthUnit.feet));
      container.read(planEngineConfigProvider);
      expect(notified, 0);

      notifier.replace(_changed.copyWith(gfHigh: 75));
      expect(container.read(planEngineConfigProvider).gfHigh, 75);
      expect(notified, 1);
    });
  });
}
