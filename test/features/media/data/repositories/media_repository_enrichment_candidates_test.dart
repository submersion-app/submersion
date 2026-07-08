import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/maintenance/maintenance_ledger_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late MediaRepository media;
  late DiveRepository dives;
  late MaintenanceLedgerRepository ledger;

  setUp(() async {
    await setUpTestDatabase();
    media = MediaRepository();
    dives = DiveRepository();
    ledger = MaintenanceLedgerRepository(DatabaseService.instance.database);
  });
  tearDown(tearDownTestDatabase);

  final diveStart = DateTime.utc(2025, 6, 1, 10, 0, 0);

  Future<void> profiledDive(String id) => dives.createDive(
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

  Future<void> photo(String id, String diveId) {
    final now = DateTime.now();
    return media.createMedia(
      MediaItem(
        id: id,
        diveId: diveId,
        filePath: '/p/$id.jpg',
        mediaType: MediaType.photo,
        takenAt: DateTime(2025, 6, 1, 10, 1, 0),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  test('counts unenriched candidate media on profiled dives', () async {
    await profiledDive('d1');
    await photo('m1', 'd1');
    await photo('m2', 'd1');
    expect(await media.countEnrichmentBackfillCandidates(), 2);

    final divesList = await media.divesNeedingEnrichmentBackfill();
    expect(divesList.map((d) => d.diveId), ['d1']);
    expect(divesList.single.diveStartMs, diveStart.millisecondsSinceEpoch);

    final perDive = await media.candidateEnrichmentMediaForDive('d1');
    expect(perDive.map((m) => m.id).toSet(), {'m1', 'm2'});
  });

  test('ledgered media are excluded from candidates', () async {
    await profiledDive('d1');
    await photo('m1', 'd1');
    await photo('m2', 'd1');
    await ledger.markProcessed('photo-enrichment-backfill', ['m1']);

    expect(await media.countEnrichmentBackfillCandidates(), 1);
    expect(
      (await media.candidateEnrichmentMediaForDive('d1')).map((m) => m.id),
      ['m2'],
    );
  });

  test('a dive with no profile is not a candidate', () async {
    await dives.createDive(
      Dive(id: 'noprof', diveNumber: 2, dateTime: diveStart),
    );
    await photo('m1', 'noprof');
    expect(await media.countEnrichmentBackfillCandidates(), 0);
    expect(await media.divesNeedingEnrichmentBackfill(), isEmpty);
  });
}
