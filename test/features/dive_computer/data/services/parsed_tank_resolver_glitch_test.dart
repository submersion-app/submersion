import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/features/dive_computer/data/services/parsed_tank_resolver.dart';

/// Issue #2441: libdivecomputer's Shearwater parser takes a cylinder's begin
/// and end pressure from the first and last non-zero sample. A transmitter
/// that logged a few bar before the valve was open, or dropped out, hands
/// that reading on as the cylinder's start or end pressure.
void main() {
  pigeon.ParsedDive makeParsedDive({
    required List<pigeon.ProfileSample> samples,
    required pigeon.TankInfo tank,
  }) => pigeon.ParsedDive(
    fingerprint: 'test',
    dateTimeYear: 2026,
    dateTimeMonth: 6,
    dateTimeDay: 20,
    dateTimeHour: 9,
    dateTimeMinute: 43,
    dateTimeSecond: 2,
    maxDepthMeters: 20.0,
    avgDepthMeters: 15.0,
    durationSeconds: 2400,
    samples: samples,
    tanks: [tank],
    gasMixes: [pigeon.GasMix(index: 0, o2Percent: 21.0, hePercent: 0.0)],
    events: const [],
  );

  pigeon.ProfileSample sample(int t, double depth, double pressure) =>
      pigeon.ProfileSample(
        timeSeconds: t,
        depthMeters: depth,
        pressureBar: pressure,
        tankIndex: 0,
        gasMixIndex: 0,
      );

  /// 200 bar draining to 80 over 40 minutes, with [first] as the reading at
  /// t=0 and a dropout at t=1200.
  List<pigeon.ProfileSample> samples({double first = 200.0}) => [
    sample(0, 0.0, first),
    for (var t = 10; t <= 2400; t += 10)
      sample(t, t < 2380 ? 20.0 : 0.0, t == 1200 ? 0.8 : 200 - t * 0.05),
  ];

  test('a start pressure taken from a lead-in reading is replaced', () {
    final tanks = resolveParsedTanks(
      makeParsedDive(
        samples: samples(first: 3.9),
        tank: pigeon.TankInfo(
          index: 0,
          gasMixIndex: 0,
          startPressureBar: 3.9,
          endPressureBar: 80.0,
        ),
      ),
      trimAtSurfacing: false,
    );
    expect(tanks.single.startPressure, closeTo(199.5, 1e-9));
    expect(tanks.single.endPressure, 80.0);
  });

  test('a start pressure that is no glitch is kept', () {
    final tanks = resolveParsedTanks(
      makeParsedDive(
        samples: samples(),
        tank: pigeon.TankInfo(
          index: 0,
          gasMixIndex: 0,
          startPressureBar: 200.0,
          endPressureBar: 80.0,
        ),
      ),
    );
    expect(tanks.single.startPressure, 200.0);
  });

  test('an end pressure taken from a dropout is replaced', () {
    final tanks = resolveParsedTanks(
      makeParsedDive(
        samples: samples(),
        tank: pigeon.TankInfo(
          index: 0,
          gasMixIndex: 0,
          startPressureBar: 200.0,
          endPressureBar: 0.8,
        ),
      ),
      trimAtSurfacing: false,
    );
    expect(tanks.single.endPressure, closeTo(80.0, 1e-9));
  });
}
