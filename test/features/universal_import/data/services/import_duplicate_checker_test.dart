import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/universal_import/data/services/import_duplicate_checker.dart';

void main() {
  const checker = ImportDuplicateChecker();
  final now = DateTime(2024, 1, 15);

  ImportDuplicateResult checkWith({
    ImportPayload? payload,
    List<Dive> dives = const [],
    List<DiveSite> sites = const [],
    List<Trip> trips = const [],
    List<EquipmentItem> equipment = const [],
    List<Buddy> buddies = const [],
    List<DiveCenter> diveCenters = const [],
    List<Certification> certifications = const [],
    List<Tag> tags = const [],
    List<DiveTypeEntity> diveTypes = const [],
  }) {
    return checker.check(
      payload: payload ?? const ImportPayload(entities: {}),
      existingDives: dives,
      existingSites: sites,
      existingTrips: trips,
      existingEquipment: equipment,
      existingBuddies: buddies,
      existingDiveCenters: diveCenters,
      existingCertifications: certifications,
      existingTags: tags,
      existingDiveTypes: diveTypes,
    );
  }

  group('ImportDuplicateResult', () {
    test('empty result has no duplicates', () {
      const result = ImportDuplicateResult();
      expect(result.hasDuplicates, isFalse);
      expect(result.totalDuplicates, 0);
    });

    test('isDuplicate returns false for empty result', () {
      const result = ImportDuplicateResult();
      expect(result.isDuplicate(ImportEntityType.trips, 0), isFalse);
      expect(result.isDuplicate(ImportEntityType.dives, 0), isFalse);
    });

    test('isDuplicate returns true for entity in duplicates map', () {
      const result = ImportDuplicateResult(
        duplicates: {
          ImportEntityType.trips: {0, 2},
        },
      );
      expect(result.isDuplicate(ImportEntityType.trips, 0), isTrue);
      expect(result.isDuplicate(ImportEntityType.trips, 1), isFalse);
      expect(result.isDuplicate(ImportEntityType.trips, 2), isTrue);
    });

    test('isDuplicate uses diveMatches for dives', () {
      const result = ImportDuplicateResult(
        diveMatches: {
          0: DiveMatchResult(
            diveId: 'existing-1',
            score: 0.8,
            timeDifferenceMs: 100,
          ),
        },
      );
      expect(result.isDuplicate(ImportEntityType.dives, 0), isTrue);
      expect(result.isDuplicate(ImportEntityType.dives, 1), isFalse);
    });
  });

  group('Name-based duplicates', () {
    test('finds trip duplicates by name', () {
      final result = checkWith(
        payload: const ImportPayload(
          entities: {
            ImportEntityType.trips: [
              {'name': 'Red Sea Trip'},
              {'name': 'Bonaire'},
            ],
          },
        ),
        trips: [
          Trip(
            id: '1',
            name: 'Red Sea Trip',
            startDate: now,
            endDate: now,
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );

      expect(result.duplicates[ImportEntityType.trips], {0});
    });

    test('case-insensitive name matching', () {
      final result = checkWith(
        payload: const ImportPayload(
          entities: {
            ImportEntityType.buddies: [
              {'name': 'alice'},
            ],
          },
        ),
        buddies: [
          Buddy(id: '1', name: 'Alice', createdAt: now, updatedAt: now),
        ],
      );

      expect(result.duplicates[ImportEntityType.buddies], {0});
    });

    test('finds tag duplicates', () {
      final result = checkWith(
        payload: const ImportPayload(
          entities: {
            ImportEntityType.tags: [
              {'name': 'Night Dive'},
              {'name': 'Training'},
            ],
          },
        ),
        tags: [
          Tag(id: '1', name: 'Night Dive', createdAt: now, updatedAt: now),
        ],
      );

      expect(result.duplicates[ImportEntityType.tags], {0});
    });

    test('finds dive center duplicates', () {
      final result = checkWith(
        payload: const ImportPayload(
          entities: {
            ImportEntityType.diveCenters: [
              {'name': 'Blue Dive Shop'},
            ],
          },
        ),
        diveCenters: [
          DiveCenter(
            id: '1',
            name: 'blue dive shop',
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );

      expect(result.duplicates[ImportEntityType.diveCenters], {0});
    });
  });

  group('Site duplicates', () {
    test('finds by name', () {
      final result = checkWith(
        payload: const ImportPayload(
          entities: {
            ImportEntityType.sites: [
              {'name': 'Blue Hole'},
            ],
          },
        ),
        sites: [const DiveSite(id: '1', name: 'Blue Hole')],
      );

      expect(result.duplicates[ImportEntityType.sites], {0});
    });

    test('finds by lat/lon proximity within 100m', () {
      final result = checkWith(
        payload: const ImportPayload(
          entities: {
            ImportEntityType.sites: [
              {
                'name': 'Different Name',
                'latitude': 27.2001,
                'longitude': 33.8601,
              },
            ],
          },
        ),
        sites: [
          const DiveSite(
            id: '1',
            name: 'Existing Site',
            location: GeoPoint(27.2, 33.86),
          ),
        ],
      );

      expect(result.duplicates[ImportEntityType.sites], {0});
    });

    test('does not flag >100m away', () {
      final result = checkWith(
        payload: const ImportPayload(
          entities: {
            ImportEntityType.sites: [
              {'name': 'Different Name', 'latitude': 27.21, 'longitude': 33.86},
            ],
          },
        ),
        sites: [
          const DiveSite(
            id: '1',
            name: 'Other',
            location: GeoPoint(27.2, 33.86),
          ),
        ],
      );

      expect(result.duplicates[ImportEntityType.sites], isNull);
    });
  });

  group('Equipment duplicates', () {
    test('matches by name + type', () {
      final result = checkWith(
        payload: const ImportPayload(
          entities: {
            ImportEntityType.equipment: [
              {'name': 'Apex XTX50', 'type': EquipmentType.regulator},
              {'name': 'Apex XTX50', 'type': EquipmentType.bcd},
            ],
          },
        ),
        equipment: [
          const EquipmentItem(
            id: '1',
            name: 'Apex XTX50',
            type: EquipmentType.regulator,
          ),
        ],
      );

      expect(result.duplicates[ImportEntityType.equipment], {0});
    });

    test('handles string type', () {
      final result = checkWith(
        payload: const ImportPayload(
          entities: {
            ImportEntityType.equipment: [
              {'name': 'Apex XTX50', 'type': 'regulator'},
            ],
          },
        ),
        equipment: [
          const EquipmentItem(
            id: '1',
            name: 'Apex XTX50',
            type: EquipmentType.regulator,
          ),
        ],
      );

      expect(result.duplicates[ImportEntityType.equipment], {0});
    });
  });

  group('Certification duplicates', () {
    test('matches by name + agency', () {
      final result = checkWith(
        payload: const ImportPayload(
          entities: {
            ImportEntityType.certifications: [
              {'name': 'Open Water', 'agency': CertificationAgency.padi},
              {'name': 'Open Water', 'agency': CertificationAgency.ssi},
            ],
          },
        ),
        certifications: [
          Certification(
            id: '1',
            name: 'Open Water',
            agency: CertificationAgency.padi,
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );

      expect(result.duplicates[ImportEntityType.certifications], {0});
    });
  });

  group('Dive type duplicates', () {
    test('matches by name', () {
      final result = checkWith(
        payload: const ImportPayload(
          entities: {
            ImportEntityType.diveTypes: [
              {'name': 'Cave', 'id': 'cave'},
            ],
          },
        ),
        diveTypes: [
          DiveTypeEntity(
            id: 'cave',
            name: 'Cave',
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );

      expect(result.duplicates[ImportEntityType.diveTypes], {0});
    });

    test('matches by ID', () {
      final result = checkWith(
        payload: const ImportPayload(
          entities: {
            ImportEntityType.diveTypes: [
              {'name': 'Different', 'id': 'cave'},
            ],
          },
        ),
        diveTypes: [
          DiveTypeEntity(
            id: 'cave',
            name: 'Cave Diving',
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );

      expect(result.duplicates[ImportEntityType.diveTypes], {0});
    });
  });

  group('Dive duplicates (fuzzy)', () {
    test('finds probable dive match', () {
      final diveTime = DateTime(2024, 1, 15, 10, 0);
      final result = checkWith(
        payload: ImportPayload(
          entities: {
            ImportEntityType.dives: [
              {
                'dateTime': diveTime,
                'maxDepth': 25.0,
                'runtime': const Duration(minutes: 45),
              },
            ],
          },
        ),
        dives: [
          Dive(
            id: 'existing-1',
            dateTime: diveTime.add(const Duration(minutes: 1)),
            maxDepth: 25.5,
            duration: const Duration(minutes: 44),
          ),
        ],
      );

      expect(result.diveMatches, contains(0));
      expect(result.diveMatches[0]!.diveId, 'existing-1');
    });

    test('no match for very different dives', () {
      final result = checkWith(
        payload: ImportPayload(
          entities: {
            ImportEntityType.dives: [
              {
                'dateTime': DateTime(2024, 1, 15, 10, 0),
                'maxDepth': 25.0,
                'runtime': const Duration(minutes: 45),
              },
            ],
          },
        ),
        dives: [
          Dive(
            id: 'existing-1',
            dateTime: DateTime(2024, 6, 1, 14, 0),
            maxDepth: 10.0,
            duration: const Duration(minutes: 20),
          ),
        ],
      );

      expect(result.diveMatches, isEmpty);
    });

    test('skips dive with null dateTime', () {
      final result = checkWith(
        payload: const ImportPayload(
          entities: {
            ImportEntityType.dives: [
              {'dateTime': null, 'maxDepth': 25.0},
            ],
          },
        ),
        dives: [
          Dive(
            id: 'existing-1',
            dateTime: DateTime(2024, 1, 15, 10, 0),
            maxDepth: 25.0,
            duration: const Duration(minutes: 45),
          ),
        ],
      );

      expect(result.diveMatches, isEmpty);
    });

    test('uses duration field as fallback for runtime', () {
      final diveTime = DateTime(2024, 1, 15, 10, 0);
      final result = checkWith(
        payload: ImportPayload(
          entities: {
            ImportEntityType.dives: [
              {
                'dateTime': diveTime,
                'maxDepth': 25.0,
                'duration': const Duration(minutes: 45),
              },
            ],
          },
        ),
        dives: [
          Dive(
            id: 'existing-1',
            dateTime: diveTime,
            maxDepth: 25.0,
            duration: const Duration(minutes: 45),
          ),
        ],
      );

      expect(result.diveMatches, contains(0));
    });
  });

  group('Empty payload', () {
    test('returns no duplicates for empty payload', () {
      final result = checkWith(
        payload: const ImportPayload(entities: {}),
        trips: [
          Trip(
            id: '1',
            name: 'Trip',
            startDate: now,
            endDate: now,
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );

      expect(result.hasDuplicates, isFalse);
    });
  });

  group('Full check across all types', () {
    test('detects duplicates in multiple entity types', () {
      final diveTime = DateTime(2024, 1, 15, 10, 0);
      final result = checkWith(
        payload: ImportPayload(
          entities: {
            ImportEntityType.trips: const [
              {'name': 'Egypt'},
            ],
            ImportEntityType.buddies: const [
              {'name': 'Alice'},
            ],
            ImportEntityType.dives: [
              {
                'dateTime': diveTime,
                'maxDepth': 25.0,
                'runtime': const Duration(minutes: 45),
              },
            ],
          },
        ),
        trips: [
          Trip(
            id: '1',
            name: 'Egypt',
            startDate: now,
            endDate: now,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        buddies: [
          Buddy(id: '1', name: 'Alice', createdAt: now, updatedAt: now),
        ],
        dives: [
          Dive(
            id: 'dive-1',
            dateTime: diveTime,
            maxDepth: 25.0,
            duration: const Duration(minutes: 45),
          ),
        ],
      );

      expect(result.hasDuplicates, isTrue);
      expect(result.duplicates[ImportEntityType.trips], {0});
      expect(result.duplicates[ImportEntityType.buddies], {0});
      expect(result.diveMatches, contains(0));
    });
  });
}
