// Covers the MediaSourceType.manifestEntry / signature branches of the
// `_effectiveOriginDeviceId` switch — the existing repository test only
// hits the gallery / network / localFile / serviceConnector branches.

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late MediaRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = MediaRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test(
    'createMedia leaves originDeviceId null for manifestEntry source',
    () async {
      final item = MediaItem(
        id: '',
        mediaType: MediaType.photo,
        sourceType: MediaSourceType.manifestEntry,
        subscriptionId: 'sub-1',
        entryKey: 'entry-1',
        url: 'https://example.com/photo.jpg',
        takenAt: DateTime.utc(2024, 1, 1),
        createdAt: DateTime.utc(2024, 1, 1),
        updatedAt: DateTime.utc(2024, 1, 1),
      );
      final created = await repository.createMedia(item);
      expect(created.originDeviceId, isNull);
    },
  );

  test('createMedia leaves originDeviceId null for signature source', () async {
    final item = MediaItem(
      id: '',
      mediaType: MediaType.instructorSignature,
      sourceType: MediaSourceType.signature,
      signerName: 'Test Signer',
      takenAt: DateTime.utc(2024, 1, 1),
      createdAt: DateTime.utc(2024, 1, 1),
      updatedAt: DateTime.utc(2024, 1, 1),
    );
    final created = await repository.createMedia(item);
    expect(created.originDeviceId, isNull);
  });
}
