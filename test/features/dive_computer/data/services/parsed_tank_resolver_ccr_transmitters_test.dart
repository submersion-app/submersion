import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/features/dive_computer/data/services/parsed_tank_resolver.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';

/// Issue #2318: a Shearwater CCR dive with a diluent and an oxygen transmitter.
///
/// Both transmitters report in the same sample, but a sample's
/// `pressureBar`/`tankIndex` pair only holds the LAST reading, which on the
/// Petrel 3 is always the oxygen transmitter. Every reading is in
/// `tankPressuresBar`. These tests model the real download: gas list in the
/// parser's order (OC slots first, so OC1 99/0 is gas 0), the whole dive on the
/// loop breathing the diluent, and both transmitters in almost every sample.
void main() {
  // DC_GASMIX_UNKNOWN: Shearwater never links a tank to a gas mix.
  const unknownGasMixIndex = 4294967295;
  const oxygenUsage = 1; // DC_USAGE_OXYGEN
  const diluentUsage = 2; // DC_USAGE_DILUENT

  // Gas list as the Shearwater parser reports it for this setup.
  const oc1Deco = 0; // OC1 99/0
  const oc5Bailout = 1; // OC5 15/55
  const dil2 = 2; // DIL2 15/55, the breathed diluent
  final gasMixes = [
    pigeon.GasMix(index: oc1Deco, o2Percent: 99.0, hePercent: 0.0),
    pigeon.GasMix(index: oc5Bailout, o2Percent: 15.0, hePercent: 55.0),
    pigeon.GasMix(
      index: dil2,
      o2Percent: 15.0,
      hePercent: 55.0,
      usage: diluentUsage,
    ),
  ];

  // Tank 0 is the transmitter named "D1", tank 1 the one named "O2". The
  // reported end pressures are the last tail samples, as libdivecomputer
  // reports them.
  final tanks = [
    pigeon.TankInfo(
      index: 0,
      gasMixIndex: unknownGasMixIndex,
      startPressureBar: 128.9,
      endPressureBar: 13.4,
      usage: diluentUsage,
    ),
    pigeon.TankInfo(
      index: 1,
      gasMixIndex: unknownGasMixIndex,
      startPressureBar: 107.7,
      endPressureBar: 29.5,
      usage: oxygenUsage,
    ),
  ];

  /// A loop sample carrying both transmitters, oxygen reported last.
  pigeon.ProfileSample bothReport(
    int t,
    double depth,
    double diluentBar,
    double oxygenBar,
  ) => pigeon.ProfileSample(
    timeSeconds: t,
    depthMeters: depth,
    pressureBar: oxygenBar,
    tankIndex: 1,
    tankPressuresBar: [diluentBar, oxygenBar],
    gasMixIndex: dil2,
  );

  pigeon.ParsedDive ccrDive(List<pigeon.ProfileSample> samples) =>
      pigeon.ParsedDive(
        fingerprint: 'test',
        dateTimeYear: 2026,
        dateTimeMonth: 9,
        dateTimeDay: 12,
        dateTimeHour: 8,
        dateTimeMinute: 56,
        dateTimeSecond: 33,
        maxDepthMeters: 61.9,
        avgDepthMeters: 30.0,
        durationSeconds: 3900,
        diveMode: 'ccr',
        samples: samples,
        tanks: tanks,
        gasMixes: gasMixes,
        events: const [],
      );

  /// Both transmitters in every sample, the oxygen transmitter always last, so
  /// the diluent transmitter never owns a sample's tankIndex. On the diver's
  /// 21.09.2026 dive this imported the diluent cylinder as 99/0.
  pigeon.ParsedDive oxygenAlwaysLast() => ccrDive([
    bothReport(0, 0.0, 128.9, 107.7),
    bothReport(600, 40.0, 120.0, 90.0),
    bothReport(1800, 61.9, 100.0, 60.0),
    bothReport(3600, 1.2, 77.6, 35.0), // last sample below the surface
    bothReport(3700, 0.0, 40.0, 31.0),
    bothReport(3800, 0.0, 13.4, 29.5), // post-surfacing tail
  ]);

  DownloadedTank tankAt(List<DownloadedTank> tanks, int index) =>
      tanks.firstWhere((t) => t.index == index);

  group('CCR dive with a diluent and an oxygen transmitter (#2318)', () {
    test('the oxygen cylinder is pure O2, not the breathed diluent', () {
      final oxygen = tankAt(resolveParsedTanks(oxygenAlwaysLast()), 1);
      expect(oxygen.role, 'oxygenSupply');
      expect(oxygen.o2Percent, 100.0);
      expect(oxygen.hePercent, 0.0);
    });

    test('the diluent cylinder carries the breathed diluent even when it '
        'never owns a sample tankIndex', () {
      final diluent = tankAt(resolveParsedTanks(oxygenAlwaysLast()), 0);
      expect(diluent.role, 'diluent');
      expect(diluent.o2Percent, 15.0);
      expect(diluent.hePercent, 55.0);
    });

    test('the dive-level diluent follows the diluent cylinder', () {
      final diluent = resolveDiluentGas(resolveParsedTanks(oxygenAlwaysLast()));
      expect(diluent, isNotNull);
      expect(diluent!.o2, 15.0);
      expect(diluent.he, 55.0);
    });

    test('gases without a transmitter keep their CCR roles: the open circuit '
        'bottom gas is bailout, 99% is deco', () {
      final resolved = resolveParsedTanks(oxygenAlwaysLast());
      expect(resolved, hasLength(4));
      final withoutTransmitter = resolved.where((t) => t.index > 1).toList();
      expect(
        withoutTransmitter.firstWhere((t) => t.o2Percent == 99.0).role,
        'deco',
      );
      expect(
        withoutTransmitter.firstWhere((t) => t.o2Percent == 15.0).role,
        'bailout',
      );
    });

    test('both transmitters are trimmed to their reading at surfacing', () {
      final resolved = resolveParsedTanks(oxygenAlwaysLast());
      expect(tankAt(resolved, 0).endPressure, 77.6);
      expect(tankAt(resolved, 1).endPressure, 35.0);
    });

    test('without the surfacing trim both keep the reported end pressure', () {
      final resolved = resolveParsedTanks(
        oxygenAlwaysLast(),
        trimAtSurfacing: false,
      );
      expect(tankAt(resolved, 0).endPressure, 13.4);
      expect(tankAt(resolved, 1).endPressure, 29.5);
    });

    test('the most-breathed diluent wins when several are programmed', () {
      // DIL1 21/0 is programmed and enabled but never breathed.
      final parsed = pigeon.ParsedDive(
        fingerprint: 'test',
        dateTimeYear: 2026,
        dateTimeMonth: 9,
        dateTimeDay: 12,
        dateTimeHour: 8,
        dateTimeMinute: 56,
        dateTimeSecond: 33,
        maxDepthMeters: 61.9,
        avgDepthMeters: 30.0,
        durationSeconds: 3900,
        diveMode: 'ccr',
        samples: [
          bothReport(0, 0.0, 128.9, 107.7),
          bothReport(600, 40.0, 120.0, 90.0),
        ],
        tanks: tanks,
        gasMixes: [
          ...gasMixes,
          pigeon.GasMix(
            index: 3,
            o2Percent: 21.0,
            hePercent: 0.0,
            usage: diluentUsage,
          ),
        ],
        events: const [],
      );
      final diluent = tankAt(resolveParsedTanks(parsed), 0);
      expect(diluent.o2Percent, 15.0);
      expect(diluent.hePercent, 55.0);
    });

    test('no gas switch is derived for a dive that stays on the loop', () {
      expect(resolveGasSwitches(oxygenAlwaysLast()), isEmpty);
    });
  });

  group('open circuit with two transmitters in one sample', () {
    test('both sidemount cylinders are labeled with the breathed gas', () {
      // Before #2318 only the last-reported transmitter was attributed a gas;
      // the other fell back to the first gas mix (here the 50% deco gas).
      final parsed = pigeon.ParsedDive(
        fingerprint: 'test',
        dateTimeYear: 2026,
        dateTimeMonth: 9,
        dateTimeDay: 12,
        dateTimeHour: 8,
        dateTimeMinute: 56,
        dateTimeSecond: 33,
        maxDepthMeters: 30.0,
        avgDepthMeters: 20.0,
        durationSeconds: 3000,
        diveMode: 'oc',
        samples: [
          for (final t in [0, 600, 1200, 1800])
            pigeon.ProfileSample(
              timeSeconds: t,
              depthMeters: 20.0,
              pressureBar: 180.0,
              tankIndex: 1,
              tankPressuresBar: const [190.0, 180.0],
              gasMixIndex: 1,
            ),
        ],
        tanks: [
          pigeon.TankInfo(index: 0, gasMixIndex: unknownGasMixIndex),
          pigeon.TankInfo(index: 1, gasMixIndex: unknownGasMixIndex),
        ],
        gasMixes: [
          pigeon.GasMix(index: 0, o2Percent: 50.0, hePercent: 0.0),
          pigeon.GasMix(index: 1, o2Percent: 32.0, hePercent: 0.0),
        ],
        events: const [],
      );
      final resolved = resolveParsedTanks(parsed);
      expect(tankAt(resolved, 0).o2Percent, 32.0);
      expect(tankAt(resolved, 1).o2Percent, 32.0);
    });
  });
}
