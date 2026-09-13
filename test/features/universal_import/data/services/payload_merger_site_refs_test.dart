import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/services/payload_merger.dart';

/// Site type and tag references across a multi-file import (issue #1765).
void main() {
  const merger = PayloadMerger();

  ImportPayload payloadWithSite(String siteName) => ImportPayload(
    entities: {
      ImportEntityType.sites: [
        {
          'uddfId': 'site_1',
          'name': siteName,
          'tagRefs': ['tag_1'],
          'siteTypeRefs': ['mine', 'wreck'],
        },
      ],
    },
    metadata: {
      ImportPayload.customSiteTypesKey: [
        {'id': 'mine', 'name': 'Mine'},
      ],
    },
  );

  final merged = merger.merge([
    FilePayload(
      fileId: 'a',
      fileName: 'a.uddf',
      payload: payloadWithSite('First'),
    ),
    FilePayload(
      fileId: 'b',
      fileName: 'b.uddf',
      payload: payloadWithSite('Second'),
    ),
  ]);

  Map<String, dynamic> site(String name) => merged
      .entitiesOf(ImportEntityType.sites)
      .firstWhere((s) => s['name'] == name);

  test('site tag refs are namespaced per file, like dive tag refs', () {
    expect(site('First')['tagRefs'], ['a:tag_1']);
    expect(site('Second')['tagRefs'], ['b:tag_1']);
  });

  test('site type refs are slugs shared across files and stay as they are', () {
    expect(site('First')['siteTypeRefs'], ['mine', 'wreck']);
    expect(site('Second')['siteTypeRefs'], ['mine', 'wreck']);
  });

  test('custom site type definitions merge by id', () {
    final defs =
        merged.metadata[ImportPayload.customSiteTypesKey] as List<dynamic>;
    expect(defs, hasLength(1));
    expect((defs.single as Map<String, dynamic>)['name'], 'Mine');
  });
}
