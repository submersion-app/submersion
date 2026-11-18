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
import 'package:submersion/features/species_id/domain/entities/video_detections.dart';
import 'package:submersion/features/species_id/domain/services/species_namer.dart';
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
Map<int, List<DetectedBox>> _fish(int fromMs, int toMs, {double y = 0.4}) => {
  for (var ms = fromMs; ms < toMs; ms += 250)
    ms: [
      DetectedBox(
        box: IdentificationBox(
          x: 0.1 + ms / 1000000,
          y: y,
          width: 0.2,
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
  });
  tearDown(() async {
    await crops.dispose();
    await library.close();
    await local.close();
    await deleteTempDir(support);
  });

  /// Names every crop the first candidate, confidently.
  Future<List<NamingResult>> name(
    List<({Float32List embedding, int shorterSide})> crops,
  ) async => [
    for (final _ in crops)
      const NamingResult(
        openScore: 0.9,
        candidates: [NamedCandidate(candidate: fixtureParrotfish, score: 0.9)],
        locationLimited: true,
        suggestable: true,
      ),
  ];

  VideoIdentificationScan scan({
    MediaIdentificationRun? resumeFrom,
    List<MediaIdentification> carry = const [],
    List<MediaIdentification> stored = const [],
    MemoryReadout? memoryReadout,
  }) => VideoIdentificationScan(
    memoryReadout: memoryReadout,
    stored: stored,
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
    expect(engine.detectCalls, [(0, 10000), (10000, 20000), (20000, 30000)]);
    final run = (await identifications.runFor('v1'))!;
    expect(run.scannedMs, 25000);
    expect(run.videoDurationMs, 25000);
    expect(run.scanComplete, isTrue);
    expect(run.imageWidth, 1920);
    expect(run.detectorId, 'det-a');
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
    engine.videoFrames = _fish(1000, 15000);
    final s = scan();
    expect(await s.runChunk(), isTrue);
    expect(await identifications.forMedia('v1'), isEmpty);
    await s.finish();
    final fish = (await identifications.forMedia('v1')).single;
    expect(fish.endMs, 9750);
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

    await runAll(
      scan(
        resumeFrom: await identifications.runFor('v1'),
        stored: await identifications.forMedia('v1'),
      ),
    );
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
      final resumed = scan(
        resumeFrom: await identifications.runFor('v1'),
        stored: await identifications.forMedia('v1'),
      );
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
    final resumed = scan(
      resumeFrom: await identifications.runFor('v1'),
      stored: await identifications.forMedia('v1'),
    );
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
    await runAll(
      scan(
        resumeFrom: await identifications.runFor('v1'),
        stored: await identifications.forMedia('v1'),
      ),
    );
    expect(await identifications.forMedia('v1'), hasLength(2));
  });

  test('a resumed scan starts where the run stopped', () async {
    await runAll(scan());
    engine.detectCalls.clear();
    final resumed = scan(
      resumeFrom: (await identifications.runFor(
        'v1',
      ))!.copyWith(scannedMs: () => 10000),
    );
    await runAll(resumed);
    expect(engine.detectCalls.first, (10000, 20000));
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
    engine.videoFrames = school(6, 1000, 15000);
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
    engine.videoFrames = school(6, 1000, 15000);
    final first = scan();
    expect(await first.runChunk(), isTrue);
    await first.finish();
    final ids = {for (final i in await identifications.forMedia('v1')) i.id};
    await runAll(
      scan(
        resumeFrom: await identifications.runFor('v1'),
        stored: await identifications.forMedia('v1'),
      ),
    );
    final found = await identifications.forMedia('v1');
    expect(found.map((i) => i.id).toSet(), ids);
    expect(found.where((i) => i.isPending), isEmpty);
    expect(found.every((i) => i.endMs == 14750), isTrue);
  });

  test(
    'a fish kept to name later that left at the stop is still named',
    () async {
      engine.videoFrames = school(6, 1000, 10000);
      final first = scan();
      expect(await first.runChunk(), isTrue);
      await first.finish();
      await runAll(
        scan(
          resumeFrom: await identifications.runFor('v1'),
          stored: await identifications.forMedia('v1'),
        ),
      );
      final found = await identifications.forMedia('v1');
      expect(found, hasLength(6));
      expect(found.where((i) => i.isPending), isEmpty);
    },
  );

  test('at a second stop the fish still unnamed are named first, and a '
      'named fish left over keeps its name and grows its path', () async {
    // Two fish arrive later, so they are the shorter tracks at both stops.
    engine.videoFrames = {
      for (final e in school(6, 1000, 20000).entries)
        e.key: [
          for (var k = 0; k < 6; k++)
            if (k < 4 || e.key >= 5000) e.value[k],
        ],
    };
    final first = scan();
    expect(await first.runChunk(), isTrue);
    await first.finish();
    final before = {
      for (final i in await identifications.forMedia('v1')) i.id: i,
    };
    expect(before.values.where((i) => i.isPending), hasLength(2));
    final second = scan(
      resumeFrom: await identifications.runFor('v1'),
      stored: before.values.toList(),
    );
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

  /// A fish crossing the 10 s boundary (8 s to 12 s, low in the frame),
  /// then five more from 10 s to 14 s: chunk 2 closes six tracks, so its
  /// pass 2 takes two batches.
  void crossingFishThenSchool() {
    engine.videoFrames = {
      for (var ms = 8000; ms < 14000; ms += 250)
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
    expect((kept.startMs, kept.endMs), (8000, 9750));
    expect((await identifications.runFor('v1'))!.scannedMs, 10000);

    keepGoing = () => true;
    await runAll(
      scan(
        resumeFrom: await identifications.runFor('v1'),
        stored: await identifications.forMedia('v1'),
      ),
    );
    final found = await identifications.forMedia('v1');
    expect(found, hasLength(6));
    expect(found.where((i) => i.isPending), isEmpty);
    final fish = found.singleWhere((i) => i.id == kept.id);
    expect((fish.startMs, fish.endMs), (8000, 11750));
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
    expect((kept.startMs, kept.endMs), (8000, 9750));
  });

  test(
    'a logbook opened while a chunk reads its rows gets nothing of it',
    () async {
      crossingFishThenSchool();
      final first = scan();
      expect(await first.runChunk(), isTrue);
      await first.finish(naming: false);
      final resumed = scan(
        resumeFrom: await identifications.runFor('v1'),
        stored: await identifications.forMedia('v1'),
      );
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
}
