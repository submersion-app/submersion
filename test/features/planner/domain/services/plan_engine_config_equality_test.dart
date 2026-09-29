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
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

/// One config per field, each differing from the defaults in that field
/// alone. Keyed by field name so the source check below can prove the map
/// covers every field the class declares.
final Map<String, PlanEngineConfig> _oneFieldChanged = {
  'ppO2Working': PlanEngineConfig(ppO2Working: 1.2),
  'ppO2Deco': PlanEngineConfig(ppO2Deco: 1.5),
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
}
