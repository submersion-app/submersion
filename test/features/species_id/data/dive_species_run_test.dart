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
  late Map<String, List<RunItemOutcome>> outcomes;
  late List<List<String>> applied;
  late List<String> cancelled;
  late int generation;
  Completer<void>? gate;
  late DiveSpeciesRun run;

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
    outcomes = {};
    applied = [];
    cancelled = [];
    generation = 0;
    gate = null;
    run = DiveSpeciesRun(
      mediaForDive: (diveId) async => media[diveId] ?? const [],
      diveLocation: (diveId) async => dives.contains(diveId)
          ? (exists: true, site: const GeoPoint(20, -87), entry: null)
          : (exists: false, site: null, entry: null),
      request: (item, location) async {
        asked.add(item.id);
        await gate?.future;
        final queue = outcomes[item.id];
        return queue == null || queue.isEmpty
            ? RunItemOutcome.done
            : queue.removeAt(0);
      },
      cancel: (mediaId) => cancelled.add(mediaId),
      applyAll: (items) async {
        applied.add([for (final i in items) i.mediaId]);
        return items.length;
      },
      databaseGeneration: () => generation,
    );
  });
  tearDown(() => run.dispose());

  DiveSpeciesRunState state(String diveId) => run.stateOf(diveId)!;

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
}
