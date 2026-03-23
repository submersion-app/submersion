import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/models/uddf_import_result.dart';
import 'package:submersion/features/dive_import/data/services/uddf_duplicate_checker.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_import/data/services/uddf_parser_service.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/import_wizard/data/adapters/uddf_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';

@GenerateNiceMocks([
  MockSpec<UddfParserService>(),
  MockSpec<UddfDuplicateChecker>(),
  MockSpec<UddfEntityImporter>(),
  MockSpec<ImportRepositories>(),
  MockSpec<DiveRepository>(),
])
import 'uddf_adapter_test.mocks.dart';

// ---------------------------------------------------------------------------
// Test data helpers
// ---------------------------------------------------------------------------

const _diverId = 'diver-1';

/// Create a minimal [UddfImportResult] with only dives.
UddfImportResult makeDiveOnlyResult({List<Map<String, dynamic>>? dives}) {
  return UddfImportResult(
    dives:
        dives ??
        [
          {
            'dateTime': DateTime(2026, 3, 15, 10, 32),
            'maxDepth': 32.4,
            'runtime': const Duration(minutes: 47),
          },
        ],
  );
}

/// Create a [UddfImportResult] with multiple entity types populated.
UddfImportResult makeMultiEntityResult() {
  return UddfImportResult(
    dives: [
      {
        'dateTime': DateTime(2026, 3, 15, 10, 32),
        'maxDepth': 32.4,
        'runtime': const Duration(minutes: 47),
      },
    ],
    sites: [
      {'name': 'Blue Hole', 'latitude': 17.315, 'longitude': -87.535},
    ],
    buddies: [
      {'firstName': 'Jane', 'lastName': 'Doe'},
    ],
    equipment: [
      {'name': 'Regulator', 'type': EquipmentType.regulator},
    ],
    trips: [
      {
        'name': 'Belize Trip',
        'startDate': DateTime(2026, 3, 10),
        'endDate': DateTime(2026, 3, 20),
      },
    ],
    certifications: [
      {'name': 'Advanced Open Water', 'agency': CertificationAgency.padi},
    ],
    diveCenters: [
      {'name': 'Reef Divers', 'country': 'Belize'},
    ],
    tags: [
      {'name': 'Night Dive'},
    ],
    customDiveTypes: [
      {'name': 'Cavern'},
    ],
    equipmentSets: [
      {'name': 'Tropical Kit'},
    ],
    courses: [
      {'name': 'Rescue Diver', 'agency': 'PADI'},
    ],
  );
}

/// Create a domain [Dive] for duplicate checking tests.
Dive makeDomainDive({
  String id = 'dive-uuid-1',
  DateTime? dateTime,
  double? maxDepth = 32.4,
  Duration? duration = const Duration(minutes: 47),
}) {
  final dt = dateTime ?? DateTime(2026, 3, 15, 10, 32);
  return Dive(
    id: id,
    diverId: _diverId,
    dateTime: dt,
    entryTime: dt,
    exitTime: dt.add(duration ?? const Duration(minutes: 47)),
    maxDepth: maxDepth,
    runtime: duration,
    notes: '',
    diveTypeId: '',
    tanks: const [],
    profile: const [],
    equipment: const [],
    photoIds: const [],
    sightings: const [],
  );
}

void main() {
  late MockUddfParserService mockParser;
  late MockUddfDuplicateChecker mockDuplicateChecker;
  late MockUddfEntityImporter mockEntityImporter;
  late MockImportRepositories mockRepositories;
  late MockDiveRepository mockDiveRepo;
  late UddfAdapter adapter;

  setUp(() {
    mockParser = MockUddfParserService();
    mockDuplicateChecker = MockUddfDuplicateChecker();
    mockEntityImporter = MockUddfEntityImporter();
    mockRepositories = MockImportRepositories();
    mockDiveRepo = MockDiveRepository();

    adapter = UddfAdapter(
      parser: mockParser,
      duplicateChecker: mockDuplicateChecker,
      entityImporter: mockEntityImporter,
      repositories: mockRepositories,
      diveRepository: mockDiveRepo,
      existingTrips: const [],
      existingSites: const [],
      existingEquipment: const [],
      existingBuddies: const [],
      existingDiveCenters: const [],
      existingCertifications: const [],
      existingTags: const [],
      existingDiveTypes: const [],
      diverId: _diverId,
    );
  });

  // -------------------------------------------------------------------------
  // buildBundle — entity types populated
  // -------------------------------------------------------------------------

  group('buildBundle()', () {
    test('populates all non-empty entity types', () async {
      final data = makeMultiEntityResult();
      adapter.setParsedData(data);

      final bundle = await adapter.buildBundle();

      expect(bundle.hasType(ImportEntityType.dives), isTrue);
      expect(bundle.hasType(ImportEntityType.sites), isTrue);
      expect(bundle.hasType(ImportEntityType.buddies), isTrue);
      expect(bundle.hasType(ImportEntityType.equipment), isTrue);
      expect(bundle.hasType(ImportEntityType.trips), isTrue);
      expect(bundle.hasType(ImportEntityType.certifications), isTrue);
      expect(bundle.hasType(ImportEntityType.diveCenters), isTrue);
      expect(bundle.hasType(ImportEntityType.tags), isTrue);
      expect(bundle.hasType(ImportEntityType.diveTypes), isTrue);
      expect(bundle.hasType(ImportEntityType.equipmentSets), isTrue);
      expect(bundle.hasType(ImportEntityType.courses), isTrue);
    });

    test('omits entity types with empty lists', () async {
      final data = makeDiveOnlyResult();
      adapter.setParsedData(data);

      final bundle = await adapter.buildBundle();

      expect(bundle.hasType(ImportEntityType.dives), isTrue);
      expect(bundle.hasType(ImportEntityType.sites), isFalse);
      expect(bundle.hasType(ImportEntityType.buddies), isFalse);
      expect(bundle.hasType(ImportEntityType.equipment), isFalse);
      expect(bundle.hasType(ImportEntityType.trips), isFalse);
      expect(bundle.hasType(ImportEntityType.certifications), isFalse);
      expect(bundle.hasType(ImportEntityType.diveCenters), isFalse);
      expect(bundle.hasType(ImportEntityType.tags), isFalse);
      expect(bundle.hasType(ImportEntityType.diveTypes), isFalse);
      expect(bundle.hasType(ImportEntityType.equipmentSets), isFalse);
      expect(bundle.hasType(ImportEntityType.courses), isFalse);
    });

    test('returns empty groups when no data parsed', () async {
      final bundle = await adapter.buildBundle();

      expect(bundle.groups, isEmpty);
    });

    test('dive EntityItems have diveData populated', () async {
      final data = makeDiveOnlyResult(
        dives: [
          {
            'dateTime': DateTime(2026, 3, 15, 10, 32),
            'maxDepth': 32.4,
            'avgDepth': 18.0,
            'runtime': const Duration(minutes: 47),
            'waterTemp': 22.1,
          },
        ],
      );
      adapter.setParsedData(data);

      final bundle = await adapter.buildBundle();
      final item = bundle.groups[ImportEntityType.dives]!.items.first;

      expect(item.diveData, isNotNull);
      expect(item.diveData!.maxDepth, equals(32.4));
      expect(item.diveData!.avgDepth, equals(18.0));
      expect(item.diveData!.durationSeconds, equals(47 * 60));
    });

    test('dive title contains formatted date and time', () async {
      final data = makeDiveOnlyResult(
        dives: [
          {
            'dateTime': DateTime(2026, 3, 15, 10, 32),
            'maxDepth': 25.0,
            'runtime': const Duration(minutes: 40),
          },
        ],
      );
      adapter.setParsedData(data);

      final bundle = await adapter.buildBundle();
      final item = bundle.groups[ImportEntityType.dives]!.items.first;

      expect(item.title, contains('Mar 15, 2026'));
      expect(item.title, contains('\u2014'));
      expect(item.title, contains('10:32'));
    });

    test('dive subtitle contains depth and duration', () async {
      final data = makeDiveOnlyResult(
        dives: [
          {
            'dateTime': DateTime(2026, 3, 15, 10, 32),
            'maxDepth': 32.4,
            'runtime': const Duration(minutes: 47),
          },
        ],
      );
      adapter.setParsedData(data);

      final bundle = await adapter.buildBundle();
      final item = bundle.groups[ImportEntityType.dives]!.items.first;

      expect(item.subtitle, contains('32.4m'));
      expect(item.subtitle, contains('47 min'));
    });

    test('site title uses name, subtitle uses coordinates', () async {
      const data = UddfImportResult(
        sites: [
          {'name': 'Blue Hole', 'latitude': 17.315, 'longitude': -87.535},
        ],
      );
      adapter.setParsedData(data);

      final bundle = await adapter.buildBundle();
      final item = bundle.groups[ImportEntityType.sites]!.items.first;

      expect(item.title, equals('Blue Hole'));
      expect(item.subtitle, contains('17.3150'));
      expect(item.subtitle, contains('-87.5350'));
    });

    test('buddy title combines firstName and lastName', () async {
      const data = UddfImportResult(
        buddies: [
          {'firstName': 'Jane', 'lastName': 'Doe'},
        ],
      );
      adapter.setParsedData(data);

      final bundle = await adapter.buildBundle();
      final item = bundle.groups[ImportEntityType.buddies]!.items.first;

      expect(item.title, equals('Jane Doe'));
    });

    test('buddy title falls back to name key', () async {
      const data = UddfImportResult(
        buddies: [
          {'name': 'Alex Smith'},
        ],
      );
      adapter.setParsedData(data);

      final bundle = await adapter.buildBundle();
      final item = bundle.groups[ImportEntityType.buddies]!.items.first;

      expect(item.title, equals('Alex Smith'));
    });

    test('equipment subtitle shows type', () async {
      const data = UddfImportResult(
        equipment: [
          {'name': 'Oceanic Alpha', 'type': EquipmentType.regulator},
        ],
      );
      adapter.setParsedData(data);

      final bundle = await adapter.buildBundle();
      final item = bundle.groups[ImportEntityType.equipment]!.items.first;

      expect(item.title, equals('Oceanic Alpha'));
      expect(item.subtitle, equals(EquipmentType.regulator.displayName));
    });

    test('trip subtitle shows date range', () async {
      final data = UddfImportResult(
        trips: [
          {
            'name': 'Belize Trip',
            'startDate': DateTime(2026, 3, 10),
            'endDate': DateTime(2026, 3, 20),
          },
        ],
      );
      adapter.setParsedData(data);

      final bundle = await adapter.buildBundle();
      final item = bundle.groups[ImportEntityType.trips]!.items.first;

      expect(item.title, equals('Belize Trip'));
      expect(item.subtitle, contains('Mar 10, 2026'));
      expect(item.subtitle, contains('Mar 20, 2026'));
    });

    test('certification title from name, subtitle from agency', () async {
      const data = UddfImportResult(
        certifications: [
          {'name': 'Advanced Open Water', 'agency': CertificationAgency.padi},
        ],
      );
      adapter.setParsedData(data);

      final bundle = await adapter.buildBundle();
      final item = bundle.groups[ImportEntityType.certifications]!.items.first;

      expect(item.title, equals('Advanced Open Water'));
      expect(item.subtitle, equals(CertificationAgency.padi.displayName));
    });

    test('course subtitle shows agency string', () async {
      const data = UddfImportResult(
        courses: [
          {'name': 'Rescue Diver', 'agency': 'PADI'},
        ],
      );
      adapter.setParsedData(data);

      final bundle = await adapter.buildBundle();
      final item = bundle.groups[ImportEntityType.courses]!.items.first;

      expect(item.title, equals('Rescue Diver'));
      expect(item.subtitle, equals('PADI'));
    });

    test('source info reflects adapter displayName and uddf type', () async {
      adapter.setParsedData(const UddfImportResult());

      final bundle = await adapter.buildBundle();

      expect(bundle.source.type, equals(ImportSourceType.uddf));
      expect(bundle.source.displayName, equals('UDDF Import'));
    });
  });

  // -------------------------------------------------------------------------
  // checkDuplicates
  // -------------------------------------------------------------------------

  group('checkDuplicates()', () {
    test('maps duplicate indices per entity type', () async {
      final data = makeMultiEntityResult();
      adapter.setParsedData(data);
      final bundle = await adapter.buildBundle();

      when(
        mockDiveRepo.getAllDives(diverId: _diverId),
      ).thenAnswer((_) async => []);

      when(
        mockDuplicateChecker.check(
          importData: data,
          existingTrips: anyNamed('existingTrips'),
          existingSites: anyNamed('existingSites'),
          existingEquipment: anyNamed('existingEquipment'),
          existingBuddies: anyNamed('existingBuddies'),
          existingDiveCenters: anyNamed('existingDiveCenters'),
          existingCertifications: anyNamed('existingCertifications'),
          existingTags: anyNamed('existingTags'),
          existingDiveTypes: anyNamed('existingDiveTypes'),
          existingDives: anyNamed('existingDives'),
          matcher: anyNamed('matcher'),
        ),
      ).thenReturn(
        const UddfDuplicateCheckResult(
          duplicateTrips: {0},
          duplicateSites: {0},
          duplicateBuddies: {0},
        ),
      );

      final result = await adapter.checkDuplicates(bundle);

      expect(
        result.groups[ImportEntityType.trips]!.duplicateIndices,
        equals({0}),
      );
      expect(
        result.groups[ImportEntityType.sites]!.duplicateIndices,
        equals({0}),
      );
      expect(
        result.groups[ImportEntityType.buddies]!.duplicateIndices,
        equals({0}),
      );
      // Non-duplicate types should remain without duplicates
      expect(
        result.groups[ImportEntityType.equipment]!.duplicateIndices,
        isEmpty,
      );
    });

    test('maps dive match results correctly', () async {
      final data = makeDiveOnlyResult();
      adapter.setParsedData(data);
      final bundle = await adapter.buildBundle();

      const diveMatch = DiveMatchResult(
        diveId: 'existing-dive-1',
        score: 0.85,
        timeDifferenceMs: 60000,
        depthDifferenceMeters: 0.5,
        durationDifferenceSeconds: 30,
      );

      when(
        mockDiveRepo.getAllDives(diverId: _diverId),
      ).thenAnswer((_) async => []);

      when(
        mockDuplicateChecker.check(
          importData: data,
          existingTrips: anyNamed('existingTrips'),
          existingSites: anyNamed('existingSites'),
          existingEquipment: anyNamed('existingEquipment'),
          existingBuddies: anyNamed('existingBuddies'),
          existingDiveCenters: anyNamed('existingDiveCenters'),
          existingCertifications: anyNamed('existingCertifications'),
          existingTags: anyNamed('existingTags'),
          existingDiveTypes: anyNamed('existingDiveTypes'),
          existingDives: anyNamed('existingDives'),
          matcher: anyNamed('matcher'),
        ),
      ).thenReturn(const UddfDuplicateCheckResult(diveMatches: {0: diveMatch}));

      final result = await adapter.checkDuplicates(bundle);
      final diveGroup = result.groups[ImportEntityType.dives]!;

      expect(diveGroup.duplicateIndices, contains(0));
      expect(diveGroup.matchResults, isNotNull);
      expect(diveGroup.matchResults![0]!.score, equals(0.85));
      expect(diveGroup.matchResults![0]!.diveId, equals('existing-dive-1'));
    });

    test('leaves bundle unchanged when no duplicates found', () async {
      final data = makeDiveOnlyResult();
      adapter.setParsedData(data);
      final bundle = await adapter.buildBundle();

      when(
        mockDiveRepo.getAllDives(diverId: _diverId),
      ).thenAnswer((_) async => []);

      when(
        mockDuplicateChecker.check(
          importData: data,
          existingTrips: anyNamed('existingTrips'),
          existingSites: anyNamed('existingSites'),
          existingEquipment: anyNamed('existingEquipment'),
          existingBuddies: anyNamed('existingBuddies'),
          existingDiveCenters: anyNamed('existingDiveCenters'),
          existingCertifications: anyNamed('existingCertifications'),
          existingTags: anyNamed('existingTags'),
          existingDiveTypes: anyNamed('existingDiveTypes'),
          existingDives: anyNamed('existingDives'),
          matcher: anyNamed('matcher'),
        ),
      ).thenReturn(const UddfDuplicateCheckResult());

      final result = await adapter.checkDuplicates(bundle);

      expect(result.groups[ImportEntityType.dives]!.duplicateIndices, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // performImport
  // -------------------------------------------------------------------------

  group('performImport()', () {
    test('calls UddfEntityImporter with correct selections', () async {
      final data = makeMultiEntityResult();
      adapter.setParsedData(data);
      final bundle = await adapter.buildBundle();

      when(
        mockEntityImporter.import(
          data: anyNamed('data'),
          selections: anyNamed('selections'),
          repositories: anyNamed('repositories'),
          diverId: anyNamed('diverId'),
          onProgress: anyNamed('onProgress'),
        ),
      ).thenAnswer(
        (_) async => const UddfEntityImportResult(dives: 1, sites: 1),
      );

      await adapter.performImport(bundle, {
        ImportEntityType.dives: {0},
        ImportEntityType.sites: {0},
      }, {});

      final captured = verify(
        mockEntityImporter.import(
          data: captureAnyNamed('data'),
          selections: captureAnyNamed('selections'),
          repositories: captureAnyNamed('repositories'),
          diverId: captureAnyNamed('diverId'),
          onProgress: anyNamed('onProgress'),
        ),
      ).captured;

      // captured[0] = data, captured[1] = selections, captured[3] = diverId
      expect(captured[0], equals(data));
      final selections = captured[1] as UddfImportSelections;
      expect(selections.dives, equals({0}));
      expect(selections.sites, equals({0}));
      expect(captured[3], equals(_diverId));
    });

    test('DuplicateAction.skip excludes dives from selection', () async {
      final data = makeDiveOnlyResult(
        dives: [
          {
            'dateTime': DateTime(2026, 3, 15, 10, 32),
            'maxDepth': 32.4,
            'runtime': const Duration(minutes: 47),
          },
          {
            'dateTime': DateTime(2026, 3, 16, 9, 0),
            'maxDepth': 20.0,
            'runtime': const Duration(minutes: 35),
          },
        ],
      );
      adapter.setParsedData(data);
      final bundle = await adapter.buildBundle();

      when(
        mockEntityImporter.import(
          data: anyNamed('data'),
          selections: anyNamed('selections'),
          repositories: anyNamed('repositories'),
          diverId: anyNamed('diverId'),
          onProgress: anyNamed('onProgress'),
        ),
      ).thenAnswer((_) async => const UddfEntityImportResult(dives: 1));

      final result = await adapter.performImport(
        bundle,
        {
          ImportEntityType.dives: {0, 1},
        },
        {
          ImportEntityType.dives: {1: DuplicateAction.skip},
        },
      );

      final captured = verify(
        mockEntityImporter.import(
          data: anyNamed('data'),
          selections: captureAnyNamed('selections'),
          repositories: anyNamed('repositories'),
          diverId: anyNamed('diverId'),
          onProgress: anyNamed('onProgress'),
        ),
      ).captured;

      final selections = captured[0] as UddfImportSelections;
      expect(selections.dives, equals({0}));
      expect(result.skippedCount, equals(1));
    });

    test('DuplicateAction.importAsNew includes dive in selection', () async {
      final data = makeDiveOnlyResult();
      adapter.setParsedData(data);
      final bundle = await adapter.buildBundle();

      when(
        mockEntityImporter.import(
          data: anyNamed('data'),
          selections: anyNamed('selections'),
          repositories: anyNamed('repositories'),
          diverId: anyNamed('diverId'),
          onProgress: anyNamed('onProgress'),
        ),
      ).thenAnswer((_) async => const UddfEntityImportResult(dives: 1));

      await adapter.performImport(
        bundle,
        {ImportEntityType.dives: <int>{}},
        {
          ImportEntityType.dives: {0: DuplicateAction.importAsNew},
        },
      );

      final captured = verify(
        mockEntityImporter.import(
          data: anyNamed('data'),
          selections: captureAnyNamed('selections'),
          repositories: anyNamed('repositories'),
          diverId: anyNamed('diverId'),
          onProgress: anyNamed('onProgress'),
        ),
      ).captured;

      final selections = captured[0] as UddfImportSelections;
      expect(selections.dives, equals({0}));
    });

    test('converts UddfEntityImportResult to UnifiedImportResult', () async {
      final data = makeMultiEntityResult();
      adapter.setParsedData(data);
      final bundle = await adapter.buildBundle();

      when(
        mockEntityImporter.import(
          data: anyNamed('data'),
          selections: anyNamed('selections'),
          repositories: anyNamed('repositories'),
          diverId: anyNamed('diverId'),
          onProgress: anyNamed('onProgress'),
        ),
      ).thenAnswer(
        (_) async => const UddfEntityImportResult(
          dives: 1,
          sites: 1,
          buddies: 1,
          equipment: 1,
          trips: 1,
          certifications: 1,
          diveCenters: 1,
          tags: 1,
          diveTypes: 1,
          equipmentSets: 1,
          courses: 1,
        ),
      );

      final result = await adapter.performImport(bundle, {
        ImportEntityType.dives: {0},
        ImportEntityType.sites: {0},
        ImportEntityType.buddies: {0},
        ImportEntityType.equipment: {0},
        ImportEntityType.trips: {0},
        ImportEntityType.certifications: {0},
        ImportEntityType.diveCenters: {0},
        ImportEntityType.tags: {0},
        ImportEntityType.diveTypes: {0},
        ImportEntityType.equipmentSets: {0},
        ImportEntityType.courses: {0},
      }, {});

      expect(result.importedCounts[ImportEntityType.dives], equals(1));
      expect(result.importedCounts[ImportEntityType.sites], equals(1));
      expect(result.importedCounts[ImportEntityType.buddies], equals(1));
      expect(result.importedCounts[ImportEntityType.equipment], equals(1));
      expect(result.importedCounts[ImportEntityType.trips], equals(1));
      expect(result.importedCounts[ImportEntityType.certifications], equals(1));
      expect(result.importedCounts[ImportEntityType.diveCenters], equals(1));
      expect(result.importedCounts[ImportEntityType.tags], equals(1));
      expect(result.importedCounts[ImportEntityType.diveTypes], equals(1));
      expect(result.importedCounts[ImportEntityType.equipmentSets], equals(1));
      expect(result.importedCounts[ImportEntityType.courses], equals(1));
      expect(result.consolidatedCount, equals(0));
    });

    test('returns error when no data parsed', () async {
      const bundle = ImportBundle(
        source: ImportSourceInfo(
          type: ImportSourceType.uddf,
          displayName: 'test',
        ),
        groups: {},
      );

      final result = await adapter.performImport(bundle, {}, {});

      expect(result.errorMessage, isNotNull);
      expect(result.importedCounts, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // Adapter metadata
  // -------------------------------------------------------------------------

  group('adapter metadata', () {
    test('sourceType is uddf', () {
      expect(adapter.sourceType, equals(ImportSourceType.uddf));
    });

    test('displayName defaults to UDDF Import', () {
      expect(adapter.displayName, equals('UDDF Import'));
    });

    test('custom displayName is used when provided', () {
      final named = UddfAdapter(
        parser: mockParser,
        duplicateChecker: mockDuplicateChecker,
        entityImporter: mockEntityImporter,
        repositories: mockRepositories,
        diveRepository: mockDiveRepo,
        existingTrips: const [],
        existingSites: const [],
        existingEquipment: const [],
        existingBuddies: const [],
        existingDiveCenters: const [],
        existingCertifications: const [],
        existingTags: const [],
        existingDiveTypes: const [],
        diverId: _diverId,
        displayName: 'my_dives.uddf',
      );
      expect(named.displayName, equals('my_dives.uddf'));
    });

    test('supportedDuplicateActions contains skip and importAsNew', () {
      expect(
        adapter.supportedDuplicateActions,
        containsAll([DuplicateAction.skip, DuplicateAction.importAsNew]),
      );
      expect(
        adapter.supportedDuplicateActions,
        isNot(contains(DuplicateAction.consolidate)),
      );
    });

    test('acquisitionSteps has one step labelled Select File', () {
      expect(adapter.acquisitionSteps, hasLength(1));
      expect(adapter.acquisitionSteps.first.label, equals('Select File'));
    });
  });
}
