import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart'
    as domain;
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

import '../../../helpers/test_database.dart';

void main() {
  late MediaRepository repository;
  late DiveRepository diveRepository;

  setUp(() async {
    await setUpTestDatabase();
    repository = MediaRepository();
    diveRepository = DiveRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<Dive> createDive() =>
      diveRepository.createDive(Dive(id: '', dateTime: DateTime.utc(2026, 7)));

  domain.PendingPhotoSuggestion connectorSuggestion({
    required String diveId,
    String assetId = 'lr-asset-1',
  }) => domain.PendingPhotoSuggestion(
    id: '',
    diveId: diveId,
    platformAssetId: assetId,
    takenAt: DateTime.utc(2026, 7, 1, 10),
    createdAt: DateTime.utc(2026, 7, 2),
    connectorAccountId: 'acct1',
    remoteAssetId: assetId,
  );

  test('createPendingSuggestion round-trips connector fields', () async {
    final dive = await createDive();
    final created = await repository.createPendingSuggestion(
      connectorSuggestion(diveId: dive.id),
    );
    expect(created.id, isNotEmpty);

    final loaded = await repository.getPendingSuggestionsForDive(dive.id);
    expect(loaded, hasLength(1));
    expect(loaded.single.remoteAssetId, 'lr-asset-1');
    expect(loaded.single.connectorAccountId, 'acct1');
    expect(loaded.single.platformAssetId, 'lr-asset-1');
    expect(loaded.single.takenAt, DateTime.utc(2026, 7, 1, 10));
  });

  test('dismiss hides a suggestion from the list and the dedup set', () async {
    final dive = await createDive();
    final created = await repository.createPendingSuggestion(
      connectorSuggestion(diveId: dive.id),
    );
    expect(await repository.getPendingSuggestionRemoteAssetIds(), {
      'lr-asset-1',
    });

    await repository.dismissPendingSuggestion(created.id);
    expect(await repository.getPendingSuggestionsForDive(dive.id), isEmpty);
    expect(await repository.getPendingSuggestionRemoteAssetIds(), isEmpty);
  });

  test('deleteSuggestionsForRemoteAsset removes all candidate rows', () async {
    final diveA = await createDive();
    final diveB = await createDive();
    await repository.createPendingSuggestion(
      connectorSuggestion(diveId: diveA.id),
    );
    await repository.createPendingSuggestion(
      connectorSuggestion(diveId: diveB.id),
    );

    await repository.deleteSuggestionsForRemoteAsset('lr-asset-1');
    expect(await repository.getPendingSuggestionsForDive(diveA.id), isEmpty);
    expect(await repository.getPendingSuggestionsForDive(diveB.id), isEmpty);
  });

  test(
    'getConnectorRemoteAssetIds returns only serviceConnector media rows',
    () async {
      final dive = await createDive();
      final now = DateTime.utc(2026, 7, 1);
      await repository.createMedia(
        domain.MediaItem(
          id: '',
          diveId: dive.id,
          mediaType: domain.MediaType.photo,
          takenAt: now,
          createdAt: now,
          updatedAt: now,
          sourceType: MediaSourceType.serviceConnector,
          connectorAccountId: 'acct1',
          remoteAssetId: 'lr-linked-1',
        ),
      );
      await repository.createMedia(
        domain.MediaItem(
          id: '',
          diveId: dive.id,
          mediaType: domain.MediaType.photo,
          takenAt: now,
          createdAt: now,
          updatedAt: now,
          sourceType: MediaSourceType.platformGallery,
          platformAssetId: 'gallery-1',
        ),
      );

      expect(await repository.getConnectorRemoteAssetIds(), {'lr-linked-1'});
    },
  );
}
