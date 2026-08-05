import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dashboard/presentation/providers/photo_providers.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = await setUpTestDatabase();
    container = ProviderContainer();
    addTearDown(container.dispose);
  });
  tearDown(tearDownTestDatabase);

  test('recentPhotosProvider returns newest dive-attached photos', () async {
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
        filePath: '/tmp/dive.jpg',
        diveId: 'd1',
        takenAt: DateTime(2026, 3, 1),
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 1),
      ),
    );

    final photos = await container.read(recentPhotosProvider.future);
    expect(photos, hasLength(1));
    expect(photos.single.diveId, 'd1');
  });

  test('recentPhotosProvider is empty when there are no photos', () async {
    final photos = await container.read(recentPhotosProvider.future);
    expect(photos, isEmpty);
  });
}
