import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/buoyancy/body_composition.dart';
import 'package:submersion/core/buoyancy/buoyancy_twin.dart';
import 'package:submersion/core/buoyancy/twin_analyzer.dart';
import 'package:submersion/core/buoyancy/twin_balance.dart';
import 'package:submersion/core/buoyancy/weight_prediction_engine.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';

const _statics = [
  TwinStaticTerm(label: 'personal', kg: 5.0, source: TermSource.measured),
  TwinStaticTerm(label: 'water', kg: 0.3, source: TermSource.physics),
  TwinStaticTerm(label: 'Backplate', kg: -2.5, source: TermSource.userSpec),
  TwinStaticTerm(label: 'Regulator', kg: -0.8, source: TermSource.typeDefault),
];

// personal 5.0 + water 0.3 + Backplate -2.5 + Regulator -0.8
const _staticKg = 2.0;
const _leadKg = 6.0;

TwinSample _sample(
  int t,
  double depth, {
  required double suit,
  required double tanks,
}) => TwinSample(
  timestamp: t,
  depthM: depth,
  suitKg: suit,
  tanksKg: tanks,
  netKg: suit + tanks + _staticKg - _leadKg,
);

BuoyancyTwinResult _result(
  List<TwinSample> samples, {
  TwinSuitKind suitKind = TwinSuitKind.wetsuit,
  List<TwinStaticTerm> statics = _statics,
  bool withTank = true,
}) => BuoyancyTwinResult(
  samples: samples,
  staticKg: statics.fold(0.0, (s, t) => s + t.kg),
  suitSurfaceKg: 4.0,
  drysuitGasLiters: 0,
  pressuresEstimated: false,
  input: TwinInput(
    profile: const [],
    tanks: withTank
        ? const [
            TwinTankInput(
              id: 't1',
              label: 'AL80',
              presetName: 'al80',
              material: TankMaterial.aluminum,
            ),
          ]
        : const [],
    suit: TwinSuitInput(
      kind: suitKind,
      anchorKg: 3.0,
      source: TermSource.typeDefault,
    ),
    staticTerms: statics,
    leadKg: _leadKg,
    droppableLeadKg: 4.0,
    environment: DiveEnvironment.forConditions(waterType: WaterType.salt),
  ),
);

TwinVerdict _verdict({
  double suit = 3.0,
  double tank = -1.0,
  TwinAnchorKind kind = TwinAnchorKind.detectedStop,
  int timestamp = 1800,
}) {
  final terms = [
    TwinStaticTerm(label: 'suit', kg: suit, source: TermSource.typeDefault),
    TwinStaticTerm(label: 'AL80', kg: tank, source: TermSource.physics),
    ..._statics,
    const TwinStaticTerm(
      label: 'lead',
      kg: -_leadKg,
      source: TermSource.measured,
    ),
  ];
  return TwinVerdict(
    anchor: TwinAnchor(kind: kind, timestamp: timestamp, depthM: 5.0),
    netKg: terms.fold(0.0, (s, t) => s + t.kg),
    terms: terms,
  );
}

double _kg(TwinBalance b, TwinBalancePartKind kind) =>
    b.parts.firstWhere((p) => p.kind == kind).kg;

void main() {
  final dive = [
    _sample(0, 0, suit: 4.0, tanks: -2.0),
    _sample(60, 2, suit: 3.6, tanks: -2.0),
    _sample(600, 28, suit: 1.2, tanks: -1.4),
    _sample(1800, 5, suit: 3.0, tanks: 0.4),
    _sample(1900, 0.5, suit: 3.9, tanks: 0.4),
  ];

  group('TwinBalance.atSample', () {
    test('parts sum to the sample net', () {
      final result = _result(dive);
      for (final s in dive) {
        final b = TwinBalance.atSample(result, s);
        final sum = b.parts.fold(0.0, (t, p) => t + p.kg);
        expect(sum, closeTo(s.netKg, 1e-9));
        expect(b.netKg, s.netKg);
      }
    });

    test('lead is down; tanks follow their sign', () {
      final result = _result(dive);
      final full = TwinBalance.atSample(result, dive[0]);
      expect(full.down.map((p) => p.kind), contains(TwinBalancePartKind.lead));
      expect(full.down.map((p) => p.kind), contains(TwinBalancePartKind.tanks));

      final empty = TwinBalance.atSample(result, dive[3]);
      expect(empty.up.map((p) => p.kind), contains(TwinBalancePartKind.tanks));
      expect(
        empty.down.map((p) => p.kind),
        isNot(contains(TwinBalancePartKind.tanks)),
      );
    });

    test('gear and body terms are grouped', () {
      final b = TwinBalance.atSample(_result(dive), dive[0]);
      expect(_kg(b, TwinBalancePartKind.body), closeTo(5.3, 1e-9));
      expect(_kg(b, TwinBalancePartKind.gear), closeTo(-3.3, 1e-9));
      expect(_kg(b, TwinBalancePartKind.lead), -6.0);
    });

    test('the body-composition term counts as body', () {
      const statics = [
        TwinStaticTerm(label: 'personal', kg: 5.0, source: TermSource.measured),
        TwinStaticTerm(
          label: BodyComposition.termLabel,
          kg: 0.7,
          source: TermSource.bodyComposition,
        ),
      ];
      final s = TwinSample(
        timestamp: 0,
        depthM: 5,
        suitKg: 3,
        tanksKg: -1,
        netKg: 3 - 1 + 5.7 - _leadKg,
      );
      final b = TwinBalance.atSample(_result([s], statics: statics), s);
      expect(_kg(b, TwinBalancePartKind.body), closeTo(5.7, 1e-9));
      expect(
        b.parts.map((p) => p.kind),
        isNot(contains(TwinBalancePartKind.gear)),
      );
    });

    test('a part under 0.05 kg is dropped', () {
      final s = _sample(0, 30, suit: 0.02, tanks: -2.0);
      final b = TwinBalance.atSample(_result([s]), s);
      expect(
        b.parts.map((p) => p.kind),
        isNot(contains(TwinBalancePartKind.suit)),
      );
      // The net still reports the real figure.
      expect(b.netKg, s.netKg);
    });

    test('side totals are positive magnitudes', () {
      final b = TwinBalance.atSample(_result(dive), dive[0]);
      // down: lead 6 + tanks 2 + gear 3.3; up: suit 4 + body 5.3
      expect(b.downTotalKg, closeTo(11.3, 1e-9));
      expect(b.upTotalKg, closeTo(9.3, 1e-9));
    });
  });

  group('TwinBalance.atRest', () {
    test('parts sum to the verdict net', () {
      final verdict = _verdict();
      final b = TwinBalance.atRest(_result(dive), verdict);
      final sum = b.parts.fold(0.0, (t, p) => t + p.kg);
      expect(sum, closeTo(verdict.netKg, 1e-9));
      expect(b.netKg, verdict.netKg);
    });

    test('reads suit and tanks from the verdict terms', () {
      final b = TwinBalance.atRest(
        _result(dive),
        _verdict(suit: 2.9, tank: 0.3),
      );
      expect(_kg(b, TwinBalancePartKind.suit), closeTo(2.9, 1e-9));
      expect(_kg(b, TwinBalancePartKind.tanks), closeTo(0.3, 1e-9));
    });

    test('with no suit, a first term is not mistaken for one', () {
      final terms = [
        const TwinStaticTerm(
          label: 'AL80',
          kg: -1.0,
          source: TermSource.physics,
        ),
        ..._statics,
        const TwinStaticTerm(
          label: 'lead',
          kg: -_leadKg,
          source: TermSource.measured,
        ),
      ];
      final verdict = TwinVerdict(
        anchor: const TwinAnchor(
          kind: TwinAnchorKind.detectedStop,
          timestamp: 1800,
          depthM: 5,
        ),
        netKg: terms.fold(0.0, (s, t) => s + t.kg),
        terms: terms,
      );
      final b = TwinBalance.atRest(
        _result(dive, suitKind: TwinSuitKind.none),
        verdict,
      );
      expect(
        b.parts.map((p) => p.kind),
        isNot(contains(TwinBalancePartKind.suit)),
      );
      expect(_kg(b, TwinBalancePartKind.tanks), closeTo(-1.0, 1e-9));
    });
  });

  group('TwinBalance.scaleKg', () {
    test('is the largest side total over the dive and the rest state', () {
      // Sample 0 has the heaviest down side: 6 + 2 + 3.3 = 11.3.
      expect(
        TwinBalance.scaleKg(_result(dive), _verdict()),
        closeTo(11.3, 1e-9),
      );
    });

    test('is never zero', () {
      final empty = _result(const [], statics: const [], withTank: false);
      final verdict = TwinVerdict(
        anchor: const TwinAnchor(
          kind: TwinAnchorKind.convention,
          timestamp: -1,
          depthM: 5,
        ),
        netKg: 0,
        terms: const [],
      );
      expect(TwinBalance.scaleKg(empty, verdict), greaterThan(0));
    });
  });

  group('TwinMoments', () {
    test('start is the first in-water sample, deepest the max depth', () {
      final m = TwinMoments.of(_result(dive), _verdict());
      expect(m.start!.timestamp, 60);
      expect(m.deepest!.timestamp, 600);
      expect(m.finalStopSeconds, 1800);
    });

    test('finalStopSeconds is null for the convention anchor', () {
      final m = TwinMoments.of(
        _result(dive),
        _verdict(kind: TwinAnchorKind.convention, timestamp: -1),
      );
      expect(m.finalStopSeconds, isNull);
    });

    test('suit squeeze is start lift minus deepest lift, wetsuit only', () {
      final wet = TwinMoments.of(_result(dive), _verdict());
      expect(wet.suitSqueezeKg, closeTo(2.4, 1e-9)); // 3.6 - 1.2

      final dry = TwinMoments.of(
        _result(dive, suitKind: TwinSuitKind.drysuit),
        _verdict(),
      );
      expect(dry.suitSqueezeKg, isNull);

      final none = TwinMoments.of(
        _result(dive, suitKind: TwinSuitKind.none),
        _verdict(),
      );
      expect(none.suitSqueezeKg, isNull);
    });

    test('gas lighter is last tanks minus first, null when negligible', () {
      final m = TwinMoments.of(_result(dive), _verdict());
      expect(m.gasLighterKg, closeTo(2.4, 1e-9)); // 0.4 - (-2.0)

      final flat = [
        _sample(0, 0, suit: 4, tanks: -2.0),
        _sample(600, 20, suit: 2, tanks: -1.98),
      ];
      expect(TwinMoments.of(_result(flat), _verdict()).gasLighterKg, isNull);
    });

    test('an empty profile has no moments', () {
      final m = TwinMoments.of(
        _result(const []),
        _verdict(kind: TwinAnchorKind.convention, timestamp: -1),
      );
      expect(m.start, isNull);
      expect(m.deepest, isNull);
      expect(m.suitSqueezeKg, isNull);
      expect(m.gasLighterKg, isNull);
    });
  });
}
