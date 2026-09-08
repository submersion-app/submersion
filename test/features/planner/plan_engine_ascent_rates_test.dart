import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

/// A planned ascent is four rates, not one, following TDI's decompression
/// procedures: bottom to the first stop, between intermediate stops, between
/// shallow stops, and the last stop to the surface. A diver comparing a plan
/// against another planner sees the difference mostly in the stop times -
/// time spent ascending slowly is decompression the stops no longer have to
/// provide.
const _air = GasMix(o2: 21);
const _airTank = DiveTank(
  id: 'back',
  volume: 22.0,
  startPressure: 200.0,
  gasMix: _air,
);
const _ean50 = DiveTank(
  id: 'deco',
  volume: 11.0,
  startPressure: 200.0,
  gasMix: GasMix(o2: 50),
);

domain.DivePlan _plan({
  required double bottomDepth,
  required int bottomMinutes,
  int gfLow = 50,
  int gfHigh = 80,
  double ascentRate = 9.0,
  double intermediateAscentRate = 6.0,
  double shallowAscentRate = 3.0,
  double finalAscentRate = 1.0,
}) => domain.DivePlan(
  id: 'p',
  name: 'rates',
  gfLow: gfLow,
  gfHigh: gfHigh,
  tanks: const [_airTank, _ean50],
  ascentRate: ascentRate,
  intermediateAscentRate: intermediateAscentRate,
  shallowAscentRate: shallowAscentRate,
  finalAscentRate: finalAscentRate,
  segments: [
    PlanSegment.travel(
      id: 'seg-1',
      fromDepth: 0,
      targetDepth: bottomDepth,
      ratePerMinute: 10,
      tankId: 'back',
      gasMix: _air,
      order: 0,
    ),
    PlanSegment.hold(
      id: 'seg-2',
      depth: bottomDepth,
      durationMinutes: bottomMinutes,
      tankId: 'back',
      gasMix: _air,
      order: 1,
    ),
  ],
  createdAt: DateTime(2026, 9, 2),
  updatedAt: DateTime(2026, 9, 2),
);

/// The same plan with every band collapsed onto the working rate: the
/// single-rate arithmetic the engine used before the bands existed.
domain.DivePlan _flat({
  required double bottomDepth,
  required int bottomMinutes,
}) => _plan(
  bottomDepth: bottomDepth,
  bottomMinutes: bottomMinutes,
  intermediateAscentRate: 9.0,
  shallowAscentRate: 9.0,
  finalAscentRate: 9.0,
);

const _engine = PlanEngine();

/// Seconds of travel between consecutive stops: the later stop's arrival
/// minus the earlier one's departure.
List<int> _travelGaps(List<dynamic> stops) => [
  for (var i = 1; i < stops.length; i++)
    stops[i].arrivalRuntimeSeconds -
        (stops[i - 1].arrivalRuntimeSeconds + stops[i - 1].durationSeconds),
];

void main() {
  group('defaults', () {
    test('a plan carries the TDI bands: 9 off the bottom, then 6, 3 and 1', () {
      final plan = domain.DivePlan(
        id: 'p',
        name: 'n',
        gfLow: 30,
        gfHigh: 70,
        createdAt: DateTime(2026, 9, 2),
        updatedAt: DateTime(2026, 9, 2),
      );
      expect(plan.ascentRate, 9.0);
      expect(plan.intermediateAscentRate, 6.0);
      expect(plan.shallowAscentRate, 3.0);
      expect(plan.finalAscentRate, 1.0);
    });
  });

  group('no-deco plan', () {
    test('the deco rates do not touch a dive that owes nothing', () {
      // 18 m for 20 min owes no decompression, so there is no first stop to
      // slow down for and no last stop to crawl off: the whole ascent is the
      // working rate, 18 m at 9 m/min. Configuring the deco rates must not
      // change a recreational profile at all.
      final banded = _engine.compute(_plan(bottomDepth: 18, bottomMinutes: 20));
      final flat = _engine.compute(_flat(bottomDepth: 18, bottomMinutes: 20));

      expect(banded.stops, isEmpty);
      expect(flat.stops, isEmpty);
      expect(banded.ttsAtBottom, flat.ttsAtBottom);
      expect(banded.ttsAtBottom, 120);
    });
  });

  group('deco plan', () {
    test(
      'a grid level that clears on arrival is flown at the working rate',
      () {
        // 36 m for 16 min puts the first grid level deeper than 9 m, but it
        // clears on arrival: the only stop actually held is at 6 m. A diver who
        // has not stopped yet is still on the working ascent off the bottom,
        // so no leg of this dive is ever timed at the intermediate rate and
        // changing that rate cannot change the schedule.
        //
        // Loading those passed-through levels at the between-stops rate is what
        // this pins against: at 1 m/min the tissues spent three minutes on a
        // 3 m leg the diver flies in twenty seconds, and the off-gassing bought
        // there deleted the 6 m stop's second minute outright.
        final crawl = _engine.compute(
          _plan(
            bottomDepth: 36,
            bottomMinutes: 16,
            intermediateAscentRate: 1.0,
          ),
        );
        final quick = _engine.compute(
          _plan(
            bottomDepth: 36,
            bottomMinutes: 16,
            intermediateAscentRate: 9.0,
          ),
        );

        expect(quick.stops.map((s) => s.depthMeters), [6.0]);
        expect(
          crawl.stops.map((s) => (s.depthMeters, s.durationSeconds)),
          quick.stops.map((s) => (s.depthMeters, s.durationSeconds)),
        );
      },
    );

    test('travel between stops slows as the stops get shallower', () {
      final out = _engine.compute(_plan(bottomDepth: 50, bottomMinutes: 30));
      final depths = out.stops.map((s) => s.depthMeters).toList();
      expect(depths.first, greaterThan(9.0));
      expect(depths.last, 3.0);

      // Deeper than 9 m: 3 m at 6 m/min = 30 s. At 9 m and above: 3 m at
      // 3 m/min = 60 s.
      final gaps = _travelGaps(out.stops);
      for (var i = 0; i < gaps.length; i++) {
        final from = depths[i];
        expect(
          gaps[i],
          from > 9.0 ? 30 : 60,
          reason: 'travel from $from m to ${depths[i + 1]} m',
        );
      }
    });

    test('the first stop is reached at the working rate', () {
      // Leaving the bottom is the working ascent even though the first stop
      // is a deco stop: 50 m to 21 m at 9 m/min = 193 s. The bottom ends at
      // 5 + 30 minutes.
      final out = _engine.compute(_plan(bottomDepth: 50, bottomMinutes: 30));
      expect(out.stops.first.arrivalRuntimeSeconds - 35 * 60, 193);
    });

    test('slowing the ascent shortens the stops it replaces', () {
      // The same obligation, redistributed: time spent ascending slowly is
      // decompression, so the stops need less of it.
      final banded = _engine.compute(_plan(bottomDepth: 50, bottomMinutes: 30));
      final flat = _engine.compute(_flat(bottomDepth: 50, bottomMinutes: 30));

      expect(
        banded.totalDecoSeconds,
        lessThan(flat.totalDecoSeconds),
        reason: 'stop time should fall when the ascent itself decompresses',
      );
    });

    test('setting every band the same reproduces a single-rate ascent', () {
      // The escape hatch: a diver who wants one rate gets exactly the old
      // arithmetic, 3 m at 9 m/min = 20 s between every pair of stops.
      final out = _engine.compute(_flat(bottomDepth: 50, bottomMinutes: 30));
      expect(_travelGaps(out.stops), everyElement(20));
    });
  });
}
