import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dashboard/presentation/providers/media_ribbon_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = await setUpTestDatabase();
    container = ProviderContainer(
      overrides: [
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
      ],
    );
    addTearDown(container.dispose);
  });
  tearDown(tearDownTestDatabase);

  test('recentMediaProvider returns newest dive-attached photos', () async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: const Value('d1'),
            diveDateTime: Value(DateTime(2026, 1, 1).millisecondsSinceEpoch),
            createdAt: Value(DateTime(2026, 1, 1).millisecondsSinceEpoch),
            updatedAt: Value(DateTime(2026, 1, 1).millisecondsSinceEpoch),
          ),
        );
    final repo = MediaRepository();
    await repo.createMedia(
      MediaItem(
        id: '',
        mediaType: MediaType.photo,
        sourceType: MediaSourceType.platformGallery,
        filePath: 'dive.jpg',
        diveId: 'd1',
        takenAt: DateTime(2026, 3, 1),
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 1),
      ),
    );

    final photos = await container.read(recentMediaProvider.future);
    expect(photos, hasLength(1));
    expect(photos.single.diveId, 'd1');
  });

  // A secondary diver with no dives used to see the primary diver's newest
  // photos, because the ribbon query had no diver scope at all.
  test('recentMediaProvider shows only the active diver\'s media', () async {
    final epoch = DateTime(2026, 1, 1).millisecondsSinceEpoch;
    for (final diver in ['primary', 'secondary']) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion(
              id: Value(diver),
              name: Value(diver),
              createdAt: Value(epoch),
              updatedAt: Value(epoch),
            ),
          );
    }
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: const Value('primary-dive'),
            diverId: const Value('primary'),
            diveDateTime: Value(epoch),
            createdAt: Value(epoch),
            updatedAt: Value(epoch),
          ),
        );
    await MediaRepository().createMedia(
      MediaItem(
        id: '',
        mediaType: MediaType.photo,
        sourceType: MediaSourceType.platformGallery,
        filePath: 'primary.jpg',
        diveId: 'primary-dive',
        takenAt: DateTime(2026, 3, 1),
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 1),
      ),
    );

    final notifier = container.read(currentDiverIdProvider.notifier);
    await notifier.setCurrentDiver('secondary');
    expect(await container.read(recentMediaProvider.future), isEmpty);

    // Switching back rebuilds the ribbon for the newly active diver.
    await notifier.setCurrentDiver('primary');
    final photos = await container.read(recentMediaProvider.future);
    expect(photos.map((m) => m.diveId), ['primary-dive']);
  });

  test('recentMediaProvider is empty when there are no photos', () async {
    final photos = await container.read(recentMediaProvider.future);
    expect(photos, isEmpty);
  });
}
