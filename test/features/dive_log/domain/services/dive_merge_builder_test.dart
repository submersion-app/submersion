import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/presentation/widgets/dive_sparkline.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_custom_field.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
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

    test('gap starts at the profile extent when samples outrun runtime', () {
      // Computers keep sampling past the runtime they declare (surface
      // bobbing before the log closes). The gap must start after the LAST
      // sample, or the seam is left with an uncovered sample hole that the
      // profile chart draws as a swooping curved line (#449 manual test).
      final a = dive(
        'a',
        entry: DateTime.utc(2026, 7, 1, 9),
        runtimeMin: 5,
        profile: const [
          DiveProfilePoint(timestamp: 2, depth: 5),
          DiveProfilePoint(timestamp: 300, depth: 0.2),
          DiveProfilePoint(timestamp: 366, depth: 0.1),
        ],
      );
      final b = dive('b', entry: DateTime.utc(2026, 7, 1, 9, 10));
      final result = builder.classify([a, b]);
      expect(result, isA<MergeSequential>());
      final gap = (result as MergeSequential).gaps.single;
      expect(gap.startSeconds, 366); // profile extent, not 5min runtime
      expect(gap.endSeconds, 600);
    });

    test('profile samples running into the next dive are overlapping', () {
      final a = dive(
        'a',
        entry: DateTime.utc(2026, 7, 1, 9),
        runtimeMin: 5,
        profile: const [
          DiveProfilePoint(timestamp: 2, depth: 5),
          DiveProfilePoint(timestamp: 660, depth: 1),
        ],
      );
      final b = dive('b', entry: DateTime.utc(2026, 7, 1, 9, 10));
      expect(builder.classify([a, b]), isA<MergeOverlapping>());
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

  group('build - metadata', () {
    test('first non-empty wins in chronological order', () {
      final a = dive('a', entry: DateTime.utc(2026, 7, 1, 9)).copyWith(
        rating: 4,
        diveNumber: 101,
        surfaceInterval: const Duration(hours: 2),
      );
      final b = dive('b', entry: DateTime.utc(2026, 7, 1, 10)).copyWith(
        rating: 2,
        waterTemp: 19.5,
        diveComputerModel: 'Perdix 2',
        diveNumber: 102,
        courseId: 'course-1',
      );
      final merged = builder.build([b, a]).mergedDive; // unsorted input
      expect(merged.rating, 4); // a is chronologically first
      expect(merged.waterTemp, 19.5); // a blank -> filled from b
      expect(merged.diveComputerModel, 'Perdix 2');
      expect(merged.diveNumber, 101); // always the first dive's
      expect(merged.surfaceInterval, const Duration(hours: 2));
      expect(merged.courseId, 'course-1'); // a has none -> filled from b
    });

    test('notes concatenate non-empty in order; favorite is OR', () {
      final a = dive(
        'a',
        entry: DateTime.utc(2026, 7, 1, 9),
      ).copyWith(notes: 'first leg');
      final b = dive('b', entry: DateTime.utc(2026, 7, 1, 10));
      final c = dive(
        'c',
        entry: DateTime.utc(2026, 7, 1, 11),
      ).copyWith(notes: 'second leg', isFavorite: true);
      final merged = builder.build([a, b, c]).mergedDive;
      expect(merged.notes, 'first leg\n\nsecond leg');
      expect(merged.isFavorite, isTrue);
    });

    test('exitLocation comes from the LAST dive that has one', () {
      final a = dive('a', entry: DateTime.utc(2026, 7, 1, 9)).copyWith(
        entryLocation: const GeoPoint(1, 1),
        exitLocation: const GeoPoint(2, 2),
      );
      final b = dive(
        'b',
        entry: DateTime.utc(2026, 7, 1, 10),
      ).copyWith(exitLocation: const GeoPoint(3, 3));
      final merged = builder.build([a, b]).mergedDive;
      expect(merged.entryLocation!.latitude, 1);
      expect(merged.exitLocation!.latitude, 3);
    });
  });

  group('build - collections', () {
    test('tanks keep chronological order, get fresh ids and an id map', () {
      var n = 0;
      final a = dive(
        'a',
        entry: DateTime.utc(2026, 7, 1, 9),
      ).copyWith(tanks: [const DiveTank(id: 'tA1', volume: 11.1, order: 0)]);
      final b = dive(
        'b',
        entry: DateTime.utc(2026, 7, 1, 10),
      ).copyWith(tanks: [const DiveTank(id: 'tB1', volume: 15.0, order: 0)]);
      final result = builder.build([b, a], idGenerator: () => 'gen-${n++}');
      final tanks = result.mergedDive.tanks;
      expect(tanks, hasLength(2));
      expect(tanks[0].volume, 11.1); // a's tank first
      expect(tanks[0].order, 0);
      expect(tanks[1].order, 1);
      expect(result.tankIdMap['tA1'], tanks[0].id);
      expect(result.tankIdMap['tB1'], tanks[1].id);
      expect(tanks[0].id, isNot('tA1')); // fresh id
    });

    test('weights come from the first dive that has any', () {
      final a = dive('a', entry: DateTime.utc(2026, 7, 1, 9));
      final b = dive('b', entry: DateTime.utc(2026, 7, 1, 10)).copyWith(
        weights: [
          const DiveWeight(
            id: 'w1',
            diveId: 'b',
            weightType: WeightType.belt,
            amountKg: 6,
          ),
        ],
      );
      final result = builder.build([a, b]);
      expect(result.mergedDive.weights, hasLength(1));
      expect(result.mergedDive.weights.single.amountKg, 6);
      expect(result.mergedDive.weights.single.diveId, result.mergedDive.id);
      expect(result.mergedDive.weights.single.id, isNot('w1'));
    });

    test('custom fields union by key (first wins); dive types union', () {
      final a = dive('a', entry: DateTime.utc(2026, 7, 1, 9)).copyWith(
        customFields: [
          const DiveCustomField(id: 'c1', key: 'boat', value: 'Sea Cat'),
        ],
        diveTypeIds: ['recreational', 'night'],
      );
      final b = dive('b', entry: DateTime.utc(2026, 7, 1, 10)).copyWith(
        customFields: [
          const DiveCustomField(id: 'c2', key: 'boat', value: 'Other'),
          const DiveCustomField(id: 'c3', key: 'guide', value: 'Maria'),
        ],
        diveTypeIds: ['recreational', 'drift'],
      );
      final merged = builder.build([a, b]).mergedDive;
      expect(merged.customFields, hasLength(2));
      expect(
        merged.customFields.firstWhere((f) => f.key == 'boat').value,
        'Sea Cat',
      );
      expect(merged.diveTypeIds, ['recreational', 'night', 'drift']);
    });

    test('sightings merge same species: counts summed, notes joined', () {
      final a = dive('a', entry: DateTime.utc(2026, 7, 1, 9));
      final b = dive('b', entry: DateTime.utc(2026, 7, 1, 10));
      final result = builder.build(
        [a, b],
        sightingsByDive: {
          'a': [
            const MarineSighting(
              id: 's1',
              speciesId: 'turtle',
              speciesName: 'Green Turtle',
              count: 2,
              notes: 'near reef',
            ),
          ],
          'b': [
            const MarineSighting(
              id: 's2',
              speciesId: 'turtle',
              speciesName: 'Green Turtle',
              count: 1,
            ),
            const MarineSighting(
              id: 's3',
              speciesId: 'ray',
              speciesName: 'Eagle Ray',
            ),
          ],
        },
      );
      expect(result.mergedSightings, hasLength(2));
      final turtle = result.mergedSightings.firstWhere(
        (s) => s.speciesId == 'turtle',
      );
      expect(turtle.count, 3);
      expect(turtle.notes, 'near reef');
      expect(turtle.id, isNot('s1'));
    });
  });

  group('build - preview profile', () {
    // A plateau profile: 0-depth at both ends, [depth] in between, sampled
    // every [cadence] seconds.
    List<DiveProfilePoint> plateau(int seconds, int cadence, double depth) => [
      for (var t = 0; t <= seconds; t += cadence)
        DiveProfilePoint(
          timestamp: t,
          depth: (t == 0 || t == seconds) ? 0 : depth,
        ),
    ];

    test('re-bases each segment and fills the gap with a dense flat run', () {
      final a = dive(
        'a',
        entry: DateTime.utc(2026, 7, 1, 9),
        runtimeMin: 5,
        profile: plateau(300, 2, 12), // 0..300 @2s
      );
      final b = dive(
        'b',
        entry: DateTime.utc(2026, 7, 1, 9, 10), // 600s after a's entry
        runtimeMin: 5,
        profile: plateau(300, 2, 8),
      );

      final preview = builder.build([a, b]).previewProfile;

      // Submerged samples from both segments survive; b re-based by +600.
      expect(preview.any((p) => p.depth == 12), isTrue);
      expect(preview.any((p) => p.timestamp == 750 && p.depth == 8), isTrue);

      // The 300..600 surface interval is a dense flat run at depth 0...
      final gap = preview
          .where((p) => p.timestamp > 300 && p.timestamp < 600)
          .toList();
      expect(gap.length, greaterThan(20));
      expect(gap.every((p) => p.depth == 0), isTrue);

      // ...with no long straight jump across the surface (native 2s cadence).
      final surface =
          preview
              .where((p) => p.timestamp >= 300 && p.timestamp <= 600)
              .map((p) => p.timestamp)
              .toList()
            ..sort();
      for (var i = 1; i < surface.length; i++) {
        expect(surface[i] - surface[i - 1], lessThanOrEqualTo(4));
      }
      for (var i = 1; i < preview.length; i++) {
        expect(
          preview[i].timestamp,
          greaterThanOrEqualTo(preview[i - 1].timestamp),
        );
      }
    });

    test('the surface interval survives the preview downsample', () {
      // Regression for the straight-line surface bug (#449 manual test): in a
      // merge dominated by the second dive, uniform-stride downsampling must
      // not drop the whole surface interval and collapse it to a diagonal.
      final a = dive(
        'a',
        entry: DateTime.utc(2026, 7, 1, 9),
        runtimeMin: 5,
        profile: plateau(300, 2, 10), // ~150 points
      );
      final b = dive(
        'b',
        entry: DateTime.utc(2026, 7, 1, 9, 10),
        runtimeMin: 40,
        profile: plateau(2400, 2, 25), // ~1200 points, dominates
      );

      final preview = builder.build([a, b]).previewProfile;
      final drawn = DiveSparkline.downsample(preview, maxPoints: 200);

      // a ends at 300; b re-based to start at 600. The 300..600 surface must
      // survive as multiple flat points, not a single diagonal.
      final surface = drawn
          .where((p) => p.timestamp > 300 && p.timestamp < 600)
          .toList();
      expect(surface.length, greaterThanOrEqualTo(3));
      expect(surface.every((p) => p.depth == 0), isTrue);
    });

    test('is empty when no source carries profile data', () {
      final a = dive('a', entry: DateTime.utc(2026, 7, 1, 9), runtimeMin: 30);
      final b = dive('b', entry: DateTime.utc(2026, 7, 1, 10), runtimeMin: 30);
      expect(builder.build([a, b]).previewProfile, isEmpty);
    });
  });
}
