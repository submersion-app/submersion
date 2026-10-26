import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/data_quality/domain/detectors/transmitter_gear_serial_mismatch_detector.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
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
  const det = TransmitterGearSerialMismatchDetector();

  test('flags a tank whose serial is in the mismatch set, once per serial', () {
    final ctx = makeContext(
      dive: makeTestDive(
        tanks: [
          _tank(id: 'a', serial: '555'),
          _tank(id: 'b', serial: ' 555', order: 1),
          _tank(id: 'c', serial: '999', order: 2),
        ],
      ),
      mismatchedTransmitterSerials: {'555'},
    );

    final out = det.detect(ctx);

    expect(out, hasLength(1));
    expect(out.single.severity, QualitySeverity.info);
    expect(out.single.category, QualityCategory.tank);
    expect(out.single.params['serial'], '555');
    expect(out.single.params['tankId'], 'a');
  });

  test('is silent when no serial is in the mismatch set', () {
    final ctx = makeContext(
      dive: makeTestDive(tanks: [_tank(serial: '555')]),
      mismatchedTransmitterSerials: {'999'},
    );
    expect(det.detect(ctx), isEmpty);
  });

  test('is silent for a tank with no transmitter serial at all', () {
    final ctx = makeContext(
      dive: makeTestDive(tanks: [_tank()]),
      mismatchedTransmitterSerials: {'555'},
    );
    expect(det.detect(ctx), isEmpty);
  });
}
