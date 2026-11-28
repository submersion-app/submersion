import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/species_id/data/services/dive_species_run.dart';
import 'package:submersion/features/species_id/data/services/media_identification_service.dart';
import 'package:submersion/features/species_id/data/services/species_batch_run.dart';
import 'package:submersion/features/species_id/domain/entities/species_batch.dart';

/// Find species over many dives (issue #5127): one dive at a time, one
/// History entry, and nothing left queued in the dive runs.
void main() {
  late Map<String, List<MediaItem>> media;
  late List<String> asked;
  late List<({String diveId, String operationId})> applied;
  late Set<String> reverted;
  late int generation;
  late int ids;
  Completer<void>? gate;
  late DiveSpeciesRun runs;
  late SpeciesBatchRun batch;

  MediaItem item(String id, String diveId) => MediaItem(
    id: id,
    diveId: diveId,
    mediaType: MediaType.photo,
    takenAt: DateTime.utc(2026),
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  SpeciesBatchPlan plan(List<String> dives) => SpeciesBatchPlan(
    dives: [
      for (final d in dives)
        PlannedDive(
          diveId: d,
          items: media[d]!.length,
          toLookAt: media[d]!.length,
        ),
    ],
  );

  setUp(() {
    media = {
      'd1': [item('a1', 'd1'), item('a2', 'd1')],
      'd2': [item('b1', 'd2')],
      'd3': [item('c1', 'd3'), item('c2', 'd3'), item('c3', 'd3')],
    };
    asked = [];
    applied = [];
    reverted = {};
    generation = 0;
    ids = 0;
    gate = null;
    runs = DiveSpeciesRun(
      mediaForDive: (diveId) async => media[diveId] ?? const [],
      diveLocation: (_) async => (exists: true, site: null, entry: null),
      request: (item, _) async {
        asked.add(item.id);
        await gate?.future;
        return RunItemOutcome.done;
      },
      cancel: (_) {},
      applyAll: (_, _) async => 0,
      applyAllInto: (items, _, operationId) async {
        applied.add((diveId: items.first.mediaId, operationId: operationId));
        return 1;
      },
      databaseGeneration: () => generation,
    );
    batch = SpeciesBatchRun(
      runs: () => runs,
      databaseGeneration: () => generation,
      isReverted: (operationId) async => reverted.contains(operationId),
      newOperationId: () => 'op${ids++}',
    );
  });
  tearDown(() {
    batch.dispose();
    runs.dispose();
  });

  test('runs the dives one after another, all under one entry', () async {
    expect(batch.start(plan(['d1', 'd2', 'd3'])), isTrue);
    await batch.done;

    expect(asked, ['a1', 'a2', 'b1', 'c1', 'c2', 'c3']);
    expect(applied.map((a) => a.operationId).toSet(), {'op0'});
    final s = batch.state!;
    expect(s.phase, SpeciesBatchPhase.finished);
    expect(s.divesDone, 3);
    expect(s.itemsDone, 6);
    expect(s.summary.photos, 6);
    expect(s.summary.speciesTagged, 3);
  });

  test('only one dive is ever queued in the dive runs', () async {
    gate = Completer<void>();
    batch.start(plan(['d1', 'd2', 'd3']));
    await pumpEventQueue();

    expect(runs.isQueuedOrRunning('d1'), isTrue);
    expect(runs.isQueuedOrRunning('d2'), isFalse);
    expect(batch.isPending('d2'), isTrue);
    expect(batch.isPending('d1'), isFalse);
    gate!.complete();
    await batch.done;
  });

  test('finished dives leave no state behind in the dive runs', () async {
    batch.start(plan(['d1', 'd2']));
    await batch.done;

    expect(runs.state, isEmpty);
  });

  test('a second start while one runs is refused', () async {
    gate = Completer<void>();
    batch.start(plan(['d1']));
    await pumpEventQueue();

    expect(batch.start(plan(['d2'])), isFalse);
    gate!.complete();
    await batch.done;
    expect(asked, ['a1', 'a2']);
  });

  test('a new start after one ended is accepted', () async {
    batch.start(plan(['d1']));
    await batch.done;

    expect(batch.start(plan(['d2'])), isTrue);
    await batch.done;
    expect(applied.last.operationId, 'op1');
  });

  test('cancel stops after the item in progress and drops the rest', () async {
    gate = Completer<void>();
    batch.start(plan(['d1', 'd2', 'd3']));
    await pumpEventQueue();

    batch.cancel();
    gate!.complete();
    await batch.done;

    expect(asked, ['a1']);
    expect(batch.state!.phase, SpeciesBatchPhase.cancelled);
    expect(batch.isPending('d2'), isFalse);
    // What it looked at is kept, in the batch's entry.
    expect(applied.single.operationId, 'op0');
  });

  test('another logbook ends the batch', () async {
    gate = Completer<void>();
    batch.start(plan(['d1', 'd2']));
    await pumpEventQueue();

    generation = 1;
    gate!.complete();
    await batch.done;

    expect(asked, ['a1']);
    expect(applied, isEmpty);
    expect(batch.state!.phase, SpeciesBatchPhase.cancelled);
  });

  test('an entry the diver reverted is not added to', () async {
    batch.start(plan(['d1', 'd2']));
    // Reverted once the first dive applied.
    reverted = {'op0'};
    await batch.done;

    expect(applied.map((a) => a.operationId).toList(), ['op0', 'op1']);
  });

  test(
    'a dive whose card run is queued is waited for, not run twice',
    () async {
      gate = Completer<void>();
      final card = runs.start('d2');
      batch.start(plan(['d2', 'd3']));
      await pumpEventQueue();
      gate!.complete();
      await card;
      await batch.done;

      expect(asked, ['b1', 'c1', 'c2', 'c3']);
      expect(batch.state!.divesDone, 2);
    },
  );

  test('progress folds in the dive in progress', () async {
    gate = Completer<void>();
    batch.start(plan(['d1', 'd3']));
    await pumpEventQueue();

    final p = SpeciesBatchProgress.of(batch.state!, runs.stateOf('d1'));
    expect(p.diveNumber, 1);
    expect(p.diveCount, 2);
    expect(p.itemsTotal, 5);
    expect(p.itemsDone, 0);
    gate!.complete();
    await batch.done;
    final end = SpeciesBatchProgress.of(batch.state!, null);
    expect(end.itemsDone, 5);
    expect(end.fraction, 1);
  });

  test('an empty plan finishes at once', () async {
    expect(batch.start(const SpeciesBatchPlan()), isTrue);
    await batch.done;
    expect(batch.state!.phase, SpeciesBatchPhase.finished);
    expect(asked, isEmpty);
  });
}
