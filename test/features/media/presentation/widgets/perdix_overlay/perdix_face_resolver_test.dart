import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/media/presentation/widgets/perdix_overlay/perdix_face_resolver.dart';

DiveProfilePoint p(
  int t,
  double depth, {
  double? temp,
  int? ndl,
  double? ceiling,
  int? decoType,
  int? tts,
  double? cns,
  double? ppO2,
}) => DiveProfilePoint(
  timestamp: t,
  depth: depth,
  temperature: temp,
  ndl: ndl,
  ceiling: ceiling,
  decoType: decoType,
  tts: tts,
  cns: cns,
  ppO2: ppO2,
);

void main() {
  final profile = [
    p(0, 0.0, temp: 24.0, ndl: 3600),
    p(10, 5.0, temp: 23.0, ndl: 3000),
    p(20, 18.0, temp: 22.0, ndl: 1500),
    p(30, 12.0, temp: 22.0, ndl: 1800),
    p(40, 6.0, temp: 23.0, ndl: 2400),
  ];

  group('PerdixFaceResolver.resolve', () {
    test('floor sample resolution between samples', () {
      final r = PerdixFaceResolver(profile: profile);
      final d = r.resolve(25); // between t=20 and t=30 -> floor to t=20
      expect(d.depthMeters, 18.0);
      expect(d.temperatureCelsius, 22.0);
      expect(d.ndlSeconds, 1500);
    });

    test('clamps below first and above last sample', () {
      final r = PerdixFaceResolver(profile: profile);
      expect(r.resolve(-100).depthMeters, 0.0);
      expect(r.resolve(-100).diveTimeSeconds, 0);
      expect(r.resolve(9999).depthMeters, 6.0);
      expect(r.resolve(9999).diveTimeSeconds, 40);
    });

    test('running max depth is max so far, not dive max', () {
      final r = PerdixFaceResolver(profile: profile);
      expect(r.resolve(10).runningMaxDepthMeters, 5.0);
      expect(r.resolve(20).runningMaxDepthMeters, 18.0);
      expect(
        r.resolve(40).runningMaxDepthMeters,
        18.0,
      ); // holds after shallowing
    });

    test('inDeco from decoType == 2 and ceiling passthrough', () {
      final decoProfile = [
        p(0, 0.0),
        p(10, 30.0, ceiling: 6.0, decoType: 2, tts: 900, ndl: -1),
      ];
      final r = PerdixFaceResolver(profile: decoProfile);
      final d = r.resolve(10);
      expect(d.inDeco, isTrue);
      expect(d.ceilingMeters, 6.0);
      expect(d.ttsSeconds, 900);
    });

    test('empty profile: isAvailable false', () {
      final r = PerdixFaceResolver(profile: const []);
      expect(r.isAvailable, isFalse);
    });

    test('all-optional-null dive resolves with nulls', () {
      final bare = [p(0, 0.0), p(10, 12.0)];
      final r = PerdixFaceResolver(profile: bare);
      final d = r.resolve(10);
      expect(d.depthMeters, 12.0);
      expect(d.temperatureCelsius, isNull);
      expect(d.ndlSeconds, isNull);
      expect(d.gasLabel, isNull);
      expect(d.tankPressureBar, isNull);
      expect(d.tankPressureMissing, isFalse);
      expect(d.inDeco, isFalse);
    });
  });

  group('gas label across a switch', () {
    // Two tanks: back gas air (order 0), deco EAN50 (order 1); switch at t=30.
    final tanks = [
      const DiveTank(
        id: 'tank-air',
        gasMix: GasMix(o2: 21.0, he: 0.0),
        order: 0,
      ),
      const DiveTank(
        id: 'tank-ean50',
        gasMix: GasMix(o2: 50.0, he: 0.0),
        order: 1,
      ),
    ];
    final switches = [
      GasSwitchWithTank(
        gasSwitch: GasSwitch(
          id: 'gs1',
          diveId: 'd1',
          timestamp: 30,
          tankId: 'tank-ean50',
          createdAt: DateTime(2026, 1, 1),
        ),
        tankName: 'Deco',
        gasMix: 'EAN50',
        o2Fraction: 0.50,
        heFraction: 0.0,
      ),
    ];

    test('label before and after the switch', () {
      final r = PerdixFaceResolver(
        profile: profile,
        tanks: tanks,
        gasSwitches: switches,
      );
      expect(r.resolve(10).gasLabel, 'Air');
      expect(r.resolve(35).gasLabel, 'EAN50');
      expect(r.resolve(40).gasLabel, 'EAN50'); // end of dive inclusive
    });

    test('tank pressure follows the active tank', () {
      final pressures = {
        'tank-air': [
          const TankPressurePoint(
            tankId: 'tank-air',
            timestamp: 0,
            pressure: 200.0,
          ),
          const TankPressurePoint(
            tankId: 'tank-air',
            timestamp: 30,
            pressure: 120.0,
          ),
        ],
        'tank-ean50': [
          const TankPressurePoint(
            tankId: 'tank-ean50',
            timestamp: 30,
            pressure: 180.0,
          ),
        ],
      };
      final r = PerdixFaceResolver(
        profile: profile,
        tanks: tanks,
        gasSwitches: switches,
        tankPressures: pressures,
      );
      expect(r.resolve(10).tankPressureBar, 200.0);
      expect(r.resolve(35).tankPressureBar, 180.0);
    });

    group('active cylinder with no pressure series (#4006)', () {
      const airOnly = {
        'tank-air': [
          TankPressurePoint(tankId: 'tank-air', timestamp: 0, pressure: 150.0),
          TankPressurePoint(tankId: 'tank-air', timestamp: 40, pressure: 150.0),
        ],
      };
      const ean50Only = {
        'tank-ean50': [
          TankPressurePoint(
            tankId: 'tank-ean50',
            timestamp: 30,
            pressure: 210.0,
          ),
          TankPressurePoint(
            tankId: 'tank-ean50',
            timestamp: 40,
            pressure: 190.0,
          ),
        ],
      };

      test('does not show the previous cylinder after a switch', () {
        final r = PerdixFaceResolver(
          profile: profile,
          tanks: tanks,
          gasSwitches: switches,
          tankPressures: airOnly,
        );

        final before = r.resolve(20);
        expect(before.gasLabel, 'Air');
        expect(before.tankPressureBar, 150.0);
        expect(before.tankPressureMissing, isFalse);

        final after = r.resolve(35);
        expect(after.gasLabel, 'EAN50');
        expect(after.tankPressureBar, isNull);
        expect(after.tankPressureMissing, isTrue);
      });

      test('stays empty through the final second of the dive', () {
        final r = PerdixFaceResolver(
          profile: profile,
          tanks: tanks,
          gasSwitches: switches,
          tankPressures: airOnly,
        );

        final last = r.resolve(40);
        expect(last.gasLabel, 'EAN50');
        expect(last.tankPressureBar, isNull);
      });

      test('does not show a later cylinder before its switch', () {
        final r = PerdixFaceResolver(
          profile: profile,
          tanks: tanks,
          gasSwitches: switches,
          tankPressures: ean50Only,
        );

        final before = r.resolve(10);
        expect(before.gasLabel, 'Air');
        expect(before.tankPressureBar, isNull);

        final after = r.resolve(35);
        expect(after.gasLabel, 'EAN50');
        expect(after.tankPressureBar, 210.0);
      });

      test('does not show another cylinder on a dive with no switches', () {
        final r = PerdixFaceResolver(
          profile: profile,
          tanks: tanks,
          tankPressures: ean50Only,
        );

        final d = r.resolve(35);
        expect(d.gasLabel, 'Air');
        expect(d.tankPressureBar, isNull);
      });

      test('a rebreather does not show oxygen beside its diluent', () {
        final r = PerdixFaceResolver(
          profile: profile,
          tanks: const [
            DiveTank(
              id: 'diluent',
              gasMix: GasMix(o2: 21.0, he: 0.0),
              role: TankRole.diluent,
              order: 0,
            ),
            DiveTank(
              id: 'oxygen',
              gasMix: GasMix(o2: 100.0, he: 0.0),
              role: TankRole.oxygenSupply,
              order: 1,
            ),
          ],
          tankPressures: const {
            'oxygen': [
              TankPressurePoint(
                tankId: 'oxygen',
                timestamp: 0,
                pressure: 180.0,
              ),
            ],
          },
        );

        final d = r.resolve(20);
        expect(d.gasLabel, 'Air');
        expect(d.tankPressureBar, isNull);
        expect(d.tankPressureMissing, isTrue);
      });

      test('a switch back brings the measured cylinder back', () {
        final switchBack = GasSwitchWithTank(
          gasSwitch: GasSwitch(
            id: 'gs2',
            diveId: 'd1',
            timestamp: 35,
            tankId: 'tank-air',
            createdAt: DateTime(2026, 1, 1),
          ),
          tankName: 'Back',
          gasMix: 'Air',
          o2Fraction: 0.21,
          heFraction: 0.0,
        );
        final r = PerdixFaceResolver(
          profile: profile,
          tanks: tanks,
          gasSwitches: [...switches, switchBack],
          tankPressures: airOnly,
        );

        expect(r.resolve(30).tankPressureBar, isNull);

        final back = r.resolve(38);
        expect(back.gasLabel, 'Air');
        expect(back.tankPressureBar, 150.0);
      });
    });
  });

  group('no known active cylinder', () {
    const first = [
      TankPressurePoint(tankId: 'first', timestamp: 0, pressure: 150.0),
    ];
    const second = [
      TankPressurePoint(tankId: 'second', timestamp: 0, pressure: 210.0),
    ];

    test('the only reading is still shown', () {
      final r = PerdixFaceResolver(
        profile: profile,
        tankPressures: const {'first': first},
      );

      final d = r.resolve(35);
      expect(d.gasLabel, isNull);
      expect(d.tankPressureBar, 150.0);
      expect(d.tankPressureMissing, isFalse);
    });

    test('several readings show none rather than a guess', () {
      final r = PerdixFaceResolver(
        profile: profile,
        tankPressures: const {'first': first, 'second': second},
      );

      final d = r.resolve(35);
      expect(d.tankPressureBar, isNull);
      expect(d.tankPressureMissing, isTrue);
    });

    test('a sample before t=0 reads no cylinder on a dive with tanks', () {
      final r = PerdixFaceResolver(
        profile: [p(-10, 0.0), p(0, 2.0), p(30, 12.0)],
        tanks: const [
          DiveTank(id: 'first', gasMix: GasMix(o2: 21.0, he: 0.0), order: 0),
          DiveTank(id: 'second', gasMix: GasMix(o2: 50.0, he: 0.0), order: 1),
        ],
        tankPressures: const {'first': first, 'second': second},
      );

      final d = r.resolve(-5);
      expect(d.gasLabel, isNull);
      expect(d.tankPressureBar, isNull);
    });
  });

  group('forSource on a consolidated dive (#4300)', () {
    // Two overlapping recordings of one OC dive. The cylinders are A's,
    // shared with B; B logged the switch to EAN50 at 600 s, A at 900 s.
    const tanks = [
      DiveTank(
        id: 'air',
        name: 'Air back gas',
        computerId: 'computer-a',
        sharedComputerIds: ['computer-b'],
        gasMix: GasMix(o2: 21),
        order: 0,
      ),
      DiveTank(
        id: 'deco',
        name: 'EAN50 deco',
        computerId: 'computer-a',
        sharedComputerIds: ['computer-b'],
        gasMix: GasMix(o2: 50),
        role: TankRole.deco,
        order: 1,
      ),
    ];
    final activeProfile = [
      p(0, 0, ppO2: 0.21),
      p(400, 20, ppO2: 0.63),
      p(750, 12, ppO2: 0.462),
      p(950, 6, ppO2: 0.8),
      p(1200, 0, ppO2: 0.5),
    ];
    GasSwitchWithTank change(String computer, int time) => GasSwitchWithTank(
      gasSwitch: GasSwitch(
        id: 'switch-$computer',
        diveId: 'dive',
        timestamp: time,
        tankId: 'deco',
        computerId: computer,
        createdAt: DateTime.utc(2026),
      ),
      tankName: 'EAN50 deco',
      gasMix: 'EAN50',
      o2Fraction: 0.5,
    );
    final switches = [change('computer-b', 600), change('computer-a', 900)];
    const pressures = {
      'air': [
        TankPressurePoint(tankId: 'air', timestamp: 0, pressure: 200),
        TankPressurePoint(tankId: 'air', timestamp: 750, pressure: 145),
        TankPressurePoint(tankId: 'air', timestamp: 1200, pressure: 130),
      ],
      'deco': [
        TankPressurePoint(tankId: 'deco', timestamp: 0, pressure: 200),
        TankPressurePoint(tankId: 'deco', timestamp: 750, pressure: 200),
        TankPressurePoint(tankId: 'deco', timestamp: 1200, pressure: 180),
      ],
    };
    final dive = Dive(
      id: 'dive',
      dateTime: DateTime.utc(2026),
      diveMode: DiveMode.oc,
      tanks: tanks,
      profile: activeProfile,
    );

    PerdixFaceResolver resolverFor(String? computerId) =>
        PerdixFaceResolver.forSource(
          dive,
          profile: activeProfile,
          gasSwitches: switches,
          tankPressures: pressures,
          computerId: computerId,
        );

    test('another computer\'s earlier switch does not change the gas', () {
      final face = resolverFor('computer-a').resolve(750);
      expect(face.gasLabel, 'Air');
      expect(face.tankPressureBar, 145);
      expect(face.ppO2Bar, 0.462);
    });

    test('the selected computer\'s own switch still changes the gas', () {
      final r = resolverFor('computer-a');
      expect(r.resolve(400).gasLabel, 'Air');
      expect(r.resolve(950).gasLabel, 'EAN50');
      expect(r.resolve(950).tankPressureBar, 200);
    });

    test('the other computer reads its own schedule', () {
      final face = resolverFor('computer-b').resolve(750);
      expect(face.gasLabel, 'EAN50');
      expect(face.tankPressureBar, 200);
    });

    test('an empty series (metadata-only source) has no face', () {
      final r = PerdixFaceResolver.forSource(
        dive,
        profile: const [],
        gasSwitches: switches,
        tankPressures: pressures,
        computerId: 'computer-a',
      );
      expect(r.isAvailable, isFalse);
      expect(r.resolve(750).gasLabel, isNull);
      expect(r.resolve(750).tankPressureBar, isNull);
    });

    test('a whole-dive series (no computer) counts every switch', () {
      // Sequential halves of a Combine draw as one series, as on the chart.
      final face = resolverFor(null).resolve(750);
      expect(face.gasLabel, 'EAN50');
      expect(face.tankPressureBar, 200);
    });

    test('labels every moment as the profile chart\'s gas strip does', () {
      for (final computerId in ['computer-a', 'computer-b', null]) {
        final r = resolverFor(computerId);
        final strip = activeGasUsageSegments(
          dive,
          gasSwitches: switches,
          profile: activeProfile,
          computerId: computerId,
        );
        for (var t = 0; t <= 1200; t += 50) {
          final segment = strip.lastWhere((s) => t >= s.startSeconds);
          expect(
            r.resolve(t).gasLabel,
            segment.label,
            reason: 'computer $computerId at $t s',
          );
        }
      }
    });
  });

  group('forSource on an open-circuit dive with a diluent-tagged cylinder', () {
    // An OC dive is off the loop, so a diluent tag does not take the start:
    // the chart's strip starts on the back gas, and so must the face.
    const tanks = [
      DiveTank(
        id: 'dil',
        name: 'Diluent',
        gasMix: GasMix(o2: 10, he: 50),
        role: TankRole.diluent,
        order: 0,
      ),
      DiveTank(
        id: 'back',
        name: 'Back gas',
        gasMix: GasMix(o2: 21),
        role: TankRole.backGas,
        order: 1,
      ),
    ];
    const pressures = {
      'dil': [
        TankPressurePoint(tankId: 'dil', timestamp: 0, pressure: 190),
        TankPressurePoint(tankId: 'dil', timestamp: 40, pressure: 190),
      ],
      'back': [
        TankPressurePoint(tankId: 'back', timestamp: 0, pressure: 210),
        TankPressurePoint(tankId: 'back', timestamp: 40, pressure: 150),
      ],
    };
    final dive = Dive(
      id: 'oc',
      dateTime: DateTime.utc(2026),
      diveMode: DiveMode.oc,
      tanks: tanks,
      profile: profile,
    );

    test('starts on the back gas and reads its pressure', () {
      final r = PerdixFaceResolver.forSource(
        dive,
        profile: profile,
        tankPressures: pressures,
      );
      final strip = activeGasUsageSegments(
        dive,
        gasSwitches: const [],
        profile: profile,
      );
      expect(strip.single.label, 'Air');
      final face = r.resolve(20);
      expect(face.gasLabel, 'Air');
      // The back gas's reading (held from 0 s), not the diluent's 190 bar.
      expect(face.tankPressureBar, 210);
    });
  });
}
