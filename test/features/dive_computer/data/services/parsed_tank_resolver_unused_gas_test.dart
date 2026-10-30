import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/features/dive_computer/data/services/dive_parser.dart';
import 'package:submersion/features/dive_computer/data/services/parsed_dive_mapper.dart';
import 'package:submersion/features/dive_computer/data/services/parsed_tank_resolver.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';

/// Issue #3668: a rebreather dive computer reports every programmed gas, and
/// the resolver gives each gas no transmitter claimed a pressureless cylinder.
/// The resolver marks the open-circuit ones the diver never breathed, so a
/// writer can leave them out when the diver asks it to.
///
/// The fixture is the reporter's dive: a diluent and an oxygen transmitter,
/// an Air diluent, and O2 and Air still enabled as open-circuit gases.
void main() {
  const unknownGasMixIndex = 4294967295; // DC_GASMIX_UNKNOWN
  const oxygenUsage = 1; // DC_USAGE_OXYGEN
  const diluentUsage = 2; // DC_USAGE_DILUENT

  const ocOxygen = 0;
  const ocAir = 1;
  const diluentAir = 2;

  List<pigeon.GasMix> gasList({int? extraDiluentUsage}) => [
    pigeon.GasMix(index: ocOxygen, o2Percent: 100.0, hePercent: 0.0),
    pigeon.GasMix(index: ocAir, o2Percent: 21.0, hePercent: 0.0),
    pigeon.GasMix(
      index: diluentAir,
      o2Percent: 21.0,
      hePercent: 0.0,
      usage: diluentUsage,
    ),
    if (extraDiluentUsage != null)
      pigeon.GasMix(
        index: 3,
        o2Percent: 10.0,
        hePercent: 70.0,
        usage: extraDiluentUsage,
      ),
  ];

  final transmitters = [
    pigeon.TankInfo(
      index: 0,
      gasMixIndex: unknownGasMixIndex,
      startPressureBar: 190.0,
      endPressureBar: 157.0,
      usage: diluentUsage,
      transmitterSerial: 818,
    ),
    pigeon.TankInfo(
      index: 1,
      gasMixIndex: unknownGasMixIndex,
      startPressureBar: 207.0,
      endPressureBar: 146.0,
      usage: oxygenUsage,
      transmitterSerial: 154648,
    ),
  ];

  pigeon.ProfileSample sample(int t, double depth, int? gasMixIndex) =>
      pigeon.ProfileSample(
        timeSeconds: t,
        depthMeters: depth,
        gasMixIndex: gasMixIndex,
      );

  /// The whole dive on the loop, breathing the Air diluent.
  final onTheLoop = [
    sample(0, 0.0, diluentAir),
    sample(600, 30.0, diluentAir),
    sample(2400, 30.0, diluentAir),
    sample(3000, 0.0, diluentAir),
  ];

  pigeon.ParsedDive dive({
    String diveMode = 'ccr',
    List<pigeon.ProfileSample>? samples,
    List<pigeon.TankInfo>? tanks,
    List<pigeon.GasMix>? gasMixes,
  }) => pigeon.ParsedDive(
    fingerprint: 'reporter',
    dateTimeYear: 2026,
    dateTimeMonth: 10,
    dateTimeDay: 20,
    dateTimeHour: 9,
    dateTimeMinute: 0,
    dateTimeSecond: 0,
    maxDepthMeters: 30.0,
    avgDepthMeters: 20.0,
    durationSeconds: 3000,
    diveMode: diveMode,
    samples: samples ?? onTheLoop,
    tanks: tanks ?? transmitters,
    gasMixes: gasMixes ?? gasList(),
    events: const [],
  );

  DownloadedTank gasCylinder(List<DownloadedTank> tanks, double o2) =>
      tanks.firstWhere((t) => t.transmitterSerial == null && t.o2Percent == o2);

  test("the reporter's dive marks the O2 and Air OC gases unused", () {
    final tanks = resolveParsedTanks(dive());

    expect(tanks, hasLength(4));
    expect(gasCylinder(tanks, 100.0).unusedOcGas, isTrue);
    expect(gasCylinder(tanks, 21.0).unusedOcGas, isTrue);
    for (final transmitter in tanks.where((t) => t.transmitterSerial != null)) {
      expect(transmitter.unusedOcGas, isFalse);
    }
  });

  test('marking changes neither the cylinders nor their roles', () {
    final tanks = resolveParsedTanks(dive());

    expect(gasCylinder(tanks, 100.0).role, 'deco');
    expect(gasCylinder(tanks, 21.0).role, 'bailout');
  });

  test('a gas the diver bailed out onto is not unused', () {
    final tanks = resolveParsedTanks(
      dive(
        samples: [
          sample(0, 0.0, diluentAir),
          sample(600, 30.0, diluentAir),
          sample(2400, 30.0, ocAir),
          sample(3000, 0.0, ocAir),
        ],
      ),
    );

    expect(gasCylinder(tanks, 21.0).unusedOcGas, isFalse);
    expect(gasCylinder(tanks, 100.0).unusedOcGas, isTrue);
  });

  test('no per-sample gas marks nothing', () {
    final tanks = resolveParsedTanks(
      dive(
        samples: [
          sample(0, 0.0, null),
          sample(600, 30.0, null),
          sample(3000, 0.0, null),
        ],
      ),
    );

    expect(tanks.where((t) => t.unusedOcGas), isEmpty);
  });

  test('a CCR computer that tags no diluent marks nothing', () {
    // Many parsers (Atomics, Halcyon, Oceanic, Suunto D9 and more) report
    // CCR but never tag a diluent, so the loop gas looks like any other.
    // Logging only the switch to bailout must not make the diluent unused.
    final tanks = resolveParsedTanks(
      dive(
        tanks: const [],
        gasMixes: [
          pigeon.GasMix(index: 0, o2Percent: 21.0, hePercent: 0.0),
          pigeon.GasMix(index: 1, o2Percent: 50.0, hePercent: 0.0),
          pigeon.GasMix(index: 2, o2Percent: 18.0, hePercent: 45.0),
        ],
        samples: [
          sample(0, 0.0, null),
          sample(1800, 40.0, null),
          sample(2400, 21.0, 1),
          sample(3000, 0.0, 1),
        ],
      ),
    );

    expect(tanks.where((t) => t.unusedOcGas), isEmpty);
  });

  test('open circuit is never marked', () {
    final tanks = resolveParsedTanks(
      dive(
        diveMode: 'oc',
        tanks: const [],
        gasMixes: [
          pigeon.GasMix(index: 0, o2Percent: 100.0, hePercent: 0.0),
          pigeon.GasMix(index: 1, o2Percent: 21.0, hePercent: 0.0),
        ],
        samples: [sample(0, 0.0, 1), sample(3000, 0.0, 1)],
      ),
    );

    expect(tanks.where((t) => t.unusedOcGas), isEmpty);
  });

  test('a diluent-tagged gas with no transmitter is not marked', () {
    final tanks = resolveParsedTanks(
      dive(gasMixes: gasList(extraDiluentUsage: diluentUsage)),
    );

    final secondDiluent = tanks.firstWhere((t) => t.hePercent == 70.0);
    expect(secondDiluent.role, 'diluent');
    expect(secondDiluent.unusedOcGas, isFalse);
  });

  test('a tankless CCR dive marks its unused OC gases too', () {
    final tanks = resolveParsedTanks(dive(tanks: const []));

    expect(tanks.where((t) => t.unusedOcGas).map((t) => t.o2Percent), [
      100.0,
      21.0,
    ]);
    expect(tanks.firstWhere((t) => t.role == 'diluent').unusedOcGas, isFalse);
  });

  test('SCR is marked like CCR', () {
    final tanks = resolveParsedTanks(dive(diveMode: 'scr'));

    expect(gasCylinder(tanks, 100.0).unusedOcGas, isTrue);
    expect(gasCylinder(tanks, 21.0).unusedOcGas, isTrue);
  });

  test('tankDataFrom carries the flag', () {
    final tanks = resolveParsedTanks(dive());

    expect(
      DiveParser.tankDataFrom(gasCylinder(tanks, 21.0)).unusedOcGas,
      isTrue,
    );
    expect(
      DiveParser.tankDataFrom(
        tanks.firstWhere((t) => t.transmitterSerial == '818'),
      ).unusedOcGas,
      isFalse,
    );
  });

  test('the download mapping carries the flag to the importer', () {
    final downloaded = parsedDiveToDownloaded(dive(), vendor: 'Shearwater');

    expect(downloaded.tanks.where((t) => t.unusedOcGas), hasLength(2));
    expect(
      downloaded.tanks
          .where((t) => t.transmitterSerial != null)
          .every((t) => !t.unusedOcGas),
      isTrue,
    );
  });

  test('copyWith keeps the flag', () {
    final tank = gasCylinder(resolveParsedTanks(dive()), 21.0);

    expect(tank.copyWith(role: 'stage').unusedOcGas, isTrue);
    expect(
      DiveParser.tankDataFrom(tank).copyWith(role: 'stage').unusedOcGas,
      isTrue,
    );
  });

  test('openCircuitGasRole matches the open-circuit threshold', () {
    expect(openCircuitGasRole(21.0), 'backGas');
    expect(openCircuitGasRole(40.9), 'backGas');
    expect(openCircuitGasRole(41.0), 'deco');
    expect(openCircuitGasRole(100.0), 'deco');
  });
}
