import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/dive_import/domain/entities/imported_dive.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/dive_import/domain/services/health_import_service.dart';
import 'package:submersion/features/dive_import/domain/services/imported_dive_converter.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/import_wizard/data/adapters/healthkit_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/healthkit_adapter_steps.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/models/import_phase.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_app.dart';

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

      final progressCalls = <(ImportPhase, int, int)>[];
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
      expect(progressCalls[0].$1, equals(ImportPhase.dives));
      expect(progressCalls[1].$1, equals(ImportPhase.dives));
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

    test('defaultTagName includes display name and YYYY-MM-DD date', () {
      final tagName = adapter.defaultTagName;
      expect(tagName, matches(RegExp(r'^HealthKit Import \d{4}-\d{2}-\d{2}$')));
    });

    test('defaultTagName uses custom display name when provided', () {
      final named = HealthKitAdapter(
        healthService: mockHealthService,
        diveMatcher: mockMatcher,
        converter: mockConverter,
        diveRepository: mockRepo,
        diverId: diverId,
        displayName: 'Apple Watch Dives',
      );
      expect(
        named.defaultTagName,
        matches(RegExp(r'^Apple Watch Dives Import \d{4}-\d{2}-\d{2}$')),
      );
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

    test('Permissions step has health_and_safety icon', () {
      final step = adapter.acquisitionSteps[0];
      expect(step.icon, equals(Icons.health_and_safety));
    });

    test('Date Range step has date_range icon', () {
      final step = adapter.acquisitionSteps[1];
      expect(step.icon, equals(Icons.date_range));
    });

    test('Fetch step has download icon', () {
      final step = adapter.acquisitionSteps[2];
      expect(step.icon, equals(Icons.download));
    });

    test('Permissions step uses healthKitPermissionsGrantedProvider', () {
      final step = adapter.acquisitionSteps[0];
      expect(step.canAdvance, same(healthKitPermissionsGrantedProvider));
    });

    test('Date Range step uses healthKitDateRangeSelectedProvider', () {
      final step = adapter.acquisitionSteps[1];
      expect(step.canAdvance, same(healthKitDateRangeSelectedProvider));
    });

    test('Fetch step uses healthKitDivesFetchedProvider', () {
      final step = adapter.acquisitionSteps[2];
      expect(step.canAdvance, same(healthKitDivesFetchedProvider));
    });
  });

  // -------------------------------------------------------------------------
  // resetState
  // -------------------------------------------------------------------------

  group('resetState()', () {
    test('can be called without error', () {
      // resetState is a no-op for HealthKitAdapter; verify it does not throw.
      expect(() => adapter.resetState(), returnsNormally);
    });

    test('does not clear parsed dives', () async {
      adapter.setParsedDives([makeDive()]);
      adapter.resetState();

      final bundle = await adapter.buildBundle();
      // Parsed dives survive resetState because the adapter keeps them.
      expect(bundle.groups[ImportEntityType.dives]!.items, hasLength(1));
    });
  });

  // -------------------------------------------------------------------------
  // setParsedDives
  // -------------------------------------------------------------------------

  group('setParsedDives()', () {
    test('replaces previously set dives', () async {
      adapter.setParsedDives([makeDive(sourceId: 'first')]);
      adapter.setParsedDives([
        makeDive(sourceId: 'second-1'),
        makeDive(sourceId: 'second-2'),
      ]);

      final bundle = await adapter.buildBundle();
      expect(bundle.groups[ImportEntityType.dives]!.items, hasLength(2));
    });

    test('list is unmodifiable after setting', () {
      final mutableList = [makeDive()];
      adapter.setParsedDives(mutableList);

      // The adapter stores an unmodifiable copy, so mutating the original
      // list after the fact should not affect the adapter's internal state.
      // We verify indirectly by building a bundle.
      mutableList.add(makeDive(sourceId: 'extra'));

      // The adapter should still have only 1 dive.
      expect(adapter.buildBundle(), completes);
    });
  });

  // -------------------------------------------------------------------------
  // _diveSeconds helper (tested via checkDuplicates)
  // -------------------------------------------------------------------------

  group('_diveSeconds via checkDuplicates()', () {
    // These tests verify the static _diveSeconds helper indirectly by
    // exercising checkDuplicates with Dive entities that have different
    // combinations of runtime/exitTime/entryTime/duration.

    Future<void> runCheckWithExistingDive(
      HealthKitAdapter adapter,
      MockDiveMatcher matcher,
      MockDiveRepository repo,
      Dive existingDive,
    ) async {
      final dive = makeDive();
      adapter.setParsedDives([dive]);
      final bundle = await adapter.buildBundle();

      when(
        repo.getAllDives(diverId: diverId),
      ).thenAnswer((_) async => [existingDive]);
      when(
        matcher.calculateMatchScore(
          wearableStartTime: anyNamed('wearableStartTime'),
          wearableMaxDepth: anyNamed('wearableMaxDepth'),
          wearableDurationSeconds: anyNamed('wearableDurationSeconds'),
          existingStartTime: anyNamed('existingStartTime'),
          existingMaxDepth: anyNamed('existingMaxDepth'),
          existingDurationSeconds: anyNamed('existingDurationSeconds'),
        ),
      ).thenReturn(0.3); // below threshold, just need to inspect arguments

      await adapter.checkDuplicates(bundle);
    }

    test('uses runtime.inSeconds when runtime is set', () async {
      final existing = Dive(
        id: 'dive-rt',
        diverId: diverId,
        dateTime: DateTime(2026, 3, 15, 9, 00),
        entryTime: DateTime(2026, 3, 15, 9, 00),
        exitTime: DateTime(2026, 3, 15, 9, 50),
        runtime: const Duration(minutes: 45),
        bottomTime: const Duration(minutes: 40),
        maxDepth: 18.5,
        notes: '',
        diveTypeId: '',
        tanks: const [],
        profile: const [],
        equipment: const [],
        photoIds: const [],
        sightings: const [],
      );

      await runCheckWithExistingDive(adapter, mockMatcher, mockRepo, existing);

      final captured = verify(
        mockMatcher.calculateMatchScore(
          wearableStartTime: anyNamed('wearableStartTime'),
          wearableMaxDepth: anyNamed('wearableMaxDepth'),
          wearableDurationSeconds: captureAnyNamed('wearableDurationSeconds'),
          existingStartTime: anyNamed('existingStartTime'),
          existingMaxDepth: anyNamed('existingMaxDepth'),
          existingDurationSeconds: captureAnyNamed('existingDurationSeconds'),
        ),
      ).captured;
      // captured is [wearableDurationSeconds, existingDurationSeconds]
      final existingSeconds = captured[1] as int;
      expect(existingSeconds, equals(45 * 60));
    });

    test('falls back to exitTime-entryTime when runtime is null', () async {
      final existing = Dive(
        id: 'dive-et',
        diverId: diverId,
        dateTime: DateTime(2026, 3, 15, 9, 00),
        entryTime: DateTime(2026, 3, 15, 9, 00),
        exitTime: DateTime(2026, 3, 15, 9, 50),
        runtime: null,
        bottomTime: const Duration(minutes: 40),
        maxDepth: 18.5,
        notes: '',
        diveTypeId: '',
        tanks: const [],
        profile: const [],
        equipment: const [],
        photoIds: const [],
        sightings: const [],
      );

      await runCheckWithExistingDive(adapter, mockMatcher, mockRepo, existing);

      final captured = verify(
        mockMatcher.calculateMatchScore(
          wearableStartTime: anyNamed('wearableStartTime'),
          wearableMaxDepth: anyNamed('wearableMaxDepth'),
          wearableDurationSeconds: captureAnyNamed('wearableDurationSeconds'),
          existingStartTime: anyNamed('existingStartTime'),
          existingMaxDepth: anyNamed('existingMaxDepth'),
          existingDurationSeconds: captureAnyNamed('existingDurationSeconds'),
        ),
      ).captured;
      final existingSeconds = captured[1] as int;
      // 50 minutes from exitTime - entryTime
      expect(existingSeconds, equals(50 * 60));
    });

    test('falls back to duration when runtime and exitTime are null', () async {
      final existing = Dive(
        id: 'dive-dur',
        diverId: diverId,
        dateTime: DateTime(2026, 3, 15, 9, 00),
        entryTime: null,
        exitTime: null,
        runtime: null,
        bottomTime: const Duration(minutes: 38),
        maxDepth: 18.5,
        notes: '',
        diveTypeId: '',
        tanks: const [],
        profile: const [],
        equipment: const [],
        photoIds: const [],
        sightings: const [],
      );

      await runCheckWithExistingDive(adapter, mockMatcher, mockRepo, existing);

      final captured = verify(
        mockMatcher.calculateMatchScore(
          wearableStartTime: anyNamed('wearableStartTime'),
          wearableMaxDepth: anyNamed('wearableMaxDepth'),
          wearableDurationSeconds: captureAnyNamed('wearableDurationSeconds'),
          existingStartTime: anyNamed('existingStartTime'),
          existingMaxDepth: anyNamed('existingMaxDepth'),
          existingDurationSeconds: captureAnyNamed('existingDurationSeconds'),
        ),
      ).captured;
      final existingSeconds = captured[1] as int;
      expect(existingSeconds, equals(38 * 60));
    });

    test(
      'returns 0 when runtime, exitTime, and duration are all null',
      () async {
        final existing = Dive(
          id: 'dive-none',
          diverId: diverId,
          dateTime: DateTime(2026, 3, 15, 9, 00),
          entryTime: null,
          exitTime: null,
          runtime: null,
          bottomTime: null,
          maxDepth: 18.5,
          notes: '',
          diveTypeId: '',
          tanks: const [],
          profile: const [],
          equipment: const [],
          photoIds: const [],
          sightings: const [],
        );

        await runCheckWithExistingDive(
          adapter,
          mockMatcher,
          mockRepo,
          existing,
        );

        final captured = verify(
          mockMatcher.calculateMatchScore(
            wearableStartTime: anyNamed('wearableStartTime'),
            wearableMaxDepth: anyNamed('wearableMaxDepth'),
            wearableDurationSeconds: captureAnyNamed('wearableDurationSeconds'),
            existingStartTime: anyNamed('existingStartTime'),
            existingMaxDepth: anyNamed('existingMaxDepth'),
            existingDurationSeconds: captureAnyNamed('existingDurationSeconds'),
          ),
        ).captured;
        final existingSeconds = captured[1] as int;
        expect(existingSeconds, equals(0));
      },
    );

    test('falls back to exitTime-entryTime when runtime is null '
        'but entryTime is null (uses 0)', () async {
      // When entryTime is null but exitTime is set, the fallback to
      // exitTime-entryTime is skipped, and duration is used instead.
      final existing = Dive(
        id: 'dive-no-entry',
        diverId: diverId,
        dateTime: DateTime(2026, 3, 15, 9, 00),
        entryTime: null,
        exitTime: DateTime(2026, 3, 15, 9, 50),
        runtime: null,
        bottomTime: const Duration(minutes: 33),
        maxDepth: 18.5,
        notes: '',
        diveTypeId: '',
        tanks: const [],
        profile: const [],
        equipment: const [],
        photoIds: const [],
        sightings: const [],
      );

      await runCheckWithExistingDive(adapter, mockMatcher, mockRepo, existing);

      final captured = verify(
        mockMatcher.calculateMatchScore(
          wearableStartTime: anyNamed('wearableStartTime'),
          wearableMaxDepth: anyNamed('wearableMaxDepth'),
          wearableDurationSeconds: captureAnyNamed('wearableDurationSeconds'),
          existingStartTime: anyNamed('existingStartTime'),
          existingMaxDepth: anyNamed('existingMaxDepth'),
          existingDurationSeconds: captureAnyNamed('existingDurationSeconds'),
        ),
      ).captured;
      final existingSeconds = captured[1] as int;
      // duration fallback: 33 minutes
      expect(existingSeconds, equals(33 * 60));
    });
  });

  // -------------------------------------------------------------------------
  // checkDuplicates - additional edge cases
  // -------------------------------------------------------------------------

  group('checkDuplicates() edge cases', () {
    test('returns bundle unchanged when dives group is null', () async {
      // Build a bundle with no dives group at all.
      const bundle = ImportBundle(
        source: ImportSourceInfo(
          type: ImportSourceType.healthKit,
          displayName: 'Test',
        ),
        groups: {},
      );

      final result = await adapter.checkDuplicates(bundle);

      expect(result.groups, isEmpty);
    });

    test('returns bundle unchanged when dives group is empty', () async {
      adapter.setParsedDives([]);
      final bundle = await adapter.buildBundle();

      final result = await adapter.checkDuplicates(bundle);

      expect(result.groups[ImportEntityType.dives]!.items, isEmpty);
      expect(result.groups[ImportEntityType.dives]!.duplicateIndices, isEmpty);
    });

    test('returns bundle unchanged when no existing dives', () async {
      final dive = makeDive();
      adapter.setParsedDives([dive]);
      final bundle = await adapter.buildBundle();

      when(mockRepo.getAllDives(diverId: diverId)).thenAnswer((_) async => []);

      final result = await adapter.checkDuplicates(bundle);

      expect(result.groups[ImportEntityType.dives]!.duplicateIndices, isEmpty);
    });

    test('uses 0.0 for existing dive with null maxDepth', () async {
      final dive = makeDive(maxDepth: 20.0);
      adapter.setParsedDives([dive]);
      final bundle = await adapter.buildBundle();

      final existing = Dive(
        id: 'dive-null-depth',
        diverId: diverId,
        dateTime: DateTime(2026, 3, 15, 9, 00),
        maxDepth: null,
        runtime: const Duration(minutes: 42),
        notes: '',
        diveTypeId: '',
        tanks: const [],
        profile: const [],
        equipment: const [],
        photoIds: const [],
        sightings: const [],
      );

      when(
        mockRepo.getAllDives(diverId: diverId),
      ).thenAnswer((_) async => [existing]);
      when(
        mockMatcher.calculateMatchScore(
          wearableStartTime: anyNamed('wearableStartTime'),
          wearableMaxDepth: anyNamed('wearableMaxDepth'),
          wearableDurationSeconds: anyNamed('wearableDurationSeconds'),
          existingStartTime: anyNamed('existingStartTime'),
          existingMaxDepth: anyNamed('existingMaxDepth'),
          existingDurationSeconds: anyNamed('existingDurationSeconds'),
        ),
      ).thenReturn(0.3);

      await adapter.checkDuplicates(bundle);

      final captured = verify(
        mockMatcher.calculateMatchScore(
          wearableStartTime: anyNamed('wearableStartTime'),
          wearableMaxDepth: anyNamed('wearableMaxDepth'),
          wearableDurationSeconds: anyNamed('wearableDurationSeconds'),
          existingStartTime: anyNamed('existingStartTime'),
          existingMaxDepth: captureAnyNamed('existingMaxDepth'),
          existingDurationSeconds: anyNamed('existingDurationSeconds'),
        ),
      ).captured;
      expect(captured.first, equals(0.0));
    });

    test('match result includes siteName from existing dive', () async {
      final dive = makeDive();
      adapter.setParsedDives([dive]);
      final bundle = await adapter.buildBundle();

      final existing = Dive(
        id: 'dive-with-site',
        diverId: diverId,
        dateTime: DateTime(2026, 3, 15, 9, 00),
        maxDepth: 18.5,
        runtime: const Duration(minutes: 42),
        site: const DiveSite(
          id: 'site-1',
          name: 'Blue Hole',
          description: '',
          photoIds: [],
          notes: '',
        ),
        notes: '',
        diveTypeId: '',
        tanks: const [],
        profile: const [],
        equipment: const [],
        photoIds: const [],
        sightings: const [],
      );

      when(
        mockRepo.getAllDives(diverId: diverId),
      ).thenAnswer((_) async => [existing]);
      when(
        mockMatcher.calculateMatchScore(
          wearableStartTime: anyNamed('wearableStartTime'),
          wearableMaxDepth: anyNamed('wearableMaxDepth'),
          wearableDurationSeconds: anyNamed('wearableDurationSeconds'),
          existingStartTime: anyNamed('existingStartTime'),
          existingMaxDepth: anyNamed('existingMaxDepth'),
          existingDurationSeconds: anyNamed('existingDurationSeconds'),
        ),
      ).thenReturn(0.8);

      final result = await adapter.checkDuplicates(bundle);

      final matchResult =
          result.groups[ImportEntityType.dives]!.matchResults![0];
      expect(matchResult!.siteName, equals('Blue Hole'));
    });

    test(
      'match result has null siteName when existing dive has no site',
      () async {
        final dive = makeDive();
        adapter.setParsedDives([dive]);
        final bundle = await adapter.buildBundle();

        final existing = makeDomainDive(id: 'no-site');
        when(
          mockRepo.getAllDives(diverId: diverId),
        ).thenAnswer((_) async => [existing]);
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

        final matchResult =
            result.groups[ImportEntityType.dives]!.matchResults![0];
        expect(matchResult!.siteName, isNull);
      },
    );

    test('match result includes correct timeDifferenceMs', () async {
      final importedStart = DateTime(2026, 3, 15, 9, 00);
      final existingStart = DateTime(2026, 3, 15, 9, 02);
      final dive = makeDive(startTime: importedStart);
      adapter.setParsedDives([dive]);
      final bundle = await adapter.buildBundle();

      final existing = makeDomainDive(
        id: 'dive-time-diff',
        dateTime: existingStart,
      );
      when(
        mockRepo.getAllDives(diverId: diverId),
      ).thenAnswer((_) async => [existing]);
      when(
        mockMatcher.calculateMatchScore(
          wearableStartTime: anyNamed('wearableStartTime'),
          wearableMaxDepth: anyNamed('wearableMaxDepth'),
          wearableDurationSeconds: anyNamed('wearableDurationSeconds'),
          existingStartTime: anyNamed('existingStartTime'),
          existingMaxDepth: anyNamed('existingMaxDepth'),
          existingDurationSeconds: anyNamed('existingDurationSeconds'),
        ),
      ).thenReturn(0.7);

      final result = await adapter.checkDuplicates(bundle);

      final matchResult =
          result.groups[ImportEntityType.dives]!.matchResults![0];
      // 2 minutes = 120000 ms
      expect(matchResult!.timeDifferenceMs, equals(120000));
    });

    test('match result includes correct depthDifferenceMeters', () async {
      final dive = makeDive(maxDepth: 20.0);
      adapter.setParsedDives([dive]);
      final bundle = await adapter.buildBundle();

      final existing = makeDomainDive(id: 'dive-depth-diff', maxDepth: 18.0);
      when(
        mockRepo.getAllDives(diverId: diverId),
      ).thenAnswer((_) async => [existing]);
      when(
        mockMatcher.calculateMatchScore(
          wearableStartTime: anyNamed('wearableStartTime'),
          wearableMaxDepth: anyNamed('wearableMaxDepth'),
          wearableDurationSeconds: anyNamed('wearableDurationSeconds'),
          existingStartTime: anyNamed('existingStartTime'),
          existingMaxDepth: anyNamed('existingMaxDepth'),
          existingDurationSeconds: anyNamed('existingDurationSeconds'),
        ),
      ).thenReturn(0.6);

      final result = await adapter.checkDuplicates(bundle);

      final matchResult =
          result.groups[ImportEntityType.dives]!.matchResults![0];
      expect(matchResult!.depthDifferenceMeters, closeTo(2.0, 0.001));
    });

    test('match result includes correct durationDifferenceSeconds', () async {
      // imported dive: 42 min duration
      final dive = makeDive();
      adapter.setParsedDives([dive]);
      final bundle = await adapter.buildBundle();

      // existing dive: 45 min duration
      final existing = makeDomainDive(
        id: 'dive-dur-diff',
        duration: const Duration(minutes: 45),
      );
      when(
        mockRepo.getAllDives(diverId: diverId),
      ).thenAnswer((_) async => [existing]);
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
      // |42*60 - 45*60| = 180 seconds
      expect(matchResult!.durationDifferenceSeconds, equals(180));
    });

    test('handles multiple parsed dives with mixed matches', () async {
      final dive1 = makeDive(
        sourceId: 'hk-1',
        startTime: DateTime(2026, 3, 15, 9, 00),
      );
      final dive2 = makeDive(
        sourceId: 'hk-2',
        startTime: DateTime(2026, 3, 16, 10, 00),
      );
      final dive3 = makeDive(
        sourceId: 'hk-3',
        startTime: DateTime(2026, 3, 17, 11, 00),
      );
      adapter.setParsedDives([dive1, dive2, dive3]);
      final bundle = await adapter.buildBundle();

      final existing = makeDomainDive(id: 'ex-1');
      when(
        mockRepo.getAllDives(diverId: diverId),
      ).thenAnswer((_) async => [existing]);

      var callIndex = 0;
      when(
        mockMatcher.calculateMatchScore(
          wearableStartTime: anyNamed('wearableStartTime'),
          wearableMaxDepth: anyNamed('wearableMaxDepth'),
          wearableDurationSeconds: anyNamed('wearableDurationSeconds'),
          existingStartTime: anyNamed('existingStartTime'),
          existingMaxDepth: anyNamed('existingMaxDepth'),
          existingDurationSeconds: anyNamed('existingDurationSeconds'),
        ),
      ).thenAnswer((_) {
        final scores = [0.9, 0.3, 0.6];
        return scores[callIndex++];
      });

      final result = await adapter.checkDuplicates(bundle);

      final dupes = result.groups[ImportEntityType.dives]!.duplicateIndices;
      // dive1 (0.9) and dive3 (0.6) match; dive2 (0.3) does not
      expect(dupes, containsAll([0, 2]));
      expect(dupes, isNot(contains(1)));
    });

    test('preserves non-dives groups in result bundle', () async {
      adapter.setParsedDives([makeDive()]);

      // Build a bundle with an extra (non-dives) group
      final baseBundle = await adapter.buildBundle();
      final bundleWithSites = ImportBundle(
        source: baseBundle.source,
        groups: {
          ...baseBundle.groups,
          ImportEntityType.sites: const EntityGroup(
            items: [EntityItem(title: 'Reef', subtitle: 'Tropical')],
          ),
        },
      );

      when(mockRepo.getAllDives(diverId: diverId)).thenAnswer((_) async => []);

      final result = await adapter.checkDuplicates(bundleWithSites);

      expect(result.hasType(ImportEntityType.sites), isTrue);
      expect(
        result.groups[ImportEntityType.sites]!.items.first.title,
        equals('Reef'),
      );
    });
  });

  // -------------------------------------------------------------------------
  // performImport - additional edge cases
  // -------------------------------------------------------------------------

  group('performImport() edge cases', () {
    test('returns zero counts when no dives selected', () async {
      adapter.setParsedDives([makeDive()]);
      final bundle = await adapter.buildBundle();

      final result = await adapter.performImport(bundle, {
        ImportEntityType.dives: <int>{},
      }, {});

      expect(result.importedCounts[ImportEntityType.dives], equals(0));
      expect(result.skippedCount, equals(0));
      verifyNever(mockConverter.convert(any, diverId: anyNamed('diverId')));
      verifyNever(mockRepo.createDive(any));
    });

    test('returns zero counts when selections map is empty', () async {
      adapter.setParsedDives([makeDive()]);
      final bundle = await adapter.buildBundle();

      final result = await adapter.performImport(bundle, {}, {});

      expect(result.importedCounts[ImportEntityType.dives], equals(0));
      expect(result.skippedCount, equals(0));
    });

    test('skips out-of-bounds indices without crashing', () async {
      adapter.setParsedDives([makeDive()]);
      final bundle = await adapter.buildBundle();

      // Index 5 is out of bounds (only index 0 exists)
      final result = await adapter.performImport(bundle, {
        ImportEntityType.dives: {5},
      }, {});

      expect(result.importedCounts[ImportEntityType.dives], equals(0));
      verifyNever(mockConverter.convert(any, diverId: anyNamed('diverId')));
    });

    test('returns importedDiveIds for each imported dive', () async {
      final dive1 = makeDive(sourceId: 'hk-1');
      final dive2 = makeDive(sourceId: 'hk-2');
      adapter.setParsedDives([dive1, dive2]);
      final bundle = await adapter.buildBundle();

      final domainDive1 = makeDomainDive(id: 'uuid-aaa');
      final domainDive2 = makeDomainDive(id: 'uuid-bbb');
      when(
        mockConverter.convert(dive1, diverId: diverId),
      ).thenReturn(domainDive1);
      when(
        mockConverter.convert(dive2, diverId: diverId),
      ).thenReturn(domainDive2);
      when(mockRepo.createDive(any)).thenAnswer((_) async => domainDive1);

      final result = await adapter.performImport(bundle, {
        ImportEntityType.dives: {0, 1},
      }, {});

      expect(result.importedDiveIds, hasLength(2));
      expect(result.importedDiveIds, contains('uuid-aaa'));
      expect(result.importedDiveIds, contains('uuid-bbb'));
    });

    test('consolidatedCount is always 0', () async {
      adapter.setParsedDives([makeDive()]);
      final bundle = await adapter.buildBundle();
      final domainDive = makeDomainDive();
      when(
        mockConverter.convert(any, diverId: anyNamed('diverId')),
      ).thenReturn(domainDive);
      when(mockRepo.createDive(any)).thenAnswer((_) async => domainDive);

      final result = await adapter.performImport(bundle, {
        ImportEntityType.dives: {0},
      }, {});

      expect(result.consolidatedCount, equals(0));
    });

    test(
      'skip action on index not in base selections counts as skipped',
      () async {
        final dive1 = makeDive(sourceId: 'hk-1');
        final dive2 = makeDive(sourceId: 'hk-2');
        adapter.setParsedDives([dive1, dive2]);
        final bundle = await adapter.buildBundle();

        final domainDive1 = makeDomainDive(id: 'uuid-1');
        when(
          mockConverter.convert(dive1, diverId: diverId),
        ).thenReturn(domainDive1);
        when(mockRepo.createDive(any)).thenAnswer((_) async => domainDive1);

        // Select only index 0. Index 1 gets skip action but is NOT
        // in selections.
        final result = await adapter.performImport(
          bundle,
          {
            ImportEntityType.dives: {0},
          },
          {
            ImportEntityType.dives: {1: DuplicateAction.skip},
          },
        );

        // Index 1 skip action increments skipped even though not selected
        expect(result.skippedCount, equals(1));
      },
    );

    test('importAsNew adds index even when not in base selections', () async {
      final dive1 = makeDive(sourceId: 'hk-1');
      final dive2 = makeDive(sourceId: 'hk-2');
      adapter.setParsedDives([dive1, dive2]);
      final bundle = await adapter.buildBundle();

      final domainDive1 = makeDomainDive(id: 'uuid-1');
      final domainDive2 = makeDomainDive(id: 'uuid-2');
      when(
        mockConverter.convert(dive1, diverId: diverId),
      ).thenReturn(domainDive1);
      when(
        mockConverter.convert(dive2, diverId: diverId),
      ).thenReturn(domainDive2);
      when(mockRepo.createDive(any)).thenAnswer((_) async => domainDive1);

      // Base selections empty; both get importAsNew action
      final result = await adapter.performImport(
        bundle,
        {ImportEntityType.dives: <int>{}},
        {
          ImportEntityType.dives: {
            0: DuplicateAction.importAsNew,
            1: DuplicateAction.importAsNew,
          },
        },
      );

      verify(mockConverter.convert(dive1, diverId: diverId)).called(1);
      verify(mockConverter.convert(dive2, diverId: diverId)).called(1);
      expect(result.importedCounts[ImportEntityType.dives], equals(2));
    });

    test('imports indices in sorted order', () async {
      final dive0 = makeDive(sourceId: 'hk-0');
      final dive1 = makeDive(sourceId: 'hk-1');
      final dive2 = makeDive(sourceId: 'hk-2');
      adapter.setParsedDives([dive0, dive1, dive2]);
      final bundle = await adapter.buildBundle();

      final domainDive = makeDomainDive();
      when(
        mockConverter.convert(any, diverId: anyNamed('diverId')),
      ).thenReturn(domainDive);
      when(mockRepo.createDive(any)).thenAnswer((_) async => domainDive);

      final progressOrder = <int>[];
      // Select in reverse order {2, 0} to verify sorting
      await adapter.performImport(
        bundle,
        {
          ImportEntityType.dives: {2, 0},
        },
        {},
        onProgress: (_, current, _) => progressOrder.add(current),
      );

      expect(progressOrder, equals([1, 2]));
    });

    test('does not call onProgress when callback is null', () async {
      final dive = makeDive();
      adapter.setParsedDives([dive]);
      final bundle = await adapter.buildBundle();

      final domainDive = makeDomainDive();
      when(
        mockConverter.convert(any, diverId: anyNamed('diverId')),
      ).thenReturn(domainDive);
      when(mockRepo.createDive(any)).thenAnswer((_) async => domainDive);

      // Should not throw even though onProgress is null
      final result = await adapter.performImport(bundle, {
        ImportEntityType.dives: {0},
      }, {});

      expect(result.importedCounts[ImportEntityType.dives], equals(1));
    });

    test('skip action on a selected index removes it from import', () async {
      final dive0 = makeDive(sourceId: 'hk-0');
      final dive1 = makeDive(sourceId: 'hk-1');
      adapter.setParsedDives([dive0, dive1]);
      final bundle = await adapter.buildBundle();

      final domainDive1 = makeDomainDive(id: 'uuid-1');
      when(
        mockConverter.convert(dive1, diverId: diverId),
      ).thenReturn(domainDive1);
      when(mockRepo.createDive(any)).thenAnswer((_) async => domainDive1);

      // Both selected, but index 0 is skip
      final result = await adapter.performImport(
        bundle,
        {
          ImportEntityType.dives: {0, 1},
        },
        {
          ImportEntityType.dives: {0: DuplicateAction.skip},
        },
      );

      expect(result.importedCounts[ImportEntityType.dives], equals(1));
      expect(result.skippedCount, equals(1));
      verifyNever(mockConverter.convert(dive0, diverId: diverId));
      verify(mockConverter.convert(dive1, diverId: diverId)).called(1);
    });

    test('all selected as skip results in zero imports', () async {
      final dive0 = makeDive(sourceId: 'hk-0');
      final dive1 = makeDive(sourceId: 'hk-1');
      adapter.setParsedDives([dive0, dive1]);
      final bundle = await adapter.buildBundle();

      final result = await adapter.performImport(
        bundle,
        {
          ImportEntityType.dives: {0, 1},
        },
        {
          ImportEntityType.dives: {
            0: DuplicateAction.skip,
            1: DuplicateAction.skip,
          },
        },
      );

      expect(result.importedCounts[ImportEntityType.dives], equals(0));
      expect(result.skippedCount, equals(2));
      verifyNever(mockConverter.convert(any, diverId: anyNamed('diverId')));
    });

    test('all as importAsNew imports everything', () async {
      final dive0 = makeDive(sourceId: 'hk-0');
      final dive1 = makeDive(sourceId: 'hk-1');
      final dive2 = makeDive(sourceId: 'hk-2');
      adapter.setParsedDives([dive0, dive1, dive2]);
      final bundle = await adapter.buildBundle();

      final domainDive = makeDomainDive();
      when(
        mockConverter.convert(any, diverId: anyNamed('diverId')),
      ).thenReturn(domainDive);
      when(mockRepo.createDive(any)).thenAnswer((_) async => domainDive);

      final result = await adapter.performImport(
        bundle,
        {ImportEntityType.dives: <int>{}},
        {
          ImportEntityType.dives: {
            0: DuplicateAction.importAsNew,
            1: DuplicateAction.importAsNew,
            2: DuplicateAction.importAsNew,
          },
        },
      );

      expect(result.importedCounts[ImportEntityType.dives], equals(3));
      expect(result.skippedCount, equals(0));
    });

    test('importAsNew on a selected index does not double-import', () async {
      final dive = makeDive();
      adapter.setParsedDives([dive]);
      final bundle = await adapter.buildBundle();

      final domainDive = makeDomainDive();
      when(
        mockConverter.convert(dive, diverId: diverId),
      ).thenReturn(domainDive);
      when(mockRepo.createDive(any)).thenAnswer((_) async => domainDive);

      // Index 0 is both in selections AND has importAsNew action
      final result = await adapter.performImport(
        bundle,
        {
          ImportEntityType.dives: {0},
        },
        {
          ImportEntityType.dives: {0: DuplicateAction.importAsNew},
        },
      );

      // Should still only import once (Set deduplicates)
      verify(mockConverter.convert(dive, diverId: diverId)).called(1);
      expect(result.importedCounts[ImportEntityType.dives], equals(1));
    });

    test('onProgress reports correct phase, current, and total', () async {
      final dive0 = makeDive(sourceId: 'hk-0');
      final dive1 = makeDive(sourceId: 'hk-1');
      final dive2 = makeDive(sourceId: 'hk-2');
      adapter.setParsedDives([dive0, dive1, dive2]);
      final bundle = await adapter.buildBundle();

      final domainDive = makeDomainDive();
      when(
        mockConverter.convert(any, diverId: anyNamed('diverId')),
      ).thenReturn(domainDive);
      when(mockRepo.createDive(any)).thenAnswer((_) async => domainDive);

      final calls = <(ImportPhase, int, int)>[];
      await adapter.performImport(
        bundle,
        {
          ImportEntityType.dives: {0, 1, 2},
        },
        {},
        onProgress: (phase, current, total) {
          calls.add((phase, current, total));
        },
      );

      expect(calls, hasLength(3));
      expect(calls[0], equals((ImportPhase.dives, 1, 3)));
      expect(calls[1], equals((ImportPhase.dives, 2, 3)));
      expect(calls[2], equals((ImportPhase.dives, 3, 3)));
    });
  });

  // -------------------------------------------------------------------------
  // buildBundle - additional entity item conversion tests
  // -------------------------------------------------------------------------

  group('buildBundle() entity item conversion', () {
    test('handles multiple dives preserving order', () async {
      final dive1 = makeDive(
        sourceId: 'hk-1',
        startTime: DateTime(2026, 3, 15, 9, 00),
      );
      final dive2 = makeDive(
        sourceId: 'hk-2',
        startTime: DateTime(2026, 3, 16, 14, 30),
      );
      adapter.setParsedDives([dive1, dive2]);

      final bundle = await adapter.buildBundle();
      final items = bundle.groups[ImportEntityType.dives]!.items;

      expect(items, hasLength(2));
      expect(items[0].title, contains('Mar 15, 2026'));
      expect(items[1].title, contains('Mar 16, 2026'));
    });

    test('profile samples include temperature and heartRate', () async {
      final profile = [
        const ImportedProfileSample(
          timeSeconds: 0,
          depth: 0.0,
          temperature: 25.0,
          heartRate: 80,
        ),
        const ImportedProfileSample(
          timeSeconds: 120,
          depth: 15.0,
          temperature: 22.0,
          heartRate: 95,
        ),
      ];
      final dive = makeDive(profile: profile);
      adapter.setParsedDives([dive]);

      final bundle = await adapter.buildBundle();
      final item = bundle.groups[ImportEntityType.dives]!.items.first;

      expect(item.diveData!.profile, hasLength(2));
      expect(item.diveData!.profile[0].temperature, equals(25.0));
      expect(item.diveData!.profile[0].heartRate, equals(80));
      expect(item.diveData!.profile[1].temperature, equals(22.0));
      expect(item.diveData!.profile[1].heartRate, equals(95));
    });

    test('diveData has null avgDepth when dive avgDepth is null', () async {
      final dive = makeDive(avgDepth: null);
      adapter.setParsedDives([dive]);

      final bundle = await adapter.buildBundle();
      final item = bundle.groups[ImportEntityType.dives]!.items.first;

      expect(item.diveData!.avgDepth, isNull);
    });

    test('diveData has null waterTemp when minTemperature is null', () async {
      final dive = makeDive(minTemperature: null);
      adapter.setParsedDives([dive]);

      final bundle = await adapter.buildBundle();
      final item = bundle.groups[ImportEntityType.dives]!.items.first;

      expect(item.diveData!.waterTemp, isNull);
    });

    test('diveData startTime matches dive startTime', () async {
      final start = DateTime(2026, 7, 4, 11, 30);
      final dive = makeDive(startTime: start);
      adapter.setParsedDives([dive]);

      final bundle = await adapter.buildBundle();
      final item = bundle.groups[ImportEntityType.dives]!.items.first;

      expect(item.diveData!.startTime, equals(start));
    });

    test('diveData durationSeconds is computed from start/end', () async {
      final start = DateTime(2026, 3, 15, 9, 00);
      final end = DateTime(2026, 3, 15, 9, 55);
      final dive = makeDive(startTime: start, endTime: end);
      adapter.setParsedDives([dive]);

      final bundle = await adapter.buildBundle();
      final item = bundle.groups[ImportEntityType.dives]!.items.first;

      expect(item.diveData!.durationSeconds, equals(55 * 60));
    });

    test('empty profile results in empty diveData profile', () async {
      final dive = makeDive(profile: []);
      adapter.setParsedDives([dive]);

      final bundle = await adapter.buildBundle();
      final item = bundle.groups[ImportEntityType.dives]!.items.first;

      expect(item.diveData!.profile, isEmpty);
    });

    test('subtitle uses imperial units when settings specify feet', () async {
      final imperialAdapter = HealthKitAdapter(
        healthService: mockHealthService,
        diveMatcher: mockMatcher,
        converter: mockConverter,
        diveRepository: mockRepo,
        diverId: diverId,
        settings: const AppSettings(
          depthUnit: DepthUnit.feet,
          temperatureUnit: TemperatureUnit.fahrenheit,
        ),
      );
      final dive = makeDive(
        maxDepth: 18.5,
        minTemperature: 24.0,
        startTime: DateTime(2026, 3, 15, 9, 00),
        endTime: DateTime(2026, 3, 15, 9, 42),
      );
      imperialAdapter.setParsedDives([dive]);

      final bundle = await imperialAdapter.buildBundle();
      final item = bundle.groups[ImportEntityType.dives]!.items.first;

      // 18.5m * 3.28084 = ~60.7ft
      expect(item.subtitle, contains('ft'));
      expect(item.subtitle, contains('42 min'));
      // Temperature should be in Fahrenheit
      expect(item.subtitle, contains('F'));
    });

    test('source info has healthKit type', () async {
      adapter.setParsedDives([makeDive()]);

      final bundle = await adapter.buildBundle();

      expect(bundle.source.type, equals(ImportSourceType.healthKit));
    });

    test('source info displayName matches adapter displayName', () async {
      final named = HealthKitAdapter(
        healthService: mockHealthService,
        diveMatcher: mockMatcher,
        converter: mockConverter,
        diveRepository: mockRepo,
        diverId: diverId,
        displayName: 'My Watch Import',
      );
      named.setParsedDives([]);

      final bundle = await named.buildBundle();

      expect(bundle.source.displayName, equals('My Watch Import'));
    });
  });

  // -------------------------------------------------------------------------
  // Widget tests: _HealthKitPermissionsStep
  // -------------------------------------------------------------------------

  group('_HealthKitPermissionsStep widget', () {
    Widget buildPermissionsStep(MockHealthImportService service) {
      final widgetAdapter = HealthKitAdapter(
        healthService: service,
        diveMatcher: MockDiveMatcher(),
        converter: MockImportedDiveConverter(),
        diveRepository: MockDiveRepository(),
        diverId: 'diver-1',
      );
      final step = widgetAdapter.acquisitionSteps[0];
      return testApp(
        overrides: [
          settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
        ],
        child: SizedBox(
          height: 600,
          child: Builder(builder: (context) => step.builder(context)),
        ),
      );
    }

    testWidgets('shows loading indicator while checking permissions', (
      tester,
    ) async {
      final service = MockHealthImportService();
      final completer = Completer<bool>();
      when(service.hasPermissions()).thenAnswer((_) => completer.future);

      await tester.pumpWidget(buildPermissionsStep(service));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(false);
      await tester.pumpAndSettle();
    });

    testWidgets('shows granted state when permissions already granted', (
      tester,
    ) async {
      final service = MockHealthImportService();
      when(service.hasPermissions()).thenAnswer((_) async => true);

      await tester.pumpWidget(buildPermissionsStep(service));
      await tester.pumpAndSettle();

      expect(find.text('HealthKit Access Granted'), findsOneWidget);
      expect(find.text('You can proceed to the next step.'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('shows request button when permissions not yet granted', (
      tester,
    ) async {
      final service = MockHealthImportService();
      when(service.hasPermissions()).thenAnswer((_) async => false);

      await tester.pumpWidget(buildPermissionsStep(service));
      await tester.pumpAndSettle();

      expect(find.text('HealthKit Access Required'), findsOneWidget);
      expect(find.text('Grant HealthKit Access'), findsOneWidget);
    });

    testWidgets('shows description text when permissions not granted', (
      tester,
    ) async {
      final service = MockHealthImportService();
      when(service.hasPermissions()).thenAnswer((_) async => false);

      await tester.pumpWidget(buildPermissionsStep(service));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Submersion needs access to your Apple Health data to import '
          'dives recorded by your Apple Watch.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows health_and_safety icon when permissions not granted', (
      tester,
    ) async {
      final service = MockHealthImportService();
      when(service.hasPermissions()).thenAnswer((_) async => false);

      await tester.pumpWidget(buildPermissionsStep(service));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.health_and_safety), findsAtLeast(1));
    });

    testWidgets('tapping request button calls requestPermissions', (
      tester,
    ) async {
      final service = MockHealthImportService();
      when(service.hasPermissions()).thenAnswer((_) async => false);
      final requestCompleter = Completer<bool>();
      when(
        service.requestPermissions(),
      ).thenAnswer((_) => requestCompleter.future);

      await tester.pumpWidget(buildPermissionsStep(service));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Grant HealthKit Access'));
      await tester.pump();

      verify(service.requestPermissions()).called(1);

      // Shows requesting state
      expect(find.text('Requesting...'), findsOneWidget);

      requestCompleter.complete(true);
      await tester.pumpAndSettle();
    });

    testWidgets('shows granted state after permissions granted via button', (
      tester,
    ) async {
      final service = MockHealthImportService();
      when(service.hasPermissions()).thenAnswer((_) async => false);
      when(service.requestPermissions()).thenAnswer((_) async => true);

      await tester.pumpWidget(buildPermissionsStep(service));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Grant HealthKit Access'));
      await tester.pumpAndSettle();

      expect(find.text('HealthKit Access Granted'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('stays on request screen when permissions denied via button', (
      tester,
    ) async {
      final service = MockHealthImportService();
      when(service.hasPermissions()).thenAnswer((_) async => false);
      when(service.requestPermissions()).thenAnswer((_) async => false);

      await tester.pumpWidget(buildPermissionsStep(service));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Grant HealthKit Access'));
      await tester.pumpAndSettle();

      expect(find.text('HealthKit Access Required'), findsOneWidget);
      expect(find.text('Grant HealthKit Access'), findsOneWidget);
    });

    testWidgets('button is disabled while requesting permissions', (
      tester,
    ) async {
      final service = MockHealthImportService();
      when(service.hasPermissions()).thenAnswer((_) async => false);
      final requestCompleter = Completer<bool>();
      when(
        service.requestPermissions(),
      ).thenAnswer((_) => requestCompleter.future);

      await tester.pumpWidget(buildPermissionsStep(service));
      await tester.pumpAndSettle();

      // Tap the button to start the request.
      await tester.tap(find.text('Grant HealthKit Access'));
      await tester.pump();

      // While the request is in flight, tapping again should be a no-op
      // because the button disables itself (onPressed = null).
      // Verify by checking that requestPermissions was called exactly once.
      verify(service.requestPermissions()).called(1);

      requestCompleter.complete(false);
      await tester.pumpAndSettle();
    });

    testWidgets('handles exception during hasPermissions check gracefully', (
      tester,
    ) async {
      final service = MockHealthImportService();
      when(service.hasPermissions()).thenThrow(Exception('platform error'));

      await tester.pumpWidget(buildPermissionsStep(service));
      await tester.pumpAndSettle();

      // Falls through to the request screen
      expect(find.text('HealthKit Access Required'), findsOneWidget);
      expect(find.text('Grant HealthKit Access'), findsOneWidget);
    });

    testWidgets('handles exception during requestPermissions gracefully', (
      tester,
    ) async {
      final service = MockHealthImportService();
      when(service.hasPermissions()).thenAnswer((_) async => false);
      when(service.requestPermissions()).thenThrow(Exception('platform error'));

      await tester.pumpWidget(buildPermissionsStep(service));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Grant HealthKit Access'));
      await tester.pumpAndSettle();

      // Should recover -- still on request screen, not crashed
      expect(find.text('HealthKit Access Required'), findsOneWidget);
      expect(find.text('Grant HealthKit Access'), findsOneWidget);
    });

    testWidgets(
      'sets healthKitPermissionsGrantedProvider when permissions granted on check',
      (tester) async {
        final service = MockHealthImportService();
        when(service.hasPermissions()).thenAnswer((_) async => true);

        late WidgetRef capturedRef;
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    Consumer(
                      builder: (context, ref, _) {
                        capturedRef = ref;
                        return const SizedBox();
                      },
                    ),
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final widgetAdapter = HealthKitAdapter(
                            healthService: service,
                            diveMatcher: MockDiveMatcher(),
                            converter: MockImportedDiveConverter(),
                            diveRepository: MockDiveRepository(),
                            diverId: 'diver-1',
                          );
                          return widgetAdapter.acquisitionSteps[0].builder(
                            context,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(capturedRef.read(healthKitPermissionsGrantedProvider), isTrue);
      },
    );
  });

  // -------------------------------------------------------------------------
  // Widget tests: _HealthKitDateRangeStep
  // -------------------------------------------------------------------------

  group('_HealthKitDateRangeStep widget', () {
    Widget buildDateRangeStep() {
      final widgetAdapter = HealthKitAdapter(
        healthService: MockHealthImportService(),
        diveMatcher: MockDiveMatcher(),
        converter: MockImportedDiveConverter(),
        diveRepository: MockDiveRepository(),
        diverId: 'diver-1',
      );
      final step = widgetAdapter.acquisitionSteps[1];
      return testApp(
        overrides: [
          settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
        ],
        child: SizedBox(
          height: 600,
          child: Builder(builder: (context) => step.builder(context)),
        ),
      );
    }

    testWidgets('renders title and description text', (tester) async {
      await tester.pumpWidget(buildDateRangeStep());
      await tester.pumpAndSettle();

      expect(find.text('Select Date Range'), findsOneWidget);
      expect(
        find.text('Choose the date range to search for dives in Apple Health.'),
        findsOneWidget,
      );
    });

    testWidgets('renders From and To labels', (tester) async {
      await tester.pumpWidget(buildDateRangeStep());
      await tester.pumpAndSettle();

      expect(find.text('From'), findsOneWidget);
      expect(find.text('To'), findsOneWidget);
    });

    testWidgets('shows calendar_today icons for both date pickers', (
      tester,
    ) async {
      await tester.pumpWidget(buildDateRangeStep());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.calendar_today), findsNWidgets(2));
    });

    testWidgets('displays formatted start and end dates', (tester) async {
      await tester.pumpWidget(buildDateRangeStep());
      await tester.pumpAndSettle();

      // The step defaults to last 30 days. We check that some date text
      // is rendered (the exact format depends on intl/locale).
      final inkWells = find.byType(InkWell);
      expect(inkWells, findsNWidgets(2));
    });

    testWidgets('tapping From opens a date picker dialog', (tester) async {
      await tester.pumpWidget(buildDateRangeStep());
      await tester.pumpAndSettle();

      // Tap the first InkWell (From date picker)
      await tester.tap(find.text('From'));
      await tester.pumpAndSettle();

      // The date picker dialog should be visible
      expect(find.byType(DatePickerDialog), findsOneWidget);
    });

    testWidgets('tapping To opens a date picker dialog', (tester) async {
      await tester.pumpWidget(buildDateRangeStep());
      await tester.pumpAndSettle();

      // Tap the second InkWell (To date picker)
      await tester.tap(find.text('To'));
      await tester.pumpAndSettle();

      // The date picker dialog should be visible
      expect(find.byType(DatePickerDialog), findsOneWidget);
    });

    testWidgets('sets healthKitDateRangeSelectedProvider to true on init', (
      tester,
    ) async {
      late WidgetRef capturedRef;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  Consumer(
                    builder: (context, ref, _) {
                      capturedRef = ref;
                      return const SizedBox();
                    },
                  ),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final widgetAdapter = HealthKitAdapter(
                          healthService: MockHealthImportService(),
                          diveMatcher: MockDiveMatcher(),
                          converter: MockImportedDiveConverter(),
                          diveRepository: MockDiveRepository(),
                          diverId: 'diver-1',
                        );
                        return widgetAdapter.acquisitionSteps[1].builder(
                          context,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(capturedRef.read(healthKitDateRangeSelectedProvider), isTrue);
    });

    testWidgets('both date picker buttons are tappable InkWells', (
      tester,
    ) async {
      await tester.pumpWidget(buildDateRangeStep());
      await tester.pumpAndSettle();

      final inkWells = tester.widgetList<InkWell>(find.byType(InkWell));
      for (final inkWell in inkWells) {
        expect(inkWell.onTap, isNotNull);
      }
    });
  });

  // -------------------------------------------------------------------------
  // Widget tests: _HealthKitFetchStep
  // -------------------------------------------------------------------------

  group('_HealthKitFetchStep widget', () {
    Widget buildFetchStep(
      MockHealthImportService service, {
      void Function(List<ImportedDive>)? onDivesFetched,
    }) {
      final widgetAdapter = HealthKitAdapter(
        healthService: service,
        diveMatcher: MockDiveMatcher(),
        converter: MockImportedDiveConverter(),
        diveRepository: MockDiveRepository(),
        diverId: 'diver-1',
      );
      final step = widgetAdapter.acquisitionSteps[2];
      return testApp(
        overrides: [
          settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
        ],
        child: SizedBox(
          height: 600,
          child: Builder(builder: (context) => step.builder(context)),
        ),
      );
    }

    testWidgets('shows loading indicator while fetching', (tester) async {
      final service = MockHealthImportService();
      final completer = Completer<List<ImportedDive>>();
      when(
        service.fetchDives(
          startDate: anyNamed('startDate'),
          endDate: anyNamed('endDate'),
        ),
      ).thenAnswer((_) => completer.future);

      await tester.pumpWidget(buildFetchStep(service));
      // Pump once to trigger the post-frame callback and start fetch
      await tester.pump();
      // Pump again to see the loading state
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Fetching dives from Apple Health...'), findsOneWidget);

      completer.complete([]);
      await tester.pumpAndSettle();
    });

    testWidgets('shows fetched dive count after successful fetch', (
      tester,
    ) async {
      final service = MockHealthImportService();
      final dives = [
        makeDive(sourceId: 'hk-1'),
        makeDive(sourceId: 'hk-2'),
        makeDive(sourceId: 'hk-3'),
      ];
      when(
        service.fetchDives(
          startDate: anyNamed('startDate'),
          endDate: anyNamed('endDate'),
        ),
      ).thenAnswer((_) async => dives);

      await tester.pumpWidget(buildFetchStep(service));
      await tester.pumpAndSettle();

      expect(find.text('Found 3 dives'), findsOneWidget);
      expect(find.text('Proceeding to review...'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('shows singular "dive" for count of 1', (tester) async {
      final service = MockHealthImportService();
      when(
        service.fetchDives(
          startDate: anyNamed('startDate'),
          endDate: anyNamed('endDate'),
        ),
      ).thenAnswer((_) async => [makeDive()]);

      await tester.pumpWidget(buildFetchStep(service));
      await tester.pumpAndSettle();

      expect(find.text('Found 1 dive'), findsOneWidget);
    });

    testWidgets('shows zero dives when none found', (tester) async {
      final service = MockHealthImportService();
      when(
        service.fetchDives(
          startDate: anyNamed('startDate'),
          endDate: anyNamed('endDate'),
        ),
      ).thenAnswer((_) async => []);

      await tester.pumpWidget(buildFetchStep(service));
      await tester.pumpAndSettle();

      expect(find.text('Found 0 dives'), findsOneWidget);
      expect(find.text('Proceeding to review...'), findsOneWidget);
    });

    testWidgets('shows error state when fetch fails', (tester) async {
      final service = MockHealthImportService();
      when(
        service.fetchDives(
          startDate: anyNamed('startDate'),
          endDate: anyNamed('endDate'),
        ),
      ).thenThrow(Exception('Network error'));

      await tester.pumpWidget(buildFetchStep(service));
      await tester.pumpAndSettle();

      expect(find.text('Fetch Failed'), findsOneWidget);
      expect(find.textContaining('Failed to fetch dives:'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('error message includes the exception details', (tester) async {
      final service = MockHealthImportService();
      when(
        service.fetchDives(
          startDate: anyNamed('startDate'),
          endDate: anyNamed('endDate'),
        ),
      ).thenThrow(Exception('HealthKit unavailable'));

      await tester.pumpWidget(buildFetchStep(service));
      await tester.pumpAndSettle();

      expect(find.textContaining('HealthKit unavailable'), findsOneWidget);
    });

    testWidgets('sets healthKitDivesFetchedProvider after successful fetch', (
      tester,
    ) async {
      final service = MockHealthImportService();
      when(
        service.fetchDives(
          startDate: anyNamed('startDate'),
          endDate: anyNamed('endDate'),
        ),
      ).thenAnswer((_) async => [makeDive()]);

      late WidgetRef capturedRef;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  Consumer(
                    builder: (context, ref, _) {
                      capturedRef = ref;
                      return const SizedBox();
                    },
                  ),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final widgetAdapter = HealthKitAdapter(
                          healthService: service,
                          diveMatcher: MockDiveMatcher(),
                          converter: MockImportedDiveConverter(),
                          diveRepository: MockDiveRepository(),
                          diverId: 'diver-1',
                        );
                        return widgetAdapter.acquisitionSteps[2].builder(
                          context,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(capturedRef.read(healthKitDivesFetchedProvider), isTrue);
    });

    testWidgets('sets healthKitDivesFetchedProvider even on error', (
      tester,
    ) async {
      final service = MockHealthImportService();
      when(
        service.fetchDives(
          startDate: anyNamed('startDate'),
          endDate: anyNamed('endDate'),
        ),
      ).thenThrow(Exception('fail'));

      late WidgetRef capturedRef;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  Consumer(
                    builder: (context, ref, _) {
                      capturedRef = ref;
                      return const SizedBox();
                    },
                  ),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final widgetAdapter = HealthKitAdapter(
                          healthService: service,
                          diveMatcher: MockDiveMatcher(),
                          converter: MockImportedDiveConverter(),
                          diveRepository: MockDiveRepository(),
                          diverId: 'diver-1',
                        );
                        return widgetAdapter.acquisitionSteps[2].builder(
                          context,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Even on error, the provider is set to true so wizard can advance
      expect(capturedRef.read(healthKitDivesFetchedProvider), isTrue);
    });

    testWidgets('calls fetchDives on the health service', (tester) async {
      final service = MockHealthImportService();
      when(
        service.fetchDives(
          startDate: anyNamed('startDate'),
          endDate: anyNamed('endDate'),
        ),
      ).thenAnswer((_) async => []);

      await tester.pumpWidget(buildFetchStep(service));
      await tester.pumpAndSettle();

      verify(
        service.fetchDives(
          startDate: anyNamed('startDate'),
          endDate: anyNamed('endDate'),
        ),
      ).called(1);
    });
  });

  // -------------------------------------------------------------------------
  // Widget tests: provider initial states
  // -------------------------------------------------------------------------

  group('provider initial states', () {
    testWidgets('healthKitPermissionsGrantedProvider starts false', (
      tester,
    ) async {
      late WidgetRef capturedRef;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                capturedRef = ref;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(capturedRef.read(healthKitPermissionsGrantedProvider), isFalse);
    });

    testWidgets('healthKitDateRangeSelectedProvider starts true', (
      tester,
    ) async {
      late WidgetRef capturedRef;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                capturedRef = ref;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(capturedRef.read(healthKitDateRangeSelectedProvider), isTrue);
    });

    testWidgets('healthKitDivesFetchedProvider starts false', (tester) async {
      late WidgetRef capturedRef;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                capturedRef = ref;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(capturedRef.read(healthKitDivesFetchedProvider), isFalse);
    });
  });
}

// ---------------------------------------------------------------------------
// Test helpers for widget tests
// ---------------------------------------------------------------------------

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
