import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
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
            id: 'p1',
            tankId: 'tank-air',
            timestamp: 0,
            pressure: 200.0,
          ),
          const TankPressurePoint(
            id: 'p2',
            tankId: 'tank-air',
            timestamp: 30,
            pressure: 120.0,
          ),
        ],
        'tank-ean50': [
          const TankPressurePoint(
            id: 'p3',
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
  });
}
