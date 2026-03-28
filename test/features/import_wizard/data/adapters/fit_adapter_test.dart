import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_import/data/services/fit_parser_service.dart';
import 'package:submersion/features/dive_import/domain/entities/imported_dive.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/dive_import/domain/services/imported_dive_converter.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/import_wizard/data/adapters/fit_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/models/import_phase.dart';
import 'package:submersion/features/import_wizard/domain/models/wizard_step_def.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_app.dart';

@GenerateNiceMocks([
  MockSpec<DiveMatcher>(),
  MockSpec<ImportedDiveConverter>(),
  MockSpec<DiveRepository>(),
])
import 'fit_adapter_test.mocks.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

ImportedDive makeDive({
  String sourceId = 'garmin-123-1000000',
  DateTime? startTime,
  DateTime? endTime,
  double maxDepth = 32.4,
  double? avgDepth = 18.0,
  double? minTemperature = 22.1,
  List<ImportedProfileSample> profile = const [],
}) {
  final start = startTime ?? DateTime(2026, 3, 15, 10, 32);
  final end = endTime ?? start.add(const Duration(minutes: 47));
  return ImportedDive(
    sourceId: sourceId,
    source: ImportSource.garmin,
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
  double? maxDepth = 32.4,
  Duration? duration = const Duration(minutes: 47),
}) {
  final dt = dateTime ?? DateTime(2026, 3, 15, 10, 32);
  return Dive(
    id: id,
    diverId: diverId,
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
  late MockDiveMatcher mockMatcher;
  late MockImportedDiveConverter mockConverter;
  late MockDiveRepository mockRepo;
  late FitAdapter adapter;

  const diverId = 'diver-1';

  setUp(() {
    mockMatcher = MockDiveMatcher();
    mockConverter = MockImportedDiveConverter();
    mockRepo = MockDiveRepository();

    adapter = FitAdapter(
      fitParser: const FitParserService(),
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
      'EntityItem titles are formatted as "MMM d, yyyy — h:mm AM/PM"',
      () async {
        final dive = makeDive(startTime: DateTime(2026, 3, 15, 10, 32));
        adapter.setParsedDives([dive]);

        final bundle = await adapter.buildBundle();
        final item = bundle.groups[ImportEntityType.dives]!.items.first;

        // Should contain the date and em dash separator
        expect(item.title, contains('Mar 15, 2026'));
        expect(item.title, contains('\u2014'));
        expect(item.title, contains('10:32'));
      },
    );

    test(
      'EntityItem subtitles contain depth, duration, and temperature',
      () async {
        final dive = makeDive(
          maxDepth: 32.4,
          minTemperature: 22.1,
          startTime: DateTime(2026, 3, 15, 10, 32),
          endTime: DateTime(2026, 3, 15, 11, 19),
        );
        adapter.setParsedDives([dive]);

        final bundle = await adapter.buildBundle();
        final item = bundle.groups[ImportEntityType.dives]!.items.first;

        expect(item.subtitle, contains('32.4m'));
        expect(item.subtitle, contains('47 min'));
        expect(item.subtitle, contains('22.1'));
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
        const ImportedProfileSample(timeSeconds: 60, depth: 10.0),
      ];
      final dive = makeDive(
        maxDepth: 32.4,
        avgDepth: 18.0,
        minTemperature: 22.1,
        profile: profile,
      );
      adapter.setParsedDives([dive]);

      final bundle = await adapter.buildBundle();
      final item = bundle.groups[ImportEntityType.dives]!.items.first;

      expect(item.diveData, isNotNull);
      expect(item.diveData!.maxDepth, equals(32.4));
      expect(item.diveData!.avgDepth, equals(18.0));
      expect(item.diveData!.waterTemp, equals(22.1));
      expect(item.diveData!.durationSeconds, equals(47 * 60));
      expect(item.diveData!.profile, hasLength(2));
    });

    test('returns empty dives group when no parsed dives', () async {
      adapter.setParsedDives([]);

      final bundle = await adapter.buildBundle();

      expect(bundle.groups[ImportEntityType.dives]!.items, isEmpty);
    });

    test('source info reflects adapter displayName and fit type', () async {
      adapter.setParsedDives([]);

      final bundle = await adapter.buildBundle();

      expect(bundle.source.type, equals(ImportSourceType.fit));
      expect(bundle.source.displayName, equals('FIT Import'));
    });
  });

  // -------------------------------------------------------------------------
  // checkDuplicates
  // -------------------------------------------------------------------------

  group('checkDuplicates()', () {
    test('marks probable matches in duplicateIndices', () async {
      final dive = makeDive(startTime: DateTime(2026, 3, 15, 10, 32));
      adapter.setParsedDives([dive]);
      final bundle = await adapter.buildBundle();

      final existingDive = makeDomainDive(
        dateTime: DateTime(2026, 3, 15, 10, 33),
        maxDepth: 32.4,
        duration: const Duration(minutes: 47),
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
      // Return different scores for each existing dive
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
      final dive1 = makeDive(sourceId: 'garmin-1');
      final dive2 = makeDive(sourceId: 'garmin-2');
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
      final dive1 = makeDive(sourceId: 'garmin-1');
      final dive2 = makeDive(sourceId: 'garmin-2');
      final dive3 = makeDive(sourceId: 'garmin-3');
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
      final dive1 = makeDive(sourceId: 'garmin-1');
      final dive2 = makeDive(sourceId: 'garmin-2');
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
    test('sourceType is fit', () {
      expect(adapter.sourceType, equals(ImportSourceType.fit));
    });

    test('displayName defaults to FIT Import', () {
      expect(adapter.displayName, equals('FIT Import'));
    });

    test('custom displayName is used when provided', () {
      final named = FitAdapter(
        fitParser: const FitParserService(),
        diveMatcher: mockMatcher,
        converter: mockConverter,
        diveRepository: mockRepo,
        diverId: diverId,
        displayName: 'dive_log.fit',
      );
      expect(named.displayName, equals('dive_log.fit'));
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

    test('acquisitionSteps has one step labelled Select Files', () {
      expect(adapter.acquisitionSteps, hasLength(1));
      expect(adapter.acquisitionSteps.first.label, equals('Select Files'));
    });

    test('defaultTagName includes display name and YYYY-MM-DD date', () {
      final tagName = adapter.defaultTagName;
      expect(tagName, matches(RegExp(r'^FIT Import \d{4}-\d{2}-\d{2}$')));
    });

    test('defaultTagName uses custom display name when provided', () {
      final named = FitAdapter(
        fitParser: const FitParserService(),
        diveMatcher: mockMatcher,
        converter: mockConverter,
        diveRepository: mockRepo,
        diverId: diverId,
        displayName: 'dive_log.fit',
      );
      expect(
        named.defaultTagName,
        matches(RegExp(r'^dive_log\.fit Import \d{4}-\d{2}-\d{2}$')),
      );
    });
  });

  // -------------------------------------------------------------------------
  // resetState
  // -------------------------------------------------------------------------

  group('resetState()', () {
    test('clears parsed dives so buildBundle returns empty group', () async {
      adapter.setParsedDives([makeDive()]);
      adapter.resetState();

      final bundle = await adapter.buildBundle();

      expect(bundle.groups[ImportEntityType.dives]!.items, isEmpty);
    });

    test('can set new dives after reset', () async {
      adapter.setParsedDives([makeDive(sourceId: 'first')]);
      adapter.resetState();
      adapter.setParsedDives([makeDive(sourceId: 'second')]);

      final bundle = await adapter.buildBundle();

      expect(bundle.groups[ImportEntityType.dives]!.items, hasLength(1));
    });
  });

  // -------------------------------------------------------------------------
  // buildBundle — additional edge cases
  // -------------------------------------------------------------------------

  group('buildBundle() — edge cases', () {
    test('handles multiple dives preserving order', () async {
      final dive1 = makeDive(
        sourceId: 'garmin-1',
        startTime: DateTime(2026, 3, 15, 8, 0),
      );
      final dive2 = makeDive(
        sourceId: 'garmin-2',
        startTime: DateTime(2026, 3, 16, 9, 0),
      );
      final dive3 = makeDive(
        sourceId: 'garmin-3',
        startTime: DateTime(2026, 3, 17, 10, 0),
      );
      adapter.setParsedDives([dive1, dive2, dive3]);

      final bundle = await adapter.buildBundle();
      final items = bundle.groups[ImportEntityType.dives]!.items;

      expect(items, hasLength(3));
      expect(items[0].title, contains('Mar 15, 2026'));
      expect(items[1].title, contains('Mar 16, 2026'));
      expect(items[2].title, contains('Mar 17, 2026'));
    });

    test('EntityItem subtitle uses imperial units when configured', () async {
      final imperialAdapter = FitAdapter(
        fitParser: const FitParserService(),
        diveMatcher: mockMatcher,
        converter: mockConverter,
        diveRepository: mockRepo,
        diverId: diverId,
        settings: const AppSettings(
          depthUnit: DepthUnit.feet,
          temperatureUnit: TemperatureUnit.fahrenheit,
        ),
      );

      final dive = makeDive(maxDepth: 30.0, minTemperature: 20.0);
      imperialAdapter.setParsedDives([dive]);

      final bundle = await imperialAdapter.buildBundle();
      final item = bundle.groups[ImportEntityType.dives]!.items.first;

      // 30m ~= 98.4ft
      expect(item.subtitle, contains('ft'));
      expect(item.subtitle, contains('max'));
      // 20C = 68F
      expect(item.subtitle, contains('F'));
    });

    test(
      'EntityItem diveData profile maps heart rate and temperature',
      () async {
        final profile = [
          const ImportedProfileSample(
            timeSeconds: 0,
            depth: 0.0,
            temperature: 22.0,
            heartRate: 70,
          ),
          const ImportedProfileSample(
            timeSeconds: 120,
            depth: 15.0,
            temperature: 21.5,
            heartRate: 85,
          ),
        ];
        final dive = makeDive(profile: profile);
        adapter.setParsedDives([dive]);

        final bundle = await adapter.buildBundle();
        final diveData =
            bundle.groups[ImportEntityType.dives]!.items.first.diveData!;

        expect(diveData.profile[0].temperature, equals(22.0));
        expect(diveData.profile[0].heartRate, equals(70));
        expect(diveData.profile[1].temperature, equals(21.5));
        expect(diveData.profile[1].heartRate, equals(85));
      },
    );

    test('EntityItem diveData startTime matches source dive', () async {
      final startTime = DateTime(2026, 6, 1, 14, 30);
      final dive = makeDive(startTime: startTime);
      adapter.setParsedDives([dive]);

      final bundle = await adapter.buildBundle();
      final diveData =
          bundle.groups[ImportEntityType.dives]!.items.first.diveData!;

      expect(diveData.startTime, equals(startTime));
    });

    test(
      'EntityItem diveData waterTemp is null when source has no temp',
      () async {
        final dive = makeDive(minTemperature: null);
        adapter.setParsedDives([dive]);

        final bundle = await adapter.buildBundle();
        final diveData =
            bundle.groups[ImportEntityType.dives]!.items.first.diveData!;

        expect(diveData.waterTemp, isNull);
      },
    );
  });

  // -------------------------------------------------------------------------
  // checkDuplicates — additional edge cases
  // -------------------------------------------------------------------------

  group('checkDuplicates() — edge cases', () {
    test('returns bundle unchanged when dives group is null', () async {
      // Construct a bundle with no dives group at all
      const bundle = ImportBundle(
        source: ImportSourceInfo(
          type: ImportSourceType.fit,
          displayName: 'FIT Import',
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
      verifyNever(mockRepo.getAllDives(diverId: anyNamed('diverId')));
    });

    test('returns no duplicates when no existing dives', () async {
      final dive = makeDive();
      adapter.setParsedDives([dive]);
      final bundle = await adapter.buildBundle();

      when(mockRepo.getAllDives(diverId: diverId)).thenAnswer((_) async => []);

      final result = await adapter.checkDuplicates(bundle);

      expect(result.groups[ImportEntityType.dives]!.duplicateIndices, isEmpty);
      expect(result.groups[ImportEntityType.dives]!.matchResults, isEmpty);
    });

    test('populates siteName from existing dive site', () async {
      final dive = makeDive();
      adapter.setParsedDives([dive]);
      final bundle = await adapter.buildBundle();

      final existingDive = makeDomainDive().copyWith(
        site: const DiveSite(id: 'site-1', name: 'Blue Corner'),
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
      ).thenReturn(0.8);

      final result = await adapter.checkDuplicates(bundle);

      final matchResult =
          result.groups[ImportEntityType.dives]!.matchResults![0];
      expect(matchResult!.siteName, equals('Blue Corner'));
    });

    test('uses exit-entry time difference when runtime is null', () async {
      final dive = makeDive();
      adapter.setParsedDives([dive]);
      final bundle = await adapter.buildBundle();

      // Existing dive with no runtime, but has entry and exit times
      final entryTime = DateTime(2026, 3, 15, 10, 0);
      final exitTime = DateTime(2026, 3, 15, 10, 50);
      final existingDive = Dive(
        id: 'dive-1',
        diverId: diverId,
        dateTime: entryTime,
        entryTime: entryTime,
        exitTime: exitTime,
        runtime: null,
        maxDepth: 30.0,
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

      await adapter.checkDuplicates(bundle);

      // Verify the matcher was called with 50 minutes in seconds
      verify(
        mockMatcher.calculateMatchScore(
          wearableStartTime: anyNamed('wearableStartTime'),
          wearableMaxDepth: anyNamed('wearableMaxDepth'),
          wearableDurationSeconds: anyNamed('wearableDurationSeconds'),
          existingStartTime: anyNamed('existingStartTime'),
          existingMaxDepth: anyNamed('existingMaxDepth'),
          existingDurationSeconds: 3000,
        ),
      ).called(1);
    });

    test(
      'falls back to duration when runtime and exit time are null',
      () async {
        final dive = makeDive();
        adapter.setParsedDives([dive]);
        final bundle = await adapter.buildBundle();

        // Existing dive with only duration set, no runtime or exit time
        final existingDive = Dive(
          id: 'dive-1',
          diverId: diverId,
          dateTime: DateTime(2026, 3, 15, 10, 0),
          entryTime: DateTime(2026, 3, 15, 10, 0),
          exitTime: null,
          runtime: null,
          bottomTime: const Duration(minutes: 40),
          maxDepth: 30.0,
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

        await adapter.checkDuplicates(bundle);

        // Verify the matcher was called with 40 minutes in seconds
        verify(
          mockMatcher.calculateMatchScore(
            wearableStartTime: anyNamed('wearableStartTime'),
            wearableMaxDepth: anyNamed('wearableMaxDepth'),
            wearableDurationSeconds: anyNamed('wearableDurationSeconds'),
            existingStartTime: anyNamed('existingStartTime'),
            existingMaxDepth: anyNamed('existingMaxDepth'),
            existingDurationSeconds: 2400,
          ),
        ).called(1);
      },
    );

    test('uses zero seconds when all time fields are null', () async {
      final dive = makeDive();
      adapter.setParsedDives([dive]);
      final bundle = await adapter.buildBundle();

      // Existing dive with no runtime, no exit time, no duration
      final existingDive = Dive(
        id: 'dive-1',
        diverId: diverId,
        dateTime: DateTime(2026, 3, 15, 10, 0),
        entryTime: null,
        exitTime: null,
        runtime: null,
        bottomTime: null,
        maxDepth: 30.0,
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

      await adapter.checkDuplicates(bundle);

      verify(
        mockMatcher.calculateMatchScore(
          wearableStartTime: anyNamed('wearableStartTime'),
          wearableMaxDepth: anyNamed('wearableMaxDepth'),
          wearableDurationSeconds: anyNamed('wearableDurationSeconds'),
          existingStartTime: anyNamed('existingStartTime'),
          existingMaxDepth: anyNamed('existingMaxDepth'),
          existingDurationSeconds: 0,
        ),
      ).called(1);
    });

    test('uses zero for existing dive maxDepth when null', () async {
      final dive = makeDive();
      adapter.setParsedDives([dive]);
      final bundle = await adapter.buildBundle();

      final existingDive = makeDomainDive(maxDepth: null);
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

      await adapter.checkDuplicates(bundle);

      verify(
        mockMatcher.calculateMatchScore(
          wearableStartTime: anyNamed('wearableStartTime'),
          wearableMaxDepth: anyNamed('wearableMaxDepth'),
          wearableDurationSeconds: anyNamed('wearableDurationSeconds'),
          existingStartTime: anyNamed('existingStartTime'),
          existingMaxDepth: 0.0,
          existingDurationSeconds: anyNamed('existingDurationSeconds'),
        ),
      ).called(1);
    });

    test('handles multiple imported dives with mixed match results', () async {
      final dive1 = makeDive(
        sourceId: 'garmin-1',
        startTime: DateTime(2026, 3, 15, 8, 0),
      );
      final dive2 = makeDive(
        sourceId: 'garmin-2',
        startTime: DateTime(2026, 3, 16, 9, 0),
      );
      adapter.setParsedDives([dive1, dive2]);
      final bundle = await adapter.buildBundle();

      final existingDive = makeDomainDive();
      when(
        mockRepo.getAllDives(diverId: diverId),
      ).thenAnswer((_) async => [existingDive]);

      // First imported dive matches, second does not
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
      ).thenAnswer((_) => callCount++ == 0 ? 0.8 : 0.3);

      final result = await adapter.checkDuplicates(bundle);

      expect(
        result.groups[ImportEntityType.dives]!.duplicateIndices,
        equals({0}),
      );
      expect(
        result.groups[ImportEntityType.dives]!.matchResults!.containsKey(0),
        isTrue,
      );
      expect(
        result.groups[ImportEntityType.dives]!.matchResults!.containsKey(1),
        isFalse,
      );
    });
  });

  // -------------------------------------------------------------------------
  // performImport — additional edge cases
  // -------------------------------------------------------------------------

  group('performImport() — edge cases', () {
    test('returns zero imported when all selections are skipped', () async {
      final dive1 = makeDive(sourceId: 'garmin-1');
      final dive2 = makeDive(sourceId: 'garmin-2');
      adapter.setParsedDives([dive1, dive2]);
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

      verifyNever(mockConverter.convert(any, diverId: anyNamed('diverId')));
      verifyNever(mockRepo.createDive(any));
      expect(result.importedCounts[ImportEntityType.dives], equals(0));
      expect(result.skippedCount, equals(2));
    });

    test('returns zero counts with empty selections and no actions', () async {
      adapter.setParsedDives([makeDive()]);
      final bundle = await adapter.buildBundle();

      final result = await adapter.performImport(bundle, {}, {});

      expect(result.importedCounts[ImportEntityType.dives], equals(0));
      expect(result.skippedCount, equals(0));
    });

    test('skips out-of-bounds index gracefully', () async {
      adapter.setParsedDives([makeDive()]);
      final bundle = await adapter.buildBundle();

      // Index 5 is out of bounds (only 1 dive at index 0)
      final result = await adapter.performImport(bundle, {
        ImportEntityType.dives: {5},
      }, {});

      verifyNever(mockConverter.convert(any, diverId: anyNamed('diverId')));
      expect(result.importedCounts[ImportEntityType.dives], equals(0));
    });

    test(
      'skip action on index not in selections still counts as skipped',
      () async {
        adapter.setParsedDives([makeDive()]);
        final bundle = await adapter.buildBundle();

        // Index 0 is NOT in selections, but has a skip action
        final result = await adapter.performImport(
          bundle,
          {ImportEntityType.dives: <int>{}},
          {
            ImportEntityType.dives: {0: DuplicateAction.skip},
          },
        );

        expect(result.skippedCount, equals(1));
        expect(result.importedCounts[ImportEntityType.dives], equals(0));
      },
    );

    test('importAsNew adds index not in base selections', () async {
      final dive1 = makeDive(sourceId: 'garmin-1');
      final dive2 = makeDive(sourceId: 'garmin-2');
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

      // Only index 0 in base selections; index 1 has importAsNew action
      final result = await adapter.performImport(
        bundle,
        {
          ImportEntityType.dives: {0},
        },
        {
          ImportEntityType.dives: {1: DuplicateAction.importAsNew},
        },
      );

      verify(mockConverter.convert(dive1, diverId: diverId)).called(1);
      verify(mockConverter.convert(dive2, diverId: diverId)).called(1);
      expect(result.importedCounts[ImportEntityType.dives], equals(2));
      expect(result.skippedCount, equals(0));
    });

    test('imports sorted by index order', () async {
      final dive1 = makeDive(sourceId: 'garmin-1');
      final dive2 = makeDive(sourceId: 'garmin-2');
      final dive3 = makeDive(sourceId: 'garmin-3');
      adapter.setParsedDives([dive1, dive2, dive3]);
      final bundle = await adapter.buildBundle();

      final domainDive1 = makeDomainDive(id: 'dive-1');
      final domainDive2 = makeDomainDive(id: 'dive-2');
      final domainDive3 = makeDomainDive(id: 'dive-3');
      when(
        mockConverter.convert(dive1, diverId: diverId),
      ).thenReturn(domainDive1);
      when(
        mockConverter.convert(dive2, diverId: diverId),
      ).thenReturn(domainDive2);
      when(
        mockConverter.convert(dive3, diverId: diverId),
      ).thenReturn(domainDive3);
      when(mockRepo.createDive(any)).thenAnswer((_) async => domainDive1);

      final progressCalls = <(ImportPhase, int, int)>[];
      // Select indices out of order
      await adapter.performImport(
        bundle,
        {
          ImportEntityType.dives: {2, 0},
        },
        {},
        onProgress: (phase, current, total) {
          progressCalls.add((phase, current, total));
        },
      );

      // Should progress 1/2 then 2/2
      expect(progressCalls, hasLength(2));
      expect(progressCalls[0], equals((ImportPhase.dives, 1, 2)));
      expect(progressCalls[1], equals((ImportPhase.dives, 2, 2)));
    });

    test('returns importedDiveIds for each created dive', () async {
      final dive1 = makeDive(sourceId: 'garmin-1');
      final dive2 = makeDive(sourceId: 'garmin-2');
      adapter.setParsedDives([dive1, dive2]);
      final bundle = await adapter.buildBundle();

      final domainDive1 = makeDomainDive(id: 'dive-uuid-1');
      final domainDive2 = makeDomainDive(id: 'dive-uuid-2');
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
      expect(result.importedDiveIds, contains('dive-uuid-1'));
      expect(result.importedDiveIds, contains('dive-uuid-2'));
    });

    test('consolidatedCount is always zero', () async {
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
  });

  // -------------------------------------------------------------------------
  // _FitFilePickerStep widget tests
  // -------------------------------------------------------------------------

  group('_FitFilePickerStep widget', () {
    Widget buildPickerStep(WizardStepDef step) {
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

    testWidgets('renders empty state with icon, title, and description', (
      tester,
    ) async {
      final step = adapter.acquisitionSteps.first;

      await tester.pumpWidget(buildPickerStep(step));
      await tester.pumpAndSettle();

      expect(find.text('No dives loaded'), findsOneWidget);
      expect(
        find.text(
          'Select one or more .fit files exported from your Garmin device.',
        ),
        findsOneWidget,
      );
      expect(find.text('Select Files'), findsOneWidget);
    });

    testWidgets('shows Select Files button that is enabled initially', (
      tester,
    ) async {
      final step = adapter.acquisitionSteps.first;

      await tester.pumpWidget(buildPickerStep(step));
      await tester.pumpAndSettle();

      final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(button.onPressed, isNotNull);
    });

    testWidgets('shows file_open icon when not parsing', (tester) async {
      final step = adapter.acquisitionSteps.first;

      await tester.pumpWidget(buildPickerStep(step));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.file_open), findsWidgets);
    });

    testWidgets('canAdvance provider starts as false', (tester) async {
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

      expect(capturedRef.read(fitAdapterCanAdvanceProvider), isFalse);
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
