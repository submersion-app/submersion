// Instances here are deliberately non-const: const instances canonicalise to
// a single instance, so == short-circuits on identity and the fields under
// test are never compared.
// ignore_for_file: prefer_const_constructors

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/deco/entities/cns_calculation_method.dart';
import 'package:submersion/core/deco/schedule_policy.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

/// AirBreakPolicy has no value equality of its own (plain fields, no
/// Equatable), so the fixture and its copyWith counterpart must share one
/// instance - two separately built ones with identical fields would compare
/// unequal and fail "copyWith airBreakPolicy replaces only that field".
final _testAirBreakPolicy = AirBreakPolicy(o2Seconds: 100, breakSeconds: 50);

/// One config per field, each differing from the defaults in that field
/// alone. Keyed by field name so the source check below can prove the map
/// covers every field the class declares.
final Map<String, PlanEngineConfig> _oneFieldChanged = {
  'ppO2Working': PlanEngineConfig(ppO2Working: 1.2),
  'ppO2Deco': PlanEngineConfig(ppO2Deco: 1.5),
  'ppO2DecoBandsEnabled': PlanEngineConfig(ppO2DecoBandsEnabled: true),
  'ppO2DecoBand1': PlanEngineConfig(ppO2DecoBand1: 1.3),
  'ppO2DecoBand2': PlanEngineConfig(ppO2DecoBand2: 1.25),
  'ppO2DecoBand3': PlanEngineConfig(ppO2DecoBand3: 1.2),
  'maxO2DepthEnabled': PlanEngineConfig(maxO2DepthEnabled: true),
  'maxO2DepthMeters': PlanEngineConfig(maxO2DepthMeters: 4.5),
  'hypercapniaEnabled': PlanEngineConfig(hypercapniaEnabled: true),
  'hypercapniaFactor': PlanEngineConfig(hypercapniaFactor: 3.0),
  'hypercapniaMinutes': PlanEngineConfig(hypercapniaMinutes: 3),
  'ccrDiluentModPpO2': PlanEngineConfig(ccrDiluentModPpO2: 1.5),
  'ccrSetpointLow': PlanEngineConfig(ccrSetpointLow: 0.6),
  'ccrSetpointHigh': PlanEngineConfig(ccrSetpointHigh: 1.2),
  'cnsWarningThreshold': PlanEngineConfig(cnsWarningThreshold: 70),
  'o2Narcotic': PlanEngineConfig(o2Narcotic: false),
  'endLimitMeters': PlanEngineConfig(endLimitMeters: 40),
  'bestMixEndMeters': PlanEngineConfig(bestMixEndMeters: 35),
  'otuLimit': PlanEngineConfig(otuLimit: 250),
  'o2MetabolicRateLpm': PlanEngineConfig(o2MetabolicRateLpm: 0.8),
  'loopVolumeLiters': PlanEngineConfig(loopVolumeLiters: 7),
  'buddyFactor': PlanEngineConfig(buddyFactor: 1.5),
  'scrInjectionRateLpm': PlanEngineConfig(scrInjectionRateLpm: 10),
  'pscrO2ConsumptionMlMin': PlanEngineConfig(pscrO2ConsumptionMlMin: 800),
  'pscrSacMlMin': PlanEngineConfig(pscrSacMlMin: 18000),
  'pscrRatio': PlanEngineConfig(pscrRatio: 90),
  'cnsMethod': PlanEngineConfig(cnsMethod: CnsCalculationMethod.subsurface),
  'gasModel': PlanEngineConfig(gasModel: GasModel.ideal),
  'descentRate': PlanEngineConfig(descentRate: 24.0),
  'ascentRate': PlanEngineConfig(ascentRate: 12.0),
  'intermediateAscentRate': PlanEngineConfig(intermediateAscentRate: 8.0),
  'shallowAscentRate': PlanEngineConfig(shallowAscentRate: 4.0),
  'finalAscentRate': PlanEngineConfig(finalAscentRate: 2.0),
  'lastStopDepth': PlanEngineConfig(lastStopDepth: 4.5),
  'gasSwitchStopSeconds': PlanEngineConfig(gasSwitchStopSeconds: 60),
  'sacBottom': PlanEngineConfig(sacBottom: 20.0),
  'sacDeco': PlanEngineConfig(sacDeco: 12.0),
  'sacStressedFactor': PlanEngineConfig(sacStressedFactor: 3.0),
  'problemSolvingMinutes': PlanEngineConfig(problemSolvingMinutes: 5),
  'deviationDepthDelta': PlanEngineConfig(deviationDepthDelta: 6.0),
  'deviationTimeMinutes': PlanEngineConfig(deviationTimeMinutes: 8),
  'turnPressureRule': PlanEngineConfig(
    turnPressureRule: domain.TurnPressureRule.thirds,
  ),
  'turnPressureFraction': PlanEngineConfig(turnPressureFraction: 0.4),
  'airBreakPolicy': PlanEngineConfig(airBreakPolicy: _testAirBreakPolicy),
  'gfLow': PlanEngineConfig(gfLow: 35),
  'gfHigh': PlanEngineConfig(gfHigh: 75),
  'reservePressure': PlanEngineConfig(reservePressure: 70.0),
  'batteryReserveFraction': PlanEngineConfig(batteryReserveFraction: 0.5),
  'walkSpeedMps': PlanEngineConfig(walkSpeedMps: 1.2),
};

/// The same one-field changes as [_oneFieldChanged], made through copyWith,
/// so each entry proves its copyWith argument sets that field and no other.
final Map<String, PlanEngineConfig Function(PlanEngineConfig)> _copyOneField = {
  'ppO2Working': (c) => c.copyWith(ppO2Working: 1.2),
  'ppO2Deco': (c) => c.copyWith(ppO2Deco: 1.5),
  'ppO2DecoBandsEnabled': (c) => c.copyWith(ppO2DecoBandsEnabled: true),
  'ppO2DecoBand1': (c) => c.copyWith(ppO2DecoBand1: 1.3),
  'ppO2DecoBand2': (c) => c.copyWith(ppO2DecoBand2: 1.25),
  'ppO2DecoBand3': (c) => c.copyWith(ppO2DecoBand3: 1.2),
  'maxO2DepthEnabled': (c) => c.copyWith(maxO2DepthEnabled: true),
  'maxO2DepthMeters': (c) => c.copyWith(maxO2DepthMeters: 4.5),
  'hypercapniaEnabled': (c) => c.copyWith(hypercapniaEnabled: true),
  'hypercapniaFactor': (c) => c.copyWith(hypercapniaFactor: 3.0),
  'hypercapniaMinutes': (c) => c.copyWith(hypercapniaMinutes: 3),
  'ccrDiluentModPpO2': (c) => c.copyWith(ccrDiluentModPpO2: 1.5),
  'ccrSetpointLow': (c) => c.copyWith(ccrSetpointLow: 0.6),
  'ccrSetpointHigh': (c) => c.copyWith(ccrSetpointHigh: 1.2),
  'cnsWarningThreshold': (c) => c.copyWith(cnsWarningThreshold: 70),
  'o2Narcotic': (c) => c.copyWith(o2Narcotic: false),
  'endLimitMeters': (c) => c.copyWith(endLimitMeters: 40),
  'bestMixEndMeters': (c) => c.copyWith(bestMixEndMeters: 35),
  'otuLimit': (c) => c.copyWith(otuLimit: 250),
  'o2MetabolicRateLpm': (c) => c.copyWith(o2MetabolicRateLpm: 0.8),
  'loopVolumeLiters': (c) => c.copyWith(loopVolumeLiters: 7),
  'buddyFactor': (c) => c.copyWith(buddyFactor: 1.5),
  'scrInjectionRateLpm': (c) => c.copyWith(scrInjectionRateLpm: 10),
  'pscrO2ConsumptionMlMin': (c) => c.copyWith(pscrO2ConsumptionMlMin: 800),
  'pscrSacMlMin': (c) => c.copyWith(pscrSacMlMin: 18000),
  'pscrRatio': (c) => c.copyWith(pscrRatio: 90),
  'cnsMethod': (c) => c.copyWith(cnsMethod: CnsCalculationMethod.subsurface),
  'gasModel': (c) => c.copyWith(gasModel: GasModel.ideal),
  'descentRate': (c) => c.copyWith(descentRate: 24.0),
  'ascentRate': (c) => c.copyWith(ascentRate: 12.0),
  'intermediateAscentRate': (c) => c.copyWith(intermediateAscentRate: 8.0),
  'shallowAscentRate': (c) => c.copyWith(shallowAscentRate: 4.0),
  'finalAscentRate': (c) => c.copyWith(finalAscentRate: 2.0),
  'lastStopDepth': (c) => c.copyWith(lastStopDepth: 4.5),
  'gasSwitchStopSeconds': (c) => c.copyWith(gasSwitchStopSeconds: 60),
  'sacBottom': (c) => c.copyWith(sacBottom: 20.0),
  'sacDeco': (c) => c.copyWith(sacDeco: 12.0),
  'sacStressedFactor': (c) => c.copyWith(sacStressedFactor: 3.0),
  'problemSolvingMinutes': (c) => c.copyWith(problemSolvingMinutes: 5),
  'deviationDepthDelta': (c) => c.copyWith(deviationDepthDelta: 6.0),
  'deviationTimeMinutes': (c) => c.copyWith(deviationTimeMinutes: 8),
  'turnPressureRule': (c) =>
      c.copyWith(turnPressureRule: domain.TurnPressureRule.thirds),
  'turnPressureFraction': (c) => c.copyWith(turnPressureFraction: 0.4),
  'airBreakPolicy': (c) => c.copyWith(airBreakPolicy: _testAirBreakPolicy),
  'gfLow': (c) => c.copyWith(gfLow: 35),
  'gfHigh': (c) => c.copyWith(gfHigh: 75),
  'reservePressure': (c) => c.copyWith(reservePressure: 70.0),
  'batteryReserveFraction': (c) => c.copyWith(batteryReserveFraction: 0.5),
  'walkSpeedMps': (c) => c.copyWith(walkSpeedMps: 1.2),
};

/// A config with every field away from its default, so a field that
/// resolvedFor or copyWith fails to carry over shows up as a changed value.
///
/// Built with the constructor, never copyWith: a copyWith that dropped a
/// field's `?? this.x` fallback would otherwise reset that field while the
/// fixture was being built, and every test below would compare defaults.
/// The parameters are the fields a plan can override, so resolvedFor
/// expectations are built the same way.
PlanEngineConfig _everyFieldChanged({
  double ppO2Working = 1.2,
  double ppO2Deco = 1.5,
  double ppO2DecoBand1 = 1.3,
  double ppO2DecoBand2 = 1.25,
  double ppO2DecoBand3 = 1.2,
  double maxO2DepthMeters = 4.5,
  bool o2Narcotic = false,
  double bestMixEndMeters = 35,
  double buddyFactor = 1.5,
  int gfLow = 35,
  int gfHigh = 75,
}) => PlanEngineConfig(
  ppO2Working: ppO2Working,
  ppO2Deco: ppO2Deco,
  ppO2DecoBandsEnabled: true,
  ppO2DecoBand1: ppO2DecoBand1,
  ppO2DecoBand2: ppO2DecoBand2,
  ppO2DecoBand3: ppO2DecoBand3,
  maxO2DepthEnabled: true,
  maxO2DepthMeters: maxO2DepthMeters,
  hypercapniaEnabled: true,
  hypercapniaFactor: 3.0,
  hypercapniaMinutes: 3,
  ccrDiluentModPpO2: 1.5,
  ccrSetpointLow: 0.6,
  ccrSetpointHigh: 1.2,
  cnsWarningThreshold: 70,
  o2Narcotic: o2Narcotic,
  endLimitMeters: 40,
  bestMixEndMeters: bestMixEndMeters,
  otuLimit: 250,
  o2MetabolicRateLpm: 0.8,
  loopVolumeLiters: 7,
  buddyFactor: buddyFactor,
  scrInjectionRateLpm: 10,
  pscrO2ConsumptionMlMin: 800,
  pscrSacMlMin: 18000,
  pscrRatio: 90,
  cnsMethod: CnsCalculationMethod.subsurface,
  gasModel: GasModel.ideal,
  descentRate: 24.0,
  ascentRate: 12.0,
  intermediateAscentRate: 8.0,
  shallowAscentRate: 4.0,
  finalAscentRate: 2.0,
  lastStopDepth: 4.5,
  gasSwitchStopSeconds: 60,
  sacBottom: 20.0,
  sacDeco: 12.0,
  sacStressedFactor: 3.0,
  problemSolvingMinutes: 5,
  deviationDepthDelta: 6.0,
  deviationTimeMinutes: 8,
  turnPressureRule: domain.TurnPressureRule.thirds,
  turnPressureFraction: 0.4,
  airBreakPolicy: _testAirBreakPolicy,
  gfLow: gfLow,
  gfHigh: gfHigh,
  reservePressure: 70.0,
  batteryReserveFraction: 0.5,
  walkSpeedMps: 1.2,
);

/// A plan that overrides nothing: its nullable gas options are unset, and
/// the two it always supplies (`sacFactor`, `bestMixEndMeters`) sit at their
/// defaults, which differ from [_everyFieldChanged].
domain.DivePlan _plan({
  double? ppO2Bottom,
  double? ppO2Deco,
  double? ppO2DecoBand1,
  double? ppO2DecoBand2,
  double? ppO2DecoBand3,
  double? maxO2DepthMeters,
  bool ppO2DecoBandsExplicitlyOff = false,
  bool maxO2DepthExplicitlyOff = false,
  bool? o2Narcotic,
  double sacFactor = 2.0,
  double bestMixEndMeters = 30.0,
  int gfLow = 40,
  int gfHigh = 80,
}) {
  final now = DateTime.utc(2026, 9, 30);
  return domain.DivePlan(
    id: 'plan-1',
    name: 'resolvedFor test',
    createdAt: now,
    updatedAt: now,
    gfLow: gfLow,
    gfHigh: gfHigh,
    ppO2Bottom: ppO2Bottom,
    ppO2Deco: ppO2Deco,
    ppO2DecoBand1: ppO2DecoBand1,
    ppO2DecoBand2: ppO2DecoBand2,
    ppO2DecoBand3: ppO2DecoBand3,
    maxO2DepthMeters: maxO2DepthMeters,
    ppO2DecoBandsExplicitlyOff: ppO2DecoBandsExplicitlyOff,
    maxO2DepthExplicitlyOff: maxO2DepthExplicitlyOff,
    o2Narcotic: o2Narcotic,
    sacFactor: sacFactor,
    bestMixEndMeters: bestMixEndMeters,
  );
}

/// The instance fields `PlanEngineConfig` declares, read from its source so
/// a field added later is caught here even if nobody updates this test.
Set<String> _declaredFields() {
  final file = File(
    p.join(
      Directory.current.path,
      'lib',
      'features',
      'planner',
      'domain',
      'services',
      'plan_engine.dart',
    ),
  );
  expect(
    file.existsSync(),
    isTrue,
    reason:
        'the check must read the real plan_engine.dart; a wrong working '
        'directory would make this test pass vacuously',
  );
  final unit = parseString(
    content: file.readAsStringSync(),
    path: file.path,
  ).unit;
  final config = unit.declarations.whereType<ClassDeclaration>().singleWhere(
    (c) => c.namePart.typeName.lexeme == 'PlanEngineConfig',
  );
  return {
    for (final member in (config.body as BlockClassBody).members)
      if (member is FieldDeclaration && !member.isStatic)
        for (final variable in member.fields.variables) variable.name.lexeme,
  };
}

void main() {
  test('the field list covers every field PlanEngineConfig declares', () {
    final declared = _declaredFields();
    expect(declared, isNotEmpty);
    expect(
      _oneFieldChanged.keys.toSet(),
      declared,
      reason:
          'add the new field to _oneFieldChanged, and to the equality of '
          'PlanEngineConfig, so a change to it reaches the planner',
    );
    expect(
      _copyOneField.keys.toSet(),
      declared,
      reason: 'add the new field to _copyOneField and to copyWith',
    );
  });

  test('two configs built from the same values are equal', () {
    final a = PlanEngineConfig();
    final b = PlanEngineConfig();
    expect(identical(a, b), isFalse);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });

  for (final MapEntry(key: field, value: changed) in _oneFieldChanged.entries) {
    test('a config differing only in $field is not equal', () {
      expect(changed, isNot(PlanEngineConfig()));
    });
  }

  test('the every-field fixture differs from the defaults in every field', () {
    final changed = _everyFieldChanged().props;
    final defaults = PlanEngineConfig().props;
    expect(changed, hasLength(_declaredFields().length));
    for (var i = 0; i < changed.length; i++) {
      expect(changed[i], isNot(defaults[i]), reason: 'props[$i]');
    }
  });

  group('copyWith', () {
    test('with no arguments keeps every field', () {
      final config = _everyFieldChanged();
      expect(config.copyWith(), config);
    });

    for (final MapEntry(key: field, value: copy) in _copyOneField.entries) {
      test('$field replaces only that field', () {
        expect(copy(PlanEngineConfig()), _oneFieldChanged[field]);
      });
    }
  });

  group('resolvedFor', () {
    test('a plan with no overrides keeps every Settings-sourced field', () {
      final config = _everyFieldChanged();
      final plan = _plan();

      final resolved = config.resolvedFor(plan);

      // sacFactor, bestMixEndMeters, gfLow and gfHigh always come from the
      // plan; every other field is the config's own.
      expect(
        resolved,
        _everyFieldChanged(
          buddyFactor: 2.0,
          bestMixEndMeters: 30.0,
          gfLow: 40,
          gfHigh: 80,
        ),
      );
    });

    test('a plan with overrides replaces exactly the fields it sets', () {
      final config = _everyFieldChanged();
      final plan = _plan(
        ppO2Bottom: 1.3,
        ppO2Deco: 1.55,
        ppO2DecoBand1: 1.35,
        ppO2DecoBand2: 1.3,
        ppO2DecoBand3: 1.25,
        maxO2DepthMeters: 5.0,
        o2Narcotic: true,
        sacFactor: 1.8,
        bestMixEndMeters: 33,
        gfLow: 42,
        gfHigh: 82,
      );

      expect(
        config.resolvedFor(plan),
        _everyFieldChanged(
          ppO2Working: 1.3,
          ppO2Deco: 1.55,
          ppO2DecoBand1: 1.35,
          ppO2DecoBand2: 1.3,
          ppO2DecoBand3: 1.25,
          maxO2DepthMeters: 5.0,
          o2Narcotic: true,
          buddyFactor: 1.8,
          bestMixEndMeters: 33,
          gfLow: 42,
          gfHigh: 82,
        ),
      );
    });

    // Regression for a Copilot review finding (issue #3580 follow-up): a
    // plan's own Custom band/depth values must govern even when the
    // diver's Settings toggle is off - "Custom" is a per-plan opt-in, not
    // something the global switch can silently veto. The fixtures above
    // always build with the toggle already on and never exercise this.
    test('a plan with custom band/depth values enables them even when the '
        'Settings toggle is off', () {
      const config = PlanEngineConfig(
        ppO2DecoBandsEnabled: false,
        maxO2DepthEnabled: false,
      );
      final plan = _plan(ppO2DecoBand1: 1.35, maxO2DepthMeters: 5.0);

      final resolved = config.resolvedFor(plan);

      expect(resolved.ppO2DecoBandsEnabled, isTrue);
      expect(resolved.maxO2DepthEnabled, isTrue);
    });

    test("a plan's explicit Off still wins even with a custom value set and "
        'the Settings toggle on', () {
      const config = PlanEngineConfig(
        ppO2DecoBandsEnabled: true,
        maxO2DepthEnabled: true,
      );
      final plan = _plan(
        ppO2DecoBand1: 1.35,
        maxO2DepthMeters: 5.0,
        ppO2DecoBandsExplicitlyOff: true,
        maxO2DepthExplicitlyOff: true,
      );

      final resolved = config.resolvedFor(plan);

      expect(resolved.ppO2DecoBandsEnabled, isFalse);
      expect(resolved.maxO2DepthEnabled, isFalse);
    });

    test('a plan with no override and the Settings toggle off stays off', () {
      const config = PlanEngineConfig(
        ppO2DecoBandsEnabled: false,
        maxO2DepthEnabled: false,
      );
      final plan = _plan();

      final resolved = config.resolvedFor(plan);

      expect(resolved.ppO2DecoBandsEnabled, isFalse);
      expect(resolved.maxO2DepthEnabled, isFalse);
    });
  });
}
