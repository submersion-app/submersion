import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/services/video_identification_rules.dart';

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
}
