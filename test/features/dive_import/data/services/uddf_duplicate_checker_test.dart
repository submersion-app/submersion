import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export_service.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_import/data/services/uddf_duplicate_checker.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

void main() {
  const checker = UddfDuplicateChecker();
  final now = DateTime(2024, 1, 15);

  group('UddfDuplicateCheckResult', () {
    test('empty result has no duplicates', () {
      const result = UddfDuplicateCheckResult();
      expect(result.hasDuplicates, isFalse);
      expect(result.totalDuplicates, 0);
    });

    test('hasDuplicates is true when any set is non-empty', () {
      const result = UddfDuplicateCheckResult(duplicateTrips: {0});
      expect(result.hasDuplicates, isTrue);
      expect(result.totalDuplicates, 1);
    });

    test('totalDuplicates sums all categories', () {
      const result = UddfDuplicateCheckResult(
        duplicateTrips: {0},
        duplicateSites: {1, 2},
        duplicateBuddies: {0},
        diveMatches: {
          0: DiveMatchResult(
            diveId: 'dive-1',
            score: 0.8,
            timeDifferenceMs: 100,
          ),
        },
      );
      expect(result.totalDuplicates, 5);
    });
  });

  group('Name-based duplicates', () {
    test('finds trip duplicates by name (case-insensitive)', () {
      const importData = UddfImportResult(
        trips: [
          {'name': 'Red Sea Trip'},
          {'name': 'Bonaire Adventure'},
          {'name': 'red sea trip'}, // duplicate of index 0
        ],
      );

      final existingTrips = [
        Trip(
          id: '1',
          name: 'Red Sea Trip',
          startDate: now,
          endDate: now,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final result = checker.check(
        importData: importData,
        existingTrips: existingTrips,
        existingSites: [],
        existingEquipment: [],
        existingBuddies: [],
        existingDiveCenters: [],
        existingCertifications: [],
        existingTags: [],
        existingDiveTypes: [],
        existingDives: [],
      );

      expect(result.duplicateTrips, {0, 2});
    });

    test('finds buddy duplicates by name', () {
      const importData = UddfImportResult(
        buddies: [
          {'name': 'Alice'},
          {'name': 'Bob'},
          {'name': 'alice'}, // duplicate
        ],
      );

      final existingBuddies = [
        Buddy(id: '1', name: 'Alice', createdAt: now, updatedAt: now),
      ];

      final result = checker.check(
        importData: importData,
        existingTrips: [],
        existingSites: [],
        existingEquipment: [],
        existingBuddies: existingBuddies,
        existingDiveCenters: [],
        existingCertifications: [],
        existingTags: [],
        existingDiveTypes: [],
        existingDives: [],
      );

      expect(result.duplicateBuddies, {0, 2});
    });

    test('finds dive center duplicates by name', () {
      const importData = UddfImportResult(
        diveCenters: [
          {'name': 'Blue Dive Shop'},
          {'name': 'Ocean Center'},
        ],
      );

      final existingCenters = [
        DiveCenter(
          id: '1',
          name: 'blue dive shop',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final result = checker.check(
        importData: importData,
        existingTrips: [],
        existingSites: [],
        existingEquipment: [],
        existingBuddies: [],
        existingDiveCenters: existingCenters,
        existingCertifications: [],
        existingTags: [],
        existingDiveTypes: [],
        existingDives: [],
      );

      expect(result.duplicateDiveCenters, {0});
    });

    test('finds tag duplicates by name', () {
      const importData = UddfImportResult(
        tags: [
          {'name': 'Night Dive'},
          {'name': 'Training'},
        ],
      );

      final existingTags = [
        Tag(id: '1', name: 'Night Dive', createdAt: now, updatedAt: now),
      ];

      final result = checker.check(
        importData: importData,
        existingTrips: [],
        existingSites: [],
        existingEquipment: [],
        existingBuddies: [],
        existingDiveCenters: [],
        existingCertifications: [],
        existingTags: existingTags,
        existingDiveTypes: [],
        existingDives: [],
      );

      expect(result.duplicateTags, {0});
    });

    test('skips items with null name', () {
      const importData = UddfImportResult(
        trips: [
          {'name': null},
          {'name': 'Red Sea Trip'},
        ],
      );

      final existingTrips = [
        Trip(
          id: '1',
          name: 'Red Sea Trip',
          startDate: now,
          endDate: now,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final result = checker.check(
        importData: importData,
        existingTrips: existingTrips,
        existingSites: [],
        existingEquipment: [],
        existingBuddies: [],
        existingDiveCenters: [],
        existingCertifications: [],
        existingTags: [],
        existingDiveTypes: [],
        existingDives: [],
      );

      expect(result.duplicateTrips, {1});
    });
  });

  group('Site duplicates', () {
    test('finds site duplicates by name', () {
      const importData = UddfImportResult(
        sites: [
          {'name': 'Blue Hole'},
          {'name': 'Shark Point'},
        ],
      );

      final existingSites = [const DiveSite(id: '1', name: 'Blue Hole')];

      final result = checker.check(
        importData: importData,
        existingTrips: [],
        existingSites: existingSites,
        existingEquipment: [],
        existingBuddies: [],
        existingDiveCenters: [],
        existingCertifications: [],
        existingTags: [],
        existingDiveTypes: [],
        existingDives: [],
      );

      expect(result.duplicateSites, {0});
    });

    test('finds site duplicates by lat/lon proximity within 100m', () {
      const importData = UddfImportResult(
        sites: [
          {
            'name': 'Different Name',
            'latitude': 27.2001, // ~11m from existing
            'longitude': 33.8601,
          },
          {
            'name': 'Far Away Site',
            'latitude': 28.0, // far from existing
            'longitude': 34.0,
          },
        ],
      );

      final existingSites = [
        const DiveSite(
          id: '1',
          name: 'Existing Site',
          location: GeoPoint(27.2, 33.86),
        ),
      ];

      final result = checker.check(
        importData: importData,
        existingTrips: [],
        existingSites: existingSites,
        existingEquipment: [],
        existingBuddies: [],
        existingDiveCenters: [],
        existingCertifications: [],
        existingTags: [],
        existingDiveTypes: [],
        existingDives: [],
      );

      expect(result.duplicateSites, {0});
    });

    test('does not flag site >100m away as duplicate', () {
      const importData = UddfImportResult(
        sites: [
          {
            'name': 'Different Name',
            'latitude': 27.21, // ~1.1km from existing
            'longitude': 33.86,
          },
        ],
      );

      final existingSites = [
        const DiveSite(
          id: '1',
          name: 'Existing Site',
          location: GeoPoint(27.2, 33.86),
        ),
      ];

      final result = checker.check(
        importData: importData,
        existingTrips: [],
        existingSites: existingSites,
        existingEquipment: [],
        existingBuddies: [],
        existingDiveCenters: [],
        existingCertifications: [],
        existingTags: [],
        existingDiveTypes: [],
        existingDives: [],
      );

      expect(result.duplicateSites, isEmpty);
    });

    test('name match takes priority over lat/lon check', () {
      const importData = UddfImportResult(
        sites: [
          {'name': 'Blue Hole', 'latitude': 28.0, 'longitude': 34.0},
        ],
      );

      final existingSites = [
        const DiveSite(
          id: '1',
          name: 'Blue Hole',
          location: GeoPoint(27.2, 33.86), // far away coords
        ),
      ];

      final result = checker.check(
        importData: importData,
        existingTrips: [],
        existingSites: existingSites,
        existingEquipment: [],
        existingBuddies: [],
        existingDiveCenters: [],
        existingCertifications: [],
        existingTags: [],
        existingDiveTypes: [],
        existingDives: [],
      );

      // Matched by name, not coords
      expect(result.duplicateSites, {0});
    });
  });

  group('Equipment duplicates', () {
    test('finds equipment duplicates by name + type', () {
      const importData = UddfImportResult(
        equipment: [
          {'name': 'Apex XTX50', 'type': EquipmentType.regulator},
          {'name': 'Apex XTX50', 'type': EquipmentType.bcd}, // different type
          {'name': 'ScubaPro MK25', 'type': EquipmentType.regulator},
        ],
      );

      final existingEquipment = [
        const EquipmentItem(
          id: '1',
          name: 'Apex XTX50',
          type: EquipmentType.regulator,
        ),
      ];

      final result = checker.check(
        importData: importData,
        existingTrips: [],
        existingSites: [],
        existingEquipment: existingEquipment,
        existingBuddies: [],
        existingDiveCenters: [],
        existingCertifications: [],
        existingTags: [],
        existingDiveTypes: [],
        existingDives: [],
      );

      expect(result.duplicateEquipment, {0}); // Only name+type match
    });

    test('handles string equipment type', () {
      const importData = UddfImportResult(
        equipment: [
          {'name': 'Apex XTX50', 'type': 'regulator'},
        ],
      );

      final existingEquipment = [
        const EquipmentItem(
          id: '1',
          name: 'Apex XTX50',
          type: EquipmentType.regulator,
        ),
      ];

      final result = checker.check(
        importData: importData,
        existingTrips: [],
        existingSites: [],
        existingEquipment: existingEquipment,
        existingBuddies: [],
        existingDiveCenters: [],
        existingCertifications: [],
        existingTags: [],
        existingDiveTypes: [],
        existingDives: [],
      );

      expect(result.duplicateEquipment, {0});
    });

    test('null type defaults to other', () {
      const importData = UddfImportResult(
        equipment: [
          {'name': 'Mystery Gear', 'type': null},
        ],
      );

      final existingEquipment = [
        const EquipmentItem(
          id: '1',
          name: 'Mystery Gear',
          type: EquipmentType.other,
        ),
      ];

      final result = checker.check(
        importData: importData,
        existingTrips: [],
        existingSites: [],
        existingEquipment: existingEquipment,
        existingBuddies: [],
        existingDiveCenters: [],
        existingCertifications: [],
        existingTags: [],
        existingDiveTypes: [],
        existingDives: [],
      );

      expect(result.duplicateEquipment, {0});
    });
  });

  group('Certification duplicates', () {
    test('finds certification duplicates by name + agency', () {
      const importData = UddfImportResult(
        certifications: [
          {'name': 'Open Water', 'agency': CertificationAgency.padi},
          {'name': 'Open Water', 'agency': CertificationAgency.ssi},
          {'name': 'Advanced', 'agency': CertificationAgency.padi},
        ],
      );

      final existingCerts = [
        Certification(
          id: '1',
          name: 'Open Water',
          agency: CertificationAgency.padi,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final result = checker.check(
        importData: importData,
        existingTrips: [],
        existingSites: [],
        existingEquipment: [],
        existingBuddies: [],
        existingDiveCenters: [],
        existingCertifications: existingCerts,
        existingTags: [],
        existingDiveTypes: [],
        existingDives: [],
      );

      // Only name + same agency matches
      expect(result.duplicateCertifications, {0});
    });

    test('handles string agency', () {
      const importData = UddfImportResult(
        certifications: [
          {'name': 'Open Water', 'agency': 'padi'},
        ],
      );

      final existingCerts = [
        Certification(
          id: '1',
          name: 'Open Water',
          agency: CertificationAgency.padi,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final result = checker.check(
        importData: importData,
        existingTrips: [],
        existingSites: [],
        existingEquipment: [],
        existingBuddies: [],
        existingDiveCenters: [],
        existingCertifications: existingCerts,
        existingTags: [],
        existingDiveTypes: [],
        existingDives: [],
      );

      expect(result.duplicateCertifications, {0});
    });

    test('skips certification with null agency', () {
      const importData = UddfImportResult(
        certifications: [
          {'name': 'Open Water', 'agency': null},
        ],
      );

      final existingCerts = [
        Certification(
          id: '1',
          name: 'Open Water',
          agency: CertificationAgency.padi,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final result = checker.check(
        importData: importData,
        existingTrips: [],
        existingSites: [],
        existingEquipment: [],
        existingBuddies: [],
        existingDiveCenters: [],
        existingCertifications: existingCerts,
        existingTags: [],
        existingDiveTypes: [],
        existingDives: [],
      );

      expect(result.duplicateCertifications, isEmpty);
    });
  });

  group('Dive type duplicates', () {
    test('finds dive type duplicates by name', () {
      const importData = UddfImportResult(
        customDiveTypes: [
          {'name': 'Sidemount', 'id': 'sidemount'},
          {'name': 'Cave', 'id': 'cave'},
        ],
      );

      final existingTypes = [
        DiveTypeEntity(
          id: 'sidemount',
          name: 'Sidemount',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final result = checker.check(
        importData: importData,
        existingTrips: [],
        existingSites: [],
        existingEquipment: [],
        existingBuddies: [],
        existingDiveCenters: [],
        existingCertifications: [],
        existingTags: [],
        existingDiveTypes: existingTypes,
        existingDives: [],
      );

      expect(result.duplicateDiveTypes, {0});
    });

    test('finds dive type duplicates by slug ID', () {
      const importData = UddfImportResult(
        customDiveTypes: [
          {'name': 'Side Mount', 'id': 'sidemount'},
        ],
      );

      final existingTypes = [
        DiveTypeEntity(
          id: 'sidemount',
          name: 'Sidemount Diving', // different name
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final result = checker.check(
        importData: importData,
        existingTrips: [],
        existingSites: [],
        existingEquipment: [],
        existingBuddies: [],
        existingDiveCenters: [],
        existingCertifications: [],
        existingTags: [],
        existingDiveTypes: existingTypes,
        existingDives: [],
      );

      // Matched by ID even though name differs
      expect(result.duplicateDiveTypes, {0});
    });
  });

  group('Dive duplicates (fuzzy matching)', () {
    test('finds probable dive match', () {
      final diveTime = DateTime(2024, 1, 15, 10, 0);

      final importData = UddfImportResult(
        dives: [
          {
            'dateTime': diveTime,
            'maxDepth': 25.0,
            'runtime': const Duration(minutes: 45),
          },
        ],
      );

      final existingDives = [
        Dive(
          id: 'existing-1',
          dateTime: diveTime.add(const Duration(minutes: 1)),
          maxDepth: 25.5,
          duration: const Duration(minutes: 44),
        ),
      ];

      final result = checker.check(
        importData: importData,
        existingTrips: [],
        existingSites: [],
        existingEquipment: [],
        existingBuddies: [],
        existingDiveCenters: [],
        existingCertifications: [],
        existingTags: [],
        existingDiveTypes: [],
        existingDives: existingDives,
      );

      expect(result.diveMatches, contains(0));
      expect(result.diveMatches[0]!.diveId, 'existing-1');
      expect(result.diveMatches[0]!.score, greaterThanOrEqualTo(0.5));
    });

    test('no match for very different dives', () {
      final importData = UddfImportResult(
        dives: [
          {
            'dateTime': DateTime(2024, 1, 15, 10, 0),
            'maxDepth': 25.0,
            'runtime': const Duration(minutes: 45),
          },
        ],
      );

      final existingDives = [
        Dive(
          id: 'existing-1',
          dateTime: DateTime(2024, 6, 1, 14, 0), // very different time
          maxDepth: 10.0,
          duration: const Duration(minutes: 20),
        ),
      ];

      final result = checker.check(
        importData: importData,
        existingTrips: [],
        existingSites: [],
        existingEquipment: [],
        existingBuddies: [],
        existingDiveCenters: [],
        existingCertifications: [],
        existingTags: [],
        existingDiveTypes: [],
        existingDives: existingDives,
      );

      expect(result.diveMatches, isEmpty);
    });

    test('skips dive with null dateTime', () {
      const importData = UddfImportResult(
        dives: [
          {
            'dateTime': null,
            'maxDepth': 25.0,
            'runtime': Duration(minutes: 45),
          },
        ],
      );

      final existingDives = [
        Dive(
          id: 'existing-1',
          dateTime: DateTime(2024, 1, 15, 10, 0),
          maxDepth: 25.0,
          duration: const Duration(minutes: 45),
        ),
      ];

      final result = checker.check(
        importData: importData,
        existingTrips: [],
        existingSites: [],
        existingEquipment: [],
        existingBuddies: [],
        existingDiveCenters: [],
        existingCertifications: [],
        existingTags: [],
        existingDiveTypes: [],
        existingDives: existingDives,
      );

      expect(result.diveMatches, isEmpty);
    });

    test('picks best match when multiple existing dives are similar', () {
      final diveTime = DateTime(2024, 1, 15, 10, 0);

      final importData = UddfImportResult(
        dives: [
          {
            'dateTime': diveTime,
            'maxDepth': 25.0,
            'runtime': const Duration(minutes: 45),
          },
        ],
      );

      final existingDives = [
        Dive(
          id: 'close-match',
          dateTime: diveTime.add(const Duration(seconds: 30)),
          maxDepth: 25.0,
          duration: const Duration(minutes: 45),
        ),
        Dive(
          id: 'okay-match',
          dateTime: diveTime.add(const Duration(minutes: 5)),
          maxDepth: 24.0,
          duration: const Duration(minutes: 43),
        ),
      ];

      final result = checker.check(
        importData: importData,
        existingTrips: [],
        existingSites: [],
        existingEquipment: [],
        existingBuddies: [],
        existingDiveCenters: [],
        existingCertifications: [],
        existingTags: [],
        existingDiveTypes: [],
        existingDives: existingDives,
      );

      expect(result.diveMatches[0]!.diveId, 'close-match');
    });

    test('uses duration field as fallback for runtime', () {
      final diveTime = DateTime(2024, 1, 15, 10, 0);

      final importData = UddfImportResult(
        dives: [
          {
            'dateTime': diveTime,
            'maxDepth': 25.0,
            'duration': const Duration(minutes: 45),
          },
        ],
      );

      final existingDives = [
        Dive(
          id: 'existing-1',
          dateTime: diveTime,
          maxDepth: 25.0,
          duration: const Duration(minutes: 45),
        ),
      ];

      final result = checker.check(
        importData: importData,
        existingTrips: [],
        existingSites: [],
        existingEquipment: [],
        existingBuddies: [],
        existingDiveCenters: [],
        existingCertifications: [],
        existingTags: [],
        existingDiveTypes: [],
        existingDives: existingDives,
      );

      expect(result.diveMatches, contains(0));
    });

    test('returns empty map when no existing dives', () {
      final importData = UddfImportResult(
        dives: [
          {
            'dateTime': DateTime(2024, 1, 15, 10, 0),
            'maxDepth': 25.0,
            'runtime': const Duration(minutes: 45),
          },
        ],
      );

      final result = checker.check(
        importData: importData,
        existingTrips: [],
        existingSites: [],
        existingEquipment: [],
        existingBuddies: [],
        existingDiveCenters: [],
        existingCertifications: [],
        existingTags: [],
        existingDiveTypes: [],
        existingDives: [],
      );

      expect(result.diveMatches, isEmpty);
    });
  });

  group('Full check with multiple entity types', () {
    test('detects duplicates across all entity types', () {
      final diveTime = DateTime(2024, 1, 15, 10, 0);

      final importData = UddfImportResult(
        trips: [
          {'name': 'Egypt Trip'},
        ],
        sites: [
          {'name': 'Blue Hole'},
        ],
        equipment: [
          {'name': 'My Reg', 'type': EquipmentType.regulator},
        ],
        buddies: [
          {'name': 'Alice'},
        ],
        diveCenters: [
          {'name': 'Blue Dive'},
        ],
        certifications: [
          {'name': 'OW', 'agency': CertificationAgency.padi},
        ],
        tags: [
          {'name': 'Night'},
        ],
        customDiveTypes: [
          {'name': 'Cave', 'id': 'cave'},
        ],
        dives: [
          {
            'dateTime': diveTime,
            'maxDepth': 25.0,
            'runtime': const Duration(minutes: 45),
          },
        ],
      );

      final result = checker.check(
        importData: importData,
        existingTrips: [
          Trip(
            id: '1',
            name: 'Egypt Trip',
            startDate: now,
            endDate: now,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        existingSites: [const DiveSite(id: '1', name: 'Blue Hole')],
        existingEquipment: [
          const EquipmentItem(
            id: '1',
            name: 'My Reg',
            type: EquipmentType.regulator,
          ),
        ],
        existingBuddies: [
          Buddy(id: '1', name: 'Alice', createdAt: now, updatedAt: now),
        ],
        existingDiveCenters: [
          DiveCenter(
            id: '1',
            name: 'Blue Dive',
            createdAt: now,
            updatedAt: now,
          ),
        ],
        existingCertifications: [
          Certification(
            id: '1',
            name: 'OW',
            agency: CertificationAgency.padi,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        existingTags: [
          Tag(id: '1', name: 'Night', createdAt: now, updatedAt: now),
        ],
        existingDiveTypes: [
          DiveTypeEntity(
            id: 'cave',
            name: 'Cave',
            createdAt: now,
            updatedAt: now,
          ),
        ],
        existingDives: [
          Dive(
            id: 'dive-1',
            dateTime: diveTime,
            maxDepth: 25.0,
            duration: const Duration(minutes: 45),
          ),
        ],
      );

      expect(result.hasDuplicates, isTrue);
      expect(result.duplicateTrips, {0});
      expect(result.duplicateSites, {0});
      expect(result.duplicateEquipment, {0});
      expect(result.duplicateBuddies, {0});
      expect(result.duplicateDiveCenters, {0});
      expect(result.duplicateCertifications, {0});
      expect(result.duplicateTags, {0});
      expect(result.duplicateDiveTypes, {0});
      expect(result.diveMatches, contains(0));
    });
  });
}
