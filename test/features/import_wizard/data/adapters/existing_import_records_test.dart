import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/certification_agencies/domain/certification_catalog.dart';
import 'package:submersion/features/dive_import/domain/models/dive_match_record.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/import_wizard/data/adapters/existing_import_records.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';

/// Reads [payload] needs, by name, so a test can say exactly what ran.
Future<(ExistingImportRecords, Set<String>)> readFor(
  ImportPayload payload,
) async {
  final reads = <String>{};
  Future<T> reading<T>(String name, T value) async {
    reads.add(name);
    return value;
  }

  final records = await readRecordsNeededBy(
    payload,
    dives: () => reading('dives', [
      DiveMatchRecord(id: 'dive', dateTime: DateTime.utc(2024)),
    ]),
    sourceUuidByDiveId: () => reading('sourceUuids', {'dive': 'uuid'}),
    trips: () => reading('trips', const []),
    sites: () =>
        reading('sites', const [DiveSite(id: 'site', name: 'Blue Hole')]),
    equipment: () => reading('equipment', const []),
    buddies: () => reading('buddies', const []),
    diveCenters: () => reading('diveCenters', const []),
    certifications: () => reading('certifications', const []),
    tags: () => reading('tags', const []),
    diveTypes: () => reading('diveTypes', const []),
    certificationCatalog: () =>
        reading('certificationCatalog', CertificationCatalog.builtInOnly),
  );
  return (records, reads);
}

ImportPayload carrying(
  ImportEntityType type, [
  Map<String, dynamic> item = const {'name': 'Item'},
]) => ImportPayload(
  entities: {
    type: [item],
  },
);

void main() {
  group('readRecordsNeededBy', () {
    test('reads nothing for an empty payload', () async {
      final (_, reads) = await readFor(const ImportPayload(entities: {}));

      expect(reads, isEmpty);
    });

    test('a type present with no rows counts as absent', () async {
      final (_, reads) = await readFor(
        const ImportPayload(entities: {ImportEntityType.sites: []}),
      );

      expect(reads, isEmpty);
    });

    test(
      'a site-and-tag file reads neither dives nor certifications',
      () async {
        final (records, reads) = await readFor(
          const ImportPayload(
            entities: {
              ImportEntityType.sites: [
                {'name': 'Blue Hole'},
              ],
              ImportEntityType.tags: [
                {'name': 'Night'},
              ],
            },
          ),
        );

        expect(reads, {'sites', 'tags'});
        expect(records.sites, hasLength(1));
        expect(records.dives, isEmpty);
        expect(records.sourceUuidByDiveId, isEmpty);
        expect(records.certificationCatalog, isNull);
      },
    );

    for (final (type, name) in const [
      (ImportEntityType.trips, 'trips'),
      (ImportEntityType.sites, 'sites'),
      (ImportEntityType.equipment, 'equipment'),
      (ImportEntityType.buddies, 'buddies'),
      (ImportEntityType.diveCenters, 'diveCenters'),
      (ImportEntityType.tags, 'tags'),
      (ImportEntityType.diveTypes, 'diveTypes'),
    ]) {
      test('a file of ${type.name} reads only $name', () async {
        final (_, reads) = await readFor(carrying(type));

        expect(reads, {name});
      });
    }

    test(
      'certifications bring the catalog that names their agencies',
      () async {
        final (records, reads) = await readFor(
          carrying(ImportEntityType.certifications),
        );

        expect(reads, {'certifications', 'certificationCatalog'});
        expect(records.certificationCatalog, isNotNull);
      },
    );

    test('dives with no source id leave the source keys unread', () async {
      final (records, reads) = await readFor(
        carrying(ImportEntityType.dives, {'maxDepth': 20.0}),
      );

      expect(reads, {'dives'});
      expect(records.dives, hasLength(1));
    });

    test('an empty source id counts as none', () async {
      final (_, reads) = await readFor(
        carrying(ImportEntityType.dives, {'sourceUuid': ''}),
      );

      expect(reads, {'dives'});
    });

    test('one dive with a source id is enough to read the keys', () async {
      final (records, reads) = await readFor(
        const ImportPayload(
          entities: {
            ImportEntityType.dives: [
              {'maxDepth': 20.0},
              {'sourceUuid': 'uuid'},
            ],
          },
        ),
      );

      expect(reads, {'dives', 'sourceUuids'});
      expect(records.sourceUuidByDiveId, {'dive': 'uuid'});
    });

    test('a read that fails is not swallowed', () async {
      expect(
        readRecordsNeededBy(
          carrying(ImportEntityType.sites),
          dives: () async => const [],
          sourceUuidByDiveId: () async => const {},
          trips: () async => const [],
          sites: () async => throw StateError('no sites'),
          equipment: () async => const [],
          buddies: () async => const [],
          diveCenters: () async => const [],
          certifications: () async => const [],
          tags: () async => const [],
          diveTypes: () async => const [],
          certificationCatalog: () async => CertificationCatalog.builtInOnly,
        ),
        throwsStateError,
      );
    });
  });
}
