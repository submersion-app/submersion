import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/data_quality/data/services/quality_source_samples.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_summary.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_series.dart';

final _at = DateTime.utc(2026, 7, 1, 10);

DiveDataSource _source(String id, {String? computerId, bool primary = false}) =>
    DiveDataSource(
      id: id,
      diveId: 'd1',
      computerId: computerId,
      isPrimary: primary,
      entryTime: _at,
      importedAt: _at,
      createdAt: _at,
    );

ProfileSeries _series(
  String id, {
  required String sourceId,
  String? computerId,
  int? activatedAt,
  bool isPrimary = false,
  required List<ProfileSample> samples,
}) => ProfileSeries(
  id: id,
  diveId: 'd1',
  computerId: computerId,
  sourceId: sourceId,
  isPrimary: isPrimary,
  activatedAt: activatedAt,
  summary: ProfileSeriesSummary.of(samples),
  samples: samples,
  codecVersion: 1,
  createdAt: 0,
  updatedAt: 0,
);

void main() {
  group('qualitySourceSamples (#4296)', () {
    test("reads only a source's live generation, not an edit's original", () {
      // A demoted source that was edited owns its original and its edit
      // over the same timestamps; merging both would interleave them.
      final samples = qualitySourceSamples(
        [
          _source('s1', computerId: 'c1', primary: true),
          _source('s2', computerId: 'c2'),
        ],
        [
          _series(
            'orig',
            sourceId: 's2',
            computerId: 'c2',
            samples: const [
              ProfileSample(timestamp: 0, depth: 10),
              ProfileSample(timestamp: 10, depth: 10),
            ],
          ),
          _series(
            'edit',
            sourceId: 's2',
            activatedAt: 5,
            samples: const [
              ProfileSample(timestamp: 0, depth: 20),
              ProfileSample(timestamp: 10, depth: 20),
            ],
          ),
        ],
      );
      expect([for (final q in samples['s2']!) q.depth], [20, 20]);
    });

    test('with no source flagged primary, leaves out the one whose series '
        'the primary trace is drawn from', () {
      final samples = qualitySourceSamples(
        [_source('s1', computerId: 'c1'), _source('s2', computerId: 'c2')],
        [
          _series(
            'a',
            sourceId: 's1',
            isPrimary: true,
            samples: const [ProfileSample(timestamp: 0, depth: 10)],
          ),
          _series(
            'b',
            sourceId: 's2',
            samples: const [ProfileSample(timestamp: 0, depth: 10)],
          ),
        ],
      );
      expect(samples.keys, ['s2']);
    });

    test('a combined dive carries none of its halves, an edited half '
        "included: each owns part of the primary trace", () {
      final samples = qualitySourceSamples(
        [_source('h1', computerId: 'c1'), _source('h2', computerId: 'c2')],
        [
          _series(
            'h1-live',
            sourceId: 'h1',
            isPrimary: true,
            samples: const [ProfileSample(timestamp: 0, depth: 10)],
          ),
          _series(
            'h2-edit',
            sourceId: 'h2',
            isPrimary: true,
            samples: const [ProfileSample(timestamp: 3000, depth: 10)],
          ),
          // The second half's original, superseded by its edit.
          _series(
            'h2-orig',
            sourceId: 'h2',
            computerId: 'c2',
            samples: const [ProfileSample(timestamp: 3000, depth: 9)],
          ),
        ],
      );
      expect(samples, isEmpty);
    });

    test('a computer consolidated onto a combined dive is still carried, '
        'whichever source comes first', () {
      final samples = qualitySourceSamples(
        [
          // Consolidated computers sort anywhere among the halves.
          _source('extra', computerId: 'c3'),
          _source('h1', computerId: 'c1'),
          _source('h2', computerId: 'c2'),
        ],
        [
          _series(
            'h1-live',
            sourceId: 'h1',
            isPrimary: true,
            samples: const [ProfileSample(timestamp: 0, depth: 10)],
          ),
          _series(
            'h2-live',
            sourceId: 'h2',
            isPrimary: true,
            samples: const [ProfileSample(timestamp: 3000, depth: 10)],
          ),
          _series(
            'extra-series',
            sourceId: 'extra',
            computerId: 'c3',
            samples: const [ProfileSample(timestamp: -600, depth: 10)],
          ),
        ],
      );
      expect(samples.keys, ['extra']);
    });
  });
}
