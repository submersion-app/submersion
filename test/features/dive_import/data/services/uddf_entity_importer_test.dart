import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/core/constants/enums.dart';
// Only the companion: database.dart also exports Drift row classes whose
// names collide with the domain entities this test imports (DiveSite, Dive,
// Buddy, Tag, Trip, ...).
import 'package:submersion/core/database/database.dart' show DiveSitesCompanion;
import 'package:submersion/core/services/export/export_service.dart'
    hide ServiceRecord;
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/parsers/subsurface_xml_parser.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_roles/data/repositories/dive_role_repository.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/courses/data/repositories/course_repository.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/import_wizard/domain/models/import_phase.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_types/data/repositories/dive_type_repository.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/service_record_repository.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart'
    show ServiceRecord;
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

@GenerateMocks([
  DiveRoleRepository,
  TripRepository,
  EquipmentRepository,
  EquipmentSetRepository,
  BuddyRepository,
  DiveCenterRepository,
  CertificationRepository,
  TagRepository,
  DiveTypeRepository,
  SiteRepository,
  DiveRepository,
  TankPressureRepository,
  CourseRepository,
  ServiceRecordRepository,
])
import 'uddf_entity_importer_test.mocks.dart';

void main() {
  final importer = UddfEntityImporter();
  const diverId = 'diver-123';
  final now = DateTime(2024, 1, 15);

  late MockTripRepository mockTripRepo;
  late MockEquipmentRepository mockEquipmentRepo;
  late MockEquipmentSetRepository mockEquipmentSetRepo;
  late MockBuddyRepository mockBuddyRepo;
  late MockDiveCenterRepository mockDiveCenterRepo;
  late MockCertificationRepository mockCertificationRepo;
  late MockTagRepository mockTagRepo;
  late MockDiveTypeRepository mockDiveTypeRepo;
  late MockDiveRoleRepository mockDiveRoleRepo;
  late MockSiteRepository mockSiteRepo;
  late MockDiveRepository mockDiveRepo;
  late MockTankPressureRepository mockTankPressureRepo;
  late MockCourseRepository mockCourseRepo;
  late MockServiceRecordRepository mockServiceRecordRepo;
  late ImportRepositories repos;

  setUp(() {
    mockTripRepo = MockTripRepository();
    mockEquipmentRepo = MockEquipmentRepository();
    mockEquipmentSetRepo = MockEquipmentSetRepository();
    mockBuddyRepo = MockBuddyRepository();
    mockDiveCenterRepo = MockDiveCenterRepository();
    mockCertificationRepo = MockCertificationRepository();
    mockTagRepo = MockTagRepository();
    mockDiveTypeRepo = MockDiveTypeRepository();
    mockDiveRoleRepo = MockDiveRoleRepository();
    mockSiteRepo = MockSiteRepository();
    mockDiveRepo = MockDiveRepository();
    mockTankPressureRepo = MockTankPressureRepository();
    mockCourseRepo = MockCourseRepository();
    mockServiceRecordRepo = MockServiceRecordRepository();

    // No dive type exists yet, so every imported type is created. The
    // importer consults this to avoid duplicating a built-in slug.
    when(mockDiveTypeRepo.getDiveTypeById(any)).thenAnswer((_) async => null);

    // No tag exists yet, so every imported tag is created. The importer
    // consults this to reuse a tag the diver already has by that name
    // instead of minting a second uuid for it (#1032).
    when(
      mockTagRepo.getTagByName(any, diverId: anyNamed('diverId')),
    ).thenAnswer((_) async => null);

    // Stub getNextDiveNumber for auto-numbering during import.
    when(
      mockDiveRepo.getNextDiveNumber(diverId: anyNamed('diverId')),
    ).thenAnswer((_) async => 1);

    // Stub getAllSites for deselected-site resolution.
    when(
      mockSiteRepo.getAllSites(diverId: anyNamed('diverId')),
    ).thenAnswer((_) async => []);

    repos = ImportRepositories(
      tripRepository: mockTripRepo,
      equipmentRepository: mockEquipmentRepo,
      equipmentSetRepository: mockEquipmentSetRepo,
      buddyRepository: mockBuddyRepo,
      diveCenterRepository: mockDiveCenterRepo,
      certificationRepository: mockCertificationRepo,
      tagRepository: mockTagRepo,
      diveTypeRepository: mockDiveTypeRepo,
      diveRoleRepository: mockDiveRoleRepo,
      siteRepository: mockSiteRepo,
      diveRepository: mockDiveRepo,
      tankPressureRepository: mockTankPressureRepo,
      courseRepository: mockCourseRepo,
      serviceRecordRepository: mockServiceRecordRepo,
    );
  });

  group('UddfImportSelections', () {
    test('selectAll creates sets with all indices', () {
      final data = UddfImportResult(
        trips: [
          {'name': 'A'},
          {'name': 'B'},
        ],
        dives: [
          {'dateTime': now},
        ],
        sites: [
          {'name': 'Site'},
        ],
      );

      final selections = UddfImportSelections.selectAll(data);
      expect(selections.trips, {0, 1});
      expect(selections.dives, {0});
      expect(selections.sites, {0});
      expect(selections.buddies, isEmpty);
    });

    test('default constructor has empty sets', () {
      const selections = UddfImportSelections();
      expect(selections.trips, isEmpty);
      expect(selections.dives, isEmpty);
    });
  });

  group('UddfEntityImportResult', () {
    test('total sums all counts', () {
      const result = UddfEntityImportResult(trips: 2, equipment: 3, dives: 5);
      expect(result.total, 10);
    });

    test('summary formats counts correctly', () {
      const result = UddfEntityImportResult(dives: 5, sites: 2);
      expect(result.summary, 'Imported 5 dives, 2 sites');
    });

    test('summary returns no data message when all zero', () {
      const result = UddfEntityImportResult();
      expect(result.summary, 'No data imported');
    });
  });

  group('Import trips', () {
    test('imports selected trips', () async {
      when(mockTripRepo.createTrip(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as Trip,
      );

      const data = UddfImportResult(
        trips: [
          {'name': 'Egypt Trip', 'uddfId': 'trip-1'},
          {'name': 'Bonaire', 'uddfId': 'trip-2'},
          {'name': 'Skip This'},
        ],
      );

      final result = await importer.import(
        data: data,
        selections: const UddfImportSelections(trips: {0, 1}),
        repositories: repos,
        diverId: diverId,
      );

      expect(result.trips, 2);
      verify(mockTripRepo.createTrip(any)).called(2);
    });

    test('skips trips with null or empty name', () async {
      when(mockTripRepo.createTrip(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as Trip,
      );

      const data = UddfImportResult(
        trips: [
          {'name': null},
          {'name': ''},
          {'name': 'Valid Trip'},
        ],
      );

      final result = await importer.import(
        data: data,
        selections: const UddfImportSelections(trips: {0, 1, 2}),
        repositories: repos,
        diverId: diverId,
      );

      expect(result.trips, 1);
      verify(mockTripRepo.createTrip(any)).called(1);
    });
  });

  group('Import dive roles', () {
    test('restores custom roles preserving ids, skipping built-ins and '
        'invalid rows', () async {
      when(
        mockDiveRoleRepo.importDiveRole(
          id: anyNamed('id'),
          name: anyNamed('name'),
          diverId: anyNamed('diverId'),
          sortOrder: anyNamed('sortOrder'),
        ),
      ).thenAnswer((_) async => true);

      const data = UddfImportResult(
        customDiveRoles: [
          {
            'id': 'uuid-1',
            'name': 'Hekkensluiter',
            'sortOrder': 9,
            'isBuiltIn': false,
          },
          {'id': 'buddy', 'name': 'Buddy', 'sortOrder': 0, 'isBuiltIn': true},
          {'id': null, 'name': 'No Id'},
          {'id': 'uuid-2', 'name': ''},
        ],
      );

      await importer.import(
        data: data,
        selections: const UddfImportSelections(),
        repositories: repos,
        diverId: diverId,
      );

      verify(
        mockDiveRoleRepo.importDiveRole(
          id: 'uuid-1',
          name: 'Hekkensluiter',
          diverId: diverId,
          sortOrder: 9,
        ),
      ).called(1);
      verifyNever(
        mockDiveRoleRepo.importDiveRole(
          id: 'buddy',
          name: anyNamed('name'),
          diverId: anyNamed('diverId'),
          sortOrder: anyNamed('sortOrder'),
        ),
      );
    });

    test('a failing role import is swallowed, not fatal', () async {
      when(
        mockDiveRoleRepo.importDiveRole(
          id: anyNamed('id'),
          name: anyNamed('name'),
          diverId: anyNamed('diverId'),
          sortOrder: anyNamed('sortOrder'),
        ),
      ).thenThrow(Exception('boom'));

      const data = UddfImportResult(
        customDiveRoles: [
          {'id': 'uuid-1', 'name': 'Hekkensluiter'},
        ],
      );

      await expectLater(
        importer.import(
          data: data,
          selections: const UddfImportSelections(),
          repositories: repos,
          diverId: diverId,
        ),
        completes,
      );
    });
  });

  group('Import dives (enriched FIT fields)', () {
    setUp(() {
      when(
        mockDiveRepo.createDive(any),
      ).thenAnswer((inv) async => inv.positionalArguments[0] as Dive);
      when(mockDiveRepo.saveComputerReading(any)).thenAnswer((_) async {});
    });

    test('maps recorded ceiling and entry GPS onto the Dive', () async {
      final data = UddfImportResult(
        dives: [
          {
            'dateTime': DateTime.utc(2025, 10, 13, 11, 24, 0),
            'maxDepth': 29.5,
            'avgDepth': 16.0,
            'duration': const Duration(seconds: 3263),
            'runtime': const Duration(seconds: 3600),
            'latitude': 35.815,
            'longitude': 14.451,
            'profile': <Map<String, dynamic>>[
              {'timestamp': 0, 'depth': 1.6, 'ceiling': 0.0},
              {
                'timestamp': 60,
                'depth': 29.5,
                'ceiling': 6.0,
                'tts': 480,
                'ndl': 0,
              },
            ],
          },
        ],
      );

      await importer.import(
        data: data,
        selections: const UddfImportSelections(dives: {0}),
        repositories: repos,
        diverId: diverId,
      );

      final captured = verify(mockDiveRepo.createDive(captureAny)).captured;
      final dive = captured.single as Dive;
      expect(dive.entryLocation, isNotNull);
      expect(dive.entryLocation!.latitude, closeTo(35.815, 1e-9));
      expect(dive.entryLocation!.longitude, closeTo(14.451, 1e-9));
      expect(dive.profile.any((p) => p.ceiling == 6.0), isTrue);
      expect(dive.profile.any((p) => p.tts == 480), isTrue);
    });

    test('maps the dive name from the payload (FIT filename seed)', () async {
      final data = UddfImportResult(
        dives: [
          {
            'name': 'Dos Ojos Cenote Dive (Barbie Line)',
            'dateTime': DateTime.utc(2025, 10, 13, 11, 24, 0),
            'maxDepth': 29.5,
            'duration': const Duration(seconds: 3263),
          },
        ],
      );

      await importer.import(
        data: data,
        selections: const UddfImportSelections(dives: {0}),
        repositories: repos,
        diverId: diverId,
      );

      final dive =
          verify(mockDiveRepo.createDive(captureAny)).captured.single as Dive;
      expect(dive.name, 'Dos Ojos Cenote Dive (Barbie Line)');
    });

    test('leaves the dive unnamed when the payload has no name', () async {
      final data = UddfImportResult(
        dives: [
          {
            'dateTime': DateTime.utc(2025, 10, 13, 11, 24, 0),
            'maxDepth': 29.5,
            'duration': const Duration(seconds: 3263),
          },
        ],
      );

      await importer.import(
        data: data,
        selections: const UddfImportSelections(dives: {0}),
        repositories: repos,
        diverId: diverId,
      );

      final dive =
          verify(mockDiveRepo.createDive(captureAny)).captured.single as Dive;
      expect(dive.name, isNull);
    });
  });

  group('Import equipment', () {
    test('imports equipment with type parsing', () async {
      when(mockEquipmentRepo.createEquipment(any)).thenAnswer(
        (invocation) async =>
            invocation.positionalArguments[0] as EquipmentItem,
      );

      const data = UddfImportResult(
        equipment: [
          {
            'name': 'My Reg',
            'type': EquipmentType.regulator,
            'uddfId': 'equip-1',
          },
          {'name': 'My Fins', 'type': 'fins', 'uddfId': 'equip-2'},
        ],
      );

      final result = await importer.import(
        data: data,
        selections: const UddfImportSelections(equipment: {0, 1}),
        repositories: repos,
        diverId: diverId,
      );

      expect(result.equipment, 2);

      final captured = verify(
        mockEquipmentRepo.createEquipment(captureAny),
      ).captured;
      expect((captured[0] as EquipmentItem).type, EquipmentType.regulator);
      expect((captured[1] as EquipmentItem).type, EquipmentType.fins);
    });
  });

  group('Import buddies', () {
    test('imports selected buddies', () async {
      when(mockBuddyRepo.createBuddy(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as Buddy,
      );

      const data = UddfImportResult(
        buddies: [
          {'name': 'Alice', 'uddfId': 'buddy-1'},
          {'name': 'Bob', 'uddfId': 'buddy-2'},
        ],
      );

      final result = await importer.import(
        data: data,
        selections: const UddfImportSelections(buddies: {0, 1}),
        repositories: repos,
        diverId: diverId,
      );

      expect(result.buddies, 2);
    });
  });

  group('Import dive centers', () {
    test('imports dive centers with affiliations', () async {
      when(mockDiveCenterRepo.createDiveCenter(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as DiveCenter,
      );

      const data = UddfImportResult(
        diveCenters: [
          {
            'name': 'Blue Dive',
            'uddfId': 'center-1',
            'affiliations': ['PADI', 'SSI'],
          },
        ],
      );

      final result = await importer.import(
        data: data,
        selections: const UddfImportSelections(diveCenters: {0}),
        repositories: repos,
        diverId: diverId,
      );

      expect(result.diveCenters, 1);

      final captured = verify(
        mockDiveCenterRepo.createDiveCenter(captureAny),
      ).captured;
      expect((captured[0] as DiveCenter).affiliations, ['PADI', 'SSI']);
    });
  });

  group('Import certifications', () {
    test('imports certifications with agency parsing', () async {
      when(mockCertificationRepo.createCertification(any)).thenAnswer(
        (invocation) async =>
            invocation.positionalArguments[0] as Certification,
      );

      const data = UddfImportResult(
        certifications: [
          {'name': 'Open Water', 'agency': CertificationAgency.padi},
          {'name': 'Advanced', 'agency': 'ssi'},
        ],
      );

      final result = await importer.import(
        data: data,
        selections: const UddfImportSelections(certifications: {0, 1}),
        repositories: repos,
        diverId: diverId,
      );

      expect(result.certifications, 2);

      final captured = verify(
        mockCertificationRepo.createCertification(captureAny),
      ).captured;
      expect((captured[0] as Certification).agency, CertificationAgency.padi);
      expect((captured[1] as Certification).agency, CertificationAgency.ssi);
    });
  });

  group('Import tags', () {
    test('imports tags', () async {
      when(mockTagRepo.createTag(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as Tag,
      );

      const data = UddfImportResult(
        tags: [
          {'name': 'Night Dive', 'uddfId': 'tag-1', 'color': '#FF0000'},
        ],
      );

      final result = await importer.import(
        data: data,
        selections: const UddfImportSelections(tags: {0}),
        repositories: repos,
        diverId: diverId,
      );

      expect(result.tags, 1);

      final captured = verify(mockTagRepo.createTag(captureAny)).captured;
      expect((captured[0] as Tag).colorHex, '#FF0000');
    });

    test('reuses a tag the diver already has by that name (#1032)', () async {
      final existing = Tag(
        id: 'existing-night',
        diverId: diverId,
        name: 'Night Dive',
        createdAt: now,
        updatedAt: now,
      );
      when(
        mockTagRepo.getTagByName('Night Dive', diverId: diverId),
      ).thenAnswer((_) async => existing);
      when(mockTagRepo.addTagToDive(any, any)).thenAnswer((_) async {});
      when(mockDiveRepo.createDive(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as Dive,
      );

      final data = UddfImportResult(
        tags: [
          {'name': 'Night Dive', 'uddfId': 'tag-1'},
        ],
        dives: [
          {
            'dateTime': now,
            'maxDepth': 25.0,
            'tagRefs': ['tag-1'],
          },
        ],
      );

      final result = await importer.import(
        data: data,
        selections: const UddfImportSelections(tags: {0}, dives: {0}),
        repositories: repos,
        diverId: diverId,
      );

      expect(result.tags, 0, reason: 'nothing new was created');
      verifyNever(mockTagRepo.createTag(any));
      verify(mockTagRepo.addTagToDive(any, 'existing-night')).called(1);
    });
  });

  group('Import dive types', () {
    test('imports custom dive types', () async {
      when(mockDiveTypeRepo.createDiveType(any)).thenAnswer(
        (invocation) async =>
            invocation.positionalArguments[0] as DiveTypeEntity,
      );

      const data = UddfImportResult(
        customDiveTypes: [
          {'name': 'Cave Dive', 'id': 'cave', 'isBuiltIn': false},
        ],
      );

      final result = await importer.import(
        data: data,
        selections: const UddfImportSelections(diveTypes: {0}),
        repositories: repos,
        diverId: diverId,
      );

      expect(result.diveTypes, 1);
    });

    test('skips built-in dive types', () async {
      const data = UddfImportResult(
        customDiveTypes: [
          {'name': 'Recreational', 'id': 'recreational', 'isBuiltIn': true},
        ],
      );

      final result = await importer.import(
        data: data,
        selections: const UddfImportSelections(diveTypes: {0}),
        repositories: repos,
        diverId: diverId,
      );

      expect(result.diveTypes, 0);
      verifyNever(mockDiveTypeRepo.createDiveType(any));
    });

    test('catches duplicate dive type errors', () async {
      when(
        mockDiveTypeRepo.createDiveType(any),
      ).thenThrow(Exception('Duplicate'));

      const data = UddfImportResult(
        customDiveTypes: [
          {'name': 'Cave', 'id': 'cave'},
        ],
      );

      final result = await importer.import(
        data: data,
        selections: const UddfImportSelections(diveTypes: {0}),
        repositories: repos,
        diverId: diverId,
      );

      // Error caught, count stays at 0
      expect(result.diveTypes, 0);
    });
  });

  group('Import sites', () {
    test('imports sites', () async {
      when(mockSiteRepo.createSite(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as DiveSite,
      );

      const data = UddfImportResult(
        sites: [
          {
            'name': 'Blue Hole',
            'uddfId': 'site-1',
            'latitude': 27.2,
            'longitude': 33.86,
          },
        ],
      );

      final result = await importer.import(
        data: data,
        selections: const UddfImportSelections(sites: {0}),
        repositories: repos,
        diverId: diverId,
      );

      expect(result.sites, 1);

      final captured = verify(mockSiteRepo.createSite(captureAny)).captured;
      final site = captured[0] as DiveSite;
      expect(site.name, 'Blue Hole');
      expect(site.location, isNotNull);
      expect(site.location!.latitude, 27.2);
    });
  });

  group('Site linking fallback for a GPS-matched duplicate', () {
    // The duplicate checker flags an incoming site as a duplicate on name OR
    // on 100 m proximity, and the wizard then leaves it out of the selection.
    // A site caught by the proximity arm carries a different name, so binding
    // its uddfId by name alone strands every dive that referenced it.
    const existingSite = DiveSite(
      id: 'existing-maclearie',
      diverId: diverId,
      name: 'Maclearie Park',
      location: GeoPoint(40.179561, -74.037475),
    );

    setUp(() {
      when(
        mockSiteRepo.getAllSites(diverId: anyNamed('diverId')),
      ).thenAnswer((_) async => [existingSite]);
      when(mockDiveRepo.createDive(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as Dive,
      );
    });

    test('links the dive to the existing site the duplicate sits on', () async {
      final data = UddfImportResult(
        sites: [
          {
            // Spelled differently, so the name lookup cannot rescue this.
            'name': 'Maclearie Pk',
            'uddfId': 'site-1',
            'latitude': 40.179575,
            'longitude': -74.037466,
          },
        ],
        dives: [
          {
            'dateTime': now,
            'maxDepth': 20.0,
            'site': {'uddfId': 'site-1'},
          },
        ],
      );

      await importer.import(
        data: data,
        selections: const UddfImportSelections(sites: {}, dives: {0}),
        repositories: repos,
        diverId: diverId,
      );

      final captured = verify(mockDiveRepo.createDive(captureAny)).captured;
      final dive = captured[0] as Dive;
      expect(dive.site, isNotNull);
      expect(dive.site!.id, 'existing-maclearie');
    });

    test('leaves the dive unlinked when no existing site is near', () async {
      final data = UddfImportResult(
        sites: [
          {
            'name': 'Somewhere Else',
            'uddfId': 'site-1',
            'latitude': 18.465562,
            'longitude': -66.084902,
          },
        ],
        dives: [
          {
            'dateTime': now,
            'maxDepth': 20.0,
            'site': {'uddfId': 'site-1'},
          },
        ],
      );

      await importer.import(
        data: data,
        selections: const UddfImportSelections(sites: {}, dives: {0}),
        repositories: repos,
        diverId: diverId,
      );

      final captured = verify(mockDiveRepo.createDive(captureAny)).captured;
      final dive = captured[0] as Dive;
      expect(dive.site, isNull);
    });

    test('prefers a name match over a nearer site with another name', () async {
      const sameNameFarther = DiveSite(
        id: 'existing-by-name',
        diverId: diverId,
        name: 'Maclearie Pk',
        location: GeoPoint(40.180561, -74.037475),
      );
      when(
        mockSiteRepo.getAllSites(diverId: anyNamed('diverId')),
      ).thenAnswer((_) async => [existingSite, sameNameFarther]);

      final data = UddfImportResult(
        sites: [
          {
            'name': 'Maclearie Pk',
            'uddfId': 'site-1',
            'latitude': 40.179575,
            'longitude': -74.037466,
          },
        ],
        dives: [
          {
            'dateTime': now,
            'maxDepth': 20.0,
            'site': {'uddfId': 'site-1'},
          },
        ],
      );

      await importer.import(
        data: data,
        selections: const UddfImportSelections(sites: {}, dives: {0}),
        repositories: repos,
        diverId: diverId,
      );

      final captured = verify(mockDiveRepo.createDive(captureAny)).captured;
      final dive = captured[0] as Dive;
      expect(dive.site!.id, 'existing-by-name');
    });
  });

  group('Import sites (siteOverrides / replaceSource)', () {
    // A pre-existing site carrying values the import payload will NOT supply,
    // so tests can assert those survive the overwrite.
    const existingSite = DiveSite(
      id: 'existing-site-1',
      diverId: diverId,
      name: 'Old Name',
      description: 'Old description',
      notes: 'Old notes',
      city: 'Dahab',
      island: 'Sinai',
      country: 'Egypt',
      region: 'South Sinai',
      isShared: true,
      rating: 3.0,
    );

    setUp(() {
      when(
        mockSiteRepo.getAllSites(diverId: anyNamed('diverId')),
      ).thenAnswer((_) async => [existingSite]);
      when(
        mockSiteRepo.updateSiteWithImportedMetadata(any, any),
      ).thenAnswer((_) async {});
    });

    test('updates the matched site in place instead of creating one', () async {
      const data = UddfImportResult(
        sites: [
          {
            'name': 'Blue Hole',
            'uddfId': 'site-1',
            'latitude': 28.57,
            'longitude': 34.53,
            'maxDepth': 100.0,
          },
        ],
      );

      final result = await importer.import(
        data: data,
        selections: const UddfImportSelections(
          siteOverrides: {0: 'existing-site-1'},
        ),
        repositories: repos,
        diverId: diverId,
      );

      expect(result.sites, 1);
      verifyNever(mockSiteRepo.createSite(any));

      final captured = verify(
        mockSiteRepo.updateSiteWithImportedMetadata(captureAny, any),
      ).captured;
      final site = captured[0] as DiveSite;
      expect(site.id, 'existing-site-1', reason: 'must reuse the existing row');
      expect(site.name, 'Blue Hole');
      expect(site.maxDepth, 100.0);
      expect(site.location!.latitude, 28.57);
    });

    test('preserves existing fields the import payload omits', () async {
      const data = UddfImportResult(
        sites: [
          {'name': 'Blue Hole', 'uddfId': 'site-1'},
        ],
      );

      await importer.import(
        data: data,
        selections: const UddfImportSelections(
          siteOverrides: {0: 'existing-site-1'},
        ),
        repositories: repos,
        diverId: diverId,
      );

      final captured = verify(
        mockSiteRepo.updateSiteWithImportedMetadata(captureAny, any),
      ).captured;
      final site = captured[0] as DiveSite;
      // Supplied by the import.
      expect(site.name, 'Blue Hole');
      // Absent from the import -- must survive rather than reset to defaults.
      expect(site.isShared, isTrue);
      expect(site.description, 'Old description');
      expect(site.notes, 'Old notes');
      expect(site.city, 'Dahab');
      expect(site.island, 'Sinai');
      expect(site.rating, 3.0);
    });

    test(
      'passes waterType and bodyOfWater through as a metadata patch',
      () async {
        const data = UddfImportResult(
          sites: [
            {
              'name': 'Blue Hole',
              'uddfId': 'site-1',
              'waterType': 'salt',
              'bodyOfWater': 'Red Sea',
            },
          ],
        );

        await importer.import(
          data: data,
          selections: const UddfImportSelections(
            siteOverrides: {0: 'existing-site-1'},
          ),
          repositories: repos,
          diverId: diverId,
        );

        final captured = verify(
          mockSiteRepo.updateSiteWithImportedMetadata(any, captureAny),
        ).captured;
        final patch = captured[0] as DiveSitesCompanion;
        expect(patch.waterType.value, 'salt');
        expect(patch.bodyOfWater.value, 'Red Sea');
      },
    );

    test(
      'leaves the metadata patch absent when the payload has neither',
      () async {
        const data = UddfImportResult(
          sites: [
            {'name': 'Blue Hole', 'uddfId': 'site-1'},
          ],
        );

        await importer.import(
          data: data,
          selections: const UddfImportSelections(
            siteOverrides: {0: 'existing-site-1'},
          ),
          repositories: repos,
          diverId: diverId,
        );

        final captured = verify(
          mockSiteRepo.updateSiteWithImportedMetadata(any, captureAny),
        ).captured;
        final patch = captured[0] as DiveSitesCompanion;
        expect(patch.waterType.present, isFalse);
        expect(patch.bodyOfWater.present, isFalse);
      },
    );

    test(
      'links dives to the overwritten site via the uddfId mapping',
      () async {
        when(mockDiveRepo.createDive(any)).thenAnswer(
          (invocation) async => invocation.positionalArguments[0] as Dive,
        );

        final data = UddfImportResult(
          sites: const [
            {'name': 'Blue Hole', 'uddfId': 'site-1'},
          ],
          dives: [
            {'dateTime': now, 'maxDepth': 30.0, 'siteId': 'site-1'},
          ],
        );

        await importer.import(
          data: data,
          selections: const UddfImportSelections(
            siteOverrides: {0: 'existing-site-1'},
            dives: {0},
          ),
          repositories: repos,
          diverId: diverId,
        );

        verifyNever(mockSiteRepo.createSite(any));
        final dive =
            verify(mockDiveRepo.createDive(captureAny)).captured.single as Dive;
        expect(dive.site, isNotNull);
        // The dive points at the row that was overwritten, not a fresh one.
        expect(dive.site!.id, 'existing-site-1');
        expect(dive.site!.name, 'Blue Hole');
      },
    );

    test('counts overrides and creations in one progress total', () async {
      when(mockSiteRepo.createSite(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as DiveSite,
      );

      const data = UddfImportResult(
        sites: [
          {'name': 'Blue Hole', 'uddfId': 'site-1'},
          {'name': 'Brand New', 'uddfId': 'site-2'},
        ],
      );

      final progressCalls = <(ImportPhase, int, int)>[];
      final result = await importer.import(
        data: data,
        selections: const UddfImportSelections(
          siteOverrides: {0: 'existing-site-1'},
          sites: {1},
        ),
        repositories: repos,
        diverId: diverId,
        onProgress: (phase, current, total) {
          progressCalls.add((phase, current, total));
        },
      );

      expect(result.sites, 2);
      verify(mockSiteRepo.updateSiteWithImportedMetadata(any, any)).called(1);
      verify(mockSiteRepo.createSite(any)).called(1);

      final siteCalls = progressCalls
          .where((c) => c.$1 == ImportPhase.sites)
          .toList();
      expect(siteCalls.first, (ImportPhase.sites, 0, 2));
      expect(siteCalls.last, (ImportPhase.sites, 2, 2));
    });

    test('skips an override whose target site no longer exists', () async {
      const data = UddfImportResult(
        sites: [
          {'name': 'Blue Hole', 'uddfId': 'site-1'},
        ],
      );

      final result = await importer.import(
        data: data,
        selections: const UddfImportSelections(
          siteOverrides: {0: 'site-that-was-deleted'},
        ),
        repositories: repos,
        diverId: diverId,
      );

      expect(result.sites, 0);
      verifyNever(mockSiteRepo.updateSiteWithImportedMetadata(any, any));
      verifyNever(mockSiteRepo.createSite(any));
    });

    test('skips an override index outside the import list', () async {
      const data = UddfImportResult(
        sites: [
          {'name': 'Blue Hole', 'uddfId': 'site-1'},
        ],
      );

      final result = await importer.import(
        data: data,
        selections: const UddfImportSelections(
          siteOverrides: {5: 'existing-site-1'},
        ),
        repositories: repos,
        diverId: diverId,
      );

      expect(result.sites, 0);
      verifyNever(mockSiteRepo.updateSiteWithImportedMetadata(any, any));
    });

    test('skips an override whose payload has no name', () async {
      const data = UddfImportResult(
        sites: [
          {'uddfId': 'site-1', 'latitude': 28.57},
        ],
      );

      final result = await importer.import(
        data: data,
        selections: const UddfImportSelections(
          siteOverrides: {0: 'existing-site-1'},
        ),
        repositories: repos,
        diverId: diverId,
      );

      expect(result.sites, 0);
      verifyNever(mockSiteRepo.updateSiteWithImportedMetadata(any, any));
    });
  });

  group('Import equipment sets', () {
    test('maps equipment refs to new IDs', () async {
      // First import equipment to build ID mapping
      when(mockEquipmentRepo.createEquipment(any)).thenAnswer(
        (invocation) async =>
            invocation.positionalArguments[0] as EquipmentItem,
      );
      when(mockEquipmentSetRepo.createSet(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as EquipmentSet,
      );

      const data = UddfImportResult(
        equipment: [
          {'name': 'Reg', 'type': EquipmentType.regulator, 'uddfId': 'eq-1'},
          {'name': 'BCD', 'type': EquipmentType.bcd, 'uddfId': 'eq-2'},
        ],
        equipmentSets: [
          {
            'name': 'My Set',
            'equipmentRefs': ['eq-1', 'eq-2'],
          },
        ],
      );

      final result = await importer.import(
        data: data,
        selections: const UddfImportSelections(
          equipment: {0, 1},
          equipmentSets: {0},
        ),
        repositories: repos,
        diverId: diverId,
      );

      expect(result.equipment, 2);
      expect(result.equipmentSets, 1);

      final captured = verify(
        mockEquipmentSetRepo.createSet(captureAny),
      ).captured;
      final set = captured[0] as EquipmentSet;
      expect(set.equipmentIds, hasLength(2));
    });
  });

  group('Import dives', () {
    test('imports basic dive', () async {
      when(mockDiveRepo.createDive(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as Dive,
      );

      final data = UddfImportResult(
        dives: [
          {
            'dateTime': now,
            'maxDepth': 25.0,
            'runtime': const Duration(minutes: 45),
            'notes': 'Test dive',
          },
        ],
      );

      final result = await importer.import(
        data: data,
        selections: const UddfImportSelections(dives: {0}),
        repositories: repos,
        diverId: diverId,
      );

      expect(result.dives, 1);

      final captured = verify(mockDiveRepo.createDive(captureAny)).captured;
      final dive = captured[0] as Dive;
      expect(dive.maxDepth, 25.0);
      expect(dive.notes, 'Test dive');
      expect(dive.diverId, diverId);
    });

    // Subsurface (and similar) parsers set 'duration' and 'runtime' to the same
    // total-time value; that duration is the runtime, not a distinct bottom
    // time. When a profile exists, bottom time must be derived from it, not left
    // equal to runtime. Regression guard for the "bottom time == runtime" bug.
    test(
      'derives bottom time from profile when duration equals runtime',
      () async {
        when(mockDiveRepo.createDive(any)).thenAnswer(
          (invocation) async => invocation.positionalArguments[0] as Dive,
        );

        final data = UddfImportResult(
          dives: [
            {
              'dateTime': now,
              'maxDepth': 30.0,
              // Total dive time in both keys, as Subsurface reports it.
              'duration': const Duration(seconds: 1320),
              'runtime': const Duration(seconds: 1320),
              'profile': [
                {'timestamp': 0, 'depth': 0.0},
                {'timestamp': 60, 'depth': 30.0},
                {'timestamp': 120, 'depth': 30.0},
                {'timestamp': 1200, 'depth': 30.0},
                {'timestamp': 1260, 'depth': 5.0},
                {'timestamp': 1320, 'depth': 0.0},
              ],
            },
          ],
        );

        await importer.import(
          data: data,
          selections: const UddfImportSelections(dives: {0}),
          repositories: repos,
          diverId: diverId,
        );

        final dive =
            verify(mockDiveRepo.createDive(captureAny)).captured.single as Dive;
        // Ascent threshold is min(max(6 m, 33% of 30 m), 85% of 30 m) =
        // 9.9 m; the last sample at/deeper is t=1200 and bottom time runs
        // from surface departure (t=0), so 1200 s, not the 1320 s runtime.
        expect(dive.runtime, const Duration(seconds: 1320));
        expect(dive.bottomTime, const Duration(seconds: 1200));
        expect(dive.bottomTime!, lessThan(dive.runtime!));
      },
    );

    // FIT parsers put a genuine, device-reported bottom time in 'duration'
    // (distinct from 'runtime'). That real value must be preserved, not
    // overwritten by the profile heuristic.
    test(
      'keeps a genuine bottom time when duration differs from runtime',
      () async {
        when(mockDiveRepo.createDive(any)).thenAnswer(
          (invocation) async => invocation.positionalArguments[0] as Dive,
        );

        final data = UddfImportResult(
          dives: [
            {
              'dateTime': now,
              'maxDepth': 30.0,
              'duration': const Duration(seconds: 3263), // real bottom time
              'runtime': const Duration(seconds: 3600), // total elapsed
              'profile': [
                {'timestamp': 0, 'depth': 0.0},
                {'timestamp': 60, 'depth': 30.0},
                {'timestamp': 1200, 'depth': 30.0},
                {'timestamp': 1320, 'depth': 0.0},
              ],
            },
          ],
        );

        await importer.import(
          data: data,
          selections: const UddfImportSelections(dives: {0}),
          repositories: repos,
          diverId: diverId,
        );

        final dive =
            verify(mockDiveRepo.createDive(captureAny)).captured.single as Dive;
        expect(dive.bottomTime, const Duration(seconds: 3263));
        expect(dive.runtime, const Duration(seconds: 3600));
      },
    );

    // Minimal CSV imports carry only a single 'duration' with no profile; that
    // value must still populate bottom time so the field is not left empty.
    test(
      'falls back to duration for bottom time when there is no profile',
      () async {
        when(mockDiveRepo.createDive(any)).thenAnswer(
          (invocation) async => invocation.positionalArguments[0] as Dive,
        );

        final data = UddfImportResult(
          dives: [
            {
              'dateTime': now,
              'maxDepth': 18.0,
              'duration': const Duration(minutes: 42),
            },
          ],
        );

        await importer.import(
          data: data,
          selections: const UddfImportSelections(dives: {0}),
          repositories: repos,
          diverId: diverId,
        );

        final dive =
            verify(mockDiveRepo.createDive(captureAny)).captured.single as Dive;
        expect(dive.bottomTime, const Duration(minutes: 42));
      },
    );

    test('links dive to imported site via ID mapping', () async {
      when(mockSiteRepo.createSite(any)).thenAnswer((invocation) async {
        final site = invocation.positionalArguments[0] as DiveSite;
        return site;
      });
      when(mockDiveRepo.createDive(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as Dive,
      );

      final data = UddfImportResult(
        sites: [
          {'name': 'Blue Hole', 'uddfId': 'site-1'},
        ],
        dives: [
          {
            'dateTime': now,
            'maxDepth': 25.0,
            'site': {'uddfId': 'site-1'},
          },
        ],
      );

      final result = await importer.import(
        data: data,
        selections: const UddfImportSelections(sites: {0}, dives: {0}),
        repositories: repos,
        diverId: diverId,
      );

      expect(result.sites, 1);
      expect(result.dives, 1);

      final captured = verify(mockDiveRepo.createDive(captureAny)).captured;
      final dive = captured[0] as Dive;
      expect(dive.site, isNotNull);
      expect(dive.site!.name, 'Blue Hole');
    });

    test('links dive to imported trip via ID mapping', () async {
      when(mockTripRepo.createTrip(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as Trip,
      );
      when(mockDiveRepo.createDive(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as Dive,
      );

      final data = UddfImportResult(
        trips: [
          {'name': 'Egypt Trip', 'uddfId': 'trip-1'},
        ],
        dives: [
          {'dateTime': now, 'maxDepth': 25.0, 'tripRef': 'trip-1'},
        ],
      );

      final result = await importer.import(
        data: data,
        selections: const UddfImportSelections(trips: {0}, dives: {0}),
        repositories: repos,
        diverId: diverId,
      );

      expect(result.trips, 1);
      expect(result.dives, 1);

      final captured = verify(mockDiveRepo.createDive(captureAny)).captured;
      final dive = captured[0] as Dive;
      expect(dive.tripId, isNotNull);
    });

    test('links buddies to dive', () async {
      when(mockBuddyRepo.createBuddy(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as Buddy,
      );
      when(
        mockBuddyRepo.addBuddyToDive(any, any, any),
      ).thenAnswer((_) async {});
      when(mockDiveRepo.createDive(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as Dive,
      );

      final data = UddfImportResult(
        buddies: [
          {'name': 'Alice', 'uddfId': 'buddy-1'},
        ],
        dives: [
          {
            'dateTime': now,
            'maxDepth': 25.0,
            'buddyRefs': ['buddy-1'],
          },
        ],
      );

      await importer.import(
        data: data,
        selections: const UddfImportSelections(buddies: {0}, dives: {0}),
        repositories: repos,
        diverId: diverId,
      );

      verify(
        mockBuddyRepo.addBuddyToDive(any, any, DiveRole.buddyId),
      ).called(1);
    });

    test('preResolvedBuddyIds links a skipped duplicate buddy to the existing '
        'record without creating a twin (#756)', () async {
      when(
        mockBuddyRepo.addBuddyToDive(any, any, any),
      ).thenAnswer((_) async {});
      when(mockDiveRepo.createDive(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as Dive,
      );

      final data = UddfImportResult(
        buddies: [
          {'name': 'Nathalie', 'uddfId': 'Nathalie'},
        ],
        dives: [
          {
            'dateTime': now,
            'maxDepth': 25.0,
            'buddyRefs': ['Nathalie'],
          },
        ],
      );

      await importer.import(
        data: data,
        // The buddy index is NOT selected: the reviewer chose Skip (or
        // Link to existing) for the flagged duplicate.
        selections: const UddfImportSelections(dives: {0}),
        repositories: repos,
        diverId: diverId,
        preResolvedBuddyIds: const {'Nathalie': 'existing-1'},
      );

      verifyNever(mockBuddyRepo.createBuddy(any));
      verify(
        mockBuddyRepo.addBuddyToDive(any, 'existing-1', DiveRole.buddyId),
      ).called(1);
    });

    test('preResolvedTagIds links a skipped duplicate tag to the existing '
        'record without creating a twin (#756)', () async {
      when(mockTagRepo.addTagToDive(any, any)).thenAnswer((_) async {});
      when(mockDiveRepo.createDive(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as Dive,
      );

      final data = UddfImportResult(
        tags: [
          {'name': 'Night', 'uddfId': 'Night'},
        ],
        dives: [
          {
            'dateTime': now,
            'maxDepth': 25.0,
            'tagRefs': ['Night'],
          },
        ],
      );

      await importer.import(
        data: data,
        selections: const UddfImportSelections(dives: {0}),
        repositories: repos,
        diverId: diverId,
        preResolvedTagIds: const {'Night': 'existing-tag-1'},
      );

      verifyNever(mockTagRepo.createTag(any));
      verify(mockTagRepo.addTagToDive(any, 'existing-tag-1')).called(1);
    });

    test('creates inline buddies for unmatched names', () async {
      final inlineBuddy = Buddy(
        id: 'inline-1',
        name: 'Charlie',
        createdAt: now,
        updatedAt: now,
      );
      when(
        mockBuddyRepo.findOrCreateByName('Charlie'),
      ).thenAnswer((_) async => inlineBuddy);
      when(
        mockBuddyRepo.addBuddyToDive(any, any, any),
      ).thenAnswer((_) async {});
      when(mockDiveRepo.createDive(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as Dive,
      );

      final data = UddfImportResult(
        dives: [
          {
            'dateTime': now,
            'maxDepth': 25.0,
            'unmatchedBuddyNames': ['Charlie'],
          },
        ],
      );

      final result = await importer.import(
        data: data,
        selections: const UddfImportSelections(dives: {0}),
        repositories: repos,
        diverId: diverId,
      );

      // Inline buddy counted in buddies total
      expect(result.buddies, 1);
      verify(mockBuddyRepo.findOrCreateByName('Charlie')).called(1);
    });

    test('links tags to dive', () async {
      when(mockTagRepo.createTag(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as Tag,
      );
      when(mockTagRepo.addTagToDive(any, any)).thenAnswer((_) async {});
      when(mockDiveRepo.createDive(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as Dive,
      );

      final data = UddfImportResult(
        tags: [
          {'name': 'Night Dive', 'uddfId': 'tag-1'},
        ],
        dives: [
          {
            'dateTime': now,
            'maxDepth': 25.0,
            'tagRefs': ['tag-1'],
          },
        ],
      );

      await importer.import(
        data: data,
        selections: const UddfImportSelections(tags: {0}, dives: {0}),
        repositories: repos,
        diverId: diverId,
      );

      verify(mockTagRepo.addTagToDive(any, any)).called(1);
    });

    test('imports a weight total as a DiveWeight, not as notes text', () async {
      when(mockDiveRepo.createDive(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as Dive,
      );

      final data = UddfImportResult(
        dives: [
          {
            'dateTime': now,
            'maxDepth': 25.0,
            'notes': 'Great dive',
            'weightUsed': 4.5,
          },
        ],
      );

      await importer.import(
        data: data,
        selections: const UddfImportSelections(dives: {0}),
        repositories: repos,
        diverId: diverId,
      );

      final captured = verify(mockDiveRepo.createDive(captureAny)).captured;
      final dive = captured[0] as Dive;
      expect(dive.weights, hasLength(1));
      expect(dive.weights.single.amountKg, 4.5);
      expect(dive.weights.single.diveId, dive.id);
      // #912: the value belongs in the Weights section, and the user's own
      // notes must come through untouched.
      expect(dive.notes, 'Great dive');
    });

    test('weightAmount is imported as a DiveWeight too', () async {
      when(mockDiveRepo.createDive(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as Dive,
      );

      final data = UddfImportResult(
        dives: [
          {'dateTime': now, 'maxDepth': 25.0, 'weightAmount': 6.0},
        ],
      );

      await importer.import(
        data: data,
        selections: const UddfImportSelections(dives: {0}),
        repositories: repos,
        diverId: diverId,
      );

      final captured = verify(mockDiveRepo.createDive(captureAny)).captured;
      final dive = captured[0] as Dive;
      expect(dive.weights, hasLength(1));
      expect(dive.weights.single.amountKg, 6.0);
    });

    test('an explicit weights breakdown wins over the total', () async {
      when(mockDiveRepo.createDive(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as Dive,
      );

      final data = UddfImportResult(
        dives: [
          {
            'dateTime': now,
            'weightUsed': 9.0,
            'weights': <Map<String, dynamic>>[
              {'type': WeightType.belt, 'amount': 4.0},
              {'type': WeightType.trimWeights, 'amount': 2.0},
            ],
          },
        ],
      );

      await importer.import(
        data: data,
        selections: const UddfImportSelections(dives: {0}),
        repositories: repos,
        diverId: diverId,
      );

      final captured = verify(mockDiveRepo.createDive(captureAny)).captured;
      final dive = captured[0] as Dive;
      expect(dive.weights, hasLength(2));
      expect(dive.weights.map((w) => w.amountKg), [4.0, 2.0]);
    });

    test('persists profile heart rate from imported UDDF samples', () async {
      when(mockDiveRepo.createDive(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as Dive,
      );

      final data = UddfImportResult(
        dives: [
          {
            'dateTime': now,
            'maxDepth': 25.0,
            'profile': [
              {'timestamp': 0, 'depth': 0.0, 'heartRate': 72},
              {'timestamp': 60, 'depth': 12.0},
              {'timestamp': 120, 'depth': 5.0, 'heartRate': 84},
            ],
          },
        ],
      );

      await importer.import(
        data: data,
        selections: const UddfImportSelections(dives: {0}),
        repositories: repos,
        diverId: diverId,
      );

      final captured = verify(mockDiveRepo.createDive(captureAny)).captured;
      final dive = captured[0] as Dive;
      expect(dive.profile, hasLength(3));
      expect(dive.profile[0].heartRate, 72);
      expect(dive.profile[1].heartRate, isNull);
      expect(dive.profile[2].heartRate, 84);
    });

    test(
      'persists UDDF sample cns, ndl, tts, rbt and stores dive-level cns and otu in the source snapshot',
      () async {
        when(mockDiveRepo.createDive(any)).thenAnswer(
          (invocation) async => invocation.positionalArguments[0] as Dive,
        );
        when(mockDiveRepo.saveComputerReading(any)).thenAnswer((_) async {});

        final data = UddfImportResult(
          dives: [
            {
              'dateTime': now,
              'maxDepth': 25.0,
              'cnsEnd': 18.5,
              'otu': 7.0,
              'profile': [
                {
                  'timestamp': 0,
                  'depth': 0.0,
                  'cns': 3.0,
                  'ndl': 1200,
                  'tts': 300,
                  'rbt': 1500,
                },
                {
                  'timestamp': 60,
                  'depth': 12.0,
                  'cns': 8.5,
                  'tts': 480,
                  'rbt': 900,
                },
              ],
            },
          ],
        );

        await importer.import(
          data: data,
          selections: const UddfImportSelections(dives: {0}),
          repositories: repos,
          diverId: diverId,
        );

        final capturedDives = verify(
          mockDiveRepo.createDive(captureAny),
        ).captured;
        final dive = capturedDives.single as Dive;
        expect(dive.profile, hasLength(2));
        expect(dive.profile[0].cns, 3.0);
        expect(dive.profile[0].ndl, 1200);
        expect(dive.profile[0].tts, 300);
        expect(dive.profile[0].rbt, 1500);
        expect(dive.profile[1].cns, 8.5);
        expect(dive.profile[1].ndl, isNull);
        expect(dive.profile[1].tts, 480);
        expect(dive.profile[1].rbt, 900);

        final capturedReadings = verify(
          mockDiveRepo.saveComputerReading(captureAny),
        ).captured;
        final reading = capturedReadings.single;
        expect(reading.cns.value, 18.5);
        expect(reading.otu.value, 7.0);
      },
    );

    test('persists UDDF sample decoType from decostop kind mapping', () async {
      when(mockDiveRepo.createDive(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as Dive,
      );

      final data = UddfImportResult(
        dives: [
          {
            'dateTime': now,
            'maxDepth': 25.0,
            'profile': [
              {'timestamp': 0, 'depth': 0.0},
              {'timestamp': 60, 'depth': 5.0, 'decoType': 1},
              {'timestamp': 120, 'depth': 9.0, 'decoType': 2},
            ],
          },
        ],
      );

      await importer.import(
        data: data,
        selections: const UddfImportSelections(dives: {0}),
        repositories: repos,
        diverId: diverId,
      );

      final captured = verify(mockDiveRepo.createDive(captureAny)).captured;
      final dive = captured.single as Dive;
      expect(dive.profile, hasLength(3));
      expect(dive.profile[0].decoType, isNull);
      expect(dive.profile[1].decoType, 1);
      expect(dive.profile[2].decoType, 2);
    });

    test('accepts numeric import fields when doubles arrive as ints', () async {
      when(mockDiveRepo.createDive(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as Dive,
      );
      when(mockDiveRepo.saveComputerReading(any)).thenAnswer((_) async {});

      final data = UddfImportResult(
        dives: [
          {
            'dateTime': now,
            'maxDepth': 25,
            'avgDepth': 18,
            'waterTemp': 22,
            'cnsEnd': 24,
            'otu': 64,
            'profile': [
              {
                'timestamp': 10,
                'depth': 0,
                'temperature': 20,
                'cns': 1,
                'setpoint': 1,
                'ppO2': 1,
              },
            ],
          },
        ],
      );

      await importer.import(
        data: data,
        selections: const UddfImportSelections(dives: {0}),
        repositories: repos,
        diverId: diverId,
      );

      final capturedDives = verify(
        mockDiveRepo.createDive(captureAny),
      ).captured;
      final dive = capturedDives.single as Dive;
      expect(dive.maxDepth, 25.0);
      expect(dive.avgDepth, 18.0);
      expect(dive.waterTemp, 22.0);
      expect(dive.profile.single.depth, 0.0);
      expect(dive.profile.single.temperature, 20.0);
      expect(dive.profile.single.cns, 1.0);
      expect(dive.profile.single.setpoint, 1.0);
      expect(dive.profile.single.ppO2, 1.0);

      final capturedReadings = verify(
        mockDiveRepo.saveComputerReading(captureAny),
      ).captured;
      final reading = capturedReadings.single;
      expect(reading.maxDepth.value, 25.0);
      expect(reading.avgDepth.value, 18.0);
      expect(reading.waterTemp.value, 22.0);
      expect(reading.cns.value, 24.0);
      expect(reading.otu.value, 64.0);
    });

    test(
      'imports dive with two tanks and stores pressure data for both',
      () async {
        when(mockDiveRepo.createDive(any)).thenAnswer(
          (invocation) async => invocation.positionalArguments[0] as Dive,
        );
        when(
          mockTankPressureRepo.insertTankPressures(any, any),
        ).thenAnswer((_) async {});

        final data = UddfImportResult(
          dives: [
            {
              'dateTime': now,
              'maxDepth': 30.0,
              'tanks': [
                {'uddfTankId': 'T1', 'volume': 12.0},
                {'uddfTankId': 'T2', 'volume': 11.0},
              ],
              'profile': [
                {
                  'timestamp': 0,
                  'depth': 0.0,
                  'allTankPressures': [
                    {'tankIndex': 0, 'pressure': 200.0},
                    {'tankIndex': 1, 'pressure': 190.0},
                  ],
                },
                {
                  'timestamp': 60,
                  'depth': 20.0,
                  'allTankPressures': [
                    {'tankIndex': 0, 'pressure': 180.0},
                    {'tankIndex': 1, 'pressure': 170.0},
                  ],
                },
              ],
            },
          ],
        );

        await importer.import(
          data: data,
          selections: UddfImportSelections.selectAll(data),
          repositories: repos,
          diverId: diverId,
        );

        verify(mockDiveRepo.createDive(any)).called(1);

        final captured = verify(
          mockTankPressureRepo.insertTankPressures(any, captureAny),
        ).captured;

        final pressuresByTank =
            captured.first
                as Map<String, List<({int timestamp, double pressure})>>;
        expect(pressuresByTank.keys, hasLength(2));
        expect(pressuresByTank.values.first, isNotEmpty);
        expect(pressuresByTank.values.last, isNotEmpty);
      },
    );

    test('maps gas switches by tank ref to created tank ids', () async {
      when(mockDiveRepo.createDive(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as Dive,
      );
      when(mockDiveRepo.insertGasSwitches(any)).thenAnswer((_) async {});

      final data = UddfImportResult(
        dives: [
          {
            'dateTime': now,
            'maxDepth': 30.0,
            'tanks': [
              {'uddfTankId': '0:D80', 'name': 'D80', 'volume': 22.2},
              {'uddfTankId': '1:AL80', 'name': 'AL80', 'volume': 11.094},
            ],
            'gasSwitches': [
              {'timestamp': 10, 'tankRef': '0:D80'},
              {'timestamp': 700, 'tankRef': '1:AL80'},
            ],
          },
        ],
      );

      await importer.import(
        data: data,
        selections: UddfImportSelections.selectAll(data),
        repositories: repos,
        diverId: diverId,
      );

      final capturedDive = verify(mockDiveRepo.createDive(captureAny)).captured;
      final dive = capturedDive.first as Dive;
      expect(dive.tanks, hasLength(2));
      expect(dive.tanks[0].name, 'D80');
      expect(dive.tanks[1].name, 'AL80');

      final capturedSwitches = verify(
        mockDiveRepo.insertGasSwitches(captureAny),
      ).captured;
      final switches = capturedSwitches.first as List<GasSwitch>;
      expect(switches, hasLength(2));
      expect(switches[0].tankId, dive.tanks[0].id);
      expect(switches[1].tankId, dive.tanks[1].id);
    });

    test('maps gas switches by tank index to created tank ids', () async {
      // FIT imports have no UDDF refs; switches address tanks positionally.
      when(mockDiveRepo.createDive(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as Dive,
      );
      when(mockDiveRepo.insertGasSwitches(any)).thenAnswer((_) async {});

      final data = UddfImportResult(
        dives: [
          {
            'dateTime': now,
            'maxDepth': 40.0,
            'tanks': [
              {'gasMix': const GasMix(o2: 19, he: 34)},
              {'gasMix': const GasMix(o2: 32, he: 0)},
            ],
            'gasSwitches': [
              {'timestamp': 0, 'tankIndex': 0},
              {'timestamp': 2474, 'tankIndex': 1, 'depth': 21.0},
            ],
          },
        ],
      );

      await importer.import(
        data: data,
        selections: UddfImportSelections.selectAll(data),
        repositories: repos,
        diverId: diverId,
      );

      final capturedDive = verify(mockDiveRepo.createDive(captureAny)).captured;
      final dive = capturedDive.first as Dive;
      expect(dive.tanks, hasLength(2));

      final capturedSwitches = verify(
        mockDiveRepo.insertGasSwitches(captureAny),
      ).captured;
      final switches = capturedSwitches.first as List<GasSwitch>;
      expect(switches, hasLength(2));
      expect(switches[0].tankId, dive.tanks[0].id);
      expect(switches[1].tankId, dive.tanks[1].id);
      expect(switches[1].depth, 21.0);
    });
  });

  group('Progress callback', () {
    test('reports progress for each phase', () async {
      when(mockTripRepo.createTrip(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as Trip,
      );
      when(mockDiveRepo.createDive(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as Dive,
      );

      final data = UddfImportResult(
        trips: [
          {'name': 'Trip 1'},
          {'name': 'Trip 2'},
        ],
        dives: [
          {'dateTime': now, 'maxDepth': 20.0},
        ],
      );

      final progressCalls = <(ImportPhase, int, int)>[];
      await importer.import(
        data: data,
        selections: const UddfImportSelections(trips: {0, 1}, dives: {0}),
        repositories: repos,
        diverId: diverId,
        onProgress: (phase, current, total) {
          progressCalls.add((phase, current, total));
        },
      );

      // Trip progress: initial 0/2, then 1/2, then 2/2
      final tripCalls = progressCalls.where((c) => c.$1 == ImportPhase.trips);
      expect(tripCalls, hasLength(3)); // 0/2, 1/2, 2/2
      expect(tripCalls.last, (ImportPhase.trips, 2, 2));

      // Dive progress
      final diveCalls = progressCalls.where((c) => c.$1 == ImportPhase.dives);
      expect(diveCalls, isNotEmpty);
    });
  });

  group('Selection filtering', () {
    test('only imports selected items', () async {
      when(mockTripRepo.createTrip(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as Trip,
      );

      const data = UddfImportResult(
        trips: [
          {'name': 'Trip A'},
          {'name': 'Trip B'},
          {'name': 'Trip C'},
        ],
      );

      final result = await importer.import(
        data: data,
        selections: const UddfImportSelections(trips: {1}), // Only Trip B
        repositories: repos,
        diverId: diverId,
      );

      expect(result.trips, 1);

      final captured = verify(mockTripRepo.createTrip(captureAny)).captured;
      expect((captured[0] as Trip).name, 'Trip B');
    });

    test('empty selections import nothing', () async {
      final data = UddfImportResult(
        trips: [
          {'name': 'Trip'},
        ],
        dives: [
          {'dateTime': now, 'maxDepth': 20.0},
        ],
      );

      final result = await importer.import(
        data: data,
        selections: const UddfImportSelections(),
        repositories: repos,
        diverId: diverId,
      );

      expect(result.total, 0);
      verifyNever(mockTripRepo.createTrip(any));
      verifyNever(mockDiveRepo.createDive(any));
    });
  });

  group('_parseEnum via dive enum fields', () {
    // The private _parseEnum method is tested indirectly by setting dive data
    // fields that pass through it: visibility, currentStrength,
    // currentDirection, entryMethod, exitMethod, waterType, diveMode.

    test('parses string values for visibility', () async {
      when(mockDiveRepo.createDive(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as Dive,
      );

      final data = UddfImportResult(
        dives: [
          {'dateTime': now, 'maxDepth': 15.0, 'visibility': 'good'},
        ],
      );

      await importer.import(
        data: data,
        selections: const UddfImportSelections(dives: {0}),
        repositories: repos,
        diverId: diverId,
      );

      final captured = verify(mockDiveRepo.createDive(captureAny)).captured;
      final dive = captured[0] as Dive;
      expect(dive.visibility, Visibility.good);
    });

    test('parses enum instance for visibility', () async {
      when(mockDiveRepo.createDive(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as Dive,
      );

      final data = UddfImportResult(
        dives: [
          {
            'dateTime': now,
            'maxDepth': 15.0,
            'visibility': Visibility.excellent,
          },
        ],
      );

      await importer.import(
        data: data,
        selections: const UddfImportSelections(dives: {0}),
        repositories: repos,
        diverId: diverId,
      );

      final captured = verify(mockDiveRepo.createDive(captureAny)).captured;
      final dive = captured[0] as Dive;
      expect(dive.visibility, Visibility.excellent);
    });

    test('returns null for null visibility', () async {
      when(mockDiveRepo.createDive(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as Dive,
      );

      final data = UddfImportResult(
        dives: [
          {
            'dateTime': now,
            'maxDepth': 15.0,
            // visibility not set -> null
          },
        ],
      );

      await importer.import(
        data: data,
        selections: const UddfImportSelections(dives: {0}),
        repositories: repos,
        diverId: diverId,
      );

      final captured = verify(mockDiveRepo.createDive(captureAny)).captured;
      final dive = captured[0] as Dive;
      expect(dive.visibility, isNull);
    });

    test('returns null for unrecognized visibility string', () async {
      when(mockDiveRepo.createDive(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as Dive,
      );

      final data = UddfImportResult(
        dives: [
          {'dateTime': now, 'maxDepth': 15.0, 'visibility': 'crystal_clear'},
        ],
      );

      await importer.import(
        data: data,
        selections: const UddfImportSelections(dives: {0}),
        repositories: repos,
        diverId: diverId,
      );

      final captured = verify(mockDiveRepo.createDive(captureAny)).captured;
      final dive = captured[0] as Dive;
      expect(dive.visibility, isNull);
    });

    test('parses case-insensitive string for visibility', () async {
      when(mockDiveRepo.createDive(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as Dive,
      );

      final data = UddfImportResult(
        dives: [
          {'dateTime': now, 'maxDepth': 15.0, 'visibility': 'POOR'},
        ],
      );

      await importer.import(
        data: data,
        selections: const UddfImportSelections(dives: {0}),
        repositories: repos,
        diverId: diverId,
      );

      final captured = verify(mockDiveRepo.createDive(captureAny)).captured;
      final dive = captured[0] as Dive;
      expect(dive.visibility, Visibility.poor);
    });

    test('parses string for currentStrength', () async {
      when(mockDiveRepo.createDive(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as Dive,
      );

      final data = UddfImportResult(
        dives: [
          {'dateTime': now, 'maxDepth': 15.0, 'currentStrength': 'strong'},
        ],
      );

      await importer.import(
        data: data,
        selections: const UddfImportSelections(dives: {0}),
        repositories: repos,
        diverId: diverId,
      );

      final captured = verify(mockDiveRepo.createDive(captureAny)).captured;
      final dive = captured[0] as Dive;
      expect(dive.currentStrength, CurrentStrength.strong);
    });

    test('parses enum instance for currentStrength', () async {
      when(mockDiveRepo.createDive(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as Dive,
      );

      final data = UddfImportResult(
        dives: [
          {
            'dateTime': now,
            'maxDepth': 15.0,
            'currentStrength': CurrentStrength.light,
          },
        ],
      );

      await importer.import(
        data: data,
        selections: const UddfImportSelections(dives: {0}),
        repositories: repos,
        diverId: diverId,
      );

      final captured = verify(mockDiveRepo.createDive(captureAny)).captured;
      final dive = captured[0] as Dive;
      expect(dive.currentStrength, CurrentStrength.light);
    });

    test('returns null for unrecognized currentStrength', () async {
      when(mockDiveRepo.createDive(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as Dive,
      );

      final data = UddfImportResult(
        dives: [
          {'dateTime': now, 'maxDepth': 15.0, 'currentStrength': 'hurricane'},
        ],
      );

      await importer.import(
        data: data,
        selections: const UddfImportSelections(dives: {0}),
        repositories: repos,
        diverId: diverId,
      );

      final captured = verify(mockDiveRepo.createDive(captureAny)).captured;
      final dive = captured[0] as Dive;
      expect(dive.currentStrength, isNull);
    });

    test('parses string for currentDirection', () async {
      when(mockDiveRepo.createDive(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as Dive,
      );

      final data = UddfImportResult(
        dives: [
          {'dateTime': now, 'maxDepth': 15.0, 'currentDirection': 'north'},
        ],
      );

      await importer.import(
        data: data,
        selections: const UddfImportSelections(dives: {0}),
        repositories: repos,
        diverId: diverId,
      );

      final captured = verify(mockDiveRepo.createDive(captureAny)).captured;
      final dive = captured[0] as Dive;
      expect(dive.currentDirection, CurrentDirection.north);
    });

    test('parses string for entryMethod', () async {
      when(mockDiveRepo.createDive(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as Dive,
      );

      final data = UddfImportResult(
        dives: [
          {'dateTime': now, 'maxDepth': 15.0, 'entryMethod': 'shore'},
        ],
      );

      await importer.import(
        data: data,
        selections: const UddfImportSelections(dives: {0}),
        repositories: repos,
        diverId: diverId,
      );

      final captured = verify(mockDiveRepo.createDive(captureAny)).captured;
      final dive = captured[0] as Dive;
      expect(dive.entryMethod, EntryMethod.shore);
    });

    test('parses string for exitMethod', () async {
      when(mockDiveRepo.createDive(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as Dive,
      );

      final data = UddfImportResult(
        dives: [
          {'dateTime': now, 'maxDepth': 15.0, 'exitMethod': 'boat'},
        ],
      );

      await importer.import(
        data: data,
        selections: const UddfImportSelections(dives: {0}),
        repositories: repos,
        diverId: diverId,
      );

      final captured = verify(mockDiveRepo.createDive(captureAny)).captured;
      final dive = captured[0] as Dive;
      expect(dive.exitMethod, EntryMethod.boat);
    });

    test('parses string for waterType', () async {
      when(mockDiveRepo.createDive(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as Dive,
      );

      final data = UddfImportResult(
        dives: [
          {'dateTime': now, 'maxDepth': 15.0, 'waterType': 'fresh'},
        ],
      );

      await importer.import(
        data: data,
        selections: const UddfImportSelections(dives: {0}),
        repositories: repos,
        diverId: diverId,
      );

      final captured = verify(mockDiveRepo.createDive(captureAny)).captured;
      final dive = captured[0] as Dive;
      expect(dive.waterType, WaterType.fresh);
    });

    test('parses string for diveMode', () async {
      when(mockDiveRepo.createDive(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as Dive,
      );

      final data = UddfImportResult(
        dives: [
          {'dateTime': now, 'maxDepth': 15.0, 'diveMode': 'ccr'},
        ],
      );

      await importer.import(
        data: data,
        selections: const UddfImportSelections(dives: {0}),
        repositories: repos,
        diverId: diverId,
      );

      final captured = verify(mockDiveRepo.createDive(captureAny)).captured;
      final dive = captured[0] as Dive;
      expect(dive.diveMode, DiveMode.ccr);
    });

    test('defaults diveMode to oc when null', () async {
      when(mockDiveRepo.createDive(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as Dive,
      );

      final data = UddfImportResult(
        dives: [
          {
            'dateTime': now,
            'maxDepth': 15.0,
            // diveMode not set
          },
        ],
      );

      await importer.import(
        data: data,
        selections: const UddfImportSelections(dives: {0}),
        repositories: repos,
        diverId: diverId,
      );

      final captured = verify(mockDiveRepo.createDive(captureAny)).captured;
      final dive = captured[0] as Dive;
      expect(dive.diveMode, DiveMode.oc);
    });

    test('defaults diveMode to oc for unrecognized string', () async {
      when(mockDiveRepo.createDive(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as Dive,
      );

      final data = UddfImportResult(
        dives: [
          {'dateTime': now, 'maxDepth': 15.0, 'diveMode': 'snorkel'},
        ],
      );

      await importer.import(
        data: data,
        selections: const UddfImportSelections(dives: {0}),
        repositories: repos,
        diverId: diverId,
      );

      final captured = verify(mockDiveRepo.createDive(captureAny)).captured;
      final dive = captured[0] as Dive;
      expect(dive.diveMode, DiveMode.oc);
    });

    test('parses multiple enum fields on a single dive', () async {
      when(mockDiveRepo.createDive(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as Dive,
      );

      final data = UddfImportResult(
        dives: [
          {
            'dateTime': now,
            'maxDepth': 15.0,
            'visibility': 'moderate',
            'currentStrength': 'none',
            'currentDirection': 'east',
            'entryMethod': 'giantStride',
            'exitMethod': 'shore',
            'waterType': 'salt',
            'diveMode': 'scr',
          },
        ],
      );

      await importer.import(
        data: data,
        selections: const UddfImportSelections(dives: {0}),
        repositories: repos,
        diverId: diverId,
      );

      final captured = verify(mockDiveRepo.createDive(captureAny)).captured;
      final dive = captured[0] as Dive;
      expect(dive.visibility, Visibility.moderate);
      expect(dive.currentStrength, CurrentStrength.none);
      expect(dive.currentDirection, CurrentDirection.east);
      expect(dive.entryMethod, EntryMethod.giantStride);
      expect(dive.exitMethod, EntryMethod.shore);
      expect(dive.waterType, WaterType.salt);
      expect(dive.diveMode, DiveMode.scr);
    });
  });

  group('Site linking fallback for CSV-style siteId', () {
    test(
      'links dive to site via direct siteId when site map is absent',
      () async {
        when(mockSiteRepo.createSite(any)).thenAnswer((invocation) async {
          final site = invocation.positionalArguments[0] as DiveSite;
          return site;
        });
        when(mockDiveRepo.createDive(any)).thenAnswer(
          (invocation) async => invocation.positionalArguments[0] as Dive,
        );

        final data = UddfImportResult(
          sites: [
            {'name': 'Reef Wall', 'uddfId': 'csv-site-1'},
          ],
          dives: [
            {
              'dateTime': now,
              'maxDepth': 20.0,
              // No nested 'site' map; CSV-style direct siteId instead
              'siteId': 'csv-site-1',
            },
          ],
        );

        final result = await importer.import(
          data: data,
          selections: const UddfImportSelections(sites: {0}, dives: {0}),
          repositories: repos,
          diverId: diverId,
        );

        expect(result.sites, 1);
        expect(result.dives, 1);

        final captured = verify(mockDiveRepo.createDive(captureAny)).captured;
        final dive = captured[0] as Dive;
        expect(dive.site, isNotNull);
        expect(dive.site!.name, 'Reef Wall');
      },
    );

    test(
      'does not overwrite site from nested map when siteId also present',
      () async {
        when(mockSiteRepo.createSite(any)).thenAnswer((invocation) async {
          final site = invocation.positionalArguments[0] as DiveSite;
          return site;
        });
        when(mockDiveRepo.createDive(any)).thenAnswer(
          (invocation) async => invocation.positionalArguments[0] as Dive,
        );

        final data = UddfImportResult(
          sites: [
            {'name': 'Primary Site', 'uddfId': 'site-a'},
            {'name': 'Fallback Site', 'uddfId': 'site-b'},
          ],
          dives: [
            {
              'dateTime': now,
              'maxDepth': 20.0,
              // Nested site map takes priority
              'site': {'uddfId': 'site-a'},
              // CSV-style fallback should NOT override
              'siteId': 'site-b',
            },
          ],
        );

        final result = await importer.import(
          data: data,
          selections: const UddfImportSelections(sites: {0, 1}, dives: {0}),
          repositories: repos,
          diverId: diverId,
        );

        expect(result.dives, 1);

        final captured = verify(mockDiveRepo.createDive(captureAny)).captured;
        final dive = captured[0] as Dive;
        expect(dive.site, isNotNull);
        expect(dive.site!.name, 'Primary Site');
      },
    );

    test(
      'leaves site null when siteId does not match any imported site',
      () async {
        when(mockDiveRepo.createDive(any)).thenAnswer(
          (invocation) async => invocation.positionalArguments[0] as Dive,
        );

        final data = UddfImportResult(
          dives: [
            {'dateTime': now, 'maxDepth': 20.0, 'siteId': 'nonexistent-site'},
          ],
        );

        await importer.import(
          data: data,
          selections: const UddfImportSelections(dives: {0}),
          repositories: repos,
          diverId: diverId,
        );

        final captured = verify(mockDiveRepo.createDive(captureAny)).captured;
        final dive = captured[0] as Dive;
        expect(dive.site, isNull);
      },
    );
  });

  group('Runtime fallback to duration', () {
    test('uses duration as runtime when runtime is null', () async {
      when(mockDiveRepo.createDive(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as Dive,
      );

      final data = UddfImportResult(
        dives: [
          {
            'dateTime': now,
            'maxDepth': 18.0,
            // No 'runtime' key, only 'duration'
            'duration': const Duration(minutes: 50),
          },
        ],
      );

      await importer.import(
        data: data,
        selections: const UddfImportSelections(dives: {0}),
        repositories: repos,
        diverId: diverId,
      );

      final captured = verify(mockDiveRepo.createDive(captureAny)).captured;
      final dive = captured[0] as Dive;
      expect(dive.runtime, const Duration(minutes: 50));
      expect(dive.bottomTime, const Duration(minutes: 50));
    });

    test('prefers runtime over duration when both present', () async {
      when(mockDiveRepo.createDive(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as Dive,
      );

      final data = UddfImportResult(
        dives: [
          {
            'dateTime': now,
            'maxDepth': 18.0,
            'runtime': const Duration(minutes: 55),
            'duration': const Duration(minutes: 50),
          },
        ],
      );

      await importer.import(
        data: data,
        selections: const UddfImportSelections(dives: {0}),
        repositories: repos,
        diverId: diverId,
      );

      final captured = verify(mockDiveRepo.createDive(captureAny)).captured;
      final dive = captured[0] as Dive;
      expect(dive.runtime, const Duration(minutes: 55));
      expect(dive.bottomTime, const Duration(minutes: 50));
    });

    test('sets exitTime based on runtime fallback from duration', () async {
      when(mockDiveRepo.createDive(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as Dive,
      );

      final diveTime = DateTime(2024, 6, 15, 10, 0);
      final data = UddfImportResult(
        dives: [
          {
            'dateTime': diveTime,
            'maxDepth': 18.0,
            'duration': const Duration(minutes: 40),
          },
        ],
      );

      await importer.import(
        data: data,
        selections: const UddfImportSelections(dives: {0}),
        repositories: repos,
        diverId: diverId,
      );

      final captured = verify(mockDiveRepo.createDive(captureAny)).captured;
      final dive = captured[0] as Dive;
      expect(dive.exitTime, DateTime(2024, 6, 15, 10, 40));
    });

    test('exitTime is null when both runtime and duration are null', () async {
      when(mockDiveRepo.createDive(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as Dive,
      );

      final data = UddfImportResult(
        dives: [
          {
            'dateTime': now,
            'maxDepth': 18.0,
            // Neither runtime nor duration
          },
        ],
      );

      await importer.import(
        data: data,
        selections: const UddfImportSelections(dives: {0}),
        repositories: repos,
        diverId: diverId,
      );

      final captured = verify(mockDiveRepo.createDive(captureAny)).captured;
      final dive = captured[0] as Dive;
      expect(dive.runtime, isNull);
      expect(dive.exitTime, isNull);
    });
  });

  group('_parseEnum via buddy enum fields', () {
    // _parseEnum is also used for buddy certificationLevel and
    // certificationAgency, providing another indirect test path.

    // issue #553: a buddy's parsed cert now lands on a buddy-owned row in the
    // certifications table (the inline Buddy cert fields were dropped), so
    // these assert on the created Certification. _parseEnum is still exercised.
    test('parses certificationLevel string on buddy', () async {
      when(mockBuddyRepo.createBuddy(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as Buddy,
      );
      when(mockCertificationRepo.createCertification(any)).thenAnswer(
        (invocation) async =>
            invocation.positionalArguments[0] as Certification,
      );

      const data = UddfImportResult(
        buddies: [
          {
            'name': 'Jane',
            'uddfId': 'b-1',
            'certificationLevel': 'advancedOpenWater',
          },
        ],
      );

      await importer.import(
        data: data,
        selections: const UddfImportSelections(buddies: {0}),
        repositories: repos,
        diverId: diverId,
      );

      final captured = verify(
        mockCertificationRepo.createCertification(captureAny),
      ).captured;
      final cert = captured[0] as Certification;
      expect(cert.level, CertificationLevel.advancedOpenWater);
      expect(cert.buddyId, isNotNull);
    });

    test('parses certificationAgency enum on buddy', () async {
      when(mockBuddyRepo.createBuddy(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as Buddy,
      );
      when(mockCertificationRepo.createCertification(any)).thenAnswer(
        (invocation) async =>
            invocation.positionalArguments[0] as Certification,
      );

      const data = UddfImportResult(
        buddies: [
          {
            'name': 'Jane',
            'uddfId': 'b-1',
            'certificationAgency': CertificationAgency.ssi,
          },
        ],
      );

      await importer.import(
        data: data,
        selections: const UddfImportSelections(buddies: {0}),
        repositories: repos,
        diverId: diverId,
      );

      final captured = verify(
        mockCertificationRepo.createCertification(captureAny),
      ).captured;
      final cert = captured[0] as Certification;
      expect(cert.agency, CertificationAgency.ssi);
    });

    test('returns null for unrecognized certificationLevel', () async {
      when(mockBuddyRepo.createBuddy(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as Buddy,
      );

      const data = UddfImportResult(
        buddies: [
          {'name': 'Jane', 'uddfId': 'b-1', 'certificationLevel': 'megaDiver'},
        ],
      );

      await importer.import(
        data: data,
        selections: const UddfImportSelections(buddies: {0}),
        repositories: repos,
        diverId: diverId,
      );

      final captured = verify(mockBuddyRepo.createBuddy(captureAny)).captured;
      final buddy = captured[0] as Buddy;
      expect(buddy.certificationLevel, isNull);
    });

    test('returns null for null certificationLevel on buddy', () async {
      when(mockBuddyRepo.createBuddy(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as Buddy,
      );

      const data = UddfImportResult(
        buddies: [
          {
            'name': 'Jane',
            'uddfId': 'b-1',
            // No certificationLevel -> null
          },
        ],
      );

      await importer.import(
        data: data,
        selections: const UddfImportSelections(buddies: {0}),
        repositories: repos,
        diverId: diverId,
      );

      final captured = verify(mockBuddyRepo.createBuddy(captureAny)).captured;
      final buddy = captured[0] as Buddy;
      expect(buddy.certificationLevel, isNull);
      expect(buddy.certificationAgency, isNull);
    });
  });

  group('Profile events persistence', () {
    setUp(() {
      when(mockDiveRepo.createDive(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as Dive,
      );
      when(mockDiveRepo.insertProfileEvents(any)).thenAnswer((_) async {});
    });

    test('persists setpointChange event with correct fields', () async {
      final data = UddfImportResult(
        dives: [
          {
            'dateTime': now,
            'maxDepth': 30.0,
            'events': [
              {'eventType': 'setpointChange', 'timestamp': 300, 'value': 1.2},
            ],
          },
        ],
      );

      await importer.import(
        data: data,
        selections: UddfImportSelections.selectAll(data),
        repositories: repos,
        diverId: diverId,
      );

      final captured = verify(
        mockDiveRepo.insertProfileEvents(captureAny),
      ).captured;
      final events = captured.first as List<ProfileEvent>;
      expect(events, hasLength(1));
      expect(events[0].eventType, ProfileEventType.setpointChange);
      expect(events[0].timestamp, 300);
      expect(events[0].value, 1.2);
      expect(events[0].source, EventSource.imported);
    });

    test('does not call insertProfileEvents for unknown event type', () async {
      final data = UddfImportResult(
        dives: [
          {
            'dateTime': now,
            'maxDepth': 20.0,
            'events': [
              {'eventType': 'unknownType', 'timestamp': 100},
            ],
          },
        ],
      );

      await importer.import(
        data: data,
        selections: UddfImportSelections.selectAll(data),
        repositories: repos,
        diverId: diverId,
      );

      verifyNever(mockDiveRepo.insertProfileEvents(any));
    });

    test(
      'persists all 8 event types from profile-events-variety-style diveData',
      () async {
        final data = UddfImportResult(
          dives: [
            {
              'dateTime': now,
              'maxDepth': 40.0,
              'events': [
                {'eventType': 'setpointChange', 'timestamp': 60, 'value': 0.7},
                {
                  'eventType': 'bookmark',
                  'timestamp': 120,
                  'description': 'nice spot',
                },
                {
                  'eventType': 'ascentRateWarning',
                  'timestamp': 180,
                  'value': 12.5,
                },
                {'eventType': 'ppO2High', 'timestamp': 240, 'value': 1.7},
                {'eventType': 'decoViolation', 'timestamp': 300},
                {'eventType': 'decoViolation', 'timestamp': 360, 'value': 0.5},
                {'eventType': 'decoStopStart', 'timestamp': 420},
                {'eventType': 'safetyStopStart', 'timestamp': 480},
              ],
            },
          ],
        );

        await importer.import(
          data: data,
          selections: UddfImportSelections.selectAll(data),
          repositories: repos,
          diverId: diverId,
        );

        final captured = verify(
          mockDiveRepo.insertProfileEvents(captureAny),
        ).captured;
        final events = captured.first as List<ProfileEvent>;
        expect(events, hasLength(8));

        expect(events[0].eventType, ProfileEventType.setpointChange);
        expect(events[0].source, EventSource.imported);

        expect(events[1].eventType, ProfileEventType.bookmark);
        expect(events[1].source, EventSource.imported);
        expect(events[1].description, 'nice spot');

        expect(events[2].eventType, ProfileEventType.ascentRateWarning);
        expect(events[2].source, EventSource.imported);

        expect(events[3].eventType, ProfileEventType.ppO2High);
        expect(events[3].source, EventSource.imported);
        expect(events[3].value, 1.7);

        expect(events[4].eventType, ProfileEventType.decoViolation);
        expect(events[4].source, EventSource.imported);

        expect(events[5].eventType, ProfileEventType.decoViolation);
        expect(events[5].value, 0.5);

        expect(events[6].eventType, ProfileEventType.decoStopStart);
        expect(events[6].source, EventSource.imported);

        expect(events[7].eventType, ProfileEventType.safetyStopStart);
        expect(events[7].source, EventSource.imported);
      },
    );

    test('bookmark event from import uses source=imported, not user', () async {
      final data = UddfImportResult(
        dives: [
          {
            'dateTime': now,
            'maxDepth': 18.0,
            'events': [
              {
                'eventType': 'bookmark',
                'timestamp': 90,
                'description': 'cool fish',
              },
            ],
          },
        ],
      );

      await importer.import(
        data: data,
        selections: UddfImportSelections.selectAll(data),
        repositories: repos,
        diverId: diverId,
      );

      final captured = verify(
        mockDiveRepo.insertProfileEvents(captureAny),
      ).captured;
      final events = captured.first as List<ProfileEvent>;
      expect(events, hasLength(1));
      expect(events[0].eventType, ProfileEventType.bookmark);
      expect(events[0].source, EventSource.imported);
      expect(events[0].description, 'cool fish');
    });

    test(
      'ppO2High event with missing value is skipped at importer level',
      () async {
        final data = UddfImportResult(
          dives: [
            {
              'dateTime': now,
              'maxDepth': 20.0,
              'events': [
                // No 'value' key — simulates parser malfunction or malformed event
                {'eventType': 'ppO2High', 'timestamp': 300},
              ],
            },
          ],
        );

        await importer.import(
          data: data,
          selections: UddfImportSelections.selectAll(data),
          repositories: repos,
          diverId: diverId,
        );

        verifyNever(mockDiveRepo.insertProfileEvents(any));
      },
    );

    test(
      'ppO2Low event with missing value is skipped at importer level',
      () async {
        final data = UddfImportResult(
          dives: [
            {
              'dateTime': now,
              'maxDepth': 20.0,
              'events': [
                // No 'value' key — simulates parser malfunction or malformed event
                {'eventType': 'ppO2Low', 'timestamp': 300},
              ],
            },
          ],
        );

        await importer.import(
          data: data,
          selections: UddfImportSelections.selectAll(data),
          repositories: repos,
          diverId: diverId,
        );

        verifyNever(mockDiveRepo.insertProfileEvents(any));
      },
    );

    test(
      'ascentRateWarning event with missing value is skipped at importer level',
      () async {
        final data = UddfImportResult(
          dives: [
            {
              'dateTime': now,
              'maxDepth': 20.0,
              'events': [
                // No 'value' key — avoid persisting a misleading 0 m/min rate
                {'eventType': 'ascentRateWarning', 'timestamp': 300},
              ],
            },
          ],
        );

        await importer.import(
          data: data,
          selections: UddfImportSelections.selectAll(data),
          repositories: repos,
          diverId: diverId,
        );

        verifyNever(mockDiveRepo.insertProfileEvents(any));
      },
    );
  });

  group('dive-level metadata persistence (Slice D)', () {
    test(
      'dual-cylinder.ssrf populates Dives + DiveDataSources metadata fields',
      () async {
        // This test asserts specific values from dual-cylinder.ssrf:
        // - divecomputer model: 'Shearwater Peregrine'
        // - Serial: '98d09a47'
        // - FW Version: '86'
        // - Deco model: 'GF 40/85'
        // - Surface pressure: '1.012 bar'
        // If dual-cylinder.ssrf is ever edited (e.g., sanitized for privacy),
        // update the expectations below to match.

        // 1. Load fixture bytes and wrap in required <divelog> envelope.
        const fixturePath =
            'test/features/universal_import/data/parsers/fixtures/dual-cylinder.ssrf';
        final diveXml = await File(fixturePath).readAsString();
        final wrapped =
            "<divelog program='subsurface' version='3'><dives>$diveXml</dives></divelog>";
        // Encode as UTF-8 to match SubsurfaceXmlParser.parse() decoding;
        // codeUnits would produce UTF-16 and break on non-ASCII fixtures.
        final bytes = Uint8List.fromList(utf8.encode(wrapped));

        // 2. Parse via SubsurfaceXmlParser.
        final parsePayload = await SubsurfaceXmlParser().parse(bytes);
        final diveDataList = parsePayload.entitiesOf(ImportEntityType.dives);
        expect(diveDataList.length, 1);
        final diveData = diveDataList.first;

        // 3. Parser-level assertions — metadata keys populated.
        expect(diveData['diveComputerModel'], 'Shearwater Peregrine');
        expect(diveData['diveComputerSerial'], '98d09a47');
        expect(diveData['diveComputerFirmware'], '86');
        expect(diveData['decoAlgorithm'], 'buhlmann');
        expect(diveData['gradientFactorLow'], 40);
        expect(diveData['gradientFactorHigh'], 85);
        expect(diveData['surfacePressure'], closeTo(1.012, 0.0001));

        // 4. Build UddfImportResult from parsed dives and run the importer.
        when(mockDiveRepo.createDive(any)).thenAnswer(
          (invocation) async => invocation.positionalArguments[0] as Dive,
        );
        when(mockDiveRepo.saveComputerReading(any)).thenAnswer((_) async {});

        final data = UddfImportResult(dives: diveDataList);

        await importer.import(
          data: data,
          selections: UddfImportSelections.selectAll(data),
          repositories: repos,
          diverId: diverId,
        );

        // 5. Verify captured Dive entity — assert dive-level metadata fields.
        final capturedDives = verify(
          mockDiveRepo.createDive(captureAny),
        ).captured;
        final dive = capturedDives.single as Dive;
        expect(dive.diveComputerModel, 'Shearwater Peregrine');
        expect(dive.diveComputerSerial, '98d09a47');
        expect(dive.diveComputerFirmware, '86');
        expect(dive.decoAlgorithm, 'buhlmann');
        expect(dive.gradientFactorLow, 40);
        expect(dive.gradientFactorHigh, 85);
        expect(dive.surfacePressure, closeTo(1.012, 0.0001));

        // 6. Verify captured DiveDataSourcesCompanion — assert data-source fields.
        final capturedReadings = verify(
          mockDiveRepo.saveComputerReading(captureAny),
        ).captured;
        final reading = capturedReadings.single;
        expect(reading.computerModel.value, 'Shearwater Peregrine');
        expect(reading.computerSerial.value, '98d09a47');
        expect(reading.decoAlgorithm.value, 'buhlmann');
        expect(reading.gradientFactorLow.value, 40);
        expect(reading.gradientFactorHigh.value, 85);
      },
    );
  });

  group('Import service records', () {
    setUp(() {
      when(mockEquipmentRepo.createEquipment(any)).thenAnswer(
        (invocation) async =>
            invocation.positionalArguments[0] as EquipmentItem,
      );
      when(mockServiceRecordRepo.createRecord(any)).thenAnswer(
        (invocation) async =>
            invocation.positionalArguments[0] as ServiceRecord,
      );
    });

    UddfImportResult dataWith(List<Map<String, dynamic>> records) {
      return UddfImportResult(
        equipment: const [
          {'name': 'Travel Set', 'uddfId': 'gear-1', 'type': 'regulator'},
        ],
        serviceRecords: records,
      );
    }

    test('attaches a record to the equipment it references', () async {
      await importer.import(
        data: dataWith([
          {
            'equipmentRef': 'gear-1',
            'serviceDate': DateTime(2025, 5, 12),
            'provider': 'Seals Watersports',
            'notes': 'Swapped yoke to DIN',
            'serviceCategory': 'annual',
          },
        ]),
        selections: const UddfImportSelections(equipment: {0}),
        repositories: repos,
        diverId: diverId,
      );

      final captured = verify(
        mockServiceRecordRepo.createRecord(captureAny),
      ).captured;
      expect(captured, hasLength(1));
      final record = captured.single as ServiceRecord;
      expect(record.provider, 'Seals Watersports');
      expect(record.serviceDate, DateTime(2025, 5, 12));
      expect(record.serviceCategory, ServiceCategory.annual);
      expect(record.notes, 'Swapped yoke to DIN');

      // The record must point at the newly created equipment row, not at the
      // source's own id.
      final equipment =
          verify(mockEquipmentRepo.createEquipment(captureAny)).captured.single
              as EquipmentItem;
      expect(record.equipmentId, equipment.id);
    });

    test('skips a record whose equipment was not imported', () async {
      await importer.import(
        data: dataWith([
          {
            'equipmentRef': 'gear-missing',
            'serviceDate': DateTime(2025, 5, 12),
          },
        ]),
        selections: const UddfImportSelections(equipment: {0}),
        repositories: repos,
        diverId: diverId,
      );

      verifyNever(mockServiceRecordRepo.createRecord(any));
    });

    test('skips a record with no service date', () async {
      await importer.import(
        data: dataWith([
          {'equipmentRef': 'gear-1', 'provider': 'Someone'},
        ]),
        selections: const UddfImportSelections(equipment: {0}),
        repositories: repos,
        diverId: diverId,
      );

      verifyNever(mockServiceRecordRepo.createRecord(any));
    });

    test('one failing record does not abort the import', () async {
      when(mockServiceRecordRepo.createRecord(any)).thenAnswer((
        invocation,
      ) async {
        final record = invocation.positionalArguments[0] as ServiceRecord;
        if (record.provider == 'boom') throw Exception('write failed');
        return record;
      });

      await importer.import(
        data: dataWith([
          {
            'equipmentRef': 'gear-1',
            'serviceDate': DateTime(2025, 1, 1),
            'provider': 'boom',
          },
          {
            'equipmentRef': 'gear-1',
            'serviceDate': DateTime(2025, 2, 1),
            'provider': 'fine',
          },
        ]),
        selections: const UddfImportSelections(equipment: {0}),
        repositories: repos,
        diverId: diverId,
      );

      verify(mockServiceRecordRepo.createRecord(any)).called(2);
    });
  });
}
