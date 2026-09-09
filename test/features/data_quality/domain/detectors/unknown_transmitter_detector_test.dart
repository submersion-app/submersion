import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/data_quality/domain/detectors/unknown_transmitter_detector.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/data_quality/domain/repairs/quality_repair_action.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../helpers/quality_test_helpers.dart';

domain.DiveTank _tank({String id = 't1', String? serial, int order = 0}) =>
    domain.DiveTank(
      id: id,
      gasMix: const domain.GasMix(o2: 21, he: 0),
      order: order,
      transmitterSerial: serial,
    );

void main() {
  const det = UnknownTransmitterDetector();

  test('flags a serial with no registry entry, once per serial', () {
    final ctx = makeContext(
      dive: makeTestDive(
        tanks: [
          _tank(id: 'a', serial: '180777'),
          _tank(id: 'b', serial: ' 180777', order: 1),
          _tank(id: 'c', serial: '109623', order: 2),
        ],
      ),
      knownTransmitterSerials: {'109623'},
    );

    final out = det.detect(ctx);

    expect(out, hasLength(1));
    expect(out.single.severity, QualitySeverity.info);
    expect(out.single.category, QualityCategory.tank);
    expect(out.single.params['serial'], '180777');
    expect(out.single.params['tankId'], 'a');
  });

  test('is silent when every serial is known or absent', () {
    final ctx = makeContext(
      dive: makeTestDive(
        tanks: [
          _tank(serial: '109623'),
          _tank(id: 'm', order: 1),
        ],
      ),
      knownTransmitterSerials: {'109623'},
    );
    expect(det.detect(ctx), isEmpty);
  });

  test('the finding id is stable across rescans', () {
    final ctx = makeContext(
      dive: makeTestDive(tanks: [_tank(serial: '180777')]),
    );
    expect(det.detect(ctx).single.id, det.detect(ctx).single.id);
  });

  test('offers an assign repair carrying the serial', () {
    final ctx = makeContext(
      dive: makeTestDive(tanks: [_tank(serial: '180777')]),
    );
    final repairs = repairOptionsFor(det.detect(ctx).single);

    expect(repairs.first, isA<AssignTransmitterRepair>());
    expect((repairs.first as AssignTransmitterRepair).serial, '180777');
    expect(repairs.last, isA<GoToDiveRepair>());
  });
}
