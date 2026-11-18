import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/app_enums.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/pack_candidate.dart';
import 'package:submersion/features/species_id/domain/entities/video_detections.dart';
import 'package:submersion/features/species_id/domain/services/video_identification_rules.dart';
import 'package:submersion/features/species_id/domain/services/video_tracker.dart';

import '../data/identification_fixtures.dart';

/// When a video is scanned or named again, and what survives a rescan
/// (issue #4675).
void main() {
  group('decideVideoRefresh', () {
    VideoRefreshAction decide({
      MediaIdentificationRun? run,
      bool noRun = false,
      String pack = '2026.11.1',
      String detector = 'det',
      String classifier = 'clf',
      int? cell = 1462,
      bool crops = true,
      bool embeddings = true,
    }) => decideVideoRefresh(
      run: noRun ? null : (run ?? videoRun(scannedMs: 25000)),
      packVersion: pack,
      detectorId: detector,
      classifierId: classifier,
      cell: cell,
      cropsPresent: crops,
      embeddingsPresent: embeddings,
    );

    test('a video never scanned is scanned', () {
      expect(decide(noRun: true), VideoRefreshAction.rescan);
    });

    test('a missing crop means scanning again', () {
      expect(decide(crops: false), VideoRefreshAction.rescan);
    });

    test('new models mean scanning again', () {
      expect(decide(detector: 'det-2'), VideoRefreshAction.rescan);
      expect(decide(classifier: 'clf-2'), VideoRefreshAction.rescan);
    });

    test('an unfinished scan resumes', () {
      expect(
        decide(run: videoRun(scannedMs: 10000)),
        VideoRefreshAction.resume,
      );
      expect(
        decide(run: videoRun(scannedMs: 10000), pack: '2026.12.1'),
        VideoRefreshAction.resume,
      );
    });

    test('an unfinished scan whose names are stale and cannot be renamed '
        'starts again', () {
      expect(
        decide(
          run: videoRun(scannedMs: 10000),
          pack: '2026.12.1',
          embeddings: false,
        ),
        VideoRefreshAction.rescan,
      );
      expect(
        decide(run: videoRun(scannedMs: 10000), cell: 7, embeddings: false),
        VideoRefreshAction.rescan,
      );
      expect(
        decide(run: videoRun(scannedMs: 10000), embeddings: false),
        VideoRefreshAction.resume,
      );
    });

    test('a new pack or place renames from stored embeddings', () {
      expect(decide(pack: '2026.12.1'), VideoRefreshAction.rename);
      expect(decide(cell: 7), VideoRefreshAction.rename);
    });

    test('without embeddings a rename becomes a rescan', () {
      expect(
        decide(pack: '2026.12.1', embeddings: false),
        VideoRefreshAction.rescan,
      );
    });

    test('nothing changed means nothing to do', () {
      expect(decide(), VideoRefreshAction.none);
    });
  });

  group('carryTrackDecisions', () {
    final dismissed = track(
      'old',
      decision: IdentificationDecision.rejected,
    ).copyWith(decidedAt: fixtureT1);

    test('a fresh track over the same fish takes its decision', () {
      final result = carryTrackDecisions(
        decided: [dismissed],
        fresh: [track('new', startMs: 1250, endMs: 2250)],
      );
      expect(result.deleteIds, ['old']);
      expect(result.insert.single.id, 'new');
      expect(result.insert.single.decision, IdentificationDecision.rejected);
      expect(result.insert.single.decidedAt, fixtureT1);
    });

    test('too little time together is a different fish', () {
      final result = carryTrackDecisions(
        decided: [dismissed],
        fresh: [track('new', startMs: 1750, endMs: 3750)],
      );
      expect(result.deleteIds, isEmpty);
      expect(result.insert.single.decision, IdentificationDecision.undecided);
    });

    test('the same time in another place is a different fish', () {
      final elsewhere = track('new').copyWith(
        path: [
          for (final s in track('new').path)
            s.copyWith(box: s.box.copyWith(x: s.box.x + 0.5)),
        ],
      );
      final result = carryTrackDecisions(
        decided: [dismissed],
        fresh: [elsewhere],
      );
      expect(result.deleteIds, isEmpty);
    });

    test('a decided track is carried once only', () {
      final result = carryTrackDecisions(
        decided: [dismissed],
        fresh: [track('a'), track('b')],
      );
      expect(result.deleteIds, ['old']);
      expect(result.insert.map((i) => i.decision), [
        IdentificationDecision.rejected,
        IdentificationDecision.undecided,
      ]);
    });

    test('a claim is carried', () {
      final claimed = track('old', claimedSpeciesId: 'sp_x');
      final result = carryTrackDecisions(
        decided: [claimed],
        fresh: [track('new')],
      );
      expect(result.insert.single.claimedSpeciesId, 'sp_x');
      expect(result.deleteIds, ['old']);
    });
  });

  group('naming in view (issue #4709)', () {
    TrackedAnimal animal({
      String? storedId,
      double? namedWorth,
      required List<double> widths,
      int stored = 0,
    }) {
      final points = [
        for (final (k, w) in widths.indexed)
          (
            ms: k * 250,
            detection: DetectedBox(
              box: IdentificationBox(x: 0.1, y: 0.4, width: w, height: 0.1),
              score: 1,
            ),
          ),
      ];
      final fresh = TrackedAnimal(points.sublist(0, stored));
      final tracker = VideoTracker()..resume(fresh);
      if (storedId != null) {
        tracker.markStored(
          tracker.openTracks.single,
          storedId: storedId,
          namedWorth: namedWorth,
        );
      }
      final open = tracker.openTracks.single;
      for (final p in points.skip(stored)) {
        open.points.add(p);
      }
      return open;
    }

    test('a track never named names now', () {
      expect(namesNow(animal(widths: [0.2, 0.2, 0.2])), isTrue);
    });

    test('a named track does not name again without a better view', () {
      expect(
        namesNow(
          animal(
            storedId: 'r1',
            namedWorth: 0.02,
            widths: [0.2, 0.2, 0.28],
            stored: 2,
          ),
        ),
        isFalse,
      );
    });

    test('a named track names again at 1.5 times the worth', () {
      expect(
        namesNow(
          animal(
            storedId: 'r1',
            namedWorth: 0.02,
            widths: [0.2, 0.2, 0.3],
            stored: 2,
          ),
        ),
        isTrue,
      );
    });

    test('a better view among the points already stored does not '
        'count', () {
      expect(
        namesNow(
          animal(
            storedId: 'r1',
            namedWorth: 0.02,
            widths: [0.4, 0.2, 0.2],
            stored: 2,
          ),
        ),
        isFalse,
      );
    });
  });

  group('keepDecisionOnRename', () {
    final renamedAs = track('t1').copyWith(
      candidates: const [
        NamedCandidate(
          candidate: PackCandidate(
            gbifKey: 5,
            scientificName: 'Sparisoma viride',
            commonName: 'Stoplight Parrotfish',
            category: SpeciesCategory.fish,
          ),
          score: 0.8,
        ),
      ],
    );

    test('an acceptance by name match goes back to undecided when the '
        'name changes', () {
      final before = track(
        't1',
        decision: IdentificationDecision.accepted,
        decidedSpeciesId: 'sp_queen_parrotfish',
      ).copyWith(decidedAt: fixtureT1);
      final kept = keepDecisionOnRename(before: before, renamed: renamedAs);
      expect(kept.decision, IdentificationDecision.undecided);
      expect(kept.decidedSpeciesId, isNull);
      expect(kept.decidedAt, isNull);
      expect(kept.top!.candidate.commonName, 'Stoplight Parrotfish');
    });

    test('an acceptance stays when the name is the same', () {
      final before = track(
        't1',
        decision: IdentificationDecision.accepted,
        decidedSpeciesId: 'sp_queen_parrotfish',
      ).copyWith(decidedAt: fixtureT1);
      final same = track('t1').copyWith(
        candidates: [
          NamedCandidate(
            candidate: before.top!.candidate.copyWith(
              scientificName: 'SCARUS VETULA',
            ),
            score: 0.6,
          ),
        ],
      );
      final kept = keepDecisionOnRename(before: before, renamed: same);
      expect(kept.decision, IdentificationDecision.accepted);
      expect(kept.decidedSpeciesId, 'sp_queen_parrotfish');
      expect(kept.decidedAt, fixtureT1);
    });

    test('a claim is kept whatever the name', () {
      final before = track(
        't1',
        decision: IdentificationDecision.accepted,
        decidedSpeciesId: 'sp_queen_parrotfish',
        claimedSpeciesId: 'sp_queen_parrotfish',
      );
      final kept = keepDecisionOnRename(before: before, renamed: renamedAs);
      expect(kept.decision, IdentificationDecision.accepted);
      expect(kept.claimedSpeciesId, 'sp_queen_parrotfish');
      expect(kept.decidedSpeciesId, 'sp_queen_parrotfish');
    });

    test('a dismissal is kept whatever the name', () {
      final before = track(
        't1',
        decision: IdentificationDecision.rejected,
      ).copyWith(decidedAt: fixtureT1);
      final kept = keepDecisionOnRename(before: before, renamed: renamedAs);
      expect(kept.decision, IdentificationDecision.rejected);
      expect(kept.decidedAt, fixtureT1);
    });

    test('an undecided row stays undecided', () {
      final kept = keepDecisionOnRename(
        before: track('t1'),
        renamed: renamedAs,
      );
      expect(kept.decision, IdentificationDecision.undecided);
      expect(kept.decidedSpeciesId, isNull);
    });
  });

  group('seamJoins', () {
    TrackedAnimal openUntil(int endMs, {String? storedId}) {
      final tracker = VideoTracker();
      for (var ms = endMs - 1000; ms <= endMs; ms += 250) {
        tracker.add(
          FrameDetections(
            ms: ms,
            boxes: const [
              DetectedBox(
                box: IdentificationBox(x: 0.1, y: 0.4, width: 0.2, height: 0.1),
                score: 0.9,
              ),
            ],
          ),
        );
      }
      if (storedId != null) {
        tracker.markStored(
          tracker.openTracks.single,
          storedId: storedId,
          namedWorth: 0.018,
        );
      }
      return tracker.openTracks.single;
    }

    MediaIdentification later({
      int startMs = 30000,
      IdentificationDecision decision = IdentificationDecision.undecided,
      String? decidedSpeciesId,
    }) {
      final t = track(
        'later',
        startMs: startMs,
        endMs: startMs + 2000,
        decision: decision,
        decidedSpeciesId: decidedSpeciesId,
      );
      return t.copyWith(
        path: [
          for (final s in t.path)
            s.copyWith(
              box: const IdentificationBox(
                x: 0.1,
                y: 0.4,
                width: 0.2,
                height: 0.1,
              ),
            ),
        ],
      );
    }

    test('a fish crossing the seam is paired', () {
      final open = openUntil(29750);
      final pairs = seamJoins(
        open: [open],
        openRows: const {},
        stored: [later()],
        seamMs: 30000,
      );
      expect(pairs, hasLength(1));
      expect(identical(pairs.single.open, open), isTrue);
      expect(pairs.single.later.id, 'later');
    });

    test('a stored track starting too long after the seam is not', () {
      expect(
        seamJoins(
          open: [openUntil(29750)],
          openRows: const {},
          stored: [later(startMs: 31000)],
          seamMs: 30000,
        ),
        isEmpty,
      );
    });

    test('a stored track elsewhere in the frame is not', () {
      final elsewhere = later().copyWith(
        path: [
          for (final s in later().path) s.copyWith(box: s.box.copyWith(x: 0.7)),
        ],
      );
      expect(
        seamJoins(
          open: [openUntil(29750)],
          openRows: const {},
          stored: [elsewhere],
          seamMs: 30000,
        ),
        isEmpty,
      );
    });

    test('saidDifferently needs a say on both parts, and a difference', () {
      final accepted = track(
        'a',
        decision: IdentificationDecision.accepted,
        decidedSpeciesId: 'sp_queen_parrotfish',
      );
      final rejected = track('b', decision: IdentificationDecision.rejected);
      final claimed = track('c', claimedSpeciesId: 'sp_queen_parrotfish');
      expect(saidDifferently(accepted, rejected), isTrue);
      expect(saidDifferently(accepted, claimed), isTrue);
      expect(saidDifferently(accepted, track('d')), isFalse);
      expect(
        saidDifferently(
          accepted,
          track(
            'e',
            decision: IdentificationDecision.accepted,
            decidedSpeciesId: 'sp_queen_parrotfish',
          ),
        ),
        isFalse,
      );
    });

    test('parts the diver decided differently stay apart', () {
      final accepted = track(
        'early',
        decision: IdentificationDecision.accepted,
        decidedSpeciesId: 'sp_queen_parrotfish',
      );
      expect(
        seamJoins(
          open: [openUntil(29750, storedId: 'early')],
          openRows: {'early': accepted},
          stored: [later(decision: IdentificationDecision.rejected)],
          seamMs: 30000,
        ),
        isEmpty,
      );
    });

    test('a decided part joins an undecided one', () {
      final accepted = track(
        'early',
        decision: IdentificationDecision.accepted,
        decidedSpeciesId: 'sp_queen_parrotfish',
      );
      expect(
        seamJoins(
          open: [openUntil(29750, storedId: 'early')],
          openRows: {'early': accepted},
          stored: [later()],
          seamMs: 30000,
        ),
        hasLength(1),
      );
    });

    test('each stored track is used once, the most overlapping first', () {
      final near = openUntil(29750);
      final far = VideoTracker();
      for (var ms = 28750; ms <= 29750; ms += 250) {
        far.add(
          FrameDetections(
            ms: ms,
            boxes: const [
              DetectedBox(
                box: IdentificationBox(
                  x: 0.15,
                  y: 0.4,
                  width: 0.2,
                  height: 0.1,
                ),
                score: 0.9,
              ),
            ],
          ),
        );
      }
      final pairs = seamJoins(
        open: [far.openTracks.single, near],
        openRows: const {},
        stored: [later()],
        seamMs: 30000,
      );
      expect(pairs, hasLength(1));
      expect(identical(pairs.single.open, near), isTrue);
    });
  });
}
