import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/dive_merge_builder.dart';

Dive dive(
  String id, {
  DateTime? entry,
  int runtimeMin = 30,
  String? diverId = 'diver1',
  List<DiveProfilePoint> profile = const [],
}) => Dive(
  id: id,
  diverId: diverId,
  dateTime: entry ?? DateTime.utc(2026, 7, 1, 9),
  entryTime: entry ?? DateTime.utc(2026, 7, 1, 9),
  runtime: Duration(minutes: runtimeMin),
  profile: profile,
);

void main() {
  const builder = DiveMergeBuilder();

  group('classify', () {
    test('fewer than 2 dives is invalid', () {
      final result = builder.classify([dive('a')]);
      expect(result, isA<MergeInvalid>());
      expect(
        (result as MergeInvalid).reason,
        DiveMergeInvalidReason.tooFewDives,
      );
    });

    test('mixed divers is invalid', () {
      final result = builder.classify([
        dive('a', entry: DateTime.utc(2026, 7, 1, 9)),
        dive('b', entry: DateTime.utc(2026, 7, 1, 11), diverId: 'diver2'),
      ]);
      expect(result, isA<MergeInvalid>());
      expect(
        (result as MergeInvalid).reason,
        DiveMergeInvalidReason.mixedDivers,
      );
    });

    test('overlapping dives are classified overlapping', () {
      // a runs 09:00-09:30, b starts 09:15 -> overlap
      final result = builder.classify([
        dive('a', entry: DateTime.utc(2026, 7, 1, 9)),
        dive('b', entry: DateTime.utc(2026, 7, 1, 9, 15)),
      ]);
      expect(result, isA<MergeOverlapping>());
    });

    test('sequential dives sort chronologically and report the gap', () {
      // b: 10:00-10:20, a: 09:00-09:30 -> sorted a,b; gap 09:30-10:00
      final result = builder.classify([
        dive('b', entry: DateTime.utc(2026, 7, 1, 10), runtimeMin: 20),
        dive('a', entry: DateTime.utc(2026, 7, 1, 9), runtimeMin: 30),
      ]);
      expect(result, isA<MergeSequential>());
      final seq = result as MergeSequential;
      expect(seq.sortedDives.map((d) => d.id), ['a', 'b']);
      expect(seq.gaps, hasLength(1));
      expect(seq.gaps.single.afterDiveId, 'a');
      expect(seq.gaps.single.beforeDiveId, 'b');
      expect(seq.gaps.single.startSeconds, 30 * 60);
      expect(seq.gaps.single.endSeconds, 60 * 60);
      expect(seq.gaps.single.duration, const Duration(minutes: 30));
    });

    test('a dive with no derivable duration is treated as zero-length', () {
      // No runtime, no exitTime, no profile, no bottomTime: effectiveRuntime
      // is null, so the dive is zero-length and cannot overlap anything.
      final durationless = Dive(
        id: 'a',
        diverId: 'diver1',
        dateTime: DateTime.utc(2026, 7, 1, 9),
        entryTime: DateTime.utc(2026, 7, 1, 9),
      );
      final result = builder.classify([
        durationless,
        dive('b', entry: DateTime.utc(2026, 7, 1, 10)),
      ]);
      expect(result, isA<MergeSequential>());
    });

    test('touching dives (gap == 0) are sequential with a zero gap', () {
      final result = builder.classify([
        dive('a', entry: DateTime.utc(2026, 7, 1, 9), runtimeMin: 60),
        dive('b', entry: DateTime.utc(2026, 7, 1, 10)),
      ]);
      expect(result, isA<MergeSequential>());
      expect((result as MergeSequential).gaps.single.duration, Duration.zero);
    });
  });

  group('build - timeline', () {
    test('throws for non-sequential input', () {
      expect(() => builder.build([dive('a')]), throwsArgumentError);
    });

    test(
      'merged dive spans first entry to last exit; offsets are relative',
      () {
        var n = 0;
        final result = builder.build([
          dive('b', entry: DateTime.utc(2026, 7, 1, 10), runtimeMin: 20),
          dive('a', entry: DateTime.utc(2026, 7, 1, 9), runtimeMin: 30),
        ], idGenerator: () => 'gen-${n++}');

        final merged = result.mergedDive;
        expect(merged.id, 'gen-0');
        expect(merged.diverId, 'diver1');
        expect(merged.entryTime, DateTime.utc(2026, 7, 1, 9));
        expect(merged.exitTime, DateTime.utc(2026, 7, 1, 10, 20));
        expect(merged.runtime, const Duration(minutes: 80)); // includes the gap
        expect(result.segmentOffsetsSeconds, {'a': 0, 'b': 3600});
        expect(result.sortedSources.map((d) => d.id), ['a', 'b']);
        expect(result.gaps, hasLength(1));
      },
    );

    test('uses explicit exitTime of the last dive when set', () {
      final last = Dive(
        id: 'b',
        diverId: 'diver1',
        dateTime: DateTime.utc(2026, 7, 1, 10),
        entryTime: DateTime.utc(2026, 7, 1, 10),
        exitTime: DateTime.utc(2026, 7, 1, 10, 25),
        runtime: const Duration(minutes: 25),
      );
      final result = builder.build([dive('a'), last]);
      expect(result.mergedDive.exitTime, DateTime.utc(2026, 7, 1, 10, 25));
    });
  });

  group('build - stats', () {
    List<DiveProfilePoint> flatProfile(int seconds, double depth) => [
      for (var t = 0; t <= seconds; t += 10)
        DiveProfilePoint(timestamp: t, depth: depth),
    ];

    test('bottomTime sums sources; maxDepth is the max', () {
      final a = dive(
        'a',
        entry: DateTime.utc(2026, 7, 1, 9),
      ).copyWith(bottomTime: const Duration(minutes: 25), maxDepth: 18.0);
      final b = dive(
        'b',
        entry: DateTime.utc(2026, 7, 1, 10),
      ).copyWith(bottomTime: const Duration(minutes: 20), maxDepth: 30.5);
      final merged = builder.build([a, b]).mergedDive;
      expect(merged.bottomTime, const Duration(minutes: 45));
      expect(merged.maxDepth, 30.5);
    });

    test('avgDepth is weighted by sampled time and excludes the gap', () {
      // a: 600s at a constant 10m; b: 600s at a constant 20m; 30min gap.
      final a = dive(
        'a',
        entry: DateTime.utc(2026, 7, 1, 9),
        runtimeMin: 10,
        profile: flatProfile(600, 10),
      );
      final b = dive(
        'b',
        entry: DateTime.utc(2026, 7, 1, 10),
        runtimeMin: 10,
        profile: flatProfile(600, 20),
      );
      final merged = builder.build([a, b]).mergedDive;
      // Equal sampled spans -> plain mean of 10 and 20; the 30min gap at
      // 0m must NOT drag this down.
      expect(merged.avgDepth, closeTo(15.0, 0.001));
    });

    test('profile-less source falls back to stored avgDepth x runtime', () {
      final a = dive(
        'a',
        entry: DateTime.utc(2026, 7, 1, 9),
        runtimeMin: 10,
        profile: flatProfile(600, 10),
      );
      final b = dive(
        'b',
        entry: DateTime.utc(2026, 7, 1, 10),
        runtimeMin: 30,
      ).copyWith(avgDepth: 20.0);
      final merged = builder.build([a, b]).mergedDive;
      // 600s @ 10m + 1800s @ 20m = (6000 + 36000) / 2400 = 17.5
      expect(merged.avgDepth, closeTo(17.5, 0.001));
    });

    test('stats are null when no source has any data', () {
      final merged = builder.build([
        dive('a', entry: DateTime.utc(2026, 7, 1, 9), runtimeMin: 0),
        dive('b', entry: DateTime.utc(2026, 7, 1, 10), runtimeMin: 0),
      ]).mergedDive;
      expect(merged.maxDepth, isNull);
      expect(merged.avgDepth, isNull);
      expect(merged.bottomTime, isNull);
    });
  });
}
