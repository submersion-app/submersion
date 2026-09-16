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

  group('a site two files share', () {
    /// One file's copy of the same site, tagged with [tags] (id -> name).
    ImportPayload sharedSite({
      Map<String, String> tags = const {},
      List<String> siteTypeRefs = const [],
      List<String>? suggestedSiteTypeRefs,
    }) => ImportPayload(
      entities: {
        ImportEntityType.sites: [
          {
            'uddfId': 'site_1',
            'name': 'Blue Hole',
            'tagRefs': tags.keys.toList(),
            'siteTypeRefs': siteTypeRefs,
            'suggestedSiteTypeRefs': ?suggestedSiteTypeRefs,
          },
        ],
        ImportEntityType.tags: [
          for (final MapEntry(:key, :value) in tags.entries)
            {'uddfId': key, 'name': value},
        ],
      },
    );

    Map<String, dynamic> mergeTwo(ImportPayload a, ImportPayload b) {
      final sites = merger
          .merge([
            FilePayload(fileId: 'a', fileName: 'a.uddf', payload: a),
            FilePayload(fileId: 'b', fileName: 'b.uddf', payload: b),
          ])
          .entitiesOf(ImportEntityType.sites);
      expect(sites, hasLength(1));
      return sites.single;
    }

    test('keeps the tags each file gives it', () {
      final site = mergeTwo(
        sharedSite(tags: {'tag_1': 'Night'}),
        sharedSite(tags: {'tag_2': 'Shore'}),
      );

      expect(site['tagRefs'], ['a:tag_1', 'b:tag_2']);
    });

    test('lists a tag both files give it once', () {
      final site = mergeTwo(
        sharedSite(tags: {'tag_1': 'Night'}),
        sharedSite(tags: {'tag_1': 'Night'}),
      );

      expect(site['tagRefs'], ['a:tag_1']);
    });

    test('takes a later file\'s tags when the first lists none', () {
      final site = mergeTwo(sharedSite(), sharedSite(tags: {'tag_2': 'Shore'}));

      expect(site['tagRefs'], ['b:tag_2']);
    });

    test('keeps the site types each file gives it', () {
      final site = mergeTwo(
        sharedSite(siteTypeRefs: ['wreck']),
        sharedSite(siteTypeRefs: ['reef']),
      );

      expect(site['siteTypeRefs'], ['wreck', 'reef']);
    });

    test('lists a site type both files give it once', () {
      final site = mergeTwo(
        sharedSite(siteTypeRefs: ['wreck', 'mine']),
        sharedSite(siteTypeRefs: ['wreck', 'reef']),
      );

      expect(site['siteTypeRefs'], ['wreck', 'mine', 'reef']);
    });

    test('keeps only the first file\'s suggested site types', () {
      final site = mergeTwo(
        sharedSite(suggestedSiteTypeRefs: ['quarry']),
        sharedSite(suggestedSiteTypeRefs: ['cave']),
      );

      expect(site['suggestedSiteTypeRefs'], ['quarry']);
    });
  });

  test('keeps the tags a file gives its repeats of one site', () {
    final merged = merger.merge([
      const FilePayload(
        fileId: 'a',
        fileName: 'a.uddf',
        payload: ImportPayload(
          entities: {
            ImportEntityType.sites: [
              {
                'uddfId': 'site_1',
                'name': 'Blue Hole',
                'tagRefs': ['tag_1'],
              },
              {
                'uddfId': 'site_1',
                'name': 'Blue Hole',
                'tagRefs': ['tag_2'],
              },
            ],
            ImportEntityType.tags: [
              {'uddfId': 'tag_1', 'name': 'Night'},
              {'uddfId': 'tag_2', 'name': 'Shore'},
            ],
          },
        ),
      ),
    ]);

    final sites = merged.entitiesOf(ImportEntityType.sites);
    expect(sites, hasLength(1));
    expect(sites.single['tagRefs'], ['a:tag_1', 'a:tag_2']);
  });
}
