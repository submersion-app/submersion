import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/features/dive_computer/data/services/parsed_tank_resolver.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';

/// Issue #5057: a transmitter's gas is the gas during which its pressure fell,
/// not the gas active in the most samples.
///
/// A Shearwater transmitter reports all dive long, also after the switch to a
/// gas it does not hold, and Shearwater never links a transmitter to a gas. On
/// a dive whose deco outlasts the bottom phase, the deco gas is active in more
/// samples, so counting samples gave the back-gas transmitter the deco gas.
void main() {
  // DC_GASMIX_UNKNOWN: Shearwater never links a tank to a gas mix.
  const unknownGasMixIndex = 4294967295;
  const oxygenUsage = 1; // DC_USAGE_OXYGEN
  const diluentUsage = 2; // DC_USAGE_DILUENT

  pigeon.ParsedDive dive({
    required List<pigeon.GasMix> gasMixes,
    required List<pigeon.TankInfo> tanks,
    required List<pigeon.ProfileSample> samples,
    String diveMode = 'oc',
  }) => pigeon.ParsedDive(
    fingerprint: 'test',
    dateTimeYear: 2026,
    dateTimeMonth: 11,
    dateTimeDay: 27,
    dateTimeHour: 9,
    dateTimeMinute: 0,
    dateTimeSecond: 0,
    maxDepthMeters: 60.0,
    avgDepthMeters: 30.0,
    durationSeconds: 3540,
    diveMode: diveMode,
    samples: samples,
    tanks: tanks,
    gasMixes: gasMixes,
    events: const [],
  );

  /// One sample a minute: [bar] is the transmitter's reading, [gas] the gas
  /// breathed at that minute.
  pigeon.ProfileSample minute(int m, double bar, int gas) =>
      pigeon.ProfileSample(
        timeSeconds: m * 60,
        depthMeters: 30.0,
        pressureBar: bar,
        tankIndex: 0,
        tankPressuresBar: [bar],
        gasMixIndex: gas,
      );

  DownloadedTank tankAt(List<DownloadedTank> tanks, int index) =>
      tanks.firstWhere((t) => t.index == index);

  group('OC dive, transmitter on the back gas only', () {
    const trimix = 0; // 18/45 back gas, on the transmitter
    const ean50 = 1; // deco gas, no transmitter
    final gasMixes = [
      pigeon.GasMix(index: trimix, o2Percent: 18.0, hePercent: 45.0),
      pigeon.GasMix(index: ean50, o2Percent: 50.0, hePercent: 0.0),
    ];
    final tanks = [
      pigeon.TankInfo(
        index: 0,
        gasMixIndex: unknownGasMixIndex,
        startPressureBar: 220.0,
        endPressureBar: 110.0,
      ),
    ];

    /// 22 minutes on the trimix (220 bar down to 110), then 37 on EAN50
    /// while the transmitter keeps reporting 110 bar.
    final samples = [
      for (var m = 0; m < 22; m++) minute(m, 220.0 - m * 5.0, trimix),
      for (var m = 22; m < 59; m++) minute(m, 110.0, ean50),
    ];

    test('the transmitter carries the back gas when the deco lasts longer '
        'than the bottom phase', () {
      final resolved = resolveParsedTanks(
        dive(gasMixes: gasMixes, tanks: tanks, samples: samples),
      );

      expect(resolved, hasLength(2));
      expect(tankAt(resolved, 0).o2Percent, 18.0);
      expect(tankAt(resolved, 0).hePercent, 45.0);
      final deco = resolved.firstWhere((t) => t.index != 0);
      expect(deco.o2Percent, 50.0);
      expect(deco.startPressure, isNull, reason: 'EAN50 had no transmitter');
    });

    test('the switch to EAN50 points at the EAN50 cylinder', () {
      final parsed = dive(gasMixes: gasMixes, tanks: tanks, samples: samples);
      final decoIndex = resolveParsedTanks(
        parsed,
      ).firstWhere((t) => t.o2Percent == 50.0).index;

      final switches = resolveGasSwitches(parsed);

      expect(switches, hasLength(1));
      expect(switches.single.toTankIndex, decoIndex);
      expect(switches.single.timeSeconds, 22 * 60);
    });

    test('noise inside a gas stretch does not move the gas', () {
      // The reading jitters by a bar either way through the long deco: the
      // ups and downs cancel, and only the trimix stretch really fell.
      final noisy = [
        for (var m = 0; m < 22; m++) minute(m, 220.0 - m * 5.0, trimix),
        for (var m = 22; m < 59; m++)
          minute(m, m.isEven ? 111.0 : 109.0, ean50),
      ];
      final resolved = resolveParsedTanks(
        dive(gasMixes: gasMixes, tanks: tanks, samples: noisy),
      );

      expect(tankAt(resolved, 0).o2Percent, 18.0);
    });

    test('a dropout reading during the deco is not a pressure drop', () {
      // A single zero reading right after the switch would otherwise credit
      // EAN50 with a 110 bar fall (issue #2441 glitches).
      final withDropout = [
        for (var m = 0; m < 22; m++) minute(m, 220.0 - m * 5.0, trimix),
        minute(22, 110.0, ean50),
        minute(23, 0.0, ean50),
        for (var m = 24; m < 59; m++) minute(m, 110.0, ean50),
      ];
      final resolved = resolveParsedTanks(
        dive(gasMixes: gasMixes, tanks: tanks, samples: withDropout),
      );

      expect(tankAt(resolved, 0).o2Percent, 18.0);
    });
  });

  group('OC dive, after surfacing', () {
    test('a back-gas regulator purged after surfacing does not credit the '
        'deco gas', () {
      // The diver ends on EAN50, surfaces, closes the back-gas valve and
      // purges its regulator while the computer still logs: that fall to
      // zero is no breathing, so the trimix stays on the transmitter.
      pigeon.ProfileSample at(int m, double depth, double bar, int gas) =>
          pigeon.ProfileSample(
            timeSeconds: m * 60,
            depthMeters: depth,
            pressureBar: bar,
            tankIndex: 0,
            tankPressuresBar: [bar],
            gasMixIndex: gas,
          );
      final resolved = resolveParsedTanks(
        dive(
          gasMixes: [
            pigeon.GasMix(index: 0, o2Percent: 18.0, hePercent: 45.0),
            pigeon.GasMix(index: 1, o2Percent: 50.0, hePercent: 0.0),
          ],
          tanks: [pigeon.TankInfo(index: 0, gasMixIndex: unknownGasMixIndex)],
          samples: [
            for (var m = 0; m < 10; m++) at(m, 40.0, 220.0 - m * 5.0, 0),
            for (var m = 10; m < 40; m++) at(m, 6.0, 170.0, 1),
            at(40, 0.0, 170.0, 1),
            at(41, 0.0, 60.0, 1),
            at(42, 0.0, 0.0, 1),
            at(43, 0.0, 0.0, 1),
          ],
        ),
      );

      expect(tankAt(resolved, 0).o2Percent, 18.0);
    });
  });

  group('two gases with the same fall', () {
    test('the gas breathed first wins the tie', () {
      final resolved = resolveParsedTanks(
        dive(
          gasMixes: [
            pigeon.GasMix(index: 0, o2Percent: 99.0, hePercent: 0.0),
            pigeon.GasMix(index: 1, o2Percent: 32.0, hePercent: 0.0),
          ],
          tanks: [pigeon.TankInfo(index: 0, gasMixIndex: unknownGasMixIndex)],
          samples: [
            minute(0, 200.0, 1),
            minute(1, 190.0, 0),
            minute(2, 180.0, 0),
          ],
        ),
      );

      expect(tankAt(resolved, 0).o2Percent, 32.0);
    });
  });

  group('OC dive, transmitter on the deco cylinder only', () {
    const air = 0; // back gas, no transmitter
    const ean50 = 1; // deco gas, on the transmitter
    final gasMixes = [
      pigeon.GasMix(index: air, o2Percent: 21.0, hePercent: 0.0),
      pigeon.GasMix(index: ean50, o2Percent: 50.0, hePercent: 0.0),
    ];

    test('the transmitter carries the deco gas although the bottom phase is '
        'longer and the cylinder cooled during it', () {
      // 40 minutes on air while the slung stage cools from 200 to 190 bar,
      // then 10 minutes breathing it down to 150 bar.
      final samples = [
        for (var m = 0; m < 40; m++) minute(m, 200.0 - m * 0.25, air),
        for (var m = 40; m < 50; m++) minute(m, 190.0 - (m - 39) * 4.0, ean50),
      ];
      final resolved = resolveParsedTanks(
        dive(
          gasMixes: gasMixes,
          tanks: [pigeon.TankInfo(index: 0, gasMixIndex: unknownGasMixIndex)],
          samples: samples,
        ),
      );

      expect(tankAt(resolved, 0).o2Percent, 50.0);
      expect(resolved.firstWhere((t) => t.index != 0).o2Percent, 21.0);
    });

    test("the computer's own tank->gas link beats a pressure drop", () {
      // A stage the diver carried but never breathed only cooled during the
      // bottom phase; the computer linked it to EAN50, and that stands.
      final samples = [
        for (var m = 0; m < 40; m++) minute(m, 200.0 - m * 0.25, air),
        for (var m = 40; m < 50; m++) minute(m, 190.0, air),
      ];
      final resolved = resolveParsedTanks(
        dive(
          gasMixes: gasMixes,
          tanks: [pigeon.TankInfo(index: 0, gasMixIndex: ean50)],
          samples: samples,
        ),
      );

      expect(tankAt(resolved, 0).o2Percent, 50.0);
    });
  });

  group('a transmitter whose pressure never falls', () {
    test('takes the first gas breathed while it reported, not the one '
        'breathed longest', () {
      final resolved = resolveParsedTanks(
        dive(
          gasMixes: [
            pigeon.GasMix(index: 0, o2Percent: 21.0, hePercent: 0.0),
            pigeon.GasMix(index: 1, o2Percent: 32.0, hePercent: 0.0),
          ],
          tanks: [pigeon.TankInfo(index: 0, gasMixIndex: unknownGasMixIndex)],
          samples: [
            minute(0, 200.0, 0),
            minute(1, 200.0, 1),
            minute(2, 200.0, 1),
            minute(3, 200.0, 1),
          ],
        ),
      );

      expect(tankAt(resolved, 0).o2Percent, 21.0);
    });
  });

  group('CCR dive with an untagged bailout transmitter', () {
    const bailout = 0; // OC1 21/35, on the untagged transmitter (tank 2)
    const dil = 1; // diluent 10/50
    final gasMixes = [
      pigeon.GasMix(index: bailout, o2Percent: 21.0, hePercent: 35.0),
      pigeon.GasMix(
        index: dil,
        o2Percent: 10.0,
        hePercent: 50.0,
        usage: diluentUsage,
      ),
      pigeon.GasMix(index: 2, o2Percent: 99.0, hePercent: 0.0),
    ];
    final tanks = [
      pigeon.TankInfo(
        index: 0,
        gasMixIndex: unknownGasMixIndex,
        usage: diluentUsage,
      ),
      pigeon.TankInfo(
        index: 1,
        gasMixIndex: unknownGasMixIndex,
        usage: oxygenUsage,
      ),
      pigeon.TankInfo(index: 2, gasMixIndex: unknownGasMixIndex),
    ];

    /// All three transmitters in every sample, oxygen last.
    pigeon.ProfileSample loop(int m, double bailoutBar, int gas) =>
        pigeon.ProfileSample(
          timeSeconds: m * 60,
          depthMeters: 40.0,
          pressureBar: 150.0 - m,
          tankIndex: 1,
          tankPressuresBar: [200.0 - m, 150.0 - m, bailoutBar],
          gasMixIndex: gas,
        );

    test('an unused bailout that cooled on the loop is not the diluent', () {
      // The bailout cylinder only cools (200 to 188 bar) while the diver
      // breathes the loop; that fall is no evidence it holds the diluent,
      // whose own transmitter is tank 0.
      final resolved = resolveParsedTanks(
        dive(
          diveMode: 'ccr',
          gasMixes: gasMixes,
          tanks: tanks,
          samples: [for (var m = 0; m < 60; m++) loop(m, 200.0 - m * 0.2, dil)],
        ),
      );

      expect(tankAt(resolved, 0).o2Percent, 10.0);
      expect(tankAt(resolved, 2).o2Percent, 21.0);
      expect(resolved.where((t) => t.role == 'diluent').map((t) => t.index), [
        0,
      ], reason: 'only the tagged transmitter is the diluent');
    });

    test('a bailout breathed on open circuit carries the bailout gas', () {
      final parsed = dive(
        diveMode: 'ccr',
        gasMixes: gasMixes,
        tanks: tanks,
        samples: [
          for (var m = 0; m < 40; m++) loop(m, 200.0, dil),
          for (var m = 40; m < 50; m++)
            loop(m, 200.0 - (m - 39) * 8.0, bailout),
        ],
      );

      expect(tankAt(resolveParsedTanks(parsed), 2).o2Percent, 21.0);
      expect(
        resolveGasSwitches(parsed).single.toTankIndex,
        2,
        reason: 'the bailout switch points at the bailout transmitter',
      );
    });
  });
}
