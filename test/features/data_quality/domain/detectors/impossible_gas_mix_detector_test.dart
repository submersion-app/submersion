import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/data_quality/domain/detectors/impossible_gas_mix_detector.dart';
import 'package:submersion/features/data_quality/domain/detectors/quality_detector_registry.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../helpers/quality_test_helpers.dart';

domain.DiveTank tank(
  String id, {
  required int order,
  double o2 = 21,
  double he = 0,
}) => domain.DiveTank(
  id: id,
  order: order,
  gasMix: domain.GasMix(o2: o2, he: he),
);

/// Issue #4714: mixes stored 100 times too high by earlier imports.
void main() {
  const det = ImpossibleGasMixDetector();

  test('is registered', () {
    expect(kQualityDetectors.map((d) => d.id), contains(det.id));
    expect(det.category, QualityCategory.gas);
  });

  test('possible mixes yield nothing', () {
    final ctx = makeContext(
      dive: makeTestDive(
        tanks: [
          tank('t1', order: 0, o2: 21, he: 35),
          tank('t2', order: 1, o2: 50),
          tank('t3', order: 2, o2: 100),
        ],
      ),
    );
    expect(det.detect(ctx), isEmpty);
  });

  test('a nitrox stored 100 times too high offers its correction', () {
    final ctx = makeContext(
      dive: makeTestDive(tanks: [tank('t1', order: 0, o2: 3200)]),
    );

    final finding = det.detect(ctx).single;

    expect(finding.severity, QualitySeverity.warning);
    expect(finding.diveId, 'd1');
    expect(finding.params, {
      'tankId': 't1',
      'tankPosition': 0,
      'o2Percent': 3200.0,
      'hePercent': 0.0,
      'correctedO2Percent': 32.0,
      'correctedHePercent': 0.0,
    });
  });

  test('a trimix stored 100 times too high offers both shares', () {
    final ctx = makeContext(
      dive: makeTestDive(tanks: [tank('t1', order: 0, o2: 2100, he: 3500)]),
    );

    final p = det.detect(ctx).single.params;

    expect(p['correctedO2Percent'], 21.0);
    expect(p['correctedHePercent'], 35.0);
  });

  test('an impossible mix dividing does not explain offers no correction', () {
    final ctx = makeContext(
      dive: makeTestDive(tanks: [tank('t1', order: 0, o2: 60, he: 50)]),
    );

    final p = det.detect(ctx).single.params;

    expect(p['o2Percent'], 60.0);
    expect(p['hePercent'], 50.0);
    expect(p.containsKey('correctedO2Percent'), isFalse);
    expect(p.containsKey('correctedHePercent'), isFalse);
  });

  test('each impossible cylinder is its own finding, numbered as shown', () {
    // Stored order has a gap, and the list is not in order: the number is
    // the cylinder's position on the dive page.
    final ctx = makeContext(
      dive: makeTestDive(
        tanks: [
          tank('deco', order: 5, o2: 5000),
          tank('back', order: 0, o2: 2100),
          tank('stage', order: 2, o2: 32),
        ],
      ),
    );

    final out = det.detect(ctx);

    expect(out, hasLength(2));
    final byTank = {for (final f in out) f.params['tankId']: f};
    expect(byTank['back']!.params['tankPosition'], 0);
    expect(byTank['deco']!.params['tankPosition'], 2);
    expect(byTank['back']!.id, isNot(byTank['deco']!.id));
  });

  test('flags the mixes of a rebreather dive too', () {
    final ctx = makeContext(
      dive: makeTestDive(
        diveMode: DiveMode.ccr,
        tanks: [tank('dil', order: 0, o2: 1000, he: 7000)],
      ),
    );

    final p = det.detect(ctx).single.params;

    expect(p['correctedO2Percent'], 10.0);
    expect(p['correctedHePercent'], 70.0);
  });
}
