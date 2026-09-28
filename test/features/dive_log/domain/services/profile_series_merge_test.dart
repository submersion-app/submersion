import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_summary.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_series.dart';
import 'package:submersion/features/dive_log/domain/services/profile_series_merge.dart';

TankPressureSeries tankSeries(
  String id, {
  String tankId = 'tank-a',
  String? computerId,
  required List<TankPressureSample> samples,
}) => TankPressureSeries(
  id: id,
  diveId: 'd1',
  tankId: tankId,
  computerId: computerId,
  summary: TankPressureSeriesSummary.of(samples),
  samples: samples,
  codecVersion: 1,
  createdAt: 0,
  updatedAt: 0,
);

ProfileSeries series(
  String id, {
  String? computerId,
  String? sourceId,
  bool isPrimary = true,
  required List<ProfileSample> samples,
}) => ProfileSeries(
  id: id,
  diveId: 'd1',
  computerId: computerId,
  sourceId: sourceId,
  isPrimary: isPrimary,
  summary: ProfileSeriesSummary.of(samples),
  samples: samples,
  codecVersion: 1,
  createdAt: 0,
  updatedAt: 0,
);

void main() {
  group('mergeSeriesPoints', () {
    test('a single series maps straight to points', () {
      final s = series(
        'a',
        samples: const [
          ProfileSample(timestamp: 0, depth: 0.0),
          ProfileSample(timestamp: 10, depth: 5.0),
        ],
      );
      expect(mergeSeriesPoints([s]).map((p) => p.timestamp), [0, 10]);
    });

    test('two series interleave by timestamp', () {
      final a = series(
        'a',
        computerId: 'c1',
        samples: const [
          ProfileSample(timestamp: 0, depth: 0.0),
          ProfileSample(timestamp: 20, depth: 10.0),
        ],
      );
      final b = series(
        'b',
        computerId: 'c2',
        samples: const [
          ProfileSample(timestamp: 10, depth: 4.0),
          ProfileSample(timestamp: 30, depth: 2.0),
        ],
      );
      expect(mergeSeriesPoints([a, b]).map((p) => p.timestamp), [
        0,
        10,
        20,
        30,
      ]);
    });

    test('ties keep series order, then within-series order', () {
      final a = series(
        'a',
        samples: const [
          ProfileSample(timestamp: 10, depth: 1.0),
          ProfileSample(timestamp: 10, depth: 1.5),
        ],
      );
      final b = series(
        'b',
        samples: const [ProfileSample(timestamp: 10, depth: 2.0)],
      );
      expect(mergeSeriesPoints([a, b]).map((p) => p.depth), [1.0, 1.5, 2.0]);
      expect(mergeSeriesPoints([b, a]).map((p) => p.depth), [2.0, 1.0, 1.5]);
    });

    test('an empty list merges to an empty list', () {
      expect(mergeSeriesPoints(const []), isEmpty);
    });
  });

  group('dropSupersededSeries', () {
    final original = series(
      'orig',
      computerId: 'c1',
      sourceId: 's1',
      isPrimary: false,
      samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
    );
    final edit = series(
      'edit',
      sourceId: 's1',
      samples: const [ProfileSample(timestamp: 0, depth: 2.0)],
    );
    final other = series(
      'other',
      computerId: 'c2',
      sourceId: 's2',
      isPrimary: false,
      samples: const [ProfileSample(timestamp: 0, depth: 3.0)],
    );

    test('an edit drops the demoted original of the primary family', () {
      final kept = dropSupersededSeries(
        [original, edit, other],
        hasSources: true,
        primaryComputerId: 'c1',
      );
      expect(kept.map((s) => s.id), ['edit', 'other']);
    });

    test('without an edit nothing is dropped', () {
      final kept = dropSupersededSeries(
        [original, other],
        hasSources: true,
        primaryComputerId: 'c1',
      );
      expect(kept.map((s) => s.id), ['orig', 'other']);
    });

    test('a dive with no primary series keeps everything', () {
      final kept = dropSupersededSeries(
        [original, other],
        hasSources: true,
        primaryComputerId: null,
      );
      expect(kept, hasLength(2));
    });

    test('with no data sources every series is family', () {
      final demotedManual = series(
        'old',
        isPrimary: false,
        samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
      );
      final kept = dropSupersededSeries(
        [demotedManual, edit, other],
        hasSources: false,
        primaryComputerId: null,
      );
      expect(kept.map((s) => s.id), ['edit']);
    });
  });

  group('mergeSeriesPointsCollapsingDuplicates', () {
    test('two series sharing an identity with identical samples collapse', () {
      final a = series(
        'a',
        computerId: 'c1',
        sourceId: 's1',
        samples: const [
          ProfileSample(timestamp: 0, depth: 0.0),
          ProfileSample(timestamp: 10, depth: 1.0),
          ProfileSample(timestamp: 20, depth: 2.0),
        ],
      );
      final b = series(
        'b',
        computerId: 'c1',
        sourceId: 's1',
        samples: const [
          ProfileSample(timestamp: 0, depth: 0.0),
          ProfileSample(timestamp: 10, depth: 1.0),
          ProfileSample(timestamp: 20, depth: 2.0),
        ],
      );
      final merged = mergeSeriesPointsCollapsingDuplicates([a, b]);
      expect(merged, hasLength(3));
      expect(merged.map((p) => p.timestamp), [0, 10, 20]);
    });

    test('identical samples from two different computers are both kept', () {
      final a = series(
        'a',
        computerId: 'c1',
        samples: const [
          ProfileSample(timestamp: 0, depth: 0.0),
          ProfileSample(timestamp: 10, depth: 1.0),
          ProfileSample(timestamp: 20, depth: 2.0),
        ],
      );
      final b = series(
        'b',
        computerId: 'c2',
        samples: const [
          ProfileSample(timestamp: 0, depth: 0.0),
          ProfileSample(timestamp: 10, depth: 1.0),
          ProfileSample(timestamp: 20, depth: 2.0),
        ],
      );
      expect(mergeSeriesPointsCollapsingDuplicates([a, b]), hasLength(6));
    });

    test('same identity, partially overlapping timestamps merge and collapse '
        'only the shared ones', () {
      final a = series(
        'a',
        computerId: 'c1',
        sourceId: 's1',
        samples: const [
          ProfileSample(timestamp: 0, depth: 0.0),
          ProfileSample(timestamp: 10, depth: 1.0),
        ],
      );
      final b = series(
        'b',
        computerId: 'c1',
        sourceId: 's1',
        samples: const [
          ProfileSample(timestamp: 10, depth: 1.0),
          ProfileSample(timestamp: 20, depth: 2.0),
        ],
      );
      expect(
        mergeSeriesPointsCollapsingDuplicates([a, b]).map((p) => p.timestamp),
        [0, 10, 20],
      );
    });

    test('a single series with an internal duplicate does not crash and '
        'collapses to one point', () {
      final a = series(
        'a',
        samples: const [
          ProfileSample(timestamp: 0, depth: 0.0),
          ProfileSample(timestamp: 0, depth: 0.0),
        ],
      );
      expect(mergeSeriesPointsCollapsingDuplicates([a]), hasLength(1));
    });

    test('an empty list merges to an empty list', () {
      expect(mergeSeriesPointsCollapsingDuplicates(const []), isEmpty);
    });
  });

  group('mergeTankSeriesPoints', () {
    test('two series interleave by timestamp', () {
      final a = tankSeries(
        'a',
        computerId: 'comp-1',
        samples: const [
          TankPressureSample(timestamp: 0, pressure: 200.0),
          TankPressureSample(timestamp: 1800, pressure: 150.0),
        ],
      );
      final b = tankSeries(
        'b',
        samples: const [TankPressureSample(timestamp: 900, pressure: 180.0)],
      );
      final merged = mergeTankSeriesPoints([a, b]);
      expect(merged.map((p) => p.timestamp), [0, 900, 1800]);
      expect(merged.map((p) => p.pressure), [200.0, 180.0, 150.0]);
    });

    test('ties keep series order, then within-series order', () {
      final a = tankSeries(
        'a',
        samples: const [
          TankPressureSample(timestamp: 10, pressure: 100.0),
          TankPressureSample(timestamp: 10, pressure: 90.0),
        ],
      );
      final b = tankSeries(
        'b',
        samples: const [TankPressureSample(timestamp: 10, pressure: 80.0)],
      );
      expect(mergeTankSeriesPoints([a, b]).map((p) => p.pressure), [
        100.0,
        90.0,
        80.0,
      ]);
      expect(mergeTankSeriesPoints([b, a]).map((p) => p.pressure), [
        80.0,
        100.0,
        90.0,
      ]);
    });

    test('an empty list merges to an empty list', () {
      expect(mergeTankSeriesPoints(const []), isEmpty);
    });
  });

  group('selectTankSeriesForComputer', () {
    // Two computers paired to one transmitter each log the same cylinder,
    // and consolidation files both series under one tank. Interleaving them
    // alternates between the two computers' readings sample by sample.
    final black = tankSeries(
      'black',
      computerId: 'dc-black',
      samples: const [
        TankPressureSample(timestamp: 2, pressure: 225.5),
        TankPressureSample(timestamp: 4, pressure: 225.5),
      ],
    );
    final bronze = tankSeries(
      'bronze',
      computerId: 'dc-bronze',
      samples: const [
        TankPressureSample(timestamp: 3, pressure: 223.5),
        TankPressureSample(timestamp: 5, pressure: 223.5),
      ],
    );

    test('keeps only the requested computer\'s series on a shared tank', () {
      final kept = selectTankSeriesForComputer([black, bronze], 'dc-bronze');
      expect(kept.map((s) => s.id), ['bronze']);
    });

    test('falls back to every series of a tank the computer did not log', () {
      final stage = tankSeries(
        'stage',
        tankId: 'tank-stage',
        computerId: 'dc-black',
        samples: const [TankPressureSample(timestamp: 0, pressure: 200.0)],
      );
      final kept = selectTankSeriesForComputer([
        black,
        bronze,
        stage,
      ], 'dc-bronze');
      expect(kept.map((s) => s.id), ['bronze', 'stage']);
    });

    test('a null computer prefers series with no computer', () {
      final manual = tankSeries(
        'manual',
        samples: const [TankPressureSample(timestamp: 0, pressure: 210.0)],
      );
      final kept = selectTankSeriesForComputer([black, manual], null);
      expect(kept.map((s) => s.id), ['manual']);
    });

    test('preserves input order within the kept series', () {
      final kept = selectTankSeriesForComputer([bronze, black], 'dc-black');
      expect(kept.map((s) => s.id), ['black']);
      expect(selectTankSeriesForComputer(const [], 'dc-black'), isEmpty);
    });
  });

  // Issue #2440: two file imports of one dive, consolidated, both log the
  // same cylinder with no computer. Interleaving them zigzags between two
  // recordings offset in time.
  group('selectTankSeriesPerSource', () {
    List<TankPressureSample> span(int from, int to, double start) => [
      for (var t = from; t <= to; t += 10)
        TankPressureSample(timestamp: t, pressure: start - (t - from) * 0.05),
    ];
    TankPressureSeries sourced(
      String id,
      String? sourceId,
      List<TankPressureSample> samples, {
      String tankId = 'tank-a',
      String? computerId,
    }) => tankSeries(
      id,
      tankId: tankId,
      computerId: computerId,
      samples: samples,
    ).copyWith(sourceId: sourceId);

    test('overlapping sources on one tank keep only the preferred one', () {
      final primary = sourced('p', 'src-p', span(0, 3000, 200));
      final other = sourced('o', 'src-o', span(50, 3050, 198));
      final kept = selectTankSeriesPerSource([
        other,
        primary,
      ], preferredSourceId: 'src-p');
      expect(kept.map((s) => s.id), ['p']);
    });

    test('sources that follow one another are all kept', () {
      // A combined dive: each half was recorded by its own source.
      final first = sourced('a', 'src-a', span(0, 1500, 200));
      final second = sourced('b', 'src-b', span(2000, 3500, 120));
      final kept = selectTankSeriesPerSource([
        first,
        second,
      ], preferredSourceId: 'src-a');
      expect(kept.map((s) => s.id), ['a', 'b']);
    });

    test('a recording in the gap between two of another source is kept', () {
      // Source A recorded 0-1000 and 3000-4000; source B the stretch
      // between. Nothing overlaps, so all three belong in the line even
      // though A's series together span B's.
      final a1 = sourced('a1', 'src-a', span(0, 1000, 200));
      final a2 = sourced('a2', 'src-a', span(3000, 4000, 100));
      final b = sourced('b', 'src-b', span(1500, 2500, 150));
      final kept = selectTankSeriesPerSource([
        a1,
        b,
        a2,
      ], preferredSourceId: 'src-a');
      expect(kept.map((s) => s.id), ['a1', 'b', 'a2']);
    });

    test('several series of one source are all kept', () {
      final a = sourced('a1', 'src-a', span(0, 1500, 200));
      final b = sourced('a2', 'src-a', span(1000, 3000, 150));
      final kept = selectTankSeriesPerSource([a, b], preferredSourceId: null);
      expect(kept.map((s) => s.id), ['a1', 'a2']);
    });

    test('unattributed overlapping series never interleave', () {
      // Legacy rows with no source: each is its own recording, and the
      // fuller one wins.
      final short = sourced('s', null, span(0, 600, 200));
      final full = sourced('f', null, span(0, 3000, 200));
      final kept = selectTankSeriesPerSource([
        short,
        full,
      ], preferredSourceId: 'src-x');
      expect(kept.map((s) => s.id), ['f']);
    });

    test('an unattributed series of the preferred computer wins', () {
      final mine = sourced('m', null, span(0, 600, 200), computerId: 'dc-1');
      final theirs = sourced('t', null, span(0, 3000, 200), computerId: 'dc-2');
      final kept = selectTankSeriesPerSource(
        [theirs, mine],
        preferredSourceId: null,
        preferredComputerId: 'dc-1',
      );
      expect(kept.map((s) => s.id), ['m']);
    });

    test('each tank is chosen on its own', () {
      final back = sourced('back', 'src-o', span(0, 3000, 200), tankId: 'b');
      final stage = sourced('stage', 'src-p', span(0, 3000, 200), tankId: 's');
      final kept = selectTankSeriesPerSource([
        back,
        stage,
      ], preferredSourceId: 'src-p');
      expect(kept.map((s) => s.id), ['back', 'stage']);
    });

    test('an empty list stays empty', () {
      expect(
        selectTankSeriesPerSource(const [], preferredSourceId: 'x'),
        isEmpty,
      );
    });
  });
}
