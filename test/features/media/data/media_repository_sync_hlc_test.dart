import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

import '../../../helpers/test_database.dart';

void main() {
  setUp(() async => setUpTestDatabase());
  tearDown(() => tearDownTestDatabase());

  test(
    'getSyncHlc reads the row\'s clock and null for an unknown id',
    () async {
      final repo = MediaRepository();
      final created = await repo.createMedia(
        MediaItem(
          id: '',
          mediaType: MediaType.photo,
          sourceType: MediaSourceType.localFile,
          localPath: '/nowhere/reef.jpg',
          takenAt: DateTime(2026, 7, 1),
          createdAt: DateTime(2026, 7, 1),
          updatedAt: DateTime(2026, 7, 1),
        ),
      );
      expect(
        await repo.getSyncHlc(created.id),
        isNotNull,
        reason: 'createMedia marks the row pending, which stamps hlc',
      );
      expect(await repo.getSyncHlc('missing'), isNull);
    },
  );
}
