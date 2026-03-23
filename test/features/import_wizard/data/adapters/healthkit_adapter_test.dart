import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/features/dive_import/domain/entities/imported_dive.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/dive_import/domain/services/health_import_service.dart';
import 'package:submersion/features/dive_import/domain/services/imported_dive_converter.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/import_wizard/data/adapters/healthkit_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';

@GenerateNiceMocks([
  MockSpec<HealthImportService>(),
  MockSpec<DiveMatcher>(),
  MockSpec<ImportedDiveConverter>(),
  MockSpec<DiveRepository>(),
])
import 'healthkit_adapter_test.mocks.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

ImportedDive makeDive({
  String sourceId = 'healthkit-abc-1000000',
  DateTime? startTime,
  DateTime? endTime,
  double maxDepth = 18.5,
  double? avgDepth = 10.0,
  double? minTemperature = 24.0,
  List<ImportedProfileSample> profile = const [],
}) {
  final start = startTime ?? DateTime(2026, 3, 15, 9, 00);
  final end = endTime ?? start.add(const Duration(minutes: 42));
  return ImportedDive(
    sourceId: sourceId,
    source: ImportSource.appleWatch,
    startTime: start,
    endTime: end,
    maxDepth: maxDepth,
    avgDepth: avgDepth,
    minTemperature: minTemperature,
    profile: profile,
  );
}

Dive makeDomainDive({
  String id = 'dive-uuid-1',
  String? diverId = 'diver-1',
  DateTime? dateTime,
  double? maxDepth = 18.5,
  Duration? duration = const Duration(minutes: 42),
}) {
  final dt = dateTime ?? DateTime(2026, 3, 15, 9, 00);
  return Dive(
    id: id,
    diverId: diverId,
    dateTime: dt,
    entryTime: dt,
    exitTime: dt.add(duration ?? const Duration(minutes: 42)),
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
  late MockHealthImportService mockHealthService;
  late MockDiveMatcher mockMatcher;
  late MockImportedDiveConverter mockConverter;
  late MockDiveRepository mockRepo;
  late HealthKitAdapter adapter;

  const diverId = 'diver-1';

  setUp(() {
    mockHealthService = MockHealthImportService();
    mockMatcher = MockDiveMatcher();
    mockConverter = MockImportedDiveConverter();
    mockRepo = MockDiveRepository();

    adapter = HealthKitAdapter(
      healthService: mockHealthService,
      diveMatcher: mockMatcher,
      converter: mockConverter,
      diveRepository: mockRepo,
      diverId: diverId,
    );
  });

  // -------------------------------------------------------------------------
  // buildBundle
  // -------------------------------------------------------------------------

  group('buildBundle()', () {
    test('returns bundle with dives group', () async {
      final dive = makeDive();
      adapter.setParsedDives([dive]);

      final bundle = await adapter.buildBundle();

      expect(bundle.hasType(ImportEntityType.dives), isTrue);
      expect(bundle.groups[ImportEntityType.dives]!.items, hasLength(1));
    });

    test(
      'EntityItem titles are formatted as "MMM d, yyyy \u2014 h:mm AM/PM"',
      () async {
        final dive = makeDive(startTime: DateTime(2026, 3, 15, 9, 00));
        adapter.setParsedDives([dive]);

        final bundle = await adapter.buildBundle();
        final item = bundle.groups[ImportEntityType.dives]!.items.first;

        expect(item.title, contains('Mar 15, 2026'));
        expect(item.title, contains('\u2014'));
        expect(item.title, contains('9:00'));
      },
    );

    test(
      'EntityItem subtitles contain depth, duration, and temperature',
      () async {
        final dive = makeDive(
          maxDepth: 18.5,
          minTemperature: 24.0,
          startTime: DateTime(2026, 3, 15, 9, 00),
          endTime: DateTime(2026, 3, 15, 9, 42),
        );
        adapter.setParsedDives([dive]);

        final bundle = await adapter.buildBundle();
        final item = bundle.groups[ImportEntityType.dives]!.items.first;

        expect(item.subtitle, contains('18.5m'));
        expect(item.subtitle, contains('42 min'));
        expect(item.subtitle, contains('24.0'));
      },
    );

    test('EntityItem subtitle omits temperature when null', () async {
      final dive = makeDive(minTemperature: null);
      adapter.setParsedDives([dive]);

      final bundle = await adapter.buildBundle();
      final item = bundle.groups[ImportEntityType.dives]!.items.first;

      expect(item.subtitle, isNot(contains('\u00b0C')));
    });

    test('EntityItem diveData is populated', () async {
      final profile = [
        const ImportedProfileSample(timeSeconds: 0, depth: 0.0),
        const ImportedProfileSample(timeSeconds: 60, depth: 8.0),
      ];
      final dive = makeDive(
        maxDepth: 18.5,
        avgDepth: 10.0,
        minTemperature: 24.0,
        profile: profile,
      );
      adapter.setParsedDives([dive]);

      final bundle = await adapter.buildBundle();
      final item = bundle.groups[ImportEntityType.dives]!.items.first;

      expect(item.diveData, isNotNull);
      expect(item.diveData!.maxDepth, equals(18.5));
      expect(item.diveData!.avgDepth, equals(10.0));
      expect(item.diveData!.waterTemp, equals(24.0));
      expect(item.diveData!.durationSeconds, equals(42 * 60));
      expect(item.diveData!.profile, hasLength(2));
    });

    test('returns empty dives group when no parsed dives', () async {
      adapter.setParsedDives([]);

      final bundle = await adapter.buildBundle();

      expect(bundle.groups[ImportEntityType.dives]!.items, isEmpty);
    });

    test(
      'source info reflects adapter displayName and healthKit type',
      () async {
        adapter.setParsedDives([]);

        final bundle = await adapter.buildBundle();

        expect(bundle.source.type, equals(ImportSourceType.healthKit));
        expect(bundle.source.displayName, equals('HealthKit Import'));
      },
    );
  });

  // -------------------------------------------------------------------------
  // checkDuplicates
  // -------------------------------------------------------------------------

  group('checkDuplicates()', () {
    test('marks probable matches in duplicateIndices', () async {
      final dive = makeDive(startTime: DateTime(2026, 3, 15, 9, 00));
      adapter.setParsedDives([dive]);
      final bundle = await adapter.buildBundle();

      final existingDive = makeDomainDive(
        dateTime: DateTime(2026, 3, 15, 9, 01),
        maxDepth: 18.5,
        duration: const Duration(minutes: 42),
      );
      when(
        mockRepo.getAllDives(diverId: diverId),
      ).thenAnswer((_) async => [existingDive]);
      when(
        mockMatcher.calculateMatchScore(
          wearableStartTime: anyNamed('wearableStartTime'),
          wearableMaxDepth: anyNamed('wearableMaxDepth'),
          wearableDurationSeconds: anyNamed('wearableDurationSeconds'),
          existingStartTime: anyNamed('existingStartTime'),
          existingMaxDepth: anyNamed('existingMaxDepth'),
          existingDurationSeconds: anyNamed('existingDurationSeconds'),
        ),
      ).thenReturn(0.9);

      final result = await adapter.checkDuplicates(bundle);

      expect(
        result.groups[ImportEntityType.dives]!.duplicateIndices,
        contains(0),
      );
    });

    test('populates matchResults with scores', () async {
      final dive = makeDive();
      adapter.setParsedDives([dive]);
      final bundle = await adapter.buildBundle();

      final existingDive = makeDomainDive();
      when(
        mockRepo.getAllDives(diverId: diverId),
      ).thenAnswer((_) async => [existingDive]);
      when(
        mockMatcher.calculateMatchScore(
          wearableStartTime: anyNamed('wearableStartTime'),
          wearableMaxDepth: anyNamed('wearableMaxDepth'),
          wearableDurationSeconds: anyNamed('wearableDurationSeconds'),
          existingStartTime: anyNamed('existingStartTime'),
          existingMaxDepth: anyNamed('existingMaxDepth'),
          existingDurationSeconds: anyNamed('existingDurationSeconds'),
        ),
      ).thenReturn(0.75);

      final result = await adapter.checkDuplicates(bundle);

      final matchResult =
          result.groups[ImportEntityType.dives]!.matchResults![0];
      expect(matchResult, isNotNull);
      expect(matchResult!.score, equals(0.75));
    });

    test('leaves bundle unchanged when no matches above threshold', () async {
      final dive = makeDive();
      adapter.setParsedDives([dive]);
      final bundle = await adapter.buildBundle();

      final existingDive = makeDomainDive();
      when(
        mockRepo.getAllDives(diverId: diverId),
      ).thenAnswer((_) async => [existingDive]);
      when(
        mockMatcher.calculateMatchScore(
          wearableStartTime: anyNamed('wearableStartTime'),
          wearableMaxDepth: anyNamed('wearableMaxDepth'),
          wearableDurationSeconds: anyNamed('wearableDurationSeconds'),
          existingStartTime: anyNamed('existingStartTime'),
          existingMaxDepth: anyNamed('existingMaxDepth'),
          existingDurationSeconds: anyNamed('existingDurationSeconds'),
        ),
      ).thenReturn(0.2);

      final result = await adapter.checkDuplicates(bundle);

      expect(result.groups[ImportEntityType.dives]!.duplicateIndices, isEmpty);
      expect(result.groups[ImportEntityType.dives]!.matchResults, isEmpty);
    });

    test('uses 0.5 threshold for possible duplicates', () async {
      final dive = makeDive();
      adapter.setParsedDives([dive]);
      final bundle = await adapter.buildBundle();

      final existingDive = makeDomainDive();
      when(
        mockRepo.getAllDives(diverId: diverId),
      ).thenAnswer((_) async => [existingDive]);
      when(
        mockMatcher.calculateMatchScore(
          wearableStartTime: anyNamed('wearableStartTime'),
          wearableMaxDepth: anyNamed('wearableMaxDepth'),
          wearableDurationSeconds: anyNamed('wearableDurationSeconds'),
          existingStartTime: anyNamed('existingStartTime'),
          existingMaxDepth: anyNamed('existingMaxDepth'),
          existingDurationSeconds: anyNamed('existingDurationSeconds'),
        ),
      ).thenReturn(0.5);

      final result = await adapter.checkDuplicates(bundle);

      expect(
        result.groups[ImportEntityType.dives]!.duplicateIndices,
        contains(0),
      );
    });

    test('picks best match when multiple existing dives', () async {
      final dive = makeDive();
      adapter.setParsedDives([dive]);
      final bundle = await adapter.buildBundle();

      final existing1 = makeDomainDive(id: 'dive-1');
      final existing2 = makeDomainDive(id: 'dive-2');
      when(
        mockRepo.getAllDives(diverId: diverId),
      ).thenAnswer((_) async => [existing1, existing2]);
      var callCount = 0;
      when(
        mockMatcher.calculateMatchScore(
          wearableStartTime: anyNamed('wearableStartTime'),
          wearableMaxDepth: anyNamed('wearableMaxDepth'),
          wearableDurationSeconds: anyNamed('wearableDurationSeconds'),
          existingStartTime: anyNamed('existingStartTime'),
          existingMaxDepth: anyNamed('existingMaxDepth'),
          existingDurationSeconds: anyNamed('existingDurationSeconds'),
        ),
      ).thenAnswer((_) => callCount++ == 0 ? 0.6 : 0.85);

      final result = await adapter.checkDuplicates(bundle);

      final matchResult =
          result.groups[ImportEntityType.dives]!.matchResults![0];
      expect(matchResult!.score, equals(0.85));
      expect(matchResult.diveId, equals('dive-2'));
    });
  });

  // -------------------------------------------------------------------------
  // performImport
  // -------------------------------------------------------------------------

  group('performImport()', () {
    test('imports selected dives via converter and repository', () async {
      final dive = makeDive();
      adapter.setParsedDives([dive]);
      final bundle = await adapter.buildBundle();

      final domainDive = makeDomainDive();
      when(
        mockConverter.convert(dive, diverId: diverId),
      ).thenReturn(domainDive);
      when(mockRepo.createDive(domainDive)).thenAnswer((_) async => domainDive);

      final result = await adapter.performImport(bundle, {
        ImportEntityType.dives: {0},
      }, {});

      verify(mockConverter.convert(dive, diverId: diverId)).called(1);
      verify(mockRepo.createDive(domainDive)).called(1);
      expect(result.importedCounts[ImportEntityType.dives], equals(1));
    });

    test('skips deselected indices', () async {
      final dive1 = makeDive(sourceId: 'healthkit-1');
      final dive2 = makeDive(sourceId: 'healthkit-2');
      adapter.setParsedDives([dive1, dive2]);
      final bundle = await adapter.buildBundle();

      final domainDive1 = makeDomainDive(id: 'dive-1');
      when(
        mockConverter.convert(dive1, diverId: diverId),
      ).thenReturn(domainDive1);
      when(
        mockRepo.createDive(domainDive1),
      ).thenAnswer((_) async => domainDive1);

      // Only index 0 selected, index 1 omitted
      final result = await adapter.performImport(bundle, {
        ImportEntityType.dives: {0},
      }, {});

      verify(mockConverter.convert(dive1, diverId: diverId)).called(1);
      verifyNever(mockConverter.convert(dive2, diverId: diverId));
      expect(result.importedCounts[ImportEntityType.dives], equals(1));
    });

    test('handles DuplicateAction.skip', () async {
      final dive = makeDive();
      adapter.setParsedDives([dive]);
      final bundle = await adapter.buildBundle();

      // Index 0 is in selections but has skip action
      final result = await adapter.performImport(
        bundle,
        {
          ImportEntityType.dives: {0},
        },
        {
          ImportEntityType.dives: {0: DuplicateAction.skip},
        },
      );

      verifyNever(mockConverter.convert(any, diverId: anyNamed('diverId')));
      verifyNever(mockRepo.createDive(any));
      expect(result.skippedCount, equals(1));
      expect(result.importedCounts[ImportEntityType.dives], equals(0));
    });

    test('handles DuplicateAction.importAsNew', () async {
      final dive = makeDive();
      adapter.setParsedDives([dive]);
      final bundle = await adapter.buildBundle();

      final domainDive = makeDomainDive();
      when(
        mockConverter.convert(dive, diverId: diverId),
      ).thenReturn(domainDive);
      when(mockRepo.createDive(domainDive)).thenAnswer((_) async => domainDive);

      // Index 0 is NOT in plain selections but has importAsNew action
      final result = await adapter.performImport(
        bundle,
        {ImportEntityType.dives: <int>{}},
        {
          ImportEntityType.dives: {0: DuplicateAction.importAsNew},
        },
      );

      verify(mockConverter.convert(dive, diverId: diverId)).called(1);
      verify(mockRepo.createDive(domainDive)).called(1);
      expect(result.importedCounts[ImportEntityType.dives], equals(1));
    });

    test('returns correct counts for mixed actions', () async {
      final dive1 = makeDive(sourceId: 'healthkit-1');
      final dive2 = makeDive(sourceId: 'healthkit-2');
      final dive3 = makeDive(sourceId: 'healthkit-3');
      adapter.setParsedDives([dive1, dive2, dive3]);
      final bundle = await adapter.buildBundle();

      final domainDive1 = makeDomainDive(id: 'dive-1');
      final domainDive3 = makeDomainDive(id: 'dive-3');
      when(
        mockConverter.convert(dive1, diverId: diverId),
      ).thenReturn(domainDive1);
      when(
        mockConverter.convert(dive3, diverId: diverId),
      ).thenReturn(domainDive3);
      when(mockRepo.createDive(any)).thenAnswer((_) async => domainDive1);

      // dive1: selected, dive2: skip, dive3: importAsNew
      final result = await adapter.performImport(
        bundle,
        {
          ImportEntityType.dives: {0},
        },
        {
          ImportEntityType.dives: {
            1: DuplicateAction.skip,
            2: DuplicateAction.importAsNew,
          },
        },
      );

      expect(result.importedCounts[ImportEntityType.dives], equals(2));
      expect(result.skippedCount, equals(1));
      expect(result.consolidatedCount, equals(0));
    });

    test('calls onProgress for each imported dive', () async {
      final dive1 = makeDive(sourceId: 'healthkit-1');
      final dive2 = makeDive(sourceId: 'healthkit-2');
      adapter.setParsedDives([dive1, dive2]);
      final bundle = await adapter.buildBundle();

      final domainDive1 = makeDomainDive(id: 'dive-1');
      final domainDive2 = makeDomainDive(id: 'dive-2');
      when(
        mockConverter.convert(dive1, diverId: diverId),
      ).thenReturn(domainDive1);
      when(
        mockConverter.convert(dive2, diverId: diverId),
      ).thenReturn(domainDive2);
      when(mockRepo.createDive(any)).thenAnswer((_) async => domainDive1);

      final progressCalls = <(String, int, int)>[];
      await adapter.performImport(
        bundle,
        {
          ImportEntityType.dives: {0, 1},
        },
        {},
        onProgress: (phase, current, total) {
          progressCalls.add((phase, current, total));
        },
      );

      expect(progressCalls, hasLength(2));
      expect(progressCalls[0].$1, equals('Dives'));
      expect(progressCalls[1].$1, equals('Dives'));
    });
  });

  // -------------------------------------------------------------------------
  // Adapter metadata
  // -------------------------------------------------------------------------

  group('adapter metadata', () {
    test('sourceType is healthKit', () {
      expect(adapter.sourceType, equals(ImportSourceType.healthKit));
    });

    test('displayName defaults to HealthKit Import', () {
      expect(adapter.displayName, equals('HealthKit Import'));
    });

    test('custom displayName is used when provided', () {
      final named = HealthKitAdapter(
        healthService: mockHealthService,
        diveMatcher: mockMatcher,
        converter: mockConverter,
        diveRepository: mockRepo,
        diverId: diverId,
        displayName: 'Apple Watch Dives',
      );
      expect(named.displayName, equals('Apple Watch Dives'));
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

    test('acquisitionSteps has three steps', () {
      expect(adapter.acquisitionSteps, hasLength(3));
    });

    test('first step is Permissions with autoAdvance false', () {
      final step = adapter.acquisitionSteps[0];
      expect(step.label, equals('Permissions'));
      expect(step.autoAdvance, isFalse);
    });

    test('second step is Date Range with autoAdvance false', () {
      final step = adapter.acquisitionSteps[1];
      expect(step.label, equals('Date Range'));
      expect(step.autoAdvance, isFalse);
    });

    test('third step is Fetch with autoAdvance true', () {
      final step = adapter.acquisitionSteps[2];
      expect(step.label, equals('Fetch'));
      expect(step.autoAdvance, isTrue);
    });
  });
}
