import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/data_quality/domain/detectors/clock_offset_detector.dart';
import 'package:submersion/features/data_quality/domain/detectors/duplicate_detector.dart';
import 'package:submersion/features/data_quality/domain/detectors/split_pair_detector.dart';
import 'package:submersion/features/data_quality/domain/entities/dive_quality_context.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
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

    test('records that the pair came from one physical computer', () {
      // A re-download from the same computer cannot be consolidated (the
      // builder rejects it on serial), so the finding has to say so and the
      // inbox has to withhold the Consolidate repair.
      final ctx = makeContext(
        dive: makeTestDive(id: 'dB', entry: entry, maxDepth: 30, serial: 'S1'),
        neighbors: [
          QualityNeighbor(
            id: 'dA',
            entryTime: entry.add(const Duration(minutes: 5)),
            maxDepth: 30,
            durationSeconds: 2400,
            computerSerial: 'S1',
          ),
        ],
      );
      expect(det.detect(ctx).single.params['sameComputer'], isTrue);
    });

    test('two different computers are consolidatable', () {
      final ctx = makeContext(
        dive: makeTestDive(id: 'dB', entry: entry, maxDepth: 30, serial: 'S1'),
        neighbors: [
          QualityNeighbor(
            id: 'dA',
            entryTime: entry.add(const Duration(minutes: 5)),
            maxDepth: 30,
            durationSeconds: 2400,
            computerSerial: 'S2',
          ),
        ],
      );
      expect(det.detect(ctx).single.params['sameComputer'], isFalse);
    });

    test('an unknown serial on either side is not assumed same-computer', () {
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
      expect(det.detect(ctx).single.params['sameComputer'], isFalse);
    });

    group('redundantDiveId', () {
      // The commonest duplicate is one dive downloaded twice from a single
      // computer. Consolidation is refused for that pair, so the repair is
      // to delete the redundant copy; the detector names it here so the
      // repair mapping (pure over params) can offer that without seeing the
      // dives. The richer recording survives: it must be at least as good
      // on every metric and strictly better on one.
      QualityNeighbor neighbor({
        required String id,
        required int samples,
        int durationSeconds = 2100,
        double maxDepth = 20,
        String? serial = 'S1',
        bool? carriesDiverData = false,
      }) => QualityNeighbor(
        id: id,
        entryTime: entry.add(const Duration(minutes: 1)),
        maxDepth: maxDepth,
        durationSeconds: durationSeconds,
        computerSerial: serial,
        sampleCount: samples,
        carriesDiverData: carriesDiverData,
      );

      test('names the fragment when the other recording dominates', () {
        // The real pair: 35 min / 20 m versus a 13 s / 1.7 m fragment.
        final ctx = makeContext(
          dive: makeTestDive(
            id: 'dA',
            entry: entry,
            maxDepth: 20,
            runtime: const Duration(minutes: 35),
            serial: 'S1',
          ),
          primarySampleCount: 420,
          neighbors: [
            neighbor(id: 'dB', samples: 3, durationSeconds: 13, maxDepth: 1.7),
          ],
        );
        final out = det.detect(ctx);
        expect(out.single.params['sameComputer'], isTrue);
        expect(out.single.params['redundantDiveId'], 'dB');
      });

      test('names the scanned dive when it is the dominated side', () {
        final ctx = makeContext(
          dive: makeTestDive(
            id: 'dB',
            entry: entry,
            maxDepth: 1.7,
            runtime: const Duration(seconds: 13),
            serial: 'S1',
          ),
          primarySampleCount: 3,
          neighbors: [neighbor(id: 'dA', samples: 420, durationSeconds: 2100)],
        );
        expect(det.detect(ctx).single.params['redundantDiveId'], 'dB');
      });

      test('an exact tie names nobody', () {
        // Two identical downloads: either copy may carry the diver's notes
        // or site, so the choice is theirs and the card keeps its
        // no-automatic-fix row.
        final ctx = makeContext(
          dive: makeTestDive(
            id: 'dA',
            entry: entry,
            maxDepth: 20,
            runtime: const Duration(minutes: 35),
            serial: 'S1',
          ),
          primarySampleCount: 420,
          neighbors: [neighbor(id: 'dB', samples: 420)],
        );
        final params = det.detect(ctx).single.params;
        expect(params.containsKey('redundantDiveId'), isFalse);
      });

      test('a mixed pair (longer but shallower) names nobody', () {
        final ctx = makeContext(
          dive: makeTestDive(
            id: 'dA',
            entry: entry,
            maxDepth: 18,
            runtime: const Duration(minutes: 40),
            serial: 'S1',
          ),
          primarySampleCount: 480,
          neighbors: [neighbor(id: 'dB', samples: 420, maxDepth: 20)],
        );
        expect(
          det.detect(ctx).single.params.containsKey('redundantDiveId'),
          isFalse,
        );
      });

      test('equal on two metrics and worse on one is still dominated', () {
        final ctx = makeContext(
          dive: makeTestDive(
            id: 'dA',
            entry: entry,
            maxDepth: 20,
            runtime: const Duration(minutes: 35),
            serial: 'S1',
          ),
          primarySampleCount: 400,
          neighbors: [neighbor(id: 'dB', samples: 420)],
        );
        expect(det.detect(ctx).single.params['redundantDiveId'], 'dA');
      });

      test('an unknown sample count on either side blocks the choice', () {
        // A missing metric is unknown, not zero: assuming zero would
        // volunteer a dive for deletion on a fact nobody recorded.
        final ctx = makeContext(
          dive: makeTestDive(
            id: 'dA',
            entry: entry,
            maxDepth: 20,
            runtime: const Duration(minutes: 35),
            serial: 'S1',
          ),
          primarySampleCount: 420,
          neighbors: [
            QualityNeighbor(
              id: 'dB',
              entryTime: entry.add(const Duration(minutes: 1)),
              maxDepth: 1.7,
              durationSeconds: 13,
              computerSerial: 'S1',
            ),
          ],
        );
        expect(
          det.detect(ctx).single.params.containsKey('redundantDiveId'),
          isFalse,
        );
      });

      test('a runtime the scanned side only computes does not decide', () {
        // The neighbor query reads the STORED runtime (else bottom time).
        // The scanned dive must read the same columns: effectiveRuntime
        // would fall back to exit minus entry, or to the profile, and the
        // two contexts of one pair would then disagree on that dive's
        // duration, making the choice depend on scan order.
        final dive = domain.Dive(
          id: 'dA',
          dateTime: entry,
          entryTime: entry,
          exitTime: entry.add(const Duration(minutes: 35)),
          maxDepth: 20,
          diveComputerSerial: 'S1',
        );
        expect(dive.runtime, isNull);
        expect(dive.effectiveRuntime, const Duration(minutes: 35));
        final ctx = makeContext(
          dive: dive,
          primarySampleCount: 420,
          neighbors: [
            neighbor(id: 'dB', samples: 3, durationSeconds: 13, maxDepth: 1.7),
          ],
        );
        final out = det.detect(ctx);
        expect(out, hasLength(1), reason: 'still a duplicate candidate');
        expect(out.single.params.containsKey('redundantDiveId'), isFalse);
      });

      test('a stored bottom time stands in for a missing runtime', () {
        // Mirrors the neighbor query's `runtime ?? bottom_time`.
        final dive = domain.Dive(
          id: 'dA',
          dateTime: entry,
          entryTime: entry,
          bottomTime: const Duration(minutes: 35),
          maxDepth: 20,
          diveComputerSerial: 'S1',
        );
        final ctx = makeContext(
          dive: dive,
          primarySampleCount: 420,
          neighbors: [
            neighbor(id: 'dB', samples: 3, durationSeconds: 13, maxDepth: 1.7),
          ],
        );
        expect(det.detect(ctx).single.params['redundantDiveId'], 'dB');
      });

      test('is not recorded for a pair from two different computers', () {
        // Consolidation is the right repair there; deleting a second
        // computer's recording would throw away real data.
        final ctx = makeContext(
          dive: makeTestDive(
            id: 'dA',
            entry: entry,
            maxDepth: 20,
            runtime: const Duration(minutes: 35),
            serial: 'S1',
          ),
          primarySampleCount: 420,
          neighbors: [
            neighbor(
              id: 'dB',
              samples: 3,
              durationSeconds: 13,
              maxDepth: 1.7,
              serial: 'S2',
            ),
          ],
        );
        expect(
          det.detect(ctx).single.params.containsKey('redundantDiveId'),
          isFalse,
        );
      });

      test('names the same dive whichever side the scan starts from', () {
        // The pair has ONE canonical finding, written by whichever dive was
        // scanned last, so the choice must not depend on scan order.
        final fromA = det.detect(
          makeContext(
            dive: makeTestDive(
              id: 'dA',
              entry: entry,
              maxDepth: 20,
              runtime: const Duration(minutes: 35),
              serial: 'S1',
            ),
            primarySampleCount: 420,
            neighbors: [
              neighbor(
                id: 'dB',
                samples: 3,
                durationSeconds: 13,
                maxDepth: 1.7,
              ),
            ],
          ),
        );
        final fromB = det.detect(
          makeContext(
            dive: makeTestDive(
              id: 'dB',
              entry: entry.add(const Duration(minutes: 1)),
              maxDepth: 1.7,
              runtime: const Duration(seconds: 13),
              serial: 'S1',
            ),
            primarySampleCount: 3,
            neighbors: [
              QualityNeighbor(
                id: 'dA',
                entryTime: entry,
                maxDepth: 20,
                durationSeconds: 2100,
                computerSerial: 'S1',
                sampleCount: 420,
              ),
            ],
          ),
        );
        expect(fromA.single.id, fromB.single.id);
        expect(fromA.single.params['redundantDiveId'], 'dB');
        expect(fromB.single.params['redundantDiveId'], 'dB');
      });

      // Issue #1720. The reporter had logged gear onto an older, shorter
      // download and then re-downloaded the dive; the fresh copy recorded
      // more, so the poorer RECORDING was the richer LOG and naming it
      // redundant offered to delete the diver's work. Recording richness
      // alone must not decide that.
      test('withholds the name when the dominated copy carries diver data', () {
        final ctx = makeContext(
          dive: makeTestDive(
            id: 'dA',
            entry: entry,
            maxDepth: 20,
            runtime: const Duration(minutes: 35),
            serial: 'S1',
          ),
          primarySampleCount: 420,
          neighbors: [
            neighbor(
              id: 'dB',
              samples: 3,
              durationSeconds: 13,
              maxDepth: 1.7,
              carriesDiverData: true,
            ),
          ],
        );
        final params = det.detect(ctx).single.params;
        expect(params['sameComputer'], isTrue);
        expect(params.containsKey('redundantDiveId'), isFalse);
      });

      test('withholds when the scanned dive is the dominated side and '
          'carries diver data', () {
        final ctx = makeContext(
          dive: makeTestDive(
            id: 'dB',
            entry: entry,
            maxDepth: 1.7,
            runtime: const Duration(seconds: 13),
            serial: 'S1',
          ),
          primarySampleCount: 3,
          carriesDiverData: true,
          neighbors: [neighbor(id: 'dA', samples: 420, durationSeconds: 2100)],
        );
        expect(
          det.detect(ctx).single.params.containsKey('redundantDiveId'),
          isFalse,
        );
      });

      // Only the copy about to be deleted matters: the survivor keeps
      // whatever it holds, so its own entries are no reason to withhold.
      test('the survivor carrying diver data does not withhold the name', () {
        final ctx = makeContext(
          dive: makeTestDive(
            id: 'dA',
            entry: entry,
            maxDepth: 20,
            runtime: const Duration(minutes: 35),
            serial: 'S1',
          ),
          primarySampleCount: 420,
          carriesDiverData: true,
          neighbors: [
            neighbor(id: 'dB', samples: 3, durationSeconds: 13, maxDepth: 1.7),
          ],
        );
        expect(det.detect(ctx).single.params['redundantDiveId'], 'dB');
      });

      // This verdict deletes a dive, so "nobody checked" must not read as
      // "nothing to lose" -- the same rule the recording metrics follow.
      test('withholds when the dominated copy\'s diver data is unknown', () {
        final ctx = makeContext(
          dive: makeTestDive(
            id: 'dA',
            entry: entry,
            maxDepth: 20,
            runtime: const Duration(minutes: 35),
            serial: 'S1',
          ),
          primarySampleCount: 420,
          neighbors: [
            neighbor(
              id: 'dB',
              samples: 3,
              durationSeconds: 13,
              maxDepth: 1.7,
              carriesDiverData: null,
            ),
          ],
        );
        expect(
          det.detect(ctx).single.params.containsKey('redundantDiveId'),
          isFalse,
        );
      });
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
