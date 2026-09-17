import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
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
}
