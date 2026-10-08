import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_summary.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_series.dart';
import 'package:submersion/features/dive_log/domain/services/source_bottom_time.dart';

// 30 m for 19 minutes, then a stop at 5 m: 1200 s of bottom time in a
// 1500 s dive.
const _deep = [
  ProfileSample(timestamp: 0, depth: 0.0),
  ProfileSample(timestamp: 60, depth: 30.0),
  ProfileSample(timestamp: 1200, depth: 30.0),
  ProfileSample(timestamp: 1260, depth: 5.0),
  ProfileSample(timestamp: 1440, depth: 5.0),
  ProfileSample(timestamp: 1500, depth: 0.0),
];

// A shallower reading of another computer: 600 s of bottom time.
const _other = [
  ProfileSample(timestamp: 0, depth: 0.0),
  ProfileSample(timestamp: 60, depth: 20.0),
  ProfileSample(timestamp: 600, depth: 20.0),
  ProfileSample(timestamp: 700, depth: 0.0),
];

ProfileSeries _series(
  String id,
  List<ProfileSample> samples, {
  String? sourceId,
  String? computerId,
  bool isPrimary = false,
}) => ProfileSeries(
  id: id,
  diveId: 'dive-1',
  sourceId: sourceId,
  computerId: computerId,
  isPrimary: isPrimary,
  summary: ProfileSeriesSummary.of(samples),
  samples: samples,
  codecVersion: 1,
  createdAt: 0,
  updatedAt: 0,
);

void main() {
  group('sourceBottomTimeSeconds', () {
    test('derives the bottom time from the series the source owns', () {
      final result = sourceBottomTimeSeconds(
        [
          _series('a', _other, sourceId: 'src-2', computerId: 'comp-2'),
          _series('b', _deep, sourceId: 'src-1', computerId: 'comp-1'),
        ],
        sourceId: 'src-1',
        computerId: 'comp-1',
        runtimeSeconds: 1500,
      );

      expect(result, 1200);
    });

    test('falls back to an unowned series of the same computer', () {
      final result = sourceBottomTimeSeconds(
        [
          _series('a', _other, sourceId: 'src-2', computerId: 'comp-2'),
          _series('b', _deep, computerId: 'comp-1'),
        ],
        sourceId: 'src-1',
        computerId: 'comp-1',
        runtimeSeconds: 1500,
      );

      expect(result, 1200);
    });

    test('never reads a series another source owns', () {
      final result = sourceBottomTimeSeconds(
        [_series('a', _deep, sourceId: 'src-2', computerId: 'comp-1')],
        sourceId: 'src-1',
        computerId: 'comp-1',
        runtimeSeconds: 1500,
      );

      expect(result, isNull);
    });

    test('a computer-less source matches only its own series', () {
      final result = sourceBottomTimeSeconds(
        [_series('a', _deep)],
        sourceId: 'src-1',
        computerId: null,
        runtimeSeconds: 1500,
      );

      expect(result, isNull);
    });

    test('never exceeds the runtime', () {
      final result = sourceBottomTimeSeconds(
        [_series('a', _deep, sourceId: 'src-1')],
        sourceId: 'src-1',
        computerId: null,
        runtimeSeconds: 900,
      );

      expect(result, 900);
    });

    test('prefers the primary series when the source owns several', () {
      final result = sourceBottomTimeSeconds(
        [
          _series('a', _other, sourceId: 'src-1'),
          _series('b', _deep, sourceId: 'src-1', isPrimary: true),
        ],
        sourceId: 'src-1',
        computerId: null,
        runtimeSeconds: 1500,
      );

      expect(result, 1200);
    });

    test('is null with no series to derive from', () {
      expect(
        sourceBottomTimeSeconds(
          const [],
          sourceId: 'src-1',
          computerId: 'comp-1',
          runtimeSeconds: 1500,
        ),
        isNull,
      );
    });
  });
}
