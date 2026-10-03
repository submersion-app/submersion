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
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

/// One config per field, each differing from the defaults in that field
/// alone. Keyed by field name so the source check below can prove the map
/// covers every field the class declares.
final Map<String, PlanEngineConfig> _oneFieldChanged = {
  'ppO2Working': PlanEngineConfig(ppO2Working: 1.2),
  'ppO2Deco': PlanEngineConfig(ppO2Deco: 1.5),
  'ccrDiluentModPpO2': PlanEngineConfig(ccrDiluentModPpO2: 1.5),
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
};

/// The same one-field changes as [_oneFieldChanged], made through copyWith,
/// so each entry proves its copyWith argument sets that field and no other.
final Map<String, PlanEngineConfig Function(PlanEngineConfig)> _copyOneField = {
  'ppO2Working': (c) => c.copyWith(ppO2Working: 1.2),
  'ppO2Deco': (c) => c.copyWith(ppO2Deco: 1.5),
  'ccrDiluentModPpO2': (c) => c.copyWith(ccrDiluentModPpO2: 1.5),
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
  bool o2Narcotic = false,
  double bestMixEndMeters = 35,
  double buddyFactor = 1.5,
}) => PlanEngineConfig(
  ppO2Working: ppO2Working,
  ppO2Deco: ppO2Deco,
  ccrDiluentModPpO2: 1.5,
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
);

/// A plan that overrides nothing: its nullable gas options are unset, and
/// the two it always supplies (`sacFactor`, `bestMixEndMeters`) sit at their
/// defaults, which differ from [_everyFieldChanged].
domain.DivePlan _plan({
  double? ppO2Bottom,
  double? ppO2Deco,
  bool? o2Narcotic,
  double sacFactor = 2.0,
  double bestMixEndMeters = 30.0,
}) {
  final now = DateTime.utc(2026, 9, 30);
  return domain.DivePlan(
    id: 'plan-1',
    name: 'resolvedFor test',
    createdAt: now,
    updatedAt: now,
    gfLow: 40,
    gfHigh: 80,
    ppO2Bottom: ppO2Bottom,
    ppO2Deco: ppO2Deco,
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

      // sacFactor and bestMixEndMeters always come from the plan; every
      // other field is the config's own.
      expect(
        resolved,
        _everyFieldChanged(buddyFactor: 2.0, bestMixEndMeters: 30.0),
      );
    });

    test('a plan with overrides replaces exactly the fields it sets', () {
      final config = _everyFieldChanged();
      final plan = _plan(
        ppO2Bottom: 1.3,
        ppO2Deco: 1.55,
        o2Narcotic: true,
        sacFactor: 1.8,
        bestMixEndMeters: 33,
      );

      expect(
        config.resolvedFor(plan),
        _everyFieldChanged(
          ppO2Working: 1.3,
          ppO2Deco: 1.55,
          o2Narcotic: true,
          buddyFactor: 1.8,
          bestMixEndMeters: 33,
        ),
      );
    });
  });
}
