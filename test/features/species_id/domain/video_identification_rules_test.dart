import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/app_enums.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/pack_candidate.dart';
import 'package:submersion/features/species_id/domain/entities/video_detections.dart';
import 'package:submersion/features/species_id/domain/services/species_namer.dart';
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

    test('a reopened track is carried to the fresh track of the same fish '
        '(issue #4825)', () {
      final reopened = track('old').copyWith(decidedAt: fixtureT1);
      final result = carryTrackDecisions(
        decided: [reopened],
        fresh: [track('new', startMs: 1250, endMs: 2250)],
      );
      expect(result.deleteIds, ['old']);
      expect(result.insert.single.decision, IdentificationDecision.undecided);
      expect(result.insert.single.reopened, isTrue);
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

    /// [of]'s path from [from] to [to], as a track of its own: a part of
    /// the same fish that an earlier tracker split off (issue #4729).
    MediaIdentification part(
      String id,
      MediaIdentification of,
      int from,
      int to, {
      IdentificationDecision decision = IdentificationDecision.rejected,
      String? decidedSpeciesId,
    }) =>
        track(
          id,
          startMs: from,
          endMs: to,
          decision: decision,
          decidedSpeciesId: decidedSpeciesId,
        ).copyWith(
          path: [
            for (final s in of.path)
              if (s.ms >= from && s.ms <= to) s,
          ],
        );

    test('every part of a fish said the same on goes with the track that '
        'joins them', () {
      final whole = track('new', startMs: 1000, endMs: 4000);
      final result = carryTrackDecisions(
        decided: [part('p1', whole, 1000, 2000), part('p2', whole, 2500, 3500)],
        fresh: [whole],
      );
      expect(result.insert.single.id, 'new');
      expect(result.insert.single.decision, IdentificationDecision.rejected);
      expect(result.deleteIds, ['p1', 'p2']);
    });

    test('a part the diver said something else on stays apart', () {
      final whole = track('new', startMs: 1000, endMs: 4000);
      final result = carryTrackDecisions(
        decided: [
          part('p1', whole, 1000, 2000),
          part(
            'p2',
            whole,
            2500,
            3500,
            decision: IdentificationDecision.accepted,
            decidedSpeciesId: 'sp_x',
          ),
        ],
        fresh: [whole],
      );
      expect(result.deleteIds, ['p1']);
    });

    test('a part goes with a kept track said the same on', () {
      final kept = track(
        'kept',
        startMs: 1000,
        endMs: 4000,
        decision: IdentificationDecision.rejected,
      );
      final result = carryTrackDecisions(
        decided: [part('p2', kept, 2500, 3500)],
        fresh: const [],
        kept: [kept],
      );
      expect(result.insert, isEmpty);
      expect(result.deleteIds, ['p2']);
    });

    test('a kept track takes no part of another fish', () {
      final kept = track(
        'kept',
        startMs: 1000,
        endMs: 4000,
        decision: IdentificationDecision.rejected,
      );
      final elsewhere = part('p2', kept, 2500, 3500).copyWith(
        path: [
          for (final s in part('p2', kept, 2500, 3500).path)
            s.copyWith(box: s.box.copyWith(x: s.box.x + 0.5)),
        ],
      );
      final result = carryTrackDecisions(
        decided: [elsewhere],
        fresh: const [],
        kept: [kept],
      );
      expect(result.deleteIds, isEmpty);
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

  group('naming a track from its views', () {
    PackCandidate species(String scientificName) => PackCandidate(
      gbifKey: scientificName.hashCode,
      scientificName: scientificName,
      commonName: scientificName,
      category: SpeciesCategory.fish,
    );

    /// One view's naming: [open] is its open score, [top] its best name.
    NamingResult view(double open, String top, {bool suggestable = true}) =>
        NamingResult(
          openScore: open,
          candidates: [NamedCandidate(candidate: species(top), score: 0.9)],
          locationLimited: true,
          suggestable: suggestable,
        );

    /// [chooseNamingView] over [views] seen at [at], by default a second
    /// apart, as the detector's best moments usually are.
    ({int index, bool suggestable})? choose(
      List<NamingResult> views, {
      List<int>? at,
    }) => chooseNamingView([
      for (final (k, v) in views.indexed) (naming: v, ms: at?[k] ?? k * 1000),
    ]);

    const stoplight = 'Sparisoma viride';
    const chromis = 'Chromis multilineata';

    test('the most decided view names the track', () {
      final pick = choose([
        view(0.3, stoplight),
        view(0.8, stoplight),
        view(0.5, stoplight),
      ])!;
      expect(pick.index, 1);
      expect(pick.suggestable, isTrue);
    });

    test("a tie goes to the first view, the detector's best", () {
      expect(choose([view(0.6, stoplight), view(0.6, stoplight)])!.index, 0);
    });

    test('a decided view no other view agrees with is not suggested', () {
      final pick = choose([
        view(0.3, chromis),
        view(0.8, stoplight),
        view(0.5, chromis),
      ])!;
      expect(pick.index, 1);
      expect(pick.suggestable, isFalse);
    });

    test('a view agrees by its name, whether or not it clears the bars', () {
      final pick = choose([
        view(0.8, stoplight),
        view(0.2, stoplight, suggestable: false),
      ])!;
      expect(pick.suggestable, isTrue);
    });

    test('the names are compared ignoring case and surrounding space', () {
      expect(
        choose([
          view(0.8, stoplight),
          view(0.2, ' sparisoma VIRIDE '),
        ])!.suggestable,
        isTrue,
      );
    });

    test('agreement never lifts a view that misses the bars', () {
      expect(
        choose([
          view(0.8, stoplight, suggestable: false),
          view(0.5, stoplight),
        ])!.suggestable,
        isFalse,
      );
    });

    test('a single view is judged as a photo is', () {
      expect(choose([view(0.8, stoplight)])!.suggestable, isTrue);
      expect(
        choose([view(0.8, stoplight, suggestable: false)])!.suggestable,
        isFalse,
      );
    });

    test('no view with names names nothing', () {
      expect(choose([NamingResult.unusable, NamingResult.unusable]), isNull);
      expect(choose(const []), isNull);
    });

    test('a view with no names neither names the track nor agrees', () {
      final pick = choose([NamingResult.unusable, view(0.4, chromis)])!;
      expect(pick.index, 1);
      // Only one usable view: judged as a photo is.
      expect(pick.suggestable, isTrue);
      expect(
        choose([
          view(0.4, chromis),
          NamingResult.unusable,
          NamingResult.unusable,
        ])!.suggestable,
        isTrue,
      );
    });

    test('a view under a second from the chosen one does not agree '
        '(issue #4747)', () {
      // The one at 0 ms agrees but is nearly the same frame as the chosen
      // one at 250 ms; the only view a second away names another species.
      final pick = choose(
        [view(0.5, stoplight), view(0.8, stoplight), view(0.6, chromis)],
        at: [0, 250, 1500],
      )!;
      expect(pick.index, 1);
      expect(pick.suggestable, isFalse);
    });

    test('a view a second from the chosen one agrees', () {
      expect(
        choose(
          [view(0.8, stoplight), view(0.3, stoplight)],
          at: [0, 1000],
        )!.suggestable,
        isTrue,
      );
    });

    test("views all under a second apart are one view: the detector's best "
        'names the track, as a photo', () {
      final pick = choose(
        [view(0.5, stoplight), view(0.9, chromis), view(0.7, chromis)],
        at: [0, 250, 500],
      )!;
      expect(pick.index, 0);
      expect(pick.suggestable, isTrue);
      expect(
        choose(
          [view(0.5, stoplight, suggestable: false), view(0.9, stoplight)],
          at: [0, 250],
        )!.suggestable,
        isFalse,
      );
    });

    test('a view with no names does not set the views apart', () {
      final pick = choose(
        [view(0.5, stoplight), NamingResult.unusable, view(0.9, chromis)],
        at: [0, 1500, 250],
      )!;
      expect(pick.index, 0);
      expect(pick.suggestable, isTrue);
    });
  });

  group('storedWorth', () {
    test("a stored track is worth its best sampled box, not the view it "
        'shows (issue #4736)', () {
      final t = track('t1');
      final row = t.copyWith(
        box: const IdentificationBox(x: 0.1, y: 0.4, width: 0.1, height: 0.1),
        detectorScore: 0.5,
        path: [
          ...t.path,
          t.path.last.copyWith(
            ms: 2250,
            box: const IdentificationBox(
              x: 0.1,
              y: 0.4,
              width: 0.4,
              height: 0.2,
            ),
          ),
        ],
      );
      expect(storedWorth(row), closeTo(0.5 * 0.4 * 0.2, 1e-12));
    });

    test('a row with no path is worth its box', () {
      final row = identification('p1');
      expect(storedWorth(row), closeTo(0.91 * 0.3 * 0.25, 1e-12));
    });
  });

  group('renaming a stored track', () {
    MediaIdentification renamedTo(
      MediaIdentification before,
      String scientificName, {
      bool suggestable = true,
    }) => before.copyWith(
      candidates: [
        NamedCandidate(
          candidate: PackCandidate(
            gbifKey: 9,
            scientificName: scientificName,
            commonName: scientificName,
            category: SpeciesCategory.fish,
          ),
          score: 0.9,
        ),
      ],
      suggestable: suggestable,
    );

    test('keeps its suggestion when its name stays the same', () {
      final before = track('a');
      expect(
        suggestableOnRename(
          before: before,
          renamed: renamedTo(before, 'Scarus vetula'),
        ),
        isTrue,
      );
    });

    test('loses it when its name changes, until it is scanned again', () {
      final before = track('a');
      expect(
        suggestableOnRename(
          before: before,
          renamed: renamedTo(before, 'Sparisoma viride'),
        ),
        isFalse,
      );
    });

    test('gains none it did not have', () {
      final before = track('a', suggestable: false);
      expect(
        suggestableOnRename(
          before: before,
          renamed: renamedTo(before, 'Scarus vetula'),
        ),
        isFalse,
      );
    });

    test('loses it when the new name misses the bars', () {
      final before = track('a');
      expect(
        suggestableOnRename(
          before: before,
          renamed: renamedTo(before, 'Scarus vetula', suggestable: false),
        ),
        isFalse,
      );
    });

    test('a photo is renamed by the bars alone', () {
      final before = identification('p').copyWith(suggestable: false);
      expect(
        suggestableOnRename(
          before: before,
          renamed: renamedTo(before, 'Sparisoma viride'),
        ),
        isTrue,
      );
    });
  });
}
