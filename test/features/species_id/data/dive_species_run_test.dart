import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/species_id/data/services/dive_species_run.dart';
import 'package:submersion/features/species_id/data/services/media_identification_service.dart';
import 'package:submersion/features/species_id/domain/entities/dive_species_run_state.dart';

/// Finding species in a whole dive's photos and videos (issue #4727).
void main() {
  late Map<String, List<MediaItem>> media;
  late Set<String> dives;
  late List<String> asked;
  late List<String> askedFresh;
  late Map<String, List<RunItemOutcome>> outcomes;
  late List<List<String>> applied;
  late List<String> cancelled;
  late int generation;
  Completer<void>? gate;
  Object? applyFailure;
  late bool foreground;
  Object? listFailure;
  late DiveSpeciesRun run;
  void Function()? onPlace;
  late List<int> appliedIn;

  MediaItem item(String id, {MediaType type = MediaType.photo}) => MediaItem(
    id: id,
    diveId: 'd1',
    mediaType: type,
    takenAt: DateTime.utc(2026),
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  setUp(() {
    media = {
      'd1': [item('v1', type: MediaType.video), item('p1'), item('p2')],
      'd2': [item('q1')],
    };
    dives = {'d1', 'd2'};
    asked = [];
    askedFresh = [];
    outcomes = {};
    applied = [];
    cancelled = [];
    generation = 0;
    gate = null;
    applyFailure = null;
    foreground = true;
    listFailure = null;
    onPlace = null;
    appliedIn = [];
    run = DiveSpeciesRun(
      mediaForDive: (diveId) async {
        if (listFailure != null && diveId == 'd1') throw listFailure!;
        return media[diveId] ?? const [];
      },
      diveLocation: (diveId) async {
        onPlace?.call();
        return dives.contains(diveId)
            ? (exists: true, site: const GeoPoint(20, -87), entry: null)
            : (exists: false, site: null, entry: null);
      },
      request: (item, location) async {
        asked.add(item.id);
        await gate?.future;
        final queue = outcomes[item.id];
        return queue == null || queue.isEmpty
            ? RunItemOutcome.done
            : queue.removeAt(0);
      },
      requestFresh: (item, location) async {
        askedFresh.add(item.id);
        await gate?.future;
        final queue = outcomes[item.id];
        return queue == null || queue.isEmpty
            ? RunItemOutcome.done
            : queue.removeAt(0);
      },
      cancel: (mediaId) => cancelled.add(mediaId),
      applyAll: (items, generation) async {
        if (applyFailure != null) throw applyFailure!;
        appliedIn.add(generation);
        applied.add([for (final i in items) i.mediaId]);
        return items.length;
      },
      databaseGeneration: () => generation,
      inForeground: () => foreground,
    );
  });
  tearDown(() => run.dispose());

  DiveSpeciesRunState state(String diveId) => run.stateOf(diveId)!;

  test(
    'disposed during a run, it ends without completing its run twice',
    () async {
      gate = Completer<void>();
      final doomed = run;
      final finished = doomed.start('d1');
      await pumpEventQueue();

      doomed.dispose();
      gate!.complete();
      await finished;
      await pumpEventQueue();

      // Disposed already: tearDown disposes a fresh one instead.
      run = DiveSpeciesRun(
        mediaForDive: (_) async => const [],
        diveLocation: (_) async => (exists: true, site: null, entry: null),
        request: (_, _) async => RunItemOutcome.done,
        cancel: (_) {},
        applyAll: (_, _) async => 0,
        databaseGeneration: () => 0,
      );
    },
  );

  test('a dive already gone is not looked at: the run stops as for a '
      'deleted dive', () async {
    dives.remove('d1');

    await run.start('d1');

    expect(asked, isEmpty);
    expect(applied, isEmpty);
    expect(state('d1').phase, DiveRunPhase.cancelled);
  });

  test('another logbook opened after the last item applies nothing', () async {
    var reads = 0;
    // The start, then after each of the three items.
    onPlace = () {
      if (++reads == 4) generation = 1;
    };

    await run.start('d1');

    expect(asked, hasLength(3));
    expect(applied, isEmpty);
    expect(state('d1').phase, DiveRunPhase.cancelled);
  });

  test('applying names the logbook the run began in', () async {
    generation = 7;

    await run.start('d1');

    expect(appliedIn, [7]);
  });

  test('photos before videos, and a summary at the end', () async {
    await run.start('d1');

    expect(asked, ['p1', 'p2', 'v1']);
    final s = state('d1');
    expect(s.phase, DiveRunPhase.finished);
    expect((s.done, s.total), (3, 3));
    expect(s.summary.photos, 2);
    expect(s.summary.videos, 1);
    expect(s.summary.speciesTagged, 3);
  });

  test('every item is applied together, at the end, once', () async {
    await run.start('d1');
    expect(applied, [
      ['p1', 'p2', 'v1'],
    ]);
  });

  test('an item that cannot be reached is counted and not applied', () async {
    outcomes['p2'] = [RunItemOutcome.unreadable];
    await run.start('d1');
    expect(state('d1').summary.unreadable, 1);
    expect(applied.single, ['p1', 'v1']);
  });

  test('too warm pauses on that item, and resume carries on', () async {
    outcomes['p2'] = [RunItemOutcome.tooHot];
    final running = run.start('d1');
    await pumpEventQueue();

    expect(state('d1').phase, DiveRunPhase.paused);
    expect(state('d1').pauseReason, DiveRunPause.tooHot);
    run.resume('d1');
    await running;

    expect(asked, ['p1', 'p2', 'p2', 'v1']);
    expect(state('d1').phase, DiveRunPhase.finished);
  });

  test('the app going to the background pauses before the next item', () async {
    gate = Completer<void>();
    final running = run.start('d1');
    await pumpEventQueue();
    run.appPaused();
    gate!.complete();
    gate = null;
    await pumpEventQueue();

    expect(asked, ['p1']);
    expect(state('d1').pauseReason, DiveRunPause.background);
    run.appResumed();
    await running;
    expect(asked, ['p1', 'p2', 'v1']);
  });

  test(
    'cancel stops after the item in progress, and applies what was found',
    () async {
      gate = Completer<void>();
      final running = run.start('d1');
      await pumpEventQueue();
      run.cancel('d1');
      gate!.complete();
      await running;

      expect(asked, ['p1']);
      expect(cancelled, ['p1']);
      expect(state('d1').phase, DiveRunPhase.cancelled);
      expect(applied.single, ['p1']);
    },
  );

  test('a second dive waits for the first', () async {
    gate = Completer<void>();
    final first = run.start('d1');
    final second = run.start('d2');
    await pumpEventQueue();
    expect(asked, ['p1']);
    gate!.complete();
    gate = null;
    await Future.wait([first, second]);
    expect(asked, ['p1', 'p2', 'v1', 'q1']);
  });

  test('another logbook opened mid-run stops it, writing nothing', () async {
    gate = Completer<void>();
    final running = run.start('d1');
    await pumpEventQueue();
    generation = 1;
    gate!.complete();
    await running;

    expect(state('d1').phase, DiveRunPhase.cancelled);
    expect(applied, isEmpty);
  });

  test('a dive deleted mid-run stops it', () async {
    gate = Completer<void>();
    final running = run.start('d1');
    await pumpEventQueue();
    dives.remove('d1');
    gate!.complete();
    await running;

    expect(asked, ['p1']);
    expect(state('d1').phase, DiveRunPhase.cancelled);
  });

  test(
    'a failure applying ends the run, and the next dive still runs',
    () async {
      applyFailure = StateError('database closed');
      final first = run.start('d1');
      final second = run.start('d2');
      await Future.wait([first, second]);

      expect(state('d1').phase, DiveRunPhase.cancelled);
      expect(state('d2').phase, DiveRunPhase.cancelled);
      expect(asked, ['p1', 'p2', 'v1', 'q1']);
    },
  );

  test('a failure listing the dive\'s media ends the run', () async {
    listFailure = StateError('no database');
    await run.start('d1');
    expect(state('d1').phase, DiveRunPhase.cancelled);
    await run.start('d2');
    expect(state('d2').phase, DiveRunPhase.finished);
  });

  test('a failed download counts as could not be opened', () async {
    outcomes['p1'] = [RunItemOutcome.failed];
    await run.start('d1');
    expect(state('d1').summary.unreadable, 1);
  });

  test('a background refusal that arrives after the app is back retries at '
      'once', () async {
    outcomes['p2'] = [RunItemOutcome.notForeground];
    await run.start('d1');
    expect(asked, ['p1', 'p2', 'p2', 'v1']);
    expect(state('d1').phase, DiveRunPhase.finished);
  });

  test('a refusal while really in the background pauses until the app is '
      'back', () async {
    foreground = false;
    outcomes['p2'] = [RunItemOutcome.notForeground];
    final running = run.start('d1');
    await pumpEventQueue();
    expect(state('d1').pauseReason, DiveRunPause.background);
    foreground = true;
    run.appResumed();
    await running;
    expect(state('d1').phase, DiveRunPhase.finished);
  });

  test('an item dropped before it ran is not counted as checked', () async {
    outcomes['p2'] = [RunItemOutcome.skipped];
    await run.start('d1');
    expect(state('d1').summary.photos, 1);
    expect(applied.single, ['p1', 'v1']);
  });

  group('a fresh run (issue #4825)', () {
    test('asks for every item afresh and tags nothing', () async {
      await run.start('d1', fresh: true);
      expect(askedFresh, ['p1', 'p2', 'v1']);
      expect(asked, isEmpty);
      expect(applied, isEmpty);
      expect(state('d1').phase, DiveRunPhase.finished);
      expect(state('d1').summary.photos, 2);
      expect(state('d1').summary.videos, 1);
      expect(state('d1').summary.speciesTagged, 0);
    });

    test('an item refused for heat is asked again where it stopped, not '
        'from the start', () async {
      outcomes['v1'] = [RunItemOutcome.tooHot];
      final finished = run.start('d1', fresh: true);
      await pumpEventQueue();
      run.resume('d1');
      await finished;
      expect(askedFresh, ['p1', 'p2', 'v1']);
      expect(asked, ['v1']);
      expect(applied, isEmpty);
    });

    test('a video refused in the background is asked again where it '
        'stopped', () async {
      outcomes['v1'] = [RunItemOutcome.notForeground];
      await run.start('d1', fresh: true);
      expect(askedFresh, ['p1', 'p2', 'v1']);
      expect(asked, ['v1']);
    });

    test('a photo refused for heat or the background is asked afresh '
        'again: nothing of it was stored', () async {
      outcomes['p1'] = [RunItemOutcome.tooHot];
      outcomes['p2'] = [RunItemOutcome.notForeground];
      final finished = run.start('d1', fresh: true);
      await pumpEventQueue();
      run.resume('d1');
      await finished;
      expect(askedFresh, ['p1', 'p1', 'p2', 'p2', 'v1']);
      expect(asked, isEmpty);
      expect(applied, isEmpty);
    });

    test('does not make the dive\'s next run fresh', () async {
      await run.start('d1', fresh: true);
      await run.start('d1');
      expect(asked, ['p1', 'p2', 'v1']);
      expect(applied, hasLength(1));
    });

    test('queued behind another dive\'s run stays fresh, and that one '
        'ordinary', () async {
      gate = Completer<void>();
      final first = run.start('d1');
      final second = run.start('d2', fresh: true);
      await pumpEventQueue();
      gate!.complete();
      gate = null;
      await first;
      await second;
      expect(asked, ['p1', 'p2', 'v1']);
      expect(askedFresh, ['q1']);
      expect(applied, [
        ['p1', 'p2', 'v1'],
      ]);
    });

    test('without its own way to ask, asks as an ordinary run does', () async {
      final plain = DiveSpeciesRun(
        mediaForDive: (diveId) async => media[diveId] ?? const [],
        diveLocation: (_) async => (exists: true, site: null, entry: null),
        request: (item, location) async {
          asked.add(item.id);
          return RunItemOutcome.done;
        },
        cancel: (_) {},
        applyAll: (items, generation) async {
          applied.add([for (final i in items) i.mediaId]);
          return items.length;
        },
        databaseGeneration: () => 0,
      );
      addTearDown(plain.dispose);
      await plain.start('d2', fresh: true);
      expect(asked, ['q1']);
      expect(applied, isEmpty);
    });
  });
}
