import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart'
    hide MediaEnrichment;
import 'package:submersion/features/media/domain/entities/media_item.dart'
    as domain
    show MediaEnrichment;
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';

import '../../../../helpers/test_database.dart';

/// The link the "newly linked media shows nothing" bug actually broke.
///
/// The viewer reads the item on screen through [mediaByIdProvider], and the
/// enrichment backfill writes the depth/elapsed row a moment later, from a
/// post-frame callback. Nothing re-reads the provider explicitly, so the
/// overlays appear only if the provider notices the write by itself. It did
/// not: its tick watched `media` while its query left-joins `media_enrichment`,
/// so the row landed and the UI kept rendering the pre-backfill answer until
/// the viewer was closed and reopened.
void main() {
  late AppDatabase db;
  late MediaRepository repo;

  final epoch = DateTime.utc(2026, 6, 1).millisecondsSinceEpoch;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = MediaRepository();
  });
  tearDown(tearDownTestDatabase);

  test('mediaByIdProvider picks up an enrichment written after the first '
      'read, with no manual invalidate', () async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'd1',
            diveDateTime: epoch,
            createdAt: epoch,
            updatedAt: epoch,
          ),
        );
    final media = await repo.createMedia(
      MediaItem(
        id: 'm1',
        diveId: 'd1',
        mediaType: MediaType.photo,
        sourceType: MediaSourceType.localFile,
        filePath: '/photos/m1.jpg',
        localPath: '/photos/m1.jpg',
        takenAt: DateTime.utc(2026, 6, 1, 12),
        createdAt: DateTime.utc(2026, 6, 1),
        updatedAt: DateTime.utc(2026, 6, 1),
      ),
    );

    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Keep the provider alive the way the open viewer does; without a listener
    // it would simply recompute on the next read and prove nothing.
    final sub = container.listen(
      mediaByIdProvider(media.id),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(sub.close);

    expect(
      (await container.read(mediaByIdProvider(media.id).future))?.enrichment,
      isNull,
      reason: 'no enrichment exists yet, exactly as after a fresh link',
    );

    await repo.saveEnrichment(
      domain.MediaEnrichment(
        id: 'e1',
        mediaId: media.id,
        diveId: 'd1',
        elapsedSeconds: 2520,
        depthMeters: 20,
        matchConfidence: MatchConfidence.exact,
        createdAt: DateTime.utc(2026, 6, 1),
      ),
    );

    // The tick is debounced, so poll rather than assume a single turn is
    // enough. Same shape as the repository tick-stream guards.
    domain.MediaEnrichment? seen;
    for (var i = 0; i < 150 && seen == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      seen = (await container.read(
        mediaByIdProvider(media.id).future,
      ))?.enrichment;
    }

    expect(
      seen,
      isNotNull,
      reason:
          'the enrichment write must invalidate mediaByIdProvider on its own; '
          'the viewer has no other way to learn the backfill finished',
    );
    expect(seen!.depthMeters, 20.0);
    expect(seen.elapsedSeconds, 2520);
  });
}
