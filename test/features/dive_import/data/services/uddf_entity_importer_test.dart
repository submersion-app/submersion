import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
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
}
