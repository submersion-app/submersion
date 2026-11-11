import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/import_tag_scopes.dart';
import 'package:submersion/features/universal_import/data/services/payload_merger.dart';

/// Equipment tag references across a multi-file import (issue #1942).
void main() {
  const merger = PayloadMerger();

  ImportPayload payloadWithItem(String name, {bool definesTag = false}) =>
      ImportPayload(
        entities: {
          ImportEntityType.equipment: [
            {
              'uddfId': 'equip_1',
              'name': name,
              'type': 'regulator',
              'tagRefs': ['tag_1'],
            },
          ],
          if (definesTag)
            ImportEntityType.tags: [
              {'uddfId': 'tag_1', 'name': 'Rental'},
            ],
        },
      );

  List<Object?> refsOf(ImportPayload merged, String name) =>
      merged
              .entitiesOf(ImportEntityType.equipment)
              .firstWhere((e) => e['name'] == name)['tagRefs']
          as List<Object?>;

  test("item tag refs are namespaced per file, like a site's", () {
    final merged = merger.merge([
      FilePayload(
        fileId: 'a',
        fileName: 'a.uddf',
        payload: payloadWithItem('First reg'),
      ),
      FilePayload(
        fileId: 'b',
        fileName: 'b.uddf',
        payload: payloadWithItem('Second reg'),
      ),
    ]);
    expect(refsOf(merged, 'First reg'), ['a:tag_1']);
    expect(refsOf(merged, 'Second reg'), ['b:tag_1']);
  });

  test('an item follows its tag when the tag folds into a namesake', () {
    final merged = merger.merge([
      FilePayload(
        fileId: 'a',
        fileName: 'a.uddf',
        payload: payloadWithItem('First reg', definesTag: true),
      ),
      FilePayload(
        fileId: 'b',
        fileName: 'b.uddf',
        payload: payloadWithItem('Second reg', definesTag: true),
      ),
    ]);
    expect(merged.entitiesOf(ImportEntityType.tags), hasLength(1));
    expect(refsOf(merged, 'Second reg'), ['a:tag_1']);
  });

  group('an item two files share', () {
    ImportPayload sharedItem(String tagId, String tagName) => ImportPayload(
      entities: {
        ImportEntityType.equipment: [
          {
            'uddfId': 'equip_1',
            'name': 'Travel reg',
            'type': 'regulator',
            'tagRefs': [tagId],
          },
        ],
        ImportEntityType.tags: [
          {'uddfId': tagId, 'name': tagName},
        ],
      },
    );

    ImportPayload mergeTwo(ImportPayload a, ImportPayload b) => merger.merge([
      FilePayload(fileId: 'a', fileName: 'a.uddf', payload: a),
      FilePayload(fileId: 'b', fileName: 'b.uddf', payload: b),
    ]);

    test('keeps the tags each file gives it', () {
      final merged = mergeTwo(
        sharedItem('tag_1', 'Rental'),
        sharedItem('tag_2', 'Cold water'),
      );

      expect(merged.entitiesOf(ImportEntityType.equipment), hasLength(1));
      expect(refsOf(merged, 'Travel reg'), ['a:tag_1', 'b:tag_2']);
    });

    test('lists a tag both files give it once', () {
      final merged = mergeTwo(
        sharedItem('tag_1', 'Rental'),
        sharedItem('tag_1', 'Rental'),
      );

      expect(refsOf(merged, 'Travel reg'), ['a:tag_1']);
    });
  });

  test('a tag two files define keeps every scope either gives it', () {
    ImportPayload tagOnly(Map<String, dynamic> tag) => ImportPayload(
      entities: {
        ImportEntityType.tags: [tag],
      },
    );
    final merged = merger.merge([
      FilePayload(
        fileId: 'a',
        fileName: 'a.uddf',
        payload: tagOnly({
          'uddfId': 'tag_1',
          'name': 'Rental',
          'appliesToDives': true,
          'appliesToSites': false,
          'appliesToEquipment': false,
        }),
      ),
      FilePayload(
        fileId: 'b',
        fileName: 'b.uddf',
        payload: tagOnly({
          'uddfId': 'tag_1',
          'name': 'Rental',
          'appliesToDives': false,
          'appliesToSites': false,
          'appliesToEquipment': true,
        }),
      ),
    ]);

    final tag = merged.entitiesOf(ImportEntityType.tags).single;
    expect(tag['appliesToDives'], isTrue);
    expect(tag['appliesToSites'], isFalse);
    expect(tag['appliesToEquipment'], isTrue);
  });

  group('the new-tag everywhere mark (#4407)', () {
    ImportPayload tagOnly(Map<String, dynamic> tag) => ImportPayload(
      entities: {
        ImportEntityType.tags: [tag],
      },
    );
    Map<String, dynamic> mergedTag(
      Map<String, dynamic> a,
      Map<String, dynamic> b,
    ) => merger
        .merge([
          FilePayload(fileId: 'a', fileName: 'a', payload: tagOnly(a)),
          FilePayload(fileId: 'b', fileName: 'b', payload: tagOnly(b)),
        ])
        .entitiesOf(ImportEntityType.tags)
        .single;

    const backup = {
      'uddfId': 'tag_1',
      'name': 'Rental',
      'appliesToDives': false,
      'appliesToSites': false,
      'appliesToEquipment': false,
      'appliesToMedia': true,
      'appliesToDocuments': false,
    };
    const csv = {
      'uddfId': 'tag_1',
      'name': 'Rental',
      'appliesToDives': false,
      'appliesToSites': false,
      'appliesToEquipment': true,
      'appliesToMedia': false,
      'appliesToDocuments': false,
      importTagNewEverywhereKey: true,
    };
    const silent = {'uddfId': 'tag_1', 'name': 'Rental'};

    test('a backup stating exact scopes drops it, in either order', () {
      for (final tag in [mergedTag(backup, csv), mergedTag(csv, backup)]) {
        expect(tag[importTagNewEverywhereKey], isFalse);
        expect(importedNewTagScopes(tag), {TagScope.equipment, TagScope.media});
      }
    });

    test('a silent record adds no dive scope to a backup\'s, in either '
        'order', () {
      // Saying nothing is not saying "dives": the backup's exact scopes
      // survive the fold untouched.
      for (final tag in [
        mergedTag(backup, silent),
        mergedTag(silent, backup),
      ]) {
        expect(importedNewTagScopes(tag), {TagScope.media});
        expect(importedTagScopes(tag), {TagScope.media});
      }
    });

    test('a silent record keeps it, in either order', () {
      for (final tag in [mergedTag(silent, csv), mergedTag(csv, silent)]) {
        expect(tag[importTagNewEverywhereKey], isTrue);
        expect(importedNewTagScopes(tag), TagScope.everywhere);
      }
    });
  });
}
