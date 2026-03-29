import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

import '../../../../helpers/test_database.dart';

void main() {
  group('TagRepository error handling', () {
    late TagRepository repository;

    setUp(() async {
      await setUpTestDatabase();
      repository = TagRepository();
    });

    tearDown(() {
      DatabaseService.instance.resetForTesting();
    });

    test('all methods rethrow on database error', () async {
      await DatabaseService.instance.database.close();
      DatabaseService.instance.resetForTesting();

      final now = DateTime.now();
      final testTag = Tag(
        id: 'test-id',
        name: 'Test Tag',
        createdAt: now,
        updatedAt: now,
      );

      await expectLater(repository.getAllTags(), throwsA(anything));
      await expectLater(repository.getTagById('test-id'), throwsA(anything));
      await expectLater(repository.getTagByName('test'), throwsA(anything));
      await expectLater(repository.createTag(testTag), throwsA(anything));
      await expectLater(repository.getOrCreateTag('test'), throwsA(anything));
      await expectLater(repository.updateTag(testTag), throwsA(anything));
      await expectLater(repository.deleteTag('test-id'), throwsA(anything));
      await expectLater(
        repository.getTagsForDive('test-id'),
        throwsA(anything),
      );
      await expectLater(
        repository.getTagsForDives(['test-id']),
        throwsA(anything),
      );
      await expectLater(
        repository.setTagsForDive('test-id', []),
        throwsA(anything),
      );
      await expectLater(
        repository.addTagToDive('test-id', 'tag-id'),
        throwsA(anything),
      );
      await expectLater(
        repository.removeTagFromDive('test-id', 'tag-id'),
        throwsA(anything),
      );
      await expectLater(repository.getTagStatistics(), throwsA(anything));
      await expectLater(
        repository.getTagUsageCount('test-id'),
        throwsA(anything),
      );
      await expectLater(
        repository.getMergedDiveCount(['test-id']),
        throwsA(anything),
      );
      await expectLater(repository.searchTags('test'), throwsA(anything));
      await expectLater(
        repository.mergeTags(
          sourceTagIds: ['source-id'],
          survivingTagId: 'survivor-id',
          name: 'Merged',
          colorHex: null,
        ),
        throwsA(anything),
      );
    });
  });
}
