import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/maintenance/maintenance_ledger_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/media_enrichment_backfill_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

import '../../../../helpers/test_database.dart';

/// A MediaRepository whose saveEnrichment always throws, to exercise the
/// terminal-failure path: the item must still be ledger-marked so it converges.
class _ThrowingSaveMediaRepository extends MediaRepository {
  @override
  Future<void> saveEnrichment(MediaEnrichment enrichment) async {
    throw StateError('simulated save failure');
  }
}

void main() {
  late MediaRepository mediaRepo;
  late DiveRepository diveRepo;
  late MaintenanceLedgerRepository ledger;
  late MediaEnrichmentBackfillService service;

  setUp(() async {
    await setUpTestDatabase();
    mediaRepo = MediaRepository();
    diveRepo = DiveRepository();
    ledger = MaintenanceLedgerRepository(DatabaseService.instance.database);
    service = MediaEnrichmentBackfillService(
      mediaRepository: mediaRepo,
      diveRepository: diveRepo,
      ledger: ledger,
    );
  });
  tearDown(tearDownTestDatabase);

  // Dive starting at a fixed wall-clock time with a two-point profile:
  // t=0s depth 0m/24C, t=120s depth 20m/18C.
  final diveStart = DateTime.utc(2025, 6, 1, 10, 0, 0);
  DateTime photoAt(int secondsIn) =>
      DateTime(2025, 6, 1, 10, 0, 0).add(Duration(seconds: secondsIn));

  Future<Dive> createProfiledDive({String id = 'dive-1'}) =>
      diveRepo.createDive(
        Dive(
          id: id,
          diveNumber: 1,
          dateTime: diveStart,
          entryTime: diveStart,
          profile: const [
            DiveProfilePoint(timestamp: 0, depth: 0, temperature: 24),
            DiveProfilePoint(timestamp: 120, depth: 20, temperature: 18),
          ],
        ),
      );

  Future<MediaItem> linkPhoto({
    required String id,
    required String diveId,
    required DateTime takenAt,
    MediaType mediaType = MediaType.photo,
  }) {
    final now = DateTime.now();
    return mediaRepo.createMedia(
      MediaItem(
        id: id,
        diveId: diveId,
        filePath: '/photos/$id.jpg',
        mediaType: mediaType,
        takenAt: takenAt,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<MediaEnrichment?> enrichmentFor(String diveId, String mediaId) async {
    final all = await mediaRepo.getMediaForDive(diveId);
    return all.firstWhere((m) => m.id == mediaId).enrichment;
  }

  test('backfills enrichment for a linked photo that has none', () async {
    await createProfiledDive();
    // Photo taken 60s into the dive -> interpolated depth ~10m.
    await linkPhoto(id: 'photo-1', diveId: 'dive-1', takenAt: photoAt(60));

    expect(await service.backfill(), 1);

    final enrichment = await enrichmentFor('dive-1', 'photo-1');
    expect(enrichment, isNotNull);
    expect(enrichment!.elapsedSeconds, 60);
    expect(enrichment.depthMeters, closeTo(10.0, 1e-6));
    expect(enrichment.matchConfidence, isNot(MatchConfidence.noProfile));
  });

  test(
    'run() (StartupMaintenanceTask entry point) performs the backfill',
    () async {
      await createProfiledDive();
      await linkPhoto(id: 'photo-1', diveId: 'dive-1', takenAt: photoAt(60));
      await service.run();
      expect(await enrichmentFor('dive-1', 'photo-1'), isNotNull);
    },
  );

  test('pendingWork reflects the backlog and reaches 0 after run', () async {
    await createProfiledDive();
    await linkPhoto(id: 'photo-1', diveId: 'dive-1', takenAt: photoAt(60));
    await linkPhoto(id: 'photo-2', diveId: 'dive-1', takenAt: photoAt(90));

    expect(await service.pendingWork(), 2);
    await service.run();
    expect(await service.pendingWork(), 0);
  });

  test('run ticks progress up to the total', () async {
    await createProfiledDive();
    await linkPhoto(id: 'photo-1', diveId: 'dive-1', takenAt: photoAt(60));
    await linkPhoto(id: 'photo-2', diveId: 'dive-1', takenAt: photoAt(90));

    final ticks = <int>[];
    await service.run(onProgress: ticks.add);
    expect(ticks.last, 2);
    expect(ticks, [1, 2]);
  });

  test('is idempotent: a second run enriches nothing', () async {
    await createProfiledDive();
    await linkPhoto(id: 'photo-1', diveId: 'dive-1', takenAt: photoAt(60));
    expect(await service.backfill(), 1);
    expect(await service.backfill(), 0);
    expect(await service.pendingWork(), 0);
  });

  test('leaves an already-enriched photo untouched', () async {
    await createProfiledDive();
    await linkPhoto(id: 'photo-1', diveId: 'dive-1', takenAt: photoAt(60));
    await mediaRepo.saveEnrichment(
      MediaEnrichment(
        id: '',
        mediaId: 'photo-1',
        diveId: 'dive-1',
        depthMeters: 99.0,
        elapsedSeconds: 999,
        matchConfidence: MatchConfidence.exact,
        createdAt: DateTime.now(),
      ),
    );
    expect(await service.backfill(), 0);
    final enrichment = await enrichmentFor('dive-1', 'photo-1');
    expect(enrichment!.depthMeters, 99.0);
    expect(enrichment.elapsedSeconds, 999);
  });

  test('skips media on a dive that has no profile', () async {
    await diveRepo.createDive(
      Dive(id: 'dive-noprofile', diveNumber: 2, dateTime: diveStart),
    );
    await linkPhoto(
      id: 'photo-np',
      diveId: 'dive-noprofile',
      takenAt: photoAt(30),
    );
    expect(await service.backfill(), 0);
    expect(await enrichmentFor('dive-noprofile', 'photo-np'), isNull);
  });

  test('backfills videos too', () async {
    await createProfiledDive();
    await linkPhoto(
      id: 'clip-1',
      diveId: 'dive-1',
      takenAt: photoAt(90),
      mediaType: MediaType.video,
    );
    expect(await service.backfill(), 1);
    expect(await enrichmentFor('dive-1', 'clip-1'), isNotNull);
  });

  test('ignores instructor signatures and does not re-scan them', () async {
    await createProfiledDive();
    await linkPhoto(
      id: 'sig-1',
      diveId: 'dive-1',
      takenAt: photoAt(45),
      mediaType: MediaType.instructorSignature,
    );
    expect(await service.backfill(), 0);
    expect(await service.pendingWork(), 0);
    expect(await enrichmentFor('dive-1', 'sig-1'), isNull);
  });

  test(
    'an item whose save fails is still ledger-marked and does not re-qualify',
    () async {
      await createProfiledDive();
      await linkPhoto(id: 'photo-1', diveId: 'dive-1', takenAt: photoAt(60));

      final throwingService = MediaEnrichmentBackfillService(
        mediaRepository: _ThrowingSaveMediaRepository(),
        diveRepository: diveRepo,
        ledger: ledger,
      );

      // The save throws, is caught, and the item is marked processed so the
      // backlog converges instead of re-scanning every launch (issue #524).
      await throwingService.run();

      expect(await throwingService.pendingWork(), 0);
      expect(await enrichmentFor('dive-1', 'photo-1'), isNull);
      expect(
        await ledger.countProcessed(MediaRepository.enrichmentBackfillTaskName),
        1,
      );
    },
  );
}
