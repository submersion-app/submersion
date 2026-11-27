import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/species_id/data/repositories/identification_embedding_repository.dart';
import 'package:submersion/features/species_id/data/repositories/media_identification_repository.dart';
import 'package:submersion/features/species_id/data/services/identification_crop_store.dart';
import 'package:submersion/features/species_id/data/services/memory_readout.dart';
import 'package:submersion/features/species_id/data/services/video_identification_scan.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/pack_candidate.dart';
import 'package:submersion/features/species_id/domain/entities/scanned_ranges.dart';
import 'package:submersion/features/species_id/domain/entities/video_detections.dart';
import 'package:submersion/features/species_id/domain/services/species_namer.dart';
import 'package:submersion/features/species_id/domain/services/video_scan_order.dart';
import 'package:submersion/features/species_id/domain/services/video_tracker.dart';
import 'package:submersion/features/species_id/domain/services/vision_engine.dart';

import '../../../helpers/temp_dir.dart';
import 'fake_vision_engine.dart';
import 'identification_fixtures.dart';
import 'pack_fixture.dart';

/// Calls [afterRead] after each read of a video's rows: where a logbook
/// switch lands between a scan's read and its write.
class _HookedRepository extends MediaIdentificationRepository {
  _HookedRepository(AppDatabase database) : super(database: database);

  void Function()? afterRead;

  @override
  Future<List<MediaIdentification>> forMedia(String mediaId) async {
    final found = await super.forMedia(mediaId);
    afterRead?.call();
    return found;
  }
}

/// Scanning a video chunk by chunk (issue #4675).
MediaItem _video() => MediaItem(
  id: 'v1',
  mediaType: MediaType.video,
  takenAt: DateTime.utc(2026, 5, 7, 12),
  createdAt: DateTime.utc(2026, 5, 7, 12),
  updatedAt: DateTime.utc(2026, 5, 7, 12),
);

/// One fish seen every sample from [fromMs] until before [toMs], drifting
/// slowly right.
Map<int, List<DetectedBox>> _fish(
  int fromMs,
  int toMs, {
  double y = 0.4,
  double width = 0.2,
}) => {
  for (var ms = fromMs; ms < toMs; ms += 250)
    ms: [
      DetectedBox(
        box: IdentificationBox(
          x: 0.1 + ms / 1000000,
          y: y,
          width: width,
          height: 0.1,
        ),
        score: 0.9,
      ),
    ],
};

void main() {
  late AppDatabase library;
  late LocalCacheDatabase local;
  late Directory support;
  late _HookedRepository identifications;
  late IdentificationEmbeddingRepository embeddings;
  late IdentificationCropStore crops;
  late FakeEngine engine;
  late bool fileReadable;
  var reloads = 0;
  bool Function() keepGoing = () => true;
  var generation = 0;
  var ids = 0;
  PlayheadReport? report;
  var sequence = 0;
  PackCandidate Function(Float32List embedding)? nameBy;
  double Function(Float32List embedding)? openBy;
  bool Function(Float32List embedding)? unusableBy;

  void seekTo(int ms) =>
      report = PlayheadReport(ms: ms, seek: true, sequence: ++sequence);
  void pauseAt(int ms) =>
      report = PlayheadReport(ms: ms, seek: false, sequence: ++sequence);

  setUp(() async {
    library = AppDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    local = LocalCacheDatabase(NativeDatabase.memory());
    support = await Directory.systemTemp.createTemp('video_scan');
    identifications = _HookedRepository(library);
    embeddings = IdentificationEmbeddingRepository(database: local);
    crops = IdentificationCropStore(supportPath: () async => support.path);
    engine = FakeEngine()..loaded = true;
    fileReadable = true;
    generation = 0;
    ids = 0;
    keepGoing = () => true;
    reloads = 0;
    report = null;
    sequence = 0;
    nameBy = null;
    openBy = null;
    unusableBy = null;
  });
  tearDown(() async {
    await crops.dispose();
    await library.close();
    await local.close();
    await deleteTempDir(support);
  });

  /// Names every crop the first candidate, confidently, unless [nameBy]
  /// picks another from its embedding; [openBy] sets its open score, and
  /// [unusableBy] makes nothing of it.
  Future<List<NamingResult>> name(
    List<({Float32List embedding, int shorterSide})> crops,
  ) async => [
    for (final c in crops)
      if (unusableBy?.call(c.embedding) ?? false)
        NamingResult.unusable
      else
        NamingResult(
          openScore: openBy?.call(c.embedding) ?? 0.9,
          candidates: [
            NamedCandidate(
              candidate: nameBy?.call(c.embedding) ?? fixtureParrotfish,
              score: 0.9,
            ),
          ],
          locationLimited: true,
          suggestable: true,
        ),
  ];

  /// Chunks of 10 s from the start, as before live naming, unless
  /// [firstChunkMs] asks for a short first one (issue #4709).
  VideoIdentificationScan scan({
    MediaIdentificationRun? resumeFrom,
    List<MediaIdentification> carry = const [],
    MemoryReadout? memoryReadout,
    int firstChunkMs = 10000,
  }) => VideoIdentificationScan(
    memoryReadout: memoryReadout,
    playhead: () => report,
    firstChunkMs: firstChunkMs,
    keepGoing: () => keepGoing(),
    reload: () async {
      reloads++;
      engine.loaded = true;
    },
    engine: engine,
    pack: fixturePack(),
    identifications: identifications,
    embeddings: embeddings,
    crops: crops,
    item: _video(),
    cell: 1462,
    reader: <T>(read) async => fileReadable ? read('/videos/v1.mp4') : null,
    name: name,
    now: () => DateTime.utc(2026, 11, 17),
    newId: () => 'id-${ids++}',
    databaseGeneration: () => generation,
    resumeFrom: resumeFrom,
    carry: carry,
  );

  Future<void> runAll(VideoIdentificationScan s) async {
    while (await s.runChunk()) {}
  }

  test('a 25 second video is scanned in three chunks', () async {
    final s = scan();
    await runAll(s);
    expect(engine.detectCalls, [(0, 10000), (10000, 20000), (20000, 25000)]);
    final run = (await identifications.runFor('v1'))!;
    expect(run.scannedMs, 25000);
    expect(run.videoDurationMs, 25000);
    expect(run.scanComplete, isTrue);
    expect(run.imageWidth, 1920);
    expect(run.detectorId, videoRunDetectorId('det-a'));
    expect(s.progress, 1);
  });

  test('a track crossing a chunk boundary is one row', () async {
    engine.videoFrames = _fish(5000, 14000);
    await runAll(scan());
    final found = await identifications.forMedia('v1');
    expect(found, hasLength(1));
    expect(found.single.startMs, 5000);
    expect(found.single.endMs, 13750);
  });

  test('each stored track has its range, path, best moment, crop, '
      'embedding and flags', () async {
    engine.videoFrames = _fish(1000, 4000);
    await runAll(scan());
    final fish = (await identifications.forMedia('v1')).single;
    expect(fish.isTrack, isTrue);
    expect(fish.path, hasLength(12));
    expect(fish.bestMs, inInclusiveRange(1000, 3750));
    expect(fish.top!.candidate, fixtureParrotfish);
    expect(fish.confident, isTrue);
    expect(fish.specific, isTrue);
    expect(fish.boxPixelWidth, 384);
    expect(engine.embedCalls.single, hasLength(3));
    expect(await (await crops.fileFor('v1', fish.id)).exists(), isTrue);
    expect((await embeddings.get([fish.id], classifierId: 'clf-a')).keys, [
      fish.id,
    ]);
  });

  test('a video shorter than a chunk finishes in one', () async {
    engine.videoDurationMs = 4000;
    final s = scan();
    expect(await s.runChunk(), isFalse);
    expect(engine.detectCalls, [(0, 10000)]);
    expect((await identifications.runFor('v1'))!.scanComplete, isTrue);
  });

  test('a reported length of 0 stores a complete run and stops', () async {
    engine.videoDurationMs = 0;
    final s = scan();
    expect(await s.runChunk(), isFalse);
    final run = (await identifications.runFor('v1'))!;
    expect(run.scanComplete, isTrue);
    expect(await identifications.forMedia('v1'), isEmpty);
  });

  test('finish stores the tracks still open', () async {
    // Seen for under a second at the chunk's end, so not named yet.
    engine.videoFrames = _fish(9250, 15000);
    final s = scan();
    expect(await s.runChunk(), isTrue);
    expect(await identifications.forMedia('v1'), isEmpty);
    await s.finish();
    final fish = (await identifications.forMedia('v1')).single;
    expect(fish.endMs, 9750);
    expect(fish.isPending, isFalse);
    expect((await identifications.runFor('v1'))!.scannedMs, 10000);
  });

  test('a fish in view when a scan stopped is one track after it resumes, '
      'keeping what the diver said', () async {
    engine.videoFrames = _fish(1000, 15000);
    final first = scan();
    expect(await first.runChunk(), isTrue);
    await first.finish();
    final cut = (await identifications.forMedia('v1')).single;
    expect(cut.endMs, 9750);
    await identifications.updateDecisions([
      cut.copyWith(
        decision: IdentificationDecision.rejected,
        decidedAt: fixtureT1,
      ),
    ]);

    await runAll(scan(resumeFrom: await identifications.runFor('v1')));
    final found = await identifications.forMedia('v1');
    expect(found, hasLength(1));
    expect(found.single.id, cut.id);
    expect(found.single.startMs, 1000);
    expect(found.single.endMs, 14750);
    expect(found.single.decision, IdentificationDecision.rejected);
    expect((await identifications.runFor('v1'))!.detectionCount, 1);
  });

  test(
    'a decision made on a continued fish while it is scanned is kept',
    () async {
      engine.videoFrames = _fish(1000, 15000);
      final first = scan();
      expect(await first.runChunk(), isTrue);
      await first.finish();
      final cut = (await identifications.forMedia('v1')).single;
      final resumed = scan(resumeFrom: await identifications.runFor('v1'));
      // The diver names the fish after the scan read the rows.
      await identifications.claim(cut.id, 'sp_named_meanwhile');
      await identifications.updateDecisions([
        cut.copyWith(
          decision: IdentificationDecision.rejected,
          decidedAt: fixtureT1,
        ),
      ]);
      await runAll(resumed);
      final found = (await identifications.forMedia('v1')).single;
      expect(found.claimedSpeciesId, 'sp_named_meanwhile');
      expect(found.decision, IdentificationDecision.rejected);
    },
  );

  test('a continued fish whose row was cleared meanwhile is not brought '
      'back', () async {
    engine.videoFrames = _fish(1000, 15000);
    final first = scan();
    expect(await first.runChunk(), isTrue);
    await first.finish();
    final resumed = scan(resumeFrom: await identifications.runFor('v1'));
    await identifications.deleteForMedia(['v1']);
    await runAll(resumed);
    expect(
      (await identifications.forMedia('v1')).map((i) => i.startMs),
      isNot(contains(1000)),
    );
  });

  test('a track that ended well before the stop is not continued', () async {
    engine.videoFrames = {..._fish(1000, 4000), ..._fish(12000, 15000)};
    final first = scan();
    expect(await first.runChunk(), isTrue);
    await first.finish();
    await runAll(scan(resumeFrom: await identifications.runFor('v1')));
    expect(await identifications.forMedia('v1'), hasLength(2));
  });

  test('a resumed scan starts where the run stopped', () async {
    await runAll(scan());
    engine.detectCalls.clear();
    final resumed = scan(
      resumeFrom: (await identifications.runFor(
        'v1',
      ))!.copyWith(scannedMs: () => 10000, scannedRanges: () => null),
    );
    await runAll(resumed);
    expect(engine.detectCalls.first, (10000, 20000));
  });

  test('each chunk keeps the run the scan started, even when another '
      'device\'s run was stored meanwhile (issue #4876)', () async {
    final start = run(mediaId: 'v1').copyWith(
      scannedMs: () => 0,
      runId: () => 'mine',
      analysedBy: () => 'laptop',
    );
    await identifications.storeRun(start, insert: const [], deleteIds: []);
    final first = _fish(0, 25000);
    final later = _fish(12000, 18000, y: 0.7);
    engine.videoFrames = {
      for (final ms in {...first.keys, ...later.keys})
        ms: [...?first[ms], ...?later[ms]],
    };
    final s = scan(resumeFrom: start);
    expect(await s.runChunk(), isTrue);
    // Another device's scan of the same video syncs in between chunks.
    await identifications.storeRun(
      (await identifications.runFor(
        'v1',
      ))!.copyWith(runId: () => 'theirs', analysedBy: () => 'mac'),
      insert: const [],
      deleteIds: const [],
    );

    await runAll(s);

    final stored = (await identifications.runFor('v1'))!;
    expect(stored.runId, 'mine');
    expect(stored.analysedBy, 'laptop');
    final rows = await identifications.forMedia('v1');
    expect(rows, hasLength(2));
    expect({for (final r in rows) r.runId}, {'mine'});
  });

  test('a rescan carries a dismissal to the same fish', () async {
    engine.videoFrames = _fish(1000, 4000);
    await runAll(scan());
    final old = (await identifications.forMedia('v1')).single;
    final dismissed = old.copyWith(
      decision: IdentificationDecision.rejected,
      decidedAt: fixtureT1,
    );
    await identifications.updateDecisions([dismissed]);
    await runAll(scan(carry: [dismissed]));
    final found = await identifications.forMedia('v1');
    expect(found, hasLength(1));
    expect(found.single.id, isNot(old.id));
    expect(found.single.decision, IdentificationDecision.rejected);
  });

  test('a rescan carries a decision to a fish named in view before the old '
      'track began (issue #4709)', () async {
    engine.videoFrames = _fish(11500, 20000);
    await runAll(scan());
    final old = (await identifications.forMedia('v1')).single;
    final dismissed = old.copyWith(
      decision: IdentificationDecision.rejected,
      decidedAt: fixtureT1,
    );
    await identifications.updateDecisions([dismissed]);
    // The new models see the fish from 8.5 s: it is named at the first
    // chunk's end from a part that does not reach the old track yet.
    engine.videoFrames = _fish(8500, 20000);
    // As the service starts a rescan: the carried rows already counted.
    await runAll(
      scan(
        resumeFrom: videoRun(scannedMs: 0, videoDurationMs: null),
        carry: [dismissed],
      ),
    );
    final found = await identifications.forMedia('v1');
    expect(found, hasLength(1));
    expect(found.single.id, isNot(old.id));
    expect(found.single.decision, IdentificationDecision.rejected);
    expect((found.single.startMs, found.single.endMs), (8500, 19750));
    expect((await identifications.runFor('v1'))!.detectionCount, 1);
  });

  test('models freed before pass 1 are loaded again, once, and the chunk '
      'is kept whole', () async {
    reloads = 0;
    engine.videoFrames = _fish(1000, 4000);
    engine.loaded = false;
    await runAll(scan());
    expect(reloads, 1);
    final fish = (await identifications.forMedia('v1')).single;
    expect(fish.startMs, 1000);
    expect(fish.path, hasLength(12));
  });

  test('models freed before pass 2 are loaded again without feeding the '
      'tracker twice', () async {
    reloads = 0;
    engine.videoFrames = _fish(1000, 4000);
    engine.embedFailure = const VisionEngineException(
      VisionEngineException.notLoaded,
    );
    await runAll(scan());
    expect(reloads, 1);
    final found = await identifications.forMedia('v1');
    expect(found, hasLength(1));
    expect(found.single.path.map((p) => p.ms).toSet(), hasLength(12));
  });

  test('a second failure to load is thrown to the caller', () async {
    engine.loaded = false;
    final s = VideoIdentificationScan(
      engine: engine,
      pack: fixturePack(),
      identifications: identifications,
      embeddings: embeddings,
      crops: crops,
      item: _video(),
      cell: null,
      reader: <T>(read) => read('/videos/v1.mp4'),
      name: name,
      now: () => DateTime.utc(2026, 11, 17),
      newId: () => 'id-${ids++}',
      databaseGeneration: () => generation,
      reload: () async {},
    );
    await expectLater(s.runChunk(), throwsA(isA<VisionEngineException>()));
    expect(await identifications.runFor('v1'), isNull);
  });

  test('a claim made on a carried fish during a rescan is carried', () async {
    engine.videoFrames = _fish(1000, 4000);
    await runAll(scan());
    final old = (await identifications.forMedia('v1')).single;
    final dismissed = old.copyWith(
      decision: IdentificationDecision.rejected,
      decidedAt: fixtureT1,
    );
    await identifications.updateDecisions([dismissed]);
    final rescan = scan(carry: [dismissed]);
    await identifications.claim(old.id, 'sp_named_meanwhile');
    await runAll(rescan);
    final found = (await identifications.forMedia('v1')).single;
    expect(found.id, isNot(old.id));
    expect(found.claimedSpeciesId, 'sp_named_meanwhile');
  });

  /// [count] fish in a row across the frame from [fromMs] to [toMs].
  Map<int, List<DetectedBox>> school(int count, int fromMs, int toMs) => {
    for (var ms = fromMs; ms < toMs; ms += 250)
      ms: [
        for (var k = 0; k < count; k++)
          DetectedBox(
            box: IdentificationBox(
              x: k * (1 / count),
              y: 0.4,
              width: 0.5 / count,
              height: 0.1,
            ),
            score: 0.9,
          ),
      ],
  };

  test('pass 2 works in batches and stops between them when told', () async {
    engine.videoFrames = school(5, 1000, 4000);
    final s = scan();
    keepGoing = () => engine.embedCalls.isEmpty;
    await expectLater(s.runChunk(), throwsA(isA<VideoScanStopped>()));
    expect(engine.embedCalls, hasLength(1));
    expect(engine.embedCalls.single, hasLength(12));
    expect(await identifications.runFor('v1'), isNull);
    await s.finish();
    expect(await identifications.forMedia('v1'), isEmpty);
    keepGoing = () => true;
  });

  test('pass 2 batches cover every moment when nothing stops it', () async {
    engine.videoFrames = school(5, 1000, 4000);
    await runAll(scan());
    expect(engine.embedCalls.map((c) => c.length), [12, 3]);
    expect(await identifications.forMedia('v1'), hasLength(5));
  });

  test('stopping names at most one batch of the tracks still open, and '
      'keeps the rest to name later', () async {
    // Arriving just before the chunk's end, so none is named early.
    engine.videoFrames = school(6, 9250, 15000);
    final s = scan();
    expect(await s.runChunk(), isTrue);
    await s.finish();
    expect(engine.embedCalls.last.length, lessThanOrEqualTo(12));
    final found = await identifications.forMedia('v1');
    expect(found, hasLength(6));
    expect(found.where((i) => i.isPending), hasLength(2));
    for (final pending in found.where((i) => i.isPending)) {
      expect(pending.path, isNotEmpty);
      expect(await (await crops.fileFor('v1', pending.id)).exists(), isFalse);
    }
  });

  test('fish kept to name later are named, not found again, when the scan '
      'resumes', () async {
    engine.videoFrames = school(6, 9250, 15000);
    final first = scan();
    expect(await first.runChunk(), isTrue);
    await first.finish();
    final ids = {for (final i in await identifications.forMedia('v1')) i.id};
    await runAll(scan(resumeFrom: await identifications.runFor('v1')));
    final found = await identifications.forMedia('v1');
    expect(found.map((i) => i.id).toSet(), ids);
    expect(found.where((i) => i.isPending), isEmpty);
    expect(found.every((i) => i.endMs == 14750), isTrue);
  });

  test(
    'a fish kept to name later that left at the stop is still named',
    () async {
      engine.videoFrames = school(6, 9250, 10000);
      final first = scan();
      expect(await first.runChunk(), isTrue);
      await first.finish();
      await runAll(scan(resumeFrom: await identifications.runFor('v1')));
      final found = await identifications.forMedia('v1');
      expect(found, hasLength(6));
      expect(found.where((i) => i.isPending), isEmpty);
    },
  );

  test('at a second stop the fish still unnamed are named first, and a '
      'named fish left over keeps its name and grows its path', () async {
    // Two fish arrive later, so they are the shorter tracks at both stops.
    // All arrive under a second before the first chunk's end, so none is
    // named early.
    engine.videoFrames = {
      for (final e in school(6, 9000, 20000).entries)
        e.key: [
          for (var k = 0; k < 6; k++)
            if (k < 4 || e.key >= 9500) e.value[k],
        ],
    };
    final first = scan();
    expect(await first.runChunk(), isTrue);
    await first.finish();
    final before = {
      for (final i in await identifications.forMedia('v1')) i.id: i,
    };
    expect(before.values.where((i) => i.isPending), hasLength(2));
    final second = scan(resumeFrom: await identifications.runFor('v1'));
    expect(await second.runChunk(), isTrue);
    await second.finish();
    expect(engine.embedCalls.last.length, lessThanOrEqualTo(12));
    final found = await identifications.forMedia('v1');
    expect(found.map((i) => i.id).toSet(), before.keys.toSet());
    expect(found.where((i) => i.isPending), isEmpty);
    for (final fish in found) {
      expect(fish.endMs, 19750);
      expect(fish.path.last.ms, 19750);
      expect(fish.top, isNotNull);
    }
    final keptName = [
      for (final fish in found)
        if (fish.bestMs == before[fish.id]!.bestMs &&
            !before[fish.id]!.isPending)
          fish,
    ];
    expect(keptName, isNotEmpty);
  });

  /// A fish crossing the 10 s boundary (9 s to 12 s, low in the frame, in
  /// view under a second at the first chunk's end so not named early),
  /// then five more from 10 s to 14 s: chunk 2 closes six tracks, so its
  /// pass 2 takes two batches.
  void crossingFishThenSchool() {
    engine.videoFrames = {
      for (var ms = 9000; ms < 14000; ms += 250)
        ms: [
          if (ms < 12000)
            const DetectedBox(
              box: IdentificationBox(x: 0.05, y: 0.8, width: 0.1, height: 0.1),
              score: 0.9,
            ),
          ...?school(5, 10000, 14000)[ms],
        ],
    };
  }

  test('a stop between batches keeps the fish open since the chunk before, '
      'as it was there', () async {
    crossingFishThenSchool();
    final s = scan();
    expect(await s.runChunk(), isTrue);
    keepGoing = () => engine.embedCalls.isEmpty;
    await expectLater(s.runChunk(), throwsA(isA<VideoScanStopped>()));
    await s.finish(naming: false);
    final kept = (await identifications.forMedia('v1')).single;
    expect(kept.isPending, isTrue);
    expect((kept.startMs, kept.endMs), (9000, 9750));
    expect((await identifications.runFor('v1'))!.scannedMs, 10000);

    keepGoing = () => true;
    await runAll(scan(resumeFrom: await identifications.runFor('v1')));
    final found = await identifications.forMedia('v1');
    expect(found, hasLength(6));
    expect(found.where((i) => i.isPending), isEmpty);
    final fish = found.singleWhere((i) => i.id == kept.id);
    expect((fish.startMs, fish.endMs), (9000, 11750));
  });

  test('an engine failure in pass 2 keeps the fish open since the chunk '
      'before, unnamed when naming fails again', () async {
    crossingFishThenSchool();
    final s = scan();
    expect(await s.runChunk(), isTrue);
    const away = VisionEngineException('not_foreground');
    engine.embedFailure = away;
    await expectLater(s.runChunk(), throwsA(away));
    engine.embedFailure = away;
    await s.finish();
    final kept = (await identifications.forMedia('v1')).single;
    expect(kept.isPending, isTrue);
    expect((kept.startMs, kept.endMs), (9000, 9750));
  });

  test(
    'a logbook opened while a chunk reads its rows gets nothing of it',
    () async {
      crossingFishThenSchool();
      final first = scan();
      expect(await first.runChunk(), isTrue);
      await first.finish(naming: false);
      final resumed = scan(resumeFrom: await identifications.runFor('v1'));
      // The chunk closes the continued fish, so its store reads the rows.
      identifications.afterRead = () => generation++;
      expect(await resumed.runChunk(), isFalse);
      identifications.afterRead = null;
      final kept = (await identifications.forMedia('v1')).single;
      expect(kept.isPending, isTrue);
      expect(kept.endMs, 9750);
      expect((await identifications.runFor('v1'))!.scannedMs, 10000);
    },
  );

  test('finish runs no pass 2 once another logbook has opened', () async {
    crossingFishThenSchool();
    final s = scan();
    expect(await s.runChunk(), isTrue);
    generation++;
    await s.finish();
    expect(engine.embedCalls, isEmpty);
  });

  test('with no file nothing is stored and the scan stops', () async {
    fileReadable = false;
    expect(await scan().runChunk(), isFalse);
    expect(await identifications.runFor('v1'), isNull);
  });

  test('another logbook opening during a chunk drops it', () async {
    engine.videoFrames = _fish(1000, 4000);
    engine.videoFailureAt = (_) {
      generation++;
      return null;
    };
    expect(await scan().runChunk(), isFalse);
    expect(await identifications.runFor('v1'), isNull);
    expect(await identifications.forMedia('v1'), isEmpty);
  });

  group('following the playhead (issue #4709)', () {
    List<ScannedStretch> stretches(MediaIdentificationRun run) =>
        run.scanned.stretches;

    test('the first chunk is short when asked', () async {
      await runAll(scan(firstChunkMs: 2000));
      expect(engine.detectCalls, [
        (0, 2000),
        (2000, 12000),
        (12000, 22000),
        (22000, 25000),
      ]);
    });

    test('a seek report moves the next chunk there', () async {
      engine.videoDurationMs = 60000;
      final s = scan(firstChunkMs: 2000);
      await s.runChunk();
      await s.runChunk();
      seekTo(40000);
      expect(await s.runChunk(), isTrue);
      expect(engine.detectCalls.last, (40000, 42000));
      final run = (await identifications.runFor('v1'))!;
      expect(stretches(run), [
        (startMs: 0, endMs: 12000),
        (startMs: 40000, endMs: 42000),
      ]);
      expect(run.scannedMs, 12000);
      expect(run.scanComplete, isFalse);
      expect(s.progress, closeTo(14000 / 60000, 1e-9));
    });

    test('the scan fills what it skipped, then ends', () async {
      engine.videoDurationMs = 60000;
      final s = scan();
      await s.runChunk();
      seekTo(40000);
      await runAll(s);
      expect(engine.detectCalls, [
        (0, 10000),
        (40000, 50000),
        (50000, 60000),
        (10000, 20000),
        (20000, 30000),
        (30000, 40000),
      ]);
      final run = (await identifications.runFor('v1'))!;
      expect(run.scanComplete, isTrue);
      expect(run.scannedMs, 60000);
      expect(s.progress, 1);
    });

    test('a fish still in view at a chunk end is stored named', () async {
      engine.videoFrames = _fish(5000, 25000);
      final s = scan();
      expect(await s.runChunk(), isTrue);
      final fish = (await identifications.forMedia('v1')).single;
      expect(fish.isPending, isFalse);
      expect(fish.top!.candidate, fixtureParrotfish);
      expect((fish.startMs, fish.endMs), (5000, 9750));
    });

    test('a fish seen under a second at a chunk end is not stored '
        'yet', () async {
      engine.videoFrames = _fish(9250, 25000);
      expect(await scan().runChunk(), isTrue);
      expect(await identifications.forMedia('v1'), isEmpty);
    });

    test('a fish is not named again without a better view', () async {
      engine.videoFrames = _fish(5000, 25000);
      await runAll(scan());
      expect(engine.embedCalls, hasLength(1));
      final fish = (await identifications.forMedia('v1')).single;
      expect((fish.startMs, fish.endMs), (5000, 24750));
      expect(fish.path, hasLength(80));
    });

    /// A fish that comes much closer in the second chunk: its box doubles,
    /// and its moments there look like another species.
    void closerInTheSecondChunk() {
      engine.videoFrames = {
        ..._fish(5000, 10000),
        ..._fish(10000, 15000, width: 0.4),
      };
      for (var ms = 10000; ms < 15000; ms += 250) {
        engine.momentEmbeddings[0.1 + ms / 1000000] = Float32List.fromList([
          0,
          1,
          0,
        ]);
      }
      nameBy = (e) => e[1] > 0.5 ? fixtureTang : fixtureParrotfish;
    }

    test('a fish is renamed on a clearly better view', () async {
      closerInTheSecondChunk();
      final s = scan();
      await s.runChunk();
      final first = (await identifications.forMedia('v1')).single;
      expect(first.top!.candidate, fixtureParrotfish);
      await runAll(s);
      expect(engine.embedCalls, hasLength(2));
      final renamed = (await identifications.forMedia('v1')).single;
      expect(renamed.id, first.id);
      expect(renamed.top!.candidate, fixtureTang);
      expect(renamed.box.width, closeTo(0.4, 1e-9));
    });

    test('a fish whose better view cannot be cropped keeps its name and '
        'its whole path', () async {
      closerInTheSecondChunk();
      engine.cropMissing = (m) => m.ms >= 10000;
      await runAll(scan());
      final fish = (await identifications.forMedia('v1')).single;
      expect(fish.top!.candidate, fixtureParrotfish);
      expect((fish.startMs, fish.endMs), (5000, 14750));
      expect(fish.path, hasLength(40));
    });

    test('a fish whose better views cannot be named keeps its name and '
        'its whole path', () async {
      closerInTheSecondChunk();
      unusableBy = (e) => e[1] > 0.5;
      await runAll(scan());
      final fish = (await identifications.forMedia('v1')).single;
      expect(fish.top!.candidate, fixtureParrotfish);
      expect((fish.startMs, fish.endMs), (5000, 14750));
      expect(fish.path, hasLength(40));
    });

    test('a new fish none of whose views can be named is not '
        'stored', () async {
      engine.videoFrames = _fish(1000, 4000);
      unusableBy = (_) => true;
      await runAll(scan());
      expect(await identifications.forMedia('v1'), isEmpty);
    });

    test('a renamed fish accepted by a name match goes back to '
        'undecided', () async {
      closerInTheSecondChunk();
      final s = scan();
      await s.runChunk();
      final first = (await identifications.forMedia('v1')).single;
      await identifications.updateDecisions([
        first.copyWith(
          decision: IdentificationDecision.accepted,
          decidedSpeciesId: 'sp_queen_parrotfish',
          decidedAt: fixtureT1,
        ),
      ]);
      await runAll(s);
      final renamed = (await identifications.forMedia('v1')).single;
      expect(renamed.top!.candidate, fixtureTang);
      expect(renamed.decision, IdentificationDecision.undecided);
      expect(renamed.decidedSpeciesId, isNull);
    });

    test('a renamed fish the diver named from the frame keeps it', () async {
      closerInTheSecondChunk();
      final s = scan();
      await s.runChunk();
      final first = (await identifications.forMedia('v1')).single;
      await identifications.claim(first.id, 'sp_queen_parrotfish');
      await runAll(s);
      final renamed = (await identifications.forMedia('v1')).single;
      expect(renamed.claimedSpeciesId, 'sp_queen_parrotfish');
    });

    test('a fish crossing where two stretches meet is one row', () async {
      engine.videoDurationMs = 60000;
      engine.videoFrames = _fish(15000, 35000);
      seekTo(30000);
      await runAll(scan());
      expect(engine.detectCalls.first, (30000, 40000));
      final found = await identifications.forMedia('v1');
      expect(found, hasLength(1));
      expect((found.single.startMs, found.single.endMs), (15000, 34750));
      expect(found.single.path.first.ms, 15000);
      expect(found.single.path.last.ms, 34750);
      expect((await identifications.runFor('v1'))!.detectionCount, 1);
    });

    test('a decision on the later part carries over the seam', () async {
      engine.videoDurationMs = 60000;
      engine.videoFrames = _fish(15000, 35000);
      seekTo(30000);
      final s = scan();
      await s.runChunk();
      final later = (await identifications.forMedia('v1')).single;
      await identifications.updateDecisions([
        later.copyWith(
          decision: IdentificationDecision.rejected,
          decidedAt: fixtureT1,
        ),
      ]);
      await runAll(s);
      final joined = (await identifications.forMedia('v1')).single;
      expect(joined.id, later.id);
      expect(joined.startMs, 15000);
      expect(joined.decision, IdentificationDecision.rejected);
    });

    test('parts the diver decided differently stay two rows', () async {
      engine.videoDurationMs = 60000;
      engine.videoFrames = _fish(15000, 35000);
      seekTo(30000);
      final s = scan();
      await s.runChunk();
      final later = (await identifications.forMedia('v1')).single;
      await identifications.updateDecisions([
        later.copyWith(
          decision: IdentificationDecision.rejected,
          decidedAt: fixtureT1,
        ),
      ]);
      // On to the fill from the start, which names the earlier part.
      await s.runChunk();
      await s.runChunk();
      await s.runChunk();
      await s.runChunk();
      final earlier = (await identifications.forMedia(
        'v1',
      )).singleWhere((i) => i.id != later.id);
      await identifications.claim(earlier.id, 'sp_queen_parrotfish');
      await runAll(s);
      expect(await identifications.forMedia('v1'), hasLength(2));
    });

    test(
      'a seek during pass 1 drops the chunk, storing nothing of it',
      () async {
        engine.videoDurationMs = 60000;
        engine.videoFrames = _fish(11000, 14000);
        engine.videoFailureAt = (start) {
          if (start == 10000) seekTo(50000);
          return null;
        };
        final s = scan();
        await s.runChunk();
        expect(await s.runChunk(), isTrue);
        expect(stretches((await identifications.runFor('v1'))!), [
          (startMs: 0, endMs: 10000),
        ]);
        expect(await identifications.forMedia('v1'), isEmpty);
        await s.runChunk();
        expect(engine.detectCalls, [
          (0, 10000),
          (10000, 20000),
          (50000, 60000),
        ]);
      },
    );

    test('a seek between pass 2 batches drops the chunk', () async {
      engine.videoDurationMs = 60000;
      engine.videoFrames = school(5, 11000, 14000);
      final s = scan();
      await s.runChunk();
      engine.onEmbedMoments = () => seekTo(50000);
      expect(await s.runChunk(), isTrue);
      engine.onEmbedMoments = null;
      expect(engine.embedCalls, hasLength(1));
      expect(await identifications.forMedia('v1'), isEmpty);
      await s.runChunk();
      expect(engine.detectCalls.last, (50000, 60000));
    });

    test('a seek inside the running chunk does not drop it', () async {
      engine.videoDurationMs = 60000;
      engine.videoFailureAt = (start) {
        if (start == 10000) seekTo(15000);
        return null;
      };
      final s = scan();
      await s.runChunk();
      await s.runChunk();
      await s.runChunk();
      expect(engine.detectCalls, [(0, 10000), (10000, 20000), (20000, 30000)]);
    });

    test('a pause on scanned video moves nothing', () async {
      engine.videoDurationMs = 60000;
      final s = scan();
      await s.runChunk();
      pauseAt(5000);
      await s.runChunk();
      expect(engine.detectCalls.last, (10000, 20000));
    });

    test('a pause on video not yet scanned moves the scan there', () async {
      engine.videoDurationMs = 60000;
      final s = scan(firstChunkMs: 2000);
      await s.runChunk();
      pauseAt(45000);
      await s.runChunk();
      expect(engine.detectCalls.last, (45000, 47000));
    });

    test('a report beyond the end of the video fills from the start and '
        'ends', () async {
      engine.videoDurationMs = 20000;
      seekTo(90000);
      await runAll(scan(firstChunkMs: 2000));
      expect(engine.detectCalls, [
        (90000, 92000),
        (0, 2000),
        (2000, 12000),
        (12000, 20000),
      ]);
      expect((await identifications.runFor('v1'))!.scanComplete, isTrue);
    });

    test('a v376 run resumes from its mark', () async {
      final v376 = MediaIdentificationRun(
        mediaId: 'v1',
        packVersion: '2026.11.1',
        detectorId: 'det-a',
        classifierId: 'clf-a',
        locationCell: 1462,
        analysedAt: DateTime.utc(2026, 11, 17),
        imageWidth: 1920,
        imageHeight: 1080,
        detectionCount: 0,
        scannedMs: 12000,
        videoDurationMs: 25000,
      );
      await runAll(scan(resumeFrom: v376));
      expect(engine.detectCalls, [(12000, 22000), (22000, 25000)]);
      final run = (await identifications.runFor('v1'))!;
      expect(stretches(run), [(startMs: 0, endMs: 25000)]);
      expect(run.scanComplete, isTrue);
    });

    test('a fish is never linked across video not yet scanned', () async {
      engine.videoDurationMs = 30000;
      // Seen at every sample of both the chunks from 10 s and from 10.4 s.
      engine.videoFrames = {..._fish(5000, 10400), ..._fish(10400, 15000)};
      final s = scan();
      await s.runChunk();
      // Just past the stretch's end: the 400 ms between are not scanned.
      seekTo(10400);
      await runAll(s);
      expect(engine.detectCalls.last, (10000, 10400));
      final found = await identifications.forMedia('v1');
      expect(found, hasLength(1));
      expect((found.single.startMs, found.single.endMs), (5000, 14900));
      expect(
        found.single.path.map((p) => p.ms),
        containsAll([9750, 10000, 10250, 10400]),
      );
    });

    /// A fish seen closer before 30 s than after, scanned from 30 s first
    /// and then from the start: after three chunks, a dismissed earlier
    /// part (from 15 s) and a later part (from 30 s) about to be joined.
    Future<
      ({
        VideoIdentificationScan scan,
        MediaIdentification earlier,
        MediaIdentification later,
      })
    >
    dismissedBeforeASeam() async {
      engine.videoDurationMs = 40000;
      engine.videoFrames = {
        ..._fish(15000, 30000, width: 0.4),
        ..._fish(30000, 35000),
      };
      seekTo(30000);
      final s = scan();
      await s.runChunk();
      await s.runChunk();
      await s.runChunk();
      final rows = await identifications.forMedia('v1');
      expect(rows, hasLength(2));
      final earlier = rows.singleWhere((i) => i.startMs == 15000);
      await identifications.updateDecisions([
        earlier.copyWith(
          decision: IdentificationDecision.rejected,
          decidedAt: fixtureT1,
        ),
      ]);
      return (
        scan: s,
        earlier: earlier,
        later: rows.singleWhere((i) => i.startMs == 30000),
      );
    }

    test('a join across a seam whose better view gives no crop keeps the '
        'later name and what was said on the earlier part', () async {
      final (:scan, :earlier, :later) = await dismissedBeforeASeam();
      // The better view the join would be named from gives no crop.
      engine.cropMissing = (m) => m.box.width > 0.3;
      await runAll(scan);
      final found = (await identifications.forMedia('v1')).single;
      expect(found.id, later.id);
      expect(found.top!.candidate, later.top!.candidate);
      expect(found.decision, IdentificationDecision.rejected);
      expect((found.startMs, found.endMs), (15000, 34750));
    });

    test('a join is undone when the diver says something different on the '
        'later part while the chunk is named', () async {
      final (:scan, :earlier, :later) = await dismissedBeforeASeam();
      identifications.afterRead = () {
        identifications.afterRead = null;
        // The diver accepts the later part just as the seam reads it.
        unawaited(
          identifications.updateDecisions([
            later.copyWith(
              decision: IdentificationDecision.accepted,
              decidedSpeciesId: 'sp_queen_parrotfish',
              decidedAt: fixtureT1,
            ),
          ]),
        );
      };
      await runAll(scan);
      final found = await identifications.forMedia('v1');
      expect(found, hasLength(2));
      final first = found.singleWhere((i) => i.id == earlier.id);
      expect(first.decision, IdentificationDecision.rejected);
      // The earlier part keeps the path it swam up to the seam.
      expect((first.startMs, first.endMs), (15000, 29750));
      final second = found.singleWhere((i) => i.id == later.id);
      expect(second.decision, IdentificationDecision.accepted);
      expect((second.startMs, second.endMs), (30000, 34750));
    });

    test('an earlier part is kept when the later part it joins was cleared '
        'meanwhile', () async {
      final (:scan, :earlier, :later) = await dismissedBeforeASeam();
      identifications.afterRead = () {
        identifications.afterRead = null;
        // The later part goes just as the seam reads it.
        unawaited(
          (library.delete(
            library.mediaIdentifications,
          )..where((r) => r.id.equals(later.id))).go(),
        );
      };
      await runAll(scan);
      final found = (await identifications.forMedia('v1')).single;
      expect(found.id, earlier.id);
      expect(found.decision, IdentificationDecision.rejected);
    });

    test('a decision written while a chunk is stored is not '
        'overwritten', () async {
      engine.videoFrames = _fish(5000, 25000);
      final s = scan();
      await s.runChunk();
      final fish = (await identifications.forMedia('v1')).single;
      identifications.afterRead = () {
        identifications.afterRead = null;
        // The diver dismisses the fish just as the scan reads its row.
        Zone.root.run(
          () => unawaited(
            identifications.updateDecisions([
              fish.copyWith(
                decision: IdentificationDecision.rejected,
                decidedAt: fixtureT1,
              ),
            ]),
          ),
        );
      };
      await runAll(s);
      await identifications.updateDecisions(const []);
      expect(
        (await identifications.forMedia('v1')).single.decision,
        IdentificationDecision.rejected,
      );
    });

    test('a fish in view when the scan stopped carries on across '
        'openings with stretches', () async {
      engine.videoDurationMs = 60000;
      engine.videoFrames = _fish(42000, 48000);
      seekTo(40000);
      final first = scan(firstChunkMs: 5000);
      await first.runChunk();
      await first.finish();
      final cut = (await identifications.forMedia('v1')).single;
      expect(cut.endMs, 44750);
      report = null;
      final second = scan(
        resumeFrom: await identifications.runFor('v1'),
        firstChunkMs: 5000,
      );
      seekTo(41000);
      await second.runChunk();
      expect(engine.detectCalls.last, (45000, 50000));
      final found = (await identifications.forMedia('v1')).single;
      expect(found.id, cut.id);
      expect(found.endMs, 47750);
    });
  });

  group('memory readout', () {
    List<String> passes() => [
      for (final e in engine.events)
        if (e.startsWith('detectVideo') || e == 'embedMoments' || e == 'memory')
          e,
    ];

    test('each chunk logs a reading after pass 1 and after pass 2', () async {
      engine.videoDurationMs = 20000;
      engine.videoFrames = {..._fish(1000, 4000), ..._fish(11000, 14000)};
      await runAll(
        scan(
          memoryReadout: MemoryReadout(engine: engine, enabled: () => true),
        ),
      );
      expect(passes(), [
        'detectVideo:0',
        'memory',
        'embedMoments',
        'memory',
        'detectVideo:10000',
        'memory',
        'embedMoments',
        'memory',
      ]);
    });

    test('each reading names its pass and the chunk it covers', () async {
      engine.videoDurationMs = 65000;
      engine.videoFrames = _fish(61000, 64000);
      final stages = <String>[];
      final sub = LoggerService.logStream.listen((e) {
        if (e.message.startsWith('Memory after ')) {
          stages.add(e.message.substring(0, e.message.indexOf('): ') + 1));
        }
      });
      addTearDown(sub.cancel);
      await runAll(
        scan(
          memoryReadout: MemoryReadout(engine: engine, enabled: () => true),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(stages, [
        'Memory after pass 1 (0:00 to 0:10)',
        'Memory after pass 1 (0:10 to 0:20)',
        'Memory after pass 1 (0:20 to 0:30)',
        'Memory after pass 1 (0:30 to 0:40)',
        'Memory after pass 1 (0:40 to 0:50)',
        'Memory after pass 1 (0:50 to 1:00)',
        'Memory after pass 1 (1:00 to 1:05)',
        'Memory after pass 2 (1:00 to 1:05)',
      ]);
    });

    test('a failing memory reading leaves the video scanned', () async {
      engine.memoryFailure = const VisionEngineException('unsupported');
      engine.videoFrames = _fish(1000, 4000);
      await runAll(
        scan(
          memoryReadout: MemoryReadout(engine: engine, enabled: () => true),
        ),
      );
      expect((await identifications.runFor('v1'))!.scanComplete, isTrue);
      expect(await identifications.forMedia('v1'), hasLength(1));
    });

    test('a chunk with nothing to embed logs no pass 2 reading', () async {
      engine.videoDurationMs = 10000;
      await runAll(
        scan(
          memoryReadout: MemoryReadout(engine: engine, enabled: () => true),
        ),
      );
      expect(passes(), ['detectVideo:0', 'memory']);
    });
  });

  group('naming from single views', () {
    /// A fish in view from 0 to 2.75 s: its best moments are at 0, 1 and
    /// 2 s. The views at [tangAt] look like a tang, and more decided.
    void fishWithViews({required List<int> tangAt}) {
      engine.videoFrames = _fish(0, 3000);
      for (final ms in tangAt) {
        engine.momentEmbeddings[0.1 + ms / 1000000] = Float32List.fromList([
          0,
          1,
          0,
        ]);
      }
      nameBy = (e) => e[1] > 0.5 ? fixtureTang : fixtureParrotfish;
      openBy = (e) => e[1] > 0.5 ? 0.95 : 0.5;
    }

    test('a track is named from its most decided view, and shows that '
        'view', () async {
      fishWithViews(tangAt: [1000, 2000]);
      await runAll(scan());
      expect(engine.embedCalls.single.map((m) => m.ms), [0, 1000, 2000]);
      final fish = (await identifications.forMedia('v1')).single;
      expect(fish.top!.candidate, fixtureTang);
      expect(fish.openScore, closeTo(0.95, 1e-9));
      expect(fish.bestMs, 1000);
      expect(fish.box.x, closeTo(0.1 + 1000 / 1000000, 1e-9));
      expect(fish.suggestable, isTrue);
      final stored = await embeddings.get([
        fish.id,
      ], classifierId: fixturePack().pack.manifest.classifier.embeddingId);
      expect(stored[fish.id], Float32List.fromList([0, 1, 0]));
    });

    test('a view no other view agrees with is not suggested', () async {
      fishWithViews(tangAt: [1000]);
      await runAll(scan());
      final fish = (await identifications.forMedia('v1')).single;
      expect(fish.top!.candidate, fixtureTang);
      expect(fish.suggestable, isFalse);
    });
  });
}
