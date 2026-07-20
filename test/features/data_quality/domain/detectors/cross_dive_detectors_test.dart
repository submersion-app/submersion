import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/data_quality/domain/detectors/clock_offset_detector.dart';
import 'package:submersion/features/data_quality/domain/detectors/duplicate_detector.dart';
import 'package:submersion/features/data_quality/domain/detectors/split_pair_detector.dart';
import 'package:submersion/features/data_quality/domain/entities/dive_quality_context.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';

import '../../helpers/quality_test_helpers.dart';

void main() {
  final entry = DateTime.utc(2026, 7, 1, 10);

  group('ClockOffsetDetector', () {
    const det = ClockOffsetDetector();

    test('flags future-dated dive as critical', () {
      final ctx = makeContext(
        dive: makeTestDive(entry: DateTime.utc(2027, 1, 1)),
        now: DateTime.utc(2026, 7, 17),
      );
      final out = det.detect(ctx);
      expect(out, hasLength(1));
      expect(out.single.severity, QualitySeverity.critical);
      expect(out.single.detectorId, 'clock_offset');
    });

    test('flags whole-hour source offset (179 min -> 3 h, remainder 1)', () {
      final ctx = makeContext(
        dive: makeTestDive(entry: entry),
        sources: [
          DiveDataSource(
            id: 's-primary',
            diveId: 'd1',
            isPrimary: true,
            entryTime: entry,
            importedAt: entry,
            createdAt: entry,
          ),
          DiveDataSource(
            id: 's-off',
            diveId: 'd1',
            isPrimary: false,
            entryTime: entry.add(const Duration(minutes: 179)),
            importedAt: entry,
            createdAt: entry,
          ),
        ],
      );
      final out = det.detect(ctx);
      expect(out, hasLength(1));
      expect(out.single.params['offsetHours'], 3);
    });

    test('45 min offset is NOT a timezone signature (remainder 15 > 5)', () {
      final ctx = makeContext(
        dive: makeTestDive(entry: entry),
        sources: [
          DiveDataSource(
            id: 's-primary',
            diveId: 'd1',
            isPrimary: true,
            entryTime: entry,
            importedAt: entry,
            createdAt: entry,
          ),
          DiveDataSource(
            id: 's-off',
            diveId: 'd1',
            isPrimary: false,
            entryTime: entry.add(const Duration(minutes: 45)),
            importedAt: entry,
            createdAt: entry,
          ),
        ],
      );
      expect(det.detect(ctx), isEmpty);
    });

    test('flags overlapping same-diver neighbor as a pair finding', () {
      // Dive runs 10:00-10:40; neighbor 10:20-11:00 overlaps 20 min.
      final ctx = makeContext(
        dive: makeTestDive(id: 'dB', entry: entry),
        neighbors: [
          QualityNeighbor(
            id: 'dA',
            entryTime: entry.add(const Duration(minutes: 20)),
            exitTime: entry.add(const Duration(minutes: 60)),
          ),
        ],
      );
      final out = det.detect(ctx);
      expect(out, hasLength(1));
      expect(out.single.diveId, 'dA'); // lexically smaller anchors the pair
      expect(out.single.relatedDiveId, 'dB');
      expect(out.single.params['overlapMinutes'], 20);
    });
  });

  group('DuplicateDetector', () {
    const det = DuplicateDetector();

    test('near-identical dive 5 min apart scores 1.0 -> critical', () {
      // timeScore = bandScore(5, full:5, zero:15) = 1.0; depth and duration
      // identical -> 1.0 each; score = .5 + .3 + .2 = 1.0 >= 0.7.
      final ctx = makeContext(
        dive: makeTestDive(id: 'dB', entry: entry, maxDepth: 30),
        neighbors: [
          QualityNeighbor(
            id: 'dA',
            entryTime: entry.add(const Duration(minutes: 5)),
            maxDepth: 30,
            durationSeconds: 2400,
          ),
        ],
      );
      final out = det.detect(ctx);
      expect(out, hasLength(1));
      expect(out.single.severity, QualitySeverity.critical);
      expect(out.single.params['score'], closeTo(1.0, 1e-9));
    });

    test('12 min apart, same profile -> 0.65 -> warning', () {
      // timeScore = 1 - (12-5)/(15-5) = 0.3; score = .5*.3 + .3 + .2 = 0.65.
      final ctx = makeContext(
        dive: makeTestDive(id: 'dB', entry: entry, maxDepth: 30),
        neighbors: [
          QualityNeighbor(
            id: 'dA',
            entryTime: entry.add(const Duration(minutes: 12)),
            maxDepth: 30,
            durationSeconds: 2400,
          ),
        ],
      );
      final out = det.detect(ctx);
      expect(out.single.severity, QualitySeverity.warning);
      expect(out.single.params['score'], closeTo(0.65, 1e-9));
    });

    test('16 min apart is gated to zero -> no finding', () {
      final ctx = makeContext(
        dive: makeTestDive(id: 'dB', entry: entry, maxDepth: 30),
        neighbors: [
          QualityNeighbor(
            id: 'dA',
            entryTime: entry.add(const Duration(minutes: 16)),
            maxDepth: 30,
            durationSeconds: 2400,
          ),
        ],
      );
      expect(det.detect(ctx), isEmpty);
    });
  });

  group('SplitPairDetector', () {
    const det = SplitPairDetector();

    test('same-serial dive resuming 5 min later, deep ends -> finding', () {
      // This dive 10:00-10:40 ends at 8 m; neighbor starts 10:45.
      final samples = [
        const QualitySample(t: 0, depth: 0),
        const QualitySample(t: 2400, depth: 8.0),
      ];
      final ctx = makeContext(
        dive: makeTestDive(id: 'dA', entry: entry, serial: 'SN-1'),
        samples: samples,
        neighbors: [
          QualityNeighbor(
            id: 'dB',
            entryTime: entry.add(const Duration(minutes: 45)),
            computerSerial: 'SN-1',
            firstSampleDepth: 6.0,
          ),
        ],
      );
      final out = det.detect(ctx);
      expect(out, hasLength(1));
      expect(out.single.params['gapSeconds'], 300);
      expect(out.single.params['earlierEndsDeep'], true);
    });

    test('different serial -> no finding', () {
      final ctx = makeContext(
        dive: makeTestDive(id: 'dA', entry: entry, serial: 'SN-1'),
        neighbors: [
          QualityNeighbor(
            id: 'dB',
            entryTime: entry.add(const Duration(minutes: 45)),
            computerSerial: 'SN-2',
            firstSampleDepth: 6.0,
          ),
        ],
      );
      expect(det.detect(ctx), isEmpty);
    });

    test('12 min gap exceeds splitMaxGap -> no finding', () {
      final ctx = makeContext(
        dive: makeTestDive(id: 'dA', entry: entry, serial: 'SN-1'),
        neighbors: [
          QualityNeighbor(
            id: 'dB',
            entryTime: entry.add(const Duration(minutes: 52)),
            computerSerial: 'SN-1',
            firstSampleDepth: 6.0,
          ),
        ],
      );
      expect(det.detect(ctx), isEmpty);
    });

    test('null serial -> no finding', () {
      final ctx = makeContext(
        dive: makeTestDive(id: 'dA', entry: entry, serial: null),
        neighbors: [
          QualityNeighbor(
            id: 'dB',
            entryTime: entry.add(const Duration(minutes: 5)),
            computerSerial: null,
            firstSampleDepth: 6.0,
          ),
        ],
      );
      expect(det.detect(ctx), isEmpty);
    });

    test('null runtime -> no finding', () {
      final ctx = makeContext(
        dive: makeTestDive(
          id: 'dA',
          entry: entry,
          serial: 'SN-1',
          runtime: null,
        ),
        neighbors: [
          QualityNeighbor(
            id: 'dB',
            entryTime: entry.add(const Duration(minutes: 5)),
            computerSerial: 'SN-1',
            firstSampleDepth: 6.0,
          ),
        ],
      );
      expect(det.detect(ctx), isEmpty);
    });

    test(
      'this dive resuming after an earlier same-serial neighbor -> finding',
      () {
        // Neighbor 09:15-09:55 ends deep (8 m); this dive starts 10:00, gap 5 min.
        final samples = [
          const QualitySample(t: 0, depth: 6.0),
          const QualitySample(t: 2400, depth: 3.0),
        ];
        final ctx = makeContext(
          dive: makeTestDive(id: 'dB', entry: entry, serial: 'SN-1'),
          samples: samples,
          neighbors: [
            QualityNeighbor(
              id: 'dA',
              entryTime: entry.subtract(const Duration(minutes: 45)),
              exitTime: entry.subtract(const Duration(minutes: 5)),
              computerSerial: 'SN-1',
              lastSampleDepth: 8.0,
            ),
          ],
        );
        final out = det.detect(ctx);
        expect(out, hasLength(1));
        expect(out.single.params['gapSeconds'], 300);
        expect(out.single.params['earlierEndsDeep'], true);
      },
    );

    test(
      'later dive whose earlier neighbor has no exit time -> no finding',
      () {
        final ctx = makeContext(
          dive: makeTestDive(id: 'dB', entry: entry, serial: 'SN-1'),
          neighbors: [
            QualityNeighbor(
              id: 'dA',
              entryTime: entry.subtract(const Duration(minutes: 45)),
              computerSerial: 'SN-1',
              lastSampleDepth: 8.0,
            ),
          ],
        );
        expect(det.detect(ctx), isEmpty);
      },
    );

    test(
      'shallow 2 min gap with no deep ends still reads as a continuation',
      () {
        // Both ends shallow, but the 2 min gap is within splitShallowGap.
        final samples = [
          const QualitySample(t: 0, depth: 0),
          const QualitySample(t: 2400, depth: 0.5),
        ];
        final ctx = makeContext(
          dive: makeTestDive(id: 'dA', entry: entry, serial: 'SN-1'),
          samples: samples,
          neighbors: [
            QualityNeighbor(
              id: 'dB',
              entryTime: entry.add(const Duration(minutes: 42)),
              computerSerial: 'SN-1',
              firstSampleDepth: 0.5,
            ),
          ],
        );
        final out = det.detect(ctx);
        expect(out, hasLength(1));
        expect(out.single.params['earlierEndsDeep'], false);
        expect(out.single.params['laterStartsDeep'], false);
      },
    );

    test('5 min gap with shallow ends is not a continuation', () {
      final samples = [
        const QualitySample(t: 0, depth: 0),
        const QualitySample(t: 2400, depth: 0.5),
      ];
      final ctx = makeContext(
        dive: makeTestDive(id: 'dA', entry: entry, serial: 'SN-1'),
        samples: samples,
        neighbors: [
          QualityNeighbor(
            id: 'dB',
            entryTime: entry.add(const Duration(minutes: 45)),
            computerSerial: 'SN-1',
            firstSampleDepth: 0.5,
          ),
        ],
      );
      expect(det.detect(ctx), isEmpty);
    });

    test('overlapping neighbor (negative gap) is skipped', () {
      final ctx = makeContext(
        dive: makeTestDive(id: 'dA', entry: entry, serial: 'SN-1'),
        neighbors: [
          QualityNeighbor(
            id: 'dB',
            entryTime: entry.add(const Duration(minutes: 20)),
            computerSerial: 'SN-1',
            firstSampleDepth: 6.0,
          ),
        ],
      );
      expect(det.detect(ctx), isEmpty);
    });
  });
}
