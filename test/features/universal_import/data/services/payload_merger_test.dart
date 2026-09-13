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

    test('keeps every file\'s custom dive roles, once per id', () {
      // Role ids are UUIDs minted on one device, so the same id in two
      // backups is the same role and must not be restored twice.
      ImportPayload withRoles(List<String> ids) => ImportPayload(
        entities: const {},
        metadata: {
          ImportPayload.customDiveRolesKey: [
            for (final id in ids) {'id': id, 'name': 'Role $id'},
          ],
        },
      );

      final merged = merger.merge([
        FilePayload(
          fileId: 'f0',
          fileName: 'a.uddf',
          payload: withRoles(['r1', 'r2']),
        ),
        FilePayload(
          fileId: 'f1',
          fileName: 'b.uddf',
          payload: withRoles(['r2', 'r3']),
        ),
      ]);

      final roles = merged.metadata[ImportPayload.customDiveRolesKey] as List;
      expect([for (final r in roles) (r as Map)['id']], ['r1', 'r2', 'r3']);
    });

    test('rewrites the person in each exact buddy role (issue #1737)', () {
      final a = payloadWith(
        buddies: [
          {'uddfId': 'b1', 'name': 'Alice'},
        ],
      );
      final b = payloadWith(
        buddies: [
          {'uddfId': 'b7', 'name': 'ALICE'},
          {'uddfId': 'b8', 'name': 'Bob'},
        ],
        dives: [
          {
            'dateTime': DateTime(2026, 2, 1, 9),
            'buddyRoleRefs': [
              {'buddyRef': 'b7', 'roleId': 'diveMaster'},
              {'buddyRef': 'b8', 'roleId': 'student'},
            ],
          },
        ],
      );

      final merged = merger.merge([
        FilePayload(fileId: 'f0', fileName: 'a.uddf', payload: a),
        FilePayload(fileId: 'f1', fileName: 'b.uddf', payload: b),
      ]);

      final dives = merged.entitiesOf(ImportEntityType.dives);
      expect(dives[0]['buddyRoleRefs'], [
        {'buddyRef': 'f0:b1', 'roleId': 'diveMaster'},
        {'buddyRef': 'f1:b8', 'roleId': 'student'},
      ]);
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

  group('same-name records within one file (issue #1807)', () {
    // A file that holds nothing foldable, so the batch path runs without
    // giving the namesakes anything to fold into.
    final unrelated = payloadWith(
      dives: [
        {'dateTime': DateTime(2026, 3, 1, 9)},
      ],
    );

    List<Object?> idsOf(ImportPayload merged, ImportEntityType type) => [
      for (final e in merged.entitiesOf(type)) e['uddfId'],
    ];

    test('keeps two people with the same name apart, with their roles', () {
      final a = payloadWith(
        buddies: [
          {'uddfId': 'b1', 'name': 'Chris Diver'},
          {'uddfId': 'b2', 'name': 'Chris Diver'},
        ],
        dives: [
          {
            'dateTime': DateTime(2026, 1, 1, 9),
            'buddyRefs': ['b1'],
            'diveGuideRefs': ['b2'],
            'buddyRoleRefs': [
              {'buddyRef': 'b1', 'roleId': 'buddy'},
              {'buddyRef': 'b2', 'roleId': 'diveGuide'},
            ],
          },
        ],
      );

      final merged = merger.merge([
        FilePayload(fileId: 'f0', fileName: 'a.uddf', payload: a),
        FilePayload(fileId: 'f1', fileName: 'b.fit', payload: unrelated),
      ]);

      expect(idsOf(merged, ImportEntityType.buddies), ['f0:b1', 'f0:b2']);
      final dive = merged.entitiesOf(ImportEntityType.dives).first;
      expect(dive['buddyRefs'], ['f0:b1']);
      expect(dive['diveGuideRefs'], ['f0:b2']);
      expect(dive['buddyRoleRefs'], [
        {'buddyRef': 'f0:b1', 'roleId': 'buddy'},
        {'buddyRef': 'f0:b2', 'roleId': 'diveGuide'},
      ]);
    });

    test('keeps same-name records apart for every name-folded type', () {
      List<Map<String, dynamic>> pair(
        String prefix, [
        Map<String, dynamic> extra = const {},
      ]) => [
        {'uddfId': '${prefix}1', 'name': 'Same', ...extra},
        {'uddfId': '${prefix}2', 'name': 'Same', ...extra},
      ];

      final a = ImportPayload(
        entities: {
          ImportEntityType.sites: pair('s'),
          ImportEntityType.trips: pair('t'),
          ImportEntityType.diveCenters: pair('d'),
          ImportEntityType.tags: pair('g'),
          ImportEntityType.courses: pair('k'),
          ImportEntityType.equipmentSets: pair('q'),
          ImportEntityType.equipment: pair('e', {'type': 'computer'}),
          ImportEntityType.certifications: pair('c', {'agency': 'PADI'}),
        },
      );

      final merged = merger.merge([
        FilePayload(fileId: 'f0', fileName: 'a.uddf', payload: a),
        FilePayload(fileId: 'f1', fileName: 'b.fit', payload: unrelated),
      ]);

      for (final type in a.entities.keys) {
        expect(merged.entitiesOf(type), hasLength(2), reason: type.name);
      }
    });

    test('folds repeats of one id, which are the same record', () {
      // MacDive keys sites by name, so two same-name rows share an id.
      final a = payloadWith(
        sites: [
          {'uddfId': 'Blue Hole', 'name': 'Blue Hole'},
          {'uddfId': 'Blue Hole', 'name': 'Blue Hole', 'latitude': 12.2},
        ],
        dives: [
          {
            'dateTime': DateTime(2026, 1, 1, 9),
            'site': {'uddfId': 'Blue Hole', 'name': 'Blue Hole'},
          },
        ],
      );

      final merged = merger.merge([
        FilePayload(fileId: 'f0', fileName: 'a.sqlite', payload: a),
        FilePayload(fileId: 'f1', fileName: 'b.fit', payload: unrelated),
      ]);

      final sites = merged.entitiesOf(ImportEntityType.sites);
      expect(sites, hasLength(1));
      expect(sites.single['uddfId'], 'f0:Blue Hole');
      expect(sites.single['latitude'], 12.2);
    });

    test('a repeated id folds with its record into an earlier file', () {
      final a = payloadWith(
        sites: [
          {'uddfId': 's0', 'name': 'Blue Hole'},
        ],
      );
      final b = payloadWith(
        sites: [
          {'uddfId': 'Blue Hole', 'name': 'Blue Hole'},
          {'uddfId': 'Blue Hole', 'name': 'Blue Hole', 'latitude': 12.2},
        ],
        dives: [
          {
            'dateTime': DateTime(2026, 2, 1, 9),
            'site': {'uddfId': 'Blue Hole', 'name': 'Blue Hole'},
          },
        ],
      );

      final merged = merger.merge([
        FilePayload(fileId: 'f0', fileName: 'a.uddf', payload: a),
        FilePayload(fileId: 'f1', fileName: 'b.sqlite', payload: b),
      ]);

      final sites = merged.entitiesOf(ImportEntityType.sites);
      expect(sites, hasLength(1));
      expect(sites.single['uddfId'], 'f0:s0');
      expect(sites.single['latitude'], 12.2);
      final dive = merged.entitiesOf(ImportEntityType.dives).single;
      expect((dive['site'] as Map<String, dynamic>)['uddfId'], 'f0:s0');
    });

    test('a repeated id is one record even when only a repeat is named', () {
      final a = payloadWith(
        sites: [
          {'uddfId': 's0', 'name': 'Blue Hole'},
        ],
      );
      final b = payloadWith(
        sites: [
          {'uddfId': 's1'},
          {'uddfId': 's1', 'name': 'Blue Hole'},
        ],
        dives: [
          {
            'dateTime': DateTime(2026, 2, 1, 9),
            'site': {'uddfId': 's1'},
          },
        ],
      );

      final merged = merger.merge([
        FilePayload(fileId: 'f0', fileName: 'a.uddf', payload: a),
        FilePayload(fileId: 'f1', fileName: 'b.uddf', payload: b),
      ]);

      // The name arrives on the repeat, and still folds the one record.
      expect(idsOf(merged, ImportEntityType.sites), ['f0:s0']);
      final dive = merged.entitiesOf(ImportEntityType.dives).single;
      expect((dive['site'] as Map<String, dynamic>)['uddfId'], 'f0:s0');
    });

    test('a dive type is identified by its slug over any uddfId', () {
      const a = ImportPayload(
        entities: {
          ImportEntityType.diveTypes: [
            {'id': 'wreck', 'uddfId': 'w1', 'name': 'Wreck'},
            {'id': 'wreck', 'uddfId': 'w2', 'name': 'Wreck'},
          ],
        },
      );

      final merged = merger.merge([
        const FilePayload(fileId: 'f0', fileName: 'a.uddf', payload: a),
        FilePayload(fileId: 'f1', fileName: 'b.fit', payload: unrelated),
      ]);

      expect(merged.entitiesOf(ImportEntityType.diveTypes), hasLength(1));
    });

    test('folds dive types sharing a slug, which is their id', () {
      const a = ImportPayload(
        entities: {
          ImportEntityType.diveTypes: [
            {'id': 'wreck', 'name': 'Wreck'},
            {'id': 'wreck', 'name': 'Wreck', 'sortOrder': 7},
          ],
        },
      );

      final merged = merger.merge([
        const FilePayload(fileId: 'f0', fileName: 'a.uddf', payload: a),
        FilePayload(fileId: 'f1', fileName: 'b.fit', payload: unrelated),
      ]);

      final types = merged.entitiesOf(ImportEntityType.diveTypes);
      expect(types, hasLength(1));
      expect(types.single['sortOrder'], 7);
    });

    test('pairs namesakes in two files by their source id', () {
      // Two backups of one logbook: the same pair of namesakes, listed in
      // a different order.
      final a = payloadWith(
        buddies: [
          {'uddfId': 'b1', 'name': 'Chris Diver'},
          {'uddfId': 'b2', 'name': 'Chris Diver'},
        ],
      );
      final b = payloadWith(
        buddies: [
          {'uddfId': 'b2', 'name': 'Chris Diver'},
          {'uddfId': 'b1', 'name': 'Chris Diver'},
        ],
        dives: [
          {
            'dateTime': DateTime(2026, 2, 1, 9),
            'buddyRefs': ['b1'],
            'diveGuideRefs': ['b2'],
          },
        ],
      );

      final merged = merger.merge([
        FilePayload(fileId: 'f0', fileName: 'a.uddf', payload: a),
        FilePayload(fileId: 'f1', fileName: 'b.uddf', payload: b),
      ]);

      expect(idsOf(merged, ImportEntityType.buddies), ['f0:b1', 'f0:b2']);
      final dive = merged.entitiesOf(ImportEntityType.dives).single;
      expect(dive['buddyRefs'], ['f0:b1']);
      expect(dive['diveGuideRefs'], ['f0:b2']);
    });

    test('keeps a later record apart when earlier namesakes are ambiguous', () {
      final a = payloadWith(
        buddies: [
          {'uddfId': 'b1', 'name': 'Chris Diver'},
          {'uddfId': 'b2', 'name': 'Chris Diver'},
        ],
      );
      final b = payloadWith(
        buddies: [
          {'uddfId': 'x9', 'name': 'Chris Diver'},
        ],
        dives: [
          {
            'dateTime': DateTime(2026, 2, 1, 9),
            'buddyRefs': ['x9'],
          },
        ],
      );

      final merged = merger.merge([
        FilePayload(fileId: 'f0', fileName: 'a.uddf', payload: a),
        FilePayload(fileId: 'f1', fileName: 'b.uddf', payload: b),
      ]);

      expect(idsOf(merged, ImportEntityType.buddies), [
        'f0:b1',
        'f0:b2',
        'f1:x9',
      ]);
      final dive = merged.entitiesOf(ImportEntityType.dives).single;
      expect(dive['buddyRefs'], ['f1:x9']);
    });

    test('keeps later namesakes apart unless one shares the source id', () {
      final a = payloadWith(
        buddies: [
          {'uddfId': 'b1', 'name': 'Chris Diver'},
        ],
      );
      ImportPayload later(String first) => payloadWith(
        buddies: [
          {'uddfId': first, 'name': 'Chris Diver'},
          {'uddfId': 'c2', 'name': 'Chris Diver'},
        ],
      );

      final noMatch = merger.merge([
        FilePayload(fileId: 'f0', fileName: 'a.uddf', payload: a),
        FilePayload(fileId: 'f1', fileName: 'b.uddf', payload: later('c1')),
      ]);
      expect(idsOf(noMatch, ImportEntityType.buddies), [
        'f0:b1',
        'f1:c1',
        'f1:c2',
      ]);

      final idMatch = merger.merge([
        FilePayload(fileId: 'f0', fileName: 'a.uddf', payload: a),
        FilePayload(fileId: 'f1', fileName: 'b.uddf', payload: later('b1')),
      ]);
      expect(idsOf(idMatch, ImportEntityType.buddies), ['f0:b1', 'f1:c2']);
    });

    test('keeps a leftover namesake apart after a partial id match', () {
      final a = payloadWith(
        buddies: [
          {'uddfId': 'b1', 'name': 'Chris Diver'},
          {'uddfId': 'b2', 'name': 'Chris Diver'},
        ],
      );
      final b = payloadWith(
        buddies: [
          {'uddfId': 'b1', 'name': 'Chris Diver'},
          {'uddfId': 'x9', 'name': 'Chris Diver'},
        ],
      );

      final merged = merger.merge([
        FilePayload(fileId: 'f0', fileName: 'a.uddf', payload: a),
        FilePayload(fileId: 'f1', fileName: 'b.uddf', payload: b),
      ]);

      // b1 pairs by id. x9 and f0:b2 are then the only records left on
      // each side, but after an ambiguous start that is no evidence they
      // are the same person, so x9 stays its own record.
      expect(idsOf(merged, ImportEntityType.buddies), [
        'f0:b1',
        'f0:b2',
        'f1:x9',
      ]);
    });

    test('a fold carries its source ids forward to later files', () {
      ImportPayload chrises(List<String> ids) => payloadWith(
        buddies: [
          for (final id in ids) {'uddfId': id, 'name': 'Chris Diver'},
        ],
        dives: [
          {'dateTime': DateTime(2026, 2, 1, 9), 'buddyRefs': ids},
        ],
      );

      final merged = merger.merge([
        FilePayload(fileId: 'f0', fileName: 'a', payload: chrises(['x'])),
        // One on each side: y folds into f0:x as today.
        FilePayload(fileId: 'f1', fileName: 'b', payload: chrises(['y'])),
        // y is known as f0:x now, so it pairs there; z stays apart.
        FilePayload(fileId: 'f2', fileName: 'c', payload: chrises(['y', 'z'])),
      ]);

      expect(idsOf(merged, ImportEntityType.buddies), ['f0:x', 'f2:z']);
      final dives = merged.entitiesOf(ImportEntityType.dives);
      expect(dives[2]['buddyRefs'], ['f0:x', 'f2:z']);
    });
  });

  group('media', () {
    ImportPayload mediaPayload({
      required int diveCount,
      required List<int> pictureDiveIndices,
    }) {
      return ImportPayload(
        entities: {
          ImportEntityType.dives: [
            for (var i = 0; i < diveCount; i++)
              {'uddfId': 'd$i', 'dateTime': DateTime(2025, 1, 1 + i)},
          ],
          ImportEntityType.media: [
            for (final index in pictureDiveIndices)
              {
                'filename': '/home/jai/Pictures/p$index.jpg',
                'offsetSeconds': 200,
                '_diveIndex': index,
              },
          ],
        },
      );
    }

    test('rebases _diveIndex onto the merged dive list', () {
      final merged = const PayloadMerger().merge([
        FilePayload(
          fileId: 'f0',
          fileName: 'first.ssrf',
          payload: mediaPayload(diveCount: 2, pictureDiveIndices: [0, 1]),
        ),
        FilePayload(
          fileId: 'f1',
          fileName: 'second.ssrf',
          payload: mediaPayload(diveCount: 3, pictureDiveIndices: [0, 2]),
        ),
      ]);

      final dives = merged.entitiesOf(ImportEntityType.dives);
      final media = merged.entitiesOf(ImportEntityType.media);
      expect(dives, hasLength(5));
      expect(media, hasLength(4));
      // First file's pictures keep their indices; second file's shift by 2.
      expect(media.map((m) => m['_diveIndex']), [0, 1, 2, 4]);
    });

    test('never folds two pictures with the same filename', () {
      final payload = ImportPayload(
        entities: {
          ImportEntityType.dives: [
            {'uddfId': 'd0', 'dateTime': DateTime(2025, 1, 1)},
          ],
          ImportEntityType.media: [
            {'filename': '/p/same.jpg', '_diveIndex': 0},
            {'filename': '/p/same.jpg', '_diveIndex': 0},
          ],
        },
      );

      final merged = const PayloadMerger().merge([
        FilePayload(fileId: 'f0', fileName: 'a.ssrf', payload: payload),
      ]);

      expect(merged.entitiesOf(ImportEntityType.media), hasLength(2));
    });
  });
}
