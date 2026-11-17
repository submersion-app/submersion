import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_computer/data/services/parsed_tank_resolver.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';

/// Issue #4657: in Shearwater's Avelo mode the fork tags the T1 transmitter's
/// tank as the Avelo Hydrotank (DC_USAGE_HYDROTANK, 4), which the resolver
/// turns into the Hydrotank role, whatever gas is in it.
void main() {
  // DC_GASMIX_UNKNOWN: Shearwater never links a tank to a gas mix.
  const unknownGasMixIndex = 4294967295;
  const hydrotankUsage = 4; // DC_USAGE_HYDROTANK

  pigeon.ParsedDive dive({required double o2, int? usage}) => pigeon.ParsedDive(
    fingerprint: 'avelo',
    dateTimeYear: 2026,
    dateTimeMonth: 11,
    dateTimeDay: 17,
    dateTimeHour: 9,
    dateTimeMinute: 0,
    dateTimeSecond: 0,
    maxDepthMeters: 18.0,
    avgDepthMeters: 12.0,
    durationSeconds: 2700,
    diveMode: 'open_circuit',
    samples: [
      pigeon.ProfileSample(
        timeSeconds: 0,
        depthMeters: 0.0,
        tankPressuresBar: const [200.0],
        gasMixIndex: 0,
      ),
    ],
    tanks: [
      pigeon.TankInfo(
        index: 0,
        gasMixIndex: unknownGasMixIndex,
        startPressureBar: 200.0,
        endPressureBar: 185.0,
        usage: usage,
        transmitterSerial: 123086,
      ),
    ],
    gasMixes: [pigeon.GasMix(index: 0, o2Percent: o2, hePercent: 0.0)],
    events: const [],
  );

  DownloadedTank only(List<DownloadedTank> tanks) => tanks.single;

  test('a tank tagged as the Hydrotank takes the Hydrotank role', () {
    final resolved = resolveParsedTanks(
      dive(o2: 21.0, usage: hydrotankUsage),
      vendor: 'Shearwater',
    );
    expect(only(resolved).role, TankRole.hydrotank.name);
    expect(only(resolved).roleSource, isNull);
  });

  test('a Hydrotank of nitrox is still the Hydrotank, not a deco gas', () {
    final resolved = resolveParsedTanks(
      dive(o2: 50.0, usage: hydrotankUsage),
      vendor: 'Shearwater',
    );
    expect(only(resolved).role, TankRole.hydrotank.name);
  });

  test('the same tank without the tag stays back gas', () {
    final resolved = resolveParsedTanks(dive(o2: 21.0), vendor: 'Shearwater');
    expect(only(resolved).role, TankRole.backGas.name);
  });
}
