import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_computer/data/services/parsed_tank_resolver.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';

/// Issue #2595: on a Shearwater CCR dive libdivecomputer derives a wireless
/// transmitter's usage from nothing but the first letter of the name the
/// diver gave it ("O..." oxygen, "D..." diluent), so a bailout named "OC"
/// arrives tagged as the oxygen supply. The resolver cannot check the name,
/// but it must record that the role came from it, so the app can let the
/// diver's own transmitter registry correct it and can say so on screen.
void main() {
  // DC_GASMIX_UNKNOWN: Shearwater never links a tank to a gas mix.
  const unknownGasMixIndex = 4294967295;
  const oxygenUsage = 1; // DC_USAGE_OXYGEN
  const diluentUsage = 2; // DC_USAGE_DILUENT
  const sidemountUsage = 3; // DC_USAGE_SIDEMOUNT

  final gasMixes = [
    pigeon.GasMix(index: 0, o2Percent: 99.0, hePercent: 0.0),
    pigeon.GasMix(index: 1, o2Percent: 15.0, hePercent: 55.0),
    pigeon.GasMix(
      index: 2,
      o2Percent: 15.0,
      hePercent: 55.0,
      usage: diluentUsage,
    ),
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
    String diveMode = 'ccr',
  }) => pigeon.ParsedDive(
    fingerprint: 'test',
    dateTimeYear: 2026,
    dateTimeMonth: 9,
    dateTimeDay: 12,
    dateTimeHour: 8,
    dateTimeMinute: 0,
    dateTimeSecond: 0,
    maxDepthMeters: 40.0,
    avgDepthMeters: 20.0,
    durationSeconds: 3600,
    diveMode: diveMode,
    samples: [
      pigeon.ProfileSample(
        timeSeconds: 0,
        depthMeters: 0.0,
        tankPressuresBar: [for (final _ in tanks) 200.0],
        gasMixIndex: 2,
      ),
    ],
    tanks: tanks,
    gasMixes: gasMixes,
    events: const [],
  );

  DownloadedTank tankAt(List<DownloadedTank> tanks, int index) =>
      tanks.firstWhere((t) => t.index == index);

  group('role source (#2595)', () {
    test('a Shearwater CCR transmitter tagged oxygen or diluent took its role '
        'from its name', () {
      final resolved = resolveParsedTanks(
        dive(
          tanks: [
            tank(0, usage: diluentUsage, serial: 111111),
            tank(1, usage: oxygenUsage, serial: 222222),
          ],
        ),
        vendor: 'Shearwater',
      );
      expect(tankAt(resolved, 0).role, TankRole.diluent.name);
      expect(tankAt(resolved, 0).roleSource, TankRoleSource.transmitterName);
      expect(tankAt(resolved, 1).role, TankRole.oxygenSupply.name);
      expect(tankAt(resolved, 1).roleSource, TankRoleSource.transmitterName);
    });

    test('semi-closed mode reads the names the same way', () {
      final resolved = resolveParsedTanks(
        dive(
          tanks: [tank(0, usage: oxygenUsage, serial: 222222)],
          diveMode: 'scr',
        ),
        vendor: 'shearwater ',
      );
      expect(tankAt(resolved, 0).roleSource, TankRoleSource.transmitterName);
    });

    test('an HP CCR channel has no transmitter serial and a role fixed by '
        'the hardware, so it is not name-derived', () {
      final resolved = resolveParsedTanks(
        dive(
          tanks: [
            tank(0, usage: diluentUsage),
            tank(1, usage: oxygenUsage),
          ],
        ),
        vendor: 'Shearwater',
      );
      expect(tankAt(resolved, 0).roleSource, isNull);
      expect(tankAt(resolved, 1).roleSource, isNull);
    });

    test('another vendor reports usage from its own gas plan, not a name', () {
      // Suunto tags the tank from the gas's own Oxygen/Diluent setting.
      final resolved = resolveParsedTanks(
        dive(tanks: [tank(0, usage: oxygenUsage, serial: 222222)]),
        vendor: 'Suunto',
      );
      expect(tankAt(resolved, 0).role, TankRole.oxygenSupply.name);
      expect(tankAt(resolved, 0).roleSource, isNull);
    });

    test('an unknown vendor is not flagged', () {
      final resolved = resolveParsedTanks(
        dive(tanks: [tank(0, usage: oxygenUsage, serial: 222222)]),
      );
      expect(tankAt(resolved, 0).roleSource, isNull);
    });

    test('an untagged or sidemount transmitter is not name-derived', () {
      final resolved = resolveParsedTanks(
        dive(
          tanks: [
            tank(0, serial: 111111),
            tank(1, usage: sidemountUsage, serial: 222222),
          ],
        ),
        vendor: 'Shearwater',
      );
      expect(tankAt(resolved, 0).roleSource, isNull);
      expect(tankAt(resolved, 1).roleSource, isNull);
    });

    test('open circuit never takes a usage from a name', () {
      final resolved = resolveParsedTanks(
        dive(
          tanks: [tank(0, usage: oxygenUsage, serial: 222222)],
          diveMode: 'open_circuit',
        ),
        vendor: 'Shearwater',
      );
      expect(tankAt(resolved, 0).roleSource, isNull);
    });

    test('cylinders without a transmitter are never name-derived', () {
      final resolved = resolveParsedTanks(
        dive(tanks: [tank(0, usage: oxygenUsage, serial: 222222)]),
        vendor: 'Shearwater',
      );
      for (final t in resolved.where((t) => t.index != 0)) {
        expect(t.roleSource, isNull, reason: 'gas ${t.o2Percent}');
      }
    });
  });
}
