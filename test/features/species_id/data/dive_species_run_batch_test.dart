import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/species_id/data/services/dive_species_run.dart';
import 'package:submersion/features/species_id/data/services/media_identification_service.dart';
import 'package:submersion/features/species_id/domain/entities/dive_species_run_state.dart';

/// What a run over many dives asks of one dive's run (issue #5127): only
/// the media on this device, one History entry, and no state left behind.
void main() {
  late List<String> asked;
  late List<String> askedWhereHeld;
  late Set<String> notHere;
  late Set<String> upToDate;
  late Object? libraryFailure;
  late List<({List<String> items, String? operationId})> applied;
  late int operationAsks;
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
    asked = [];
    askedWhereHeld = [];
    notHere = {};
    upToDate = {};
    libraryFailure = null;
    applied = [];
    operationAsks = 0;
    run = DiveSpeciesRun(
      mediaForDive: (_) async => [
        item('p1'),
        item('p2'),
        item('v1', type: MediaType.video),
      ],
      diveLocation: (_) async => (exists: true, site: null, entry: null),
      request: (item, _) async {
        asked.add(item.id);
        return RunItemOutcome.done;
      },
      cancel: (_) {},
      applyAll: (items, _) async {
        applied.add((
          items: [for (final i in items) i.mediaId],
          operationId: null,
        ));
        return 1;
      },
      applyAllInto: (items, _, operationId) async {
        applied.add((
          items: [for (final i in items) i.mediaId],
          operationId: operationId,
        ));
        return {'sp1', 'sp2'};
      },
      onDevice: (item) async {
        askedWhereHeld.add(item.id);
        if (libraryFailure != null && item.id == 'p2') throw libraryFailure!;
        return !notHere.contains(item.id);
      },
      upToDate: (items, _) async => {
        for (final m in items)
          if (upToDate.contains(m.id)) m.id,
      },
      databaseGeneration: () => 0,
    );
  });
  tearDown(() => run.dispose());

  Future<String> batch() async {
    operationAsks++;
    return 'batch';
  }

  test('only on this device leaves the rest out of the run', () async {
    notHere = {'p2', 'v1'};

    await run.start('d1', onDeviceOnly: true);

    expect(asked, ['p1']);
    final s = run.stateOf('d1')!;
    expect(s.phase, DiveRunPhase.finished);
    expect(s.total, 1);
    expect(s.done, 1);
    expect(s.summary.notOnDevice, 2);
    expect(applied.single.items, ['p1']);
  });

  test('only on this device keeps what is up to date: asking it downloads '
      'nothing, and its open suggestions can still be tagged', () async {
    notHere = {'p1', 'p2', 'v1'};
    upToDate = {'p2'};

    await run.start('d1', onDeviceOnly: true, operationId: batch);

    expect(asked, ['p2']);
    expect(askedWhereHeld, isNot(contains('p2')));
    final s = run.stateOf('d1')!;
    expect(s.summary.notOnDevice, 2);
    expect(applied.single.items, ['p2']);
  });

  test('a library lookup that fails costs that item, not the dive', () async {
    libraryFailure = StateError('photo library');

    await run.start('d1', onDeviceOnly: true);

    expect(asked, ['p1', 'v1']);
    final s = run.stateOf('d1')!;
    expect(s.phase, DiveRunPhase.finished);
    expect(s.summary.notOnDevice, 1);
  });

  test('without the choice nothing is asked where it is held', () async {
    notHere = {'p2'};

    await run.start('d1');

    expect(askedWhereHeld, isEmpty);
    expect(asked, ['p1', 'p2', 'v1']);
    expect(run.stateOf('d1')!.summary.notOnDevice, 0);
  });

  test('nothing on this device finishes with nothing looked at', () async {
    notHere = {'p1', 'p2', 'v1'};

    await run.start('d1', onDeviceOnly: true);

    expect(asked, isEmpty);
    expect(applied, isEmpty);
    final s = run.stateOf('d1')!;
    expect(s.phase, DiveRunPhase.finished);
    expect(s.total, 0);
    expect(s.summary.notOnDevice, 3);
  });

  test('an operation files the apply under it, asked only when it applies, '
      'and the species are named', () async {
    final done = run.start('d1', operationId: batch);
    expect(operationAsks, 0);
    await done;

    expect(operationAsks, 1);
    expect(applied.single.operationId, 'batch');
    final summary = run.stateOf('d1')!.summary;
    expect(summary.speciesTagged, 2);
    expect(summary.taggedSpeciesIds, {'sp1', 'sp2'});
  });

  test('without an operation the dive applies on its own', () async {
    await run.start('d1');

    expect(applied.single.operationId, isNull);
    expect(run.stateOf('d1')!.summary.speciesTagged, 1);
    expect(run.stateOf('d1')!.summary.taggedSpeciesIds, isEmpty);
  });

  test('forget drops a finished dive', () async {
    await run.start('d1');

    run.forget('d1');

    expect(run.stateOf('d1'), isNull);
    expect(run.state.containsKey('d1'), isFalse);
  });

  test('forget leaves a dive whose run is still going', () async {
    final done = run.start('d1');

    run.forget('d1');

    expect(run.stateOf('d1'), isNotNull);
    await done;
  });

  test('a dive whose run is queued is reported as such', () async {
    expect(run.isQueuedOrRunning('d1'), isFalse);
    final done = run.start('d1');
    expect(run.isQueuedOrRunning('d1'), isTrue);
    await done;
    expect(run.isQueuedOrRunning('d1'), isFalse);
  });
}
