import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/services/payload_merger.dart';

ImportPayload payloadWith({
  List<Map<String, dynamic>> dives = const [],
  List<Map<String, dynamic>> sites = const [],
  List<Map<String, dynamic>> buddies = const [],
  List<Map<String, dynamic>> equipment = const [],
}) {
  return ImportPayload(
    entities: {
      if (dives.isNotEmpty) ImportEntityType.dives: dives,
      if (sites.isNotEmpty) ImportEntityType.sites: sites,
      if (buddies.isNotEmpty) ImportEntityType.buddies: buddies,
      if (equipment.isNotEmpty) ImportEntityType.equipment: equipment,
    },
  );
}

void main() {
  const merger = PayloadMerger();

  group('PayloadMerger', () {
    test('namespaces colliding uddfIds across files', () {
      final a = payloadWith(
        sites: [
          {'uddfId': 'site_1', 'name': 'Blue Hole'},
        ],
        dives: [
          {
            'dateTime': DateTime(2026, 1, 1, 9),
            'site': {'uddfId': 'site_1', 'name': 'Blue Hole'},
          },
        ],
      );
      final b = payloadWith(
        sites: [
          {'uddfId': 'site_1', 'name': 'Shark Reef'},
        ],
        dives: [
          {
            'dateTime': DateTime(2026, 2, 1, 9),
            'site': {'uddfId': 'site_1', 'name': 'Shark Reef'},
          },
        ],
      );

      final merged = merger.merge([
        FilePayload(fileId: 'f0', fileName: 'a.uddf', payload: a),
        FilePayload(fileId: 'f1', fileName: 'b.uddf', payload: b),
      ]);

      final sites = merged.entitiesOf(ImportEntityType.sites);
      expect(sites, hasLength(2));
      expect(sites[0]['uddfId'], 'f0:site_1');
      expect(sites[1]['uddfId'], 'f1:site_1');

      final dives = merged.entitiesOf(ImportEntityType.dives);
      expect((dives[0]['site'] as Map<String, dynamic>)['uddfId'], 'f0:site_1');
      expect((dives[1]['site'] as Map<String, dynamic>)['uddfId'], 'f1:site_1');
    });

    test('folds same-name sites across files and rewrites dive refs', () {
      final a = payloadWith(
        sites: [
          {'uddfId': 's1', 'name': 'Blue Hole'},
        ],
        dives: [
          {
            'dateTime': DateTime(2026, 1, 1, 9),
            'site': {'uddfId': 's1', 'name': 'Blue Hole'},
          },
        ],
      );
      final b = payloadWith(
        sites: [
          {
            'uddfId': 's9',
            'name': 'blue hole ', // different case + trailing space
            'latitude': 12.2,
            'longitude': 43.1,
          },
        ],
        dives: [
          {
            'dateTime': DateTime(2026, 2, 1, 9),
            'site': {'uddfId': 's9', 'name': 'blue hole '},
          },
        ],
      );

      final merged = merger.merge([
        FilePayload(fileId: 'f0', fileName: 'a.uddf', payload: a),
        FilePayload(fileId: 'f1', fileName: 'b.uddf', payload: b),
      ]);

      final sites = merged.entitiesOf(ImportEntityType.sites);
      expect(sites, hasLength(1));
      // Survivor is the first occurrence, enriched with the later file's
      // non-null fields.
      expect(sites[0]['uddfId'], 'f0:s1');
      expect(sites[0]['name'], 'Blue Hole');
      expect(sites[0]['latitude'], 12.2);

      // The second dive's site ref is rewritten to the survivor.
      final dives = merged.entitiesOf(ImportEntityType.dives);
      expect((dives[1]['site'] as Map<String, dynamic>)['uddfId'], 'f0:s1');
    });

    test('rewrites list refs (buddyRefs) through the alias map', () {
      final a = payloadWith(
        buddies: [
          {'uddfId': 'b1', 'name': 'Alice'},
        ],
      );
      final b = payloadWith(
        buddies: [
          {'uddfId': 'b7', 'name': 'ALICE'},
        ],
        dives: [
          {
            'dateTime': DateTime(2026, 2, 1, 9),
            'buddyRefs': ['b7'],
          },
        ],
      );

      final merged = merger.merge([
        FilePayload(fileId: 'f0', fileName: 'a.uddf', payload: a),
        FilePayload(fileId: 'f1', fileName: 'b.uddf', payload: b),
      ]);

      expect(merged.entitiesOf(ImportEntityType.buddies), hasLength(1));
      final dives = merged.entitiesOf(ImportEntityType.dives);
      expect(dives[0]['buddyRefs'], ['f0:b1']);
    });

    test('never folds dives, even identical ones', () {
      final dive = {'dateTime': DateTime(2026, 1, 1, 9), 'maxDepth': 18.0};
      final merged = merger.merge([
        FilePayload(
          fileId: 'f0',
          fileName: 'a.fit',
          payload: payloadWith(dives: [Map.of(dive)]),
        ),
        FilePayload(
          fileId: 'f1',
          fileName: 'b.uddf',
          payload: payloadWith(dives: [Map.of(dive)]),
        ),
      ]);
      expect(merged.entitiesOf(ImportEntityType.dives), hasLength(2));
    });

    test('equipment folds by name AND type, not name alone', () {
      final a = payloadWith(
        equipment: [
          {'uddfId': 'e1', 'name': 'Perdix', 'type': 'computer'},
        ],
      );
      final b = payloadWith(
        equipment: [
          {'uddfId': 'e2', 'name': 'Perdix', 'type': 'other'},
        ],
      );
      final merged = merger.merge([
        FilePayload(fileId: 'f0', fileName: 'a.uddf', payload: a),
        FilePayload(fileId: 'f1', fileName: 'b.uddf', payload: b),
      ]);
      expect(merged.entitiesOf(ImportEntityType.equipment), hasLength(2));
    });

    test('stamps _sourceFile on every entity and batch metadata', () {
      final merged = merger.merge([
        FilePayload(
          fileId: 'f0',
          fileName: 'a.fit',
          payload: payloadWith(
            dives: [
              {'dateTime': DateTime(2026, 1, 1)},
            ],
          ),
        ),
        FilePayload(
          fileId: 'f1',
          fileName: 'b.fit',
          payload: payloadWith(
            dives: [
              {'dateTime': DateTime(2026, 1, 2)},
            ],
          ),
        ),
      ]);

      final dives = merged.entitiesOf(ImportEntityType.dives);
      expect(dives[0]['_sourceFile'], 'a.fit');
      expect(dives[1]['_sourceFile'], 'b.fit');
      // The id disambiguates same-named files from different folders.
      expect(dives[0]['_sourceFileId'], 'f0');
      expect(dives[1]['_sourceFileId'], 'f1');
      expect(merged.metadata['batchFileCount'], 2);
      expect(merged.metadata['sourceFiles'], ['a.fit', 'b.fit']);
    });

    test('certifications fold by name AND agency', () {
      ImportPayload certs(String uddfId, String name, String agency) {
        return ImportPayload(
          entities: {
            ImportEntityType.certifications: [
              {'uddfId': uddfId, 'name': name, 'agency': agency},
            ],
          },
        );
      }

      final merged = merger.merge([
        FilePayload(
          fileId: 'f0',
          fileName: 'a',
          payload: certs('c1', 'AOW', 'PADI'),
        ),
        FilePayload(
          fileId: 'f1',
          fileName: 'b',
          payload: certs('c2', 'aow', 'padi'),
        ),
        FilePayload(
          fileId: 'f2',
          fileName: 'c',
          payload: certs('c3', 'AOW', 'SSI'),
        ),
      ]);

      // PADI folds (case-insensitive); SSI stays separate.
      expect(merged.entitiesOf(ImportEntityType.certifications), hasLength(2));
    });

    test('folds trips, tags, dive types, courses, dive centers by name', () {
      ImportPayload onePer(String suffix) {
        return ImportPayload(
          entities: {
            ImportEntityType.trips: [
              {'uddfId': 't$suffix', 'name': 'Red Sea'},
            ],
            ImportEntityType.tags: [
              {'uddfId': 'g$suffix', 'name': 'wreck'},
            ],
            ImportEntityType.diveTypes: [
              {'id': 'boat', 'name': 'Boat'},
            ],
            ImportEntityType.courses: [
              {'uddfId': 'k$suffix', 'name': 'Nitrox'},
            ],
            ImportEntityType.diveCenters: [
              {'uddfId': 'd$suffix', 'name': 'Blue Divers'},
            ],
          },
        );
      }

      final merged = merger.merge([
        FilePayload(fileId: 'f0', fileName: 'a', payload: onePer('0')),
        FilePayload(fileId: 'f1', fileName: 'b', payload: onePer('1')),
      ]);

      expect(merged.entitiesOf(ImportEntityType.trips), hasLength(1));
      expect(merged.entitiesOf(ImportEntityType.tags), hasLength(1));
      expect(merged.entitiesOf(ImportEntityType.diveTypes), hasLength(1));
      expect(merged.entitiesOf(ImportEntityType.courses), hasLength(1));
      expect(merged.entitiesOf(ImportEntityType.diveCenters), hasLength(1));
    });

    test(
      'equipment set refs are namespaced and rewritten to fold survivor',
      () {
        const a = ImportPayload(
          entities: {
            ImportEntityType.equipment: [
              {'uddfId': 'e1', 'name': 'Perdix', 'type': 'computer'},
            ],
          },
        );
        const b = ImportPayload(
          entities: {
            ImportEntityType.equipment: [
              {'uddfId': 'e9', 'name': 'perdix', 'type': 'computer'},
            ],
            ImportEntityType.equipmentSets: [
              {
                'uddfId': 'set1',
                'name': 'Tech Rig',
                'equipmentRefs': ['e9'],
              },
            ],
          },
        );

        final merged = merger.merge(const [
          FilePayload(fileId: 'f0', fileName: 'a', payload: a),
          FilePayload(fileId: 'f1', fileName: 'b', payload: b),
        ]);

        // The two Perdix entries fold to one (survivor f0:e1).
        expect(merged.entitiesOf(ImportEntityType.equipment), hasLength(1));
        // The set's ref, namespaced to f1:e9, is rewritten to the survivor.
        final set = merged.entitiesOf(ImportEntityType.equipmentSets).single;
        expect(set['equipmentRefs'], ['f0:e1']);
      },
    );

    test('reference entities without a name are not folded', () {
      ImportPayload nameless(String uddfId) {
        return ImportPayload(
          entities: {
            ImportEntityType.sites: [
              {'uddfId': uddfId},
            ],
          },
        );
      }

      final merged = merger.merge([
        FilePayload(fileId: 'f0', fileName: 'a', payload: nameless('s1')),
        FilePayload(fileId: 'f1', fileName: 'b', payload: nameless('s2')),
      ]);

      expect(merged.entitiesOf(ImportEntityType.sites), hasLength(2));
    });

    test('concatenates warnings from all files', () {
      const a = ImportPayload(
        entities: {},
        warnings: [
          ImportWarning(severity: ImportWarningSeverity.warning, message: 'w1'),
        ],
      );
      final merged = merger.merge([
        const FilePayload(fileId: 'f0', fileName: 'a.uddf', payload: a),
      ]);
      expect(merged.warnings, hasLength(1));
    });
  });
}
