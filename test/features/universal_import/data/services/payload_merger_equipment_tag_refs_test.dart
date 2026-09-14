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
}
