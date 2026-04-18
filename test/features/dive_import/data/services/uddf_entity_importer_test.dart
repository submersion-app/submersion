import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_builders.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_import_service.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:xml/xml.dart';
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
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

@GenerateMocks([
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
  late MockSiteRepository mockSiteRepo;
  late MockDiveRepository mockDiveRepo;
  late MockTankPressureRepository mockTankPressureRepo;
  late MockCourseRepository mockCourseRepo;
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
    mockSiteRepo = MockSiteRepository();
    mockDiveRepo = MockDiveRepository();
    mockTankPressureRepo = MockTankPressureRepository();
    mockCourseRepo = MockCourseRepository();

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
      siteRepository: mockSiteRepo,
      diveRepository: mockDiveRepo,
      tankPressureRepository: mockTankPressureRepo,
      courseRepository: mockCourseRepo,
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

      verify(mockBuddyRepo.addBuddyToDive(any, any, BuddyRole.buddy)).called(1);
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

    test('appends weight to notes', () async {
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
      expect(dive.notes, contains('Great dive'));
      expect(dive.notes, contains('Weight used: 4.5 kg'));
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
      'persists UDDF sample cns, ndl, rbt and stores dive-level cns and otu in the source snapshot',
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
                  'rbt': 1500,
                },
                {'timestamp': 60, 'depth': 12.0, 'cns': 8.5, 'rbt': 900},
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
        expect(dive.profile[0].rbt, 1500);
        expect(dive.profile[1].cns, 8.5);
        expect(dive.profile[1].ndl, isNull);
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

    test('parses certificationLevel string on buddy', () async {
      when(mockBuddyRepo.createBuddy(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as Buddy,
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

      final captured = verify(mockBuddyRepo.createBuddy(captureAny)).captured;
      final buddy = captured[0] as Buddy;
      expect(buddy.certificationLevel, CertificationLevel.advancedOpenWater);
    });

    test('parses certificationAgency enum on buddy', () async {
      when(mockBuddyRepo.createBuddy(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as Buddy,
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

      final captured = verify(mockBuddyRepo.createBuddy(captureAny)).captured;
      final buddy = captured[0] as Buddy;
      expect(buddy.certificationAgency, CertificationAgency.ssi);
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

    test('UDDF severity overrides factory default via copyWith', () async {
      // ascentRateWarning factory default: warning -> UDDF says: alert
      // decoViolation factory default: alert -> UDDF says: warning
      final data = UddfImportResult(
        dives: [
          {
            'dateTime': now,
            'maxDepth': 30.0,
            'events': [
              {
                'eventType': 'ascentRateWarning',
                'timestamp': 120,
                'value': 18.0,
                'severity': 'alert',
                'depth': 15.0,
              },
              {
                'eventType': 'decoViolation',
                'timestamp': 240,
                'severity': 'warning',
                'depth': 12.0,
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
      expect(events, hasLength(2));

      expect(events[0].eventType, ProfileEventType.ascentRateWarning);
      expect(events[0].severity, EventSeverity.alert); // overridden
      expect(events[0].depth, 15.0);
      expect(events[0].source, EventSource.imported);

      expect(events[1].eventType, ProfileEventType.decoViolation);
      expect(events[1].severity, EventSeverity.warning); // overridden
      expect(events[1].depth, 12.0);
      expect(events[1].source, EventSource.imported);
    });

    test('decoViolation preserves description from UDDF event', () async {
      // decoViolation factory accepts `description`; the switch case now
      // passes it through rather than dropping it. Pins end-to-end fidelity
      // of free-text notes on ceiling/violation events.
      final data = UddfImportResult(
        dives: [
          {
            'dateTime': now,
            'maxDepth': 40.0,
            'events': [
              {
                'eventType': 'decoViolation',
                'timestamp': 200,
                'description': 'ceiling broken by 1.2 m',
                'depth': 12.0,
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
      expect(events[0].eventType, ProfileEventType.decoViolation);
      expect(events[0].description, 'ceiling broken by 1.2 m');
    });

    test(
      'SSRF path continues to use factory default severity (no regression)',
      () async {
        // SSRF-shape: no `severity` key in event map. Factory default applies.
        // decoViolation factory default severity = alert.
        final data = UddfImportResult(
          dives: [
            {
              'dateTime': now,
              'maxDepth': 25.0,
              'events': [
                // No 'severity' or 'depth' keys — SSRF shape
                {'eventType': 'decoViolation', 'timestamp': 180},
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
        expect(
          events[0].severity,
          EventSeverity.alert,
        ); // factory default preserved
        expect(events[0].depth, isNull); // factory received no depth
      },
    );

    test('unknown severity string falls through to factory default', () async {
      // UDDF event with a malformed severity string -> _parseSeverity returns null.
      // No override applied. Factory default wins.
      // ppO2High factory default severity = warning.
      final data = UddfImportResult(
        dives: [
          {
            'dateTime': now,
            'maxDepth': 20.0,
            'events': [
              {
                'eventType': 'ppO2High',
                'timestamp': 90,
                'value': 1.8,
                'severity': 'catastrophic', // unknown value
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
      expect(
        events[0].severity,
        EventSeverity.warning,
      ); // factory default, not overridden
    });

    test(
      'UDDF round-trip preserves all 8 event types with severity and depth',
      () async {
        final roundTripNow = DateTime.utc(2026, 3, 15, 10, 0, 0);
        const diveId = 'roundtrip-dive';

        // 1. Build source events covering all 8 types, each with a distinctive
        //    (timestamp, eventType, severity, value, depth) tuple.
        final sourceEvents = <ProfileEvent>[
          ProfileEvent.setpointChange(
            id: 'e1',
            diveId: diveId,
            timestamp: 0,
            setpoint: 0.7,
            depth: 0.0,
            createdAt: roundTripNow,
          ),
          ProfileEvent.bookmark(
            id: 'e2',
            diveId: diveId,
            timestamp: 120,
            depth: 5.0,
            note: 'cool fish',
            createdAt: roundTripNow,
            source: EventSource.imported,
          ),
          ProfileEvent.ascentRateWarning(
            id: 'e3',
            diveId: diveId,
            timestamp: 300,
            depth: 10.0,
            rate: 12.5,
            createdAt: roundTripNow,
          ),
          ProfileEvent.ppO2High(
            id: 'e4',
            diveId: diveId,
            timestamp: 600,
            value: 1.65,
            depth: 20.0,
            createdAt: roundTripNow,
          ),
          ProfileEvent.ppO2Low(
            id: 'e5',
            diveId: diveId,
            timestamp: 700,
            value: 0.15,
            depth: 25.0,
            createdAt: roundTripNow,
          ),
          ProfileEvent.decoViolation(
            id: 'e6',
            diveId: diveId,
            timestamp: 1500,
            value: 18.0,
            depth: 15.0,
            createdAt: roundTripNow,
          ),
          ProfileEvent.decoStop(
            id: 'e7',
            diveId: diveId,
            timestamp: 2100,
            depth: 6.0,
            createdAt: roundTripNow,
          ),
          ProfileEvent.safetyStop(
            id: 'e8',
            diveId: diveId,
            timestamp: 2400,
            depth: 5.0,
            createdAt: roundTripNow,
          ),
        ];

        // 2. Build a minimal Dive entity mirroring the export-builders test.
        final dive = Dive(
          id: diveId,
          diveNumber: 1,
          dateTime: DateTime(2026, 3, 15, 10, 0),
          bottomTime: const Duration(minutes: 40),
          maxDepth: 30.0,
          profile: const [],
          tanks: const [],
          equipment: const [],
          notes: '',
          photoIds: const [],
          sightings: const [],
          weights: const [],
          tags: const [],
        );

        // 3. Export via buildDiveElement with POSITIONAL args per Discovery.
        final builder = XmlBuilder();
        builder.processing('xml', 'version="1.0" encoding="UTF-8"');
        builder.element(
          'uddf',
          nest: () {
            builder.element(
              'profiledata',
              nest: () {
                builder.element(
                  'repetitiongroup',
                  nest: () {
                    UddfExportBuilders.buildDiveElement(
                      builder,
                      dive,
                      null, // buddies
                      const <BuddyWithRole>[],
                      const <Tag>[],
                      sourceEvents,
                      const <DiveWeight>[],
                      null, // trips
                      const <GasSwitchWithTank>[],
                    );
                  },
                );
              },
            );
          },
        );
        final uddfXml = builder.buildDocument().toXmlString();

        // 4. Parse back via UddfFullImportService.
        final importService = UddfFullImportService();
        final importResult = await importService.importAllDataFromUddf(uddfXml);

        // 5. Verify the parser produced exactly 8 events in the dives list.
        expect(importResult.dives, hasLength(1));
        final parsedDiveData = importResult.dives[0];
        final parsedEvents =
            parsedDiveData['events'] as List<Map<String, dynamic>>;
        expect(parsedEvents, hasLength(8));

        // 6. Feed parsed data through the importer to verify full
        //    _importDives -> insertProfileEvents path.
        await importer.import(
          data: importResult,
          selections: UddfImportSelections.selectAll(importResult),
          repositories: repos,
          diverId: diverId,
        );

        final captured = verify(
          mockDiveRepo.insertProfileEvents(captureAny),
        ).captured;
        final persistedEvents = captured.first as List<ProfileEvent>;

        // 7. Assert on the persisted ProfileEvent list.
        expect(persistedEvents, hasLength(8));

        // setpointChange
        expect(persistedEvents[0].eventType, ProfileEventType.setpointChange);
        expect(persistedEvents[0].value, closeTo(0.7, 0.001));
        expect(persistedEvents[0].depth, closeTo(0.0, 0.001));
        expect(persistedEvents[0].source, EventSource.imported);

        // bookmark
        expect(persistedEvents[1].eventType, ProfileEventType.bookmark);
        expect(persistedEvents[1].depth, closeTo(5.0, 0.001));
        expect(persistedEvents[1].description, 'cool fish');
        expect(persistedEvents[1].source, EventSource.imported);

        // ascentRateWarning — severity exported as 'warning', round-trips
        expect(
          persistedEvents[2].eventType,
          ProfileEventType.ascentRateWarning,
        );
        expect(persistedEvents[2].severity, EventSeverity.warning);
        expect(persistedEvents[2].depth, closeTo(10.0, 0.001));
        expect(persistedEvents[2].value, closeTo(12.5, 0.001));
        expect(persistedEvents[2].source, EventSource.imported);

        // ppO2High — severity exported as 'warning', round-trips
        expect(persistedEvents[3].eventType, ProfileEventType.ppO2High);
        expect(persistedEvents[3].severity, EventSeverity.warning);
        expect(persistedEvents[3].value, closeTo(1.65, 0.001));
        expect(persistedEvents[3].depth, closeTo(20.0, 0.001));
        expect(persistedEvents[3].source, EventSource.imported);

        // ppO2Low — severity exported as 'warning', round-trips
        expect(persistedEvents[4].eventType, ProfileEventType.ppO2Low);
        expect(persistedEvents[4].severity, EventSeverity.warning);
        expect(persistedEvents[4].value, closeTo(0.15, 0.001));
        expect(persistedEvents[4].depth, closeTo(25.0, 0.001));
        expect(persistedEvents[4].source, EventSource.imported);

        // decoViolation — severity exported as 'alert', round-trips
        expect(persistedEvents[5].eventType, ProfileEventType.decoViolation);
        expect(persistedEvents[5].severity, EventSeverity.alert);
        expect(persistedEvents[5].value, closeTo(18.0, 0.001));
        expect(persistedEvents[5].depth, closeTo(15.0, 0.001));
        expect(persistedEvents[5].source, EventSource.imported);

        // decoStopStart (decoStop factory with isStart=true)
        expect(persistedEvents[6].eventType, ProfileEventType.decoStopStart);
        expect(persistedEvents[6].depth, closeTo(6.0, 0.001));
        expect(persistedEvents[6].source, EventSource.imported);

        // safetyStopStart (safetyStop factory with isStart=true)
        expect(persistedEvents[7].eventType, ProfileEventType.safetyStopStart);
        expect(persistedEvents[7].depth, closeTo(5.0, 0.001));
        expect(persistedEvents[7].source, EventSource.imported);
      },
    );

    test(
      'stop-end event types silently drop on UDDF round-trip (known gap)',
      () async {
        // safetyStopEnd and decoStopEnd are produced by profile_analysis_service
        // with isStart: false. The exporter writes them to UDDF verbatim, but
        // the importer's _importDives switch only handles the *Start variants —
        // the End variants fall through the default: log-and-skip branch.
        //
        // This test pins that behavior so it can't regress silently, and so a
        // future developer who adds handling for stop-end events updates this
        // test + the round-trip coverage. Not a bug to fix today — Slice C.3
        // deliberately kept the 8-type scope from Slice C.2.
        //
        // TODO-IF-EXTENDED: when a future slice adds safetyStopEnd/decoStopEnd
        // handling, this test should be updated: either delete it, or change
        // the assertion to verify(insertProfileEvents(captureAny)).captured
        // contains two events with the correct eventTypes.
        final data = UddfImportResult(
          dives: [
            {
              'dateTime': now,
              'maxDepth': 20.0,
              'events': [
                {
                  'eventType': 'safetyStopEnd',
                  'timestamp': 2700,
                  'depth': 5.0,
                  'severity': 'info',
                },
                {
                  'eventType': 'decoStopEnd',
                  'timestamp': 2400,
                  'depth': 6.0,
                  'severity': 'info',
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

        verifyNever(mockDiveRepo.insertProfileEvents(any));
      },
    );
  });
}
