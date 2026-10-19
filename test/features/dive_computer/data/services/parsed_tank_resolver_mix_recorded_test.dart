import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/features/dive_computer/data/services/parsed_tank_resolver.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';

/// Issue #3307: a Shearwater CCR transmitter is never linked to a gas mix, so
/// the resolver invents one for it (100% for an oxygen supply, air when there
/// is no gas list). Later steps must be able to tell that invented mix from
/// one the computer recorded, so a reparse never writes it over a mix the
/// diver fixed.
void main() {
  // DC_GASMIX_UNKNOWN: Shearwater never links a tank to a gas mix.
  const unknownGasMixIndex = 4294967295;
  const oxygenUsage = 1; // DC_USAGE_OXYGEN
  const diluentUsage = 2; // DC_USAGE_DILUENT

  final ccrGasMixes = [
    pigeon.GasMix(
      index: 0,
      o2Percent: 10.0,
      hePercent: 50.0,
      usage: diluentUsage,
    ),
    pigeon.GasMix(index: 1, o2Percent: 18.0, hePercent: 45.0),
  ];

  pigeon.TankInfo tank(int index, {int? usage, int? serial}) => pigeon.TankInfo(
    index: index,
    gasMixIndex: unknownGasMixIndex,
    startPressureBar: 200.0,
    endPressureBar: 150.0,
    usage: usage,
    transmitterSerial: serial,
  );

  pigeon.ParsedDive dive({
    required List<pigeon.TankInfo> tanks,
    List<pigeon.GasMix>? gasMixes,
  }) => pigeon.ParsedDive(
    fingerprint: 'test',
    dateTimeYear: 2026,
    dateTimeMonth: 10,
    dateTimeDay: 17,
    dateTimeHour: 8,
    dateTimeMinute: 0,
    dateTimeSecond: 0,
    maxDepthMeters: 40.0,
    avgDepthMeters: 20.0,
    durationSeconds: 3600,
    diveMode: 'ccr',
    samples: [
      pigeon.ProfileSample(
        timeSeconds: 0,
        depthMeters: 0.0,
        tankPressuresBar: [for (final _ in tanks) 200.0],
        gasMixIndex: (gasMixes ?? ccrGasMixes).isEmpty ? null : 0,
      ),
    ],
    tanks: tanks,
    gasMixes: gasMixes ?? ccrGasMixes,
    events: const [],
  );

  DownloadedTank tankAt(List<DownloadedTank> tanks, int index) =>
      tanks.firstWhere((t) => t.index == index);

  group('mixRecorded (#3307)', () {
    test('an O-named Shearwater CCR transmitter has no recorded mix', () {
      final resolved = resolveParsedTanks(
        dive(tanks: [tank(0, usage: oxygenUsage, serial: 222222)]),
        vendor: 'Shearwater',
      );
      expect(tankAt(resolved, 0).o2Percent, 100.0);
      expect(tankAt(resolved, 0).mixRecorded, isFalse);
    });

    test('a D-named transmitter that claims the breathed diluent has a '
        'recorded mix', () {
      final resolved = resolveParsedTanks(
        dive(tanks: [tank(0, usage: diluentUsage, serial: 111111)]),
        vendor: 'Shearwater',
      );
      expect(tankAt(resolved, 0).o2Percent, 10.0);
      expect(tankAt(resolved, 0).mixRecorded, isTrue);
    });

    test('sensorless cylinders carry a recorded mix', () {
      final resolved = resolveParsedTanks(
        dive(tanks: [tank(0, usage: oxygenUsage, serial: 222222)]),
        vendor: 'Shearwater',
      );
      final sensorless = resolved.where((t) => t.index != 0).toList();
      expect(sensorless, isNotEmpty);
      for (final t in sensorless) {
        expect(t.mixRecorded, isTrue, reason: 'tank ${t.index}');
      }
    });

    test('a dive with no gas list defaults to air, unrecorded', () {
      final resolved = resolveParsedTanks(
        dive(tanks: [tank(0, serial: 333333)], gasMixes: const []),
        vendor: 'Shearwater',
      );
      expect(tankAt(resolved, 0).o2Percent, 21.0);
      expect(tankAt(resolved, 0).mixRecorded, isFalse);
    });
  });
}
