import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/core/database/database.dart'
    show DiveDataSourcesCompanion, DiveProfilesCompanion;
import 'package:submersion/features/dive_computer/data/services/dive_import_service.dart';
import 'package:submersion/features/dive_computer/domain/entities/device_model.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart'
    hide DiveMatchResult;
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/import_wizard/data/adapters/dive_computer_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/models/import_phase.dart';

@GenerateNiceMocks([
  MockSpec<DiveImportService>(),
  MockSpec<DiveComputerRepository>(),
  MockSpec<DiveRepository>(),
])
import 'dive_computer_adapter_test.mocks.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

DiveComputer makeComputer({
  String id = 'computer-1',
  String name = 'My Perdix',
  String? diverId,
  String? manufacturer = 'Shearwater',
  String? model = 'Perdix',
  String? serialNumber = 'SN-12345',
}) {
  final now = DateTime(2026, 3, 20);
  return DiveComputer(
    id: id,
    name: name,
    diverId: diverId,
    manufacturer: manufacturer,
    model: model,
    serialNumber: serialNumber,
    createdAt: now,
    updatedAt: now,
  );
}

DownloadedDive makeDownloadedDive({
  DateTime? startTime,
  int durationSeconds = 47 * 60,
  double maxDepth = 32.4,
  double? avgDepth = 18.0,
  double? minTemperature = 22.1,
  String? fingerprint,
  List<ProfileSample> profile = const [],
}) {
  return DownloadedDive(
    startTime: startTime ?? DateTime(2026, 3, 15, 10, 32),
    durationSeconds: durationSeconds,
    maxDepth: maxDepth,
    avgDepth: avgDepth,
    minTemperature: minTemperature,
    fingerprint: fingerprint,
    profile: profile,
  );
}

void main() {
  late MockDiveImportService mockImportService;
  late MockDiveComputerRepository mockComputerRepo;
  late MockDiveRepository mockDiveRepo;
  late DiveComputer computer;
  late DiveComputerAdapter adapter;

  const diverId = 'diver-1';

  setUp(() {
    mockImportService = MockDiveImportService();
    mockComputerRepo = MockDiveComputerRepository();
    mockDiveRepo = MockDiveRepository();
    computer = makeComputer();

    adapter = DiveComputerAdapter(
      importService: mockImportService,
      computerRepository: mockComputerRepo,
      diveRepository: mockDiveRepo,
      diverId: diverId,
      knownComputer: computer,
    );
  });

  // -------------------------------------------------------------------------
  // buildBundle
  // -------------------------------------------------------------------------

  group('buildBundle()', () {
    test('returns bundle with dives group from downloaded dives', () async {
      final dive = makeDownloadedDive();
      adapter.setDownloadedDives([dive]);

      final bundle = await adapter.buildBundle();

      expect(bundle.hasType(ImportEntityType.dives), isTrue);
      expect(bundle.groups[ImportEntityType.dives]!.items, hasLength(1));
    });

    test(
      'EntityItem titles are formatted as "MMM d, yyyy -- h:mm AM/PM"',
      () async {
        final dive = makeDownloadedDive(
          startTime: DateTime(2026, 3, 15, 10, 32),
        );
        adapter.setDownloadedDives([dive]);

        final bundle = await adapter.buildBundle();
        final item = bundle.groups[ImportEntityType.dives]!.items.first;

        expect(item.title, contains('Mar 15, 2026'));
        expect(item.title, contains('\u2014'));
        expect(item.title, contains('10:32'));
      },
    );

    test(
      'EntityItem subtitles contain depth, duration, and temperature',
      () async {
        final dive = makeDownloadedDive(
          maxDepth: 32.4,
          minTemperature: 22.1,
          durationSeconds: 47 * 60,
        );
        adapter.setDownloadedDives([dive]);

        final bundle = await adapter.buildBundle();
        final item = bundle.groups[ImportEntityType.dives]!.items.first;

        expect(item.subtitle, contains('32.4m'));
        expect(item.subtitle, contains('47 min'));
        expect(item.subtitle, contains('22.1'));
      },
    );

    test('EntityItem subtitle omits temperature when null', () async {
      final dive = makeDownloadedDive(minTemperature: null);
      adapter.setDownloadedDives([dive]);

      final bundle = await adapter.buildBundle();
      final item = bundle.groups[ImportEntityType.dives]!.items.first;

      expect(item.subtitle, isNot(contains('\u00b0C')));
    });

    test('EntityItem diveData is populated via IncomingDiveData', () async {
      final profile = [
        const ProfileSample(timeSeconds: 0, depth: 0.0),
        const ProfileSample(timeSeconds: 60, depth: 10.0),
      ];
      final dive = makeDownloadedDive(
        maxDepth: 32.4,
        avgDepth: 18.0,
        minTemperature: 22.1,
        durationSeconds: 47 * 60,
        profile: profile,
      );
      adapter.setDownloadedDives([dive]);

      final bundle = await adapter.buildBundle();
      final item = bundle.groups[ImportEntityType.dives]!.items.first;

      expect(item.diveData, isNotNull);
      expect(item.diveData!.maxDepth, equals(32.4));
      expect(item.diveData!.avgDepth, equals(18.0));
      expect(item.diveData!.waterTemp, equals(22.1));
      expect(item.diveData!.durationSeconds, equals(47 * 60));
      expect(item.diveData!.profile, hasLength(2));
    });

    test('diveData includes computer info', () async {
      final dive = makeDownloadedDive();
      adapter.setDownloadedDives([dive]);

      final bundle = await adapter.buildBundle();
      final item = bundle.groups[ImportEntityType.dives]!.items.first;

      expect(item.diveData!.computerName, equals('My Perdix'));
      expect(item.diveData!.computerModel, equals('Shearwater Perdix'));
      expect(item.diveData!.computerSerial, equals('SN-12345'));
    });

    test('returns empty dives group when no downloaded dives', () async {
      adapter.setDownloadedDives([]);

      final bundle = await adapter.buildBundle();

      expect(bundle.groups[ImportEntityType.dives]!.items, isEmpty);
    });

    test('source info reflects diveComputer type and display name', () async {
      adapter.setDownloadedDives([]);

      final bundle = await adapter.buildBundle();

      expect(bundle.source.type, equals(ImportSourceType.diveComputer));
      expect(bundle.source.displayName, equals('My Perdix'));
    });

    test('handles multiple dives', () async {
      final dive1 = makeDownloadedDive(startTime: DateTime(2026, 3, 15, 10, 0));
      final dive2 = makeDownloadedDive(
        startTime: DateTime(2026, 3, 15, 14, 30),
        maxDepth: 18.5,
      );
      adapter.setDownloadedDives([dive1, dive2]);

      final bundle = await adapter.buildBundle();

      expect(bundle.groups[ImportEntityType.dives]!.items, hasLength(2));
    });
  });

  // -------------------------------------------------------------------------
  // checkDuplicates
  // -------------------------------------------------------------------------

  group('checkDuplicates()', () {
    test('marks duplicates using DiveImportService.detectDuplicate', () async {
      final dive = makeDownloadedDive();
      adapter.setDownloadedDives([dive]);
      final bundle = await adapter.buildBundle();

      when(
        mockImportService.detectDuplicate(dive, diverId: diverId),
      ).thenAnswer(
        (_) async => const DuplicateResult(
          matchingDiveId: 'existing-dive-1',
          confidence: DuplicateConfidence.likely,
          score: 0.85,
          timeDifferenceSeconds: 30,
          depthDifferenceMeters: 0.2,
        ),
      );

      final result = await adapter.checkDuplicates(bundle);

      expect(
        result.groups[ImportEntityType.dives]!.duplicateIndices,
        contains(0),
      );
    });

    test('populates matchResults with correct fields', () async {
      final dive = makeDownloadedDive();
      adapter.setDownloadedDives([dive]);
      final bundle = await adapter.buildBundle();

      when(
        mockImportService.detectDuplicate(dive, diverId: diverId),
      ).thenAnswer(
        (_) async => const DuplicateResult(
          matchingDiveId: 'existing-dive-1',
          confidence: DuplicateConfidence.likely,
          score: 0.75,
          timeDifferenceSeconds: 60,
          depthDifferenceMeters: 0.5,
        ),
      );

      final result = await adapter.checkDuplicates(bundle);

      final matchResult =
          result.groups[ImportEntityType.dives]!.matchResults![0];
      expect(matchResult, isNotNull);
      expect(matchResult!.score, equals(0.75));
      expect(matchResult.diveId, equals('existing-dive-1'));
      expect(matchResult.timeDifferenceMs, equals(60000));
      expect(matchResult.depthDifferenceMeters, equals(0.5));
    });

    test('leaves bundle unchanged when no matches above threshold', () async {
      final dive = makeDownloadedDive();
      adapter.setDownloadedDives([dive]);
      final bundle = await adapter.buildBundle();

      when(
        mockImportService.detectDuplicate(dive, diverId: diverId),
      ).thenAnswer(
        (_) async => const DuplicateResult(
          confidence: DuplicateConfidence.none,
          score: 0.2,
        ),
      );

      final result = await adapter.checkDuplicates(bundle);

      expect(result.groups[ImportEntityType.dives]!.duplicateIndices, isEmpty);
      expect(result.groups[ImportEntityType.dives]!.matchResults, isEmpty);
    });

    test('uses 0.5 threshold for possible duplicates', () async {
      final dive = makeDownloadedDive();
      adapter.setDownloadedDives([dive]);
      final bundle = await adapter.buildBundle();

      when(
        mockImportService.detectDuplicate(dive, diverId: diverId),
      ).thenAnswer(
        (_) async => const DuplicateResult(
          matchingDiveId: 'existing-dive-1',
          confidence: DuplicateConfidence.possible,
          score: 0.5,
          timeDifferenceSeconds: 120,
        ),
      );

      final result = await adapter.checkDuplicates(bundle);

      expect(
        result.groups[ImportEntityType.dives]!.duplicateIndices,
        contains(0),
      );
    });

    test('ignores matches with isDuplicate true but score below 0.5', () async {
      final dive = makeDownloadedDive();
      adapter.setDownloadedDives([dive]);
      final bundle = await adapter.buildBundle();

      when(
        mockImportService.detectDuplicate(dive, diverId: diverId),
      ).thenAnswer(
        (_) async => const DuplicateResult(
          matchingDiveId: 'existing-dive-1',
          confidence: DuplicateConfidence.none,
          score: 0.3,
        ),
      );

      final result = await adapter.checkDuplicates(bundle);

      expect(result.groups[ImportEntityType.dives]!.duplicateIndices, isEmpty);
    });

    test('handles multiple dives with mixed match results', () async {
      final dive1 = makeDownloadedDive(startTime: DateTime(2026, 3, 15, 10, 0));
      final dive2 = makeDownloadedDive(
        startTime: DateTime(2026, 3, 15, 14, 30),
      );
      adapter.setDownloadedDives([dive1, dive2]);
      final bundle = await adapter.buildBundle();

      when(
        mockImportService.detectDuplicate(dive1, diverId: diverId),
      ).thenAnswer(
        (_) async => const DuplicateResult(
          matchingDiveId: 'existing-1',
          confidence: DuplicateConfidence.exact,
          score: 0.95,
          timeDifferenceSeconds: 5,
        ),
      );
      when(
        mockImportService.detectDuplicate(dive2, diverId: diverId),
      ).thenAnswer((_) async => DuplicateResult.noMatch());

      final result = await adapter.checkDuplicates(bundle);

      expect(
        result.groups[ImportEntityType.dives]!.duplicateIndices,
        equals({0}),
      );
      expect(
        result.groups[ImportEntityType.dives]!.matchResults!.length,
        equals(1),
      );
    });
  });

  // -------------------------------------------------------------------------
  // performImport
  // -------------------------------------------------------------------------

  group('performImport()', () {
    test('imports non-duplicate dives via importSingleDiveAsNew', () async {
      final dive = makeDownloadedDive();
      adapter.setDownloadedDives([dive]);
      final bundle = await adapter.buildBundle();

      when(
        mockImportService.importSingleDiveAsNew(
          dive,
          computerId: computer.id,
          diverId: diverId,
        ),
      ).thenAnswer((_) async => 'new-dive-1');

      final result = await adapter.performImport(bundle, {
        ImportEntityType.dives: {0},
      }, {});

      verify(
        mockImportService.importSingleDiveAsNew(
          dive,
          computerId: computer.id,
          diverId: diverId,
        ),
      ).called(1);
      expect(result.importedCounts[ImportEntityType.dives], equals(1));
    });

    test('handles DuplicateAction.skip', () async {
      final dive = makeDownloadedDive();
      adapter.setDownloadedDives([dive]);
      final bundle = await adapter.buildBundle();

      final result = await adapter.performImport(
        bundle,
        {
          ImportEntityType.dives: {0},
        },
        {
          ImportEntityType.dives: {0: DuplicateAction.skip},
        },
      );

      verifyNever(
        mockImportService.importSingleDiveAsNew(
          any,
          computerId: anyNamed('computerId'),
          diverId: anyNamed('diverId'),
        ),
      );
      expect(result.skippedCount, equals(1));
      expect(result.importedCounts[ImportEntityType.dives], equals(0));
    });

    test('handles DuplicateAction.importAsNew', () async {
      final dive = makeDownloadedDive();
      adapter.setDownloadedDives([dive]);
      final bundle = await adapter.buildBundle();

      when(
        mockImportService.importSingleDiveAsNew(
          dive,
          computerId: computer.id,
          diverId: diverId,
        ),
      ).thenAnswer((_) async => 'new-dive-1');

      // Index 0 is NOT in plain selections but has importAsNew action
      final result = await adapter.performImport(
        bundle,
        {ImportEntityType.dives: <int>{}},
        {
          ImportEntityType.dives: {0: DuplicateAction.importAsNew},
        },
      );

      verify(
        mockImportService.importSingleDiveAsNew(
          dive,
          computerId: computer.id,
          diverId: diverId,
        ),
      ).called(1);
      expect(result.importedCounts[ImportEntityType.dives], equals(1));
    });

    test(
      'handles DuplicateAction.consolidate by calling consolidateComputer',
      () async {
        final dive = makeDownloadedDive(
          profile: [
            const ProfileSample(timeSeconds: 0, depth: 0.0),
            const ProfileSample(timeSeconds: 60, depth: 10.0),
          ],
        );
        adapter.setDownloadedDives([dive]);

        // Build a bundle with match results to provide the target dive ID.
        final rawBundle = await adapter.buildBundle();
        final bundleWithDupes = ImportBundle(
          source: rawBundle.source,
          groups: {
            ImportEntityType.dives: EntityGroup(
              items: rawBundle.groups[ImportEntityType.dives]!.items,
              duplicateIndices: {0},
              matchResults: {
                0: const DiveMatchResult(
                  diveId: 'existing-dive-1',
                  score: 0.9,
                  timeDifferenceMs: 5000,
                ),
              },
            ),
          },
        );

        when(
          mockDiveRepo.consolidateComputer(
            targetDiveId: anyNamed('targetDiveId'),
            secondaryReading: anyNamed('secondaryReading'),
            secondaryProfile: anyNamed('secondaryProfile'),
          ),
        ).thenAnswer((_) async {});

        final result = await adapter.performImport(
          bundleWithDupes,
          {
            ImportEntityType.dives: {0},
          },
          {
            ImportEntityType.dives: {0: DuplicateAction.consolidate},
          },
        );

        verify(
          mockDiveRepo.consolidateComputer(
            targetDiveId: 'existing-dive-1',
            secondaryReading: argThat(
              isA<DiveDataSourcesCompanion>(),
              named: 'secondaryReading',
            ),
            secondaryProfile: argThat(
              isA<List<DiveProfilesCompanion>>().having(
                (l) => l.length,
                'length',
                2,
              ),
              named: 'secondaryProfile',
            ),
          ),
        ).called(1);
        expect(result.consolidatedCount, equals(1));
        expect(result.importedCounts[ImportEntityType.dives], equals(0));
      },
    );

    test('returns correct counts for mixed actions', () async {
      final dive1 = makeDownloadedDive(
        startTime: DateTime(2026, 3, 15, 10, 0),
        fingerprint: 'fp1',
      );
      final dive2 = makeDownloadedDive(startTime: DateTime(2026, 3, 15, 14, 0));
      final dive3 = makeDownloadedDive(
        startTime: DateTime(2026, 3, 15, 16, 0),
        fingerprint: 'fp3',
      );
      adapter.setDownloadedDives([dive1, dive2, dive3]);

      final rawBundle = await adapter.buildBundle();
      // Build bundle with match results for consolidation at index 1
      final bundleWithDupes = ImportBundle(
        source: rawBundle.source,
        groups: {
          ImportEntityType.dives: EntityGroup(
            items: rawBundle.groups[ImportEntityType.dives]!.items,
            duplicateIndices: {1},
            matchResults: {
              1: const DiveMatchResult(
                diveId: 'existing-dive-1',
                score: 0.85,
                timeDifferenceMs: 10000,
              ),
            },
          ),
        },
      );

      // dive1: plain import, dive2: consolidate, dive3: skip
      when(
        mockImportService.importDives(
          dives: anyNamed('dives'),
          computer: anyNamed('computer'),
          mode: anyNamed('mode'),
          defaultResolution: anyNamed('defaultResolution'),
          diverId: anyNamed('diverId'),
        ),
      ).thenAnswer(
        (_) async => ImportResult.success(
          imported: 1,
          skipped: 0,
          updated: 0,
          importedDiveIds: ['new-1'],
          importedDives: [dive1],
        ),
      );

      when(
        mockDiveRepo.consolidateComputer(
          targetDiveId: anyNamed('targetDiveId'),
          secondaryReading: anyNamed('secondaryReading'),
          secondaryProfile: anyNamed('secondaryProfile'),
        ),
      ).thenAnswer((_) async {});

      final result = await adapter.performImport(
        bundleWithDupes,
        {
          ImportEntityType.dives: {0, 1},
        },
        {
          ImportEntityType.dives: {
            1: DuplicateAction.consolidate,
            2: DuplicateAction.skip,
          },
        },
      );

      expect(result.importedCounts[ImportEntityType.dives], equals(1));
      expect(result.consolidatedCount, equals(1));
      expect(result.skippedCount, equals(1));
    });

    test('calls onProgress for each processed dive', () async {
      final dive1 = makeDownloadedDive(startTime: DateTime(2026, 3, 15, 10, 0));
      final dive2 = makeDownloadedDive(startTime: DateTime(2026, 3, 15, 14, 0));
      adapter.setDownloadedDives([dive1, dive2]);
      final bundle = await adapter.buildBundle();

      when(
        mockImportService.importDives(
          dives: anyNamed('dives'),
          computer: anyNamed('computer'),
          mode: anyNamed('mode'),
          defaultResolution: anyNamed('defaultResolution'),
          diverId: anyNamed('diverId'),
        ),
      ).thenAnswer(
        (_) async => ImportResult.success(
          imported: 1,
          skipped: 0,
          updated: 0,
          importedDiveIds: ['id'],
          importedDives: [dive1],
        ),
      );

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
      expect(progressCalls[0], equals((ImportPhase.dives, 1, 2)));
      expect(progressCalls[1], equals((ImportPhase.dives, 2, 2)));
    });

    test('updates computer metadata after import', () async {
      final dive = makeDownloadedDive(fingerprint: 'fp-newest');
      adapter.setDownloadedDives([dive]);
      final bundle = await adapter.buildBundle();

      when(
        mockImportService.importDives(
          dives: anyNamed('dives'),
          computer: anyNamed('computer'),
          mode: anyNamed('mode'),
          defaultResolution: anyNamed('defaultResolution'),
          diverId: anyNamed('diverId'),
        ),
      ).thenAnswer(
        (_) async => ImportResult.success(
          imported: 1,
          skipped: 0,
          updated: 0,
          importedDiveIds: ['id'],
          importedDives: [dive],
        ),
      );

      await adapter.performImport(bundle, {
        ImportEntityType.dives: {0},
      }, {});

      verify(
        mockComputerRepo.incrementDiveCount('computer-1', by: 1),
      ).called(1);
      verify(mockComputerRepo.updateLastDownload('computer-1')).called(1);
      verify(
        mockComputerRepo.updateLastFingerprint('computer-1', 'fp-newest'),
      ).called(1);
    });

    test('returns error result when no computer is available', () async {
      final adapterNoComputer = DiveComputerAdapter(
        importService: mockImportService,
        computerRepository: mockComputerRepo,
        diveRepository: mockDiveRepo,
        diverId: diverId,
      );
      adapterNoComputer.setDownloadedDives([makeDownloadedDive()]);
      final bundle = await adapterNoComputer.buildBundle();

      final result = await adapterNoComputer.performImport(bundle, {
        ImportEntityType.dives: {0},
      }, {});

      expect(result.errorMessage, isNotNull);
    });
  });

  // -------------------------------------------------------------------------
  // Adapter metadata
  // -------------------------------------------------------------------------

  group('adapter metadata', () {
    test('sourceType is diveComputer', () {
      expect(adapter.sourceType, equals(ImportSourceType.diveComputer));
    });

    test('displayName uses known computer displayName', () {
      expect(adapter.displayName, equals('My Perdix'));
    });

    test('custom displayName is used when provided', () {
      final named = DiveComputerAdapter(
        importService: mockImportService,
        computerRepository: mockComputerRepo,
        diveRepository: mockDiveRepo,
        diverId: diverId,
        displayName: 'Custom Name',
      );
      expect(named.displayName, equals('Custom Name'));
    });

    test(
      'supportedDuplicateActions includes skip, importAsNew, and consolidate',
      () {
        expect(
          adapter.supportedDuplicateActions,
          containsAll([
            DuplicateAction.skip,
            DuplicateAction.importAsNew,
            DuplicateAction.consolidate,
          ]),
        );
      },
    );

    test('known computer adapter has one acquisition step', () {
      expect(adapter.acquisitionSteps, hasLength(1));
      expect(adapter.acquisitionSteps.first.label, equals('Download'));
      expect(adapter.acquisitionSteps.first.autoAdvance, isTrue);
    });

    test('discovery adapter has three acquisition steps', () {
      final discoveryAdapter = DiveComputerAdapter(
        importService: mockImportService,
        computerRepository: mockComputerRepo,
        diveRepository: mockDiveRepo,
        diverId: diverId,
      );

      expect(discoveryAdapter.acquisitionSteps, hasLength(3));
      expect(discoveryAdapter.acquisitionSteps[0].label, equals('Scan'));
      expect(discoveryAdapter.acquisitionSteps[0].autoAdvance, isTrue);
      expect(discoveryAdapter.acquisitionSteps[1].label, equals('Confirm'));
      expect(discoveryAdapter.acquisitionSteps[1].autoAdvance, isTrue);
      expect(discoveryAdapter.acquisitionSteps[1].hideBottomBar, isTrue);
      expect(discoveryAdapter.acquisitionSteps[2].label, equals('Download'));
      expect(discoveryAdapter.acquisitionSteps[2].autoAdvance, isTrue);
    });

    test('isKnownComputer returns true when knownComputer is provided', () {
      expect(adapter.isKnownComputer, isTrue);
    });

    test('isKnownComputer returns false when knownComputer is null', () {
      final discoveryAdapter = DiveComputerAdapter(
        importService: mockImportService,
        computerRepository: mockComputerRepo,
        diveRepository: mockDiveRepo,
        diverId: diverId,
      );
      expect(discoveryAdapter.isKnownComputer, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // resolveKnownComputer
  // -------------------------------------------------------------------------

  group('resolveKnownComputer()', () {
    test('looks up computer by BLE address when computer is null', () async {
      // Use a discovery adapter (no knownComputer).
      final discoveryAdapter = DiveComputerAdapter(
        importService: mockImportService,
        computerRepository: mockComputerRepo,
        diveRepository: mockDiveRepo,
        diverId: diverId,
      );

      final existingComputer = makeComputer(
        id: 'found-computer',
        diverId: diverId,
      );
      when(
        mockComputerRepo.findByBluetoothAddress(
          'AA:BB:CC:DD:EE:FF',
          diverId: diverId,
        ),
      ).thenAnswer((_) async => existingComputer);

      final device = DiscoveredDevice(
        id: 'device-1',
        name: 'Perdix 2',
        connectionType: DeviceConnectionType.ble,
        address: 'AA:BB:CC:DD:EE:FF',
        discoveredAt: DateTime(2026, 3, 20),
      );

      await discoveryAdapter.resolveKnownComputer(device);

      expect(discoveryAdapter.computer, equals(existingComputer));
      verify(
        mockComputerRepo.findByBluetoothAddress(
          'AA:BB:CC:DD:EE:FF',
          diverId: diverId,
        ),
      ).called(1);
    });

    test('looks up computer by bluetoothClassic address', () async {
      final discoveryAdapter = DiveComputerAdapter(
        importService: mockImportService,
        computerRepository: mockComputerRepo,
        diveRepository: mockDiveRepo,
        diverId: diverId,
      );

      when(
        mockComputerRepo.findByBluetoothAddress(
          '11:22:33:44:55:66',
          diverId: diverId,
        ),
      ).thenAnswer((_) async => null);

      final device = DiscoveredDevice(
        id: 'device-2',
        name: 'Perdix Classic',
        connectionType: DeviceConnectionType.bluetoothClassic,
        address: '11:22:33:44:55:66',
        discoveredAt: DateTime(2026, 3, 20),
      );

      await discoveryAdapter.resolveKnownComputer(device);

      verify(
        mockComputerRepo.findByBluetoothAddress(
          '11:22:33:44:55:66',
          diverId: diverId,
        ),
      ).called(1);
      // No computer found, so it stays null.
      expect(discoveryAdapter.computer, isNull);
    });

    test('is a no-op for USB devices', () async {
      final discoveryAdapter = DiveComputerAdapter(
        importService: mockImportService,
        computerRepository: mockComputerRepo,
        diveRepository: mockDiveRepo,
        diverId: diverId,
      );

      final device = DiscoveredDevice(
        id: 'device-3',
        name: 'USB Computer',
        connectionType: DeviceConnectionType.usb,
        address: '/dev/ttyUSB0',
        discoveredAt: DateTime(2026, 3, 20),
      );

      await discoveryAdapter.resolveKnownComputer(device);

      verifyNever(
        mockComputerRepo.findByBluetoothAddress(
          any,
          diverId: anyNamed('diverId'),
        ),
      );
      expect(discoveryAdapter.computer, isNull);
    });

    test('is a no-op when computer is already set', () async {
      // Known computer adapter already has a computer.
      final device = DiscoveredDevice(
        id: 'device-1',
        name: 'Perdix 2',
        connectionType: DeviceConnectionType.ble,
        address: 'AA:BB:CC:DD:EE:FF',
        discoveredAt: DateTime(2026, 3, 20),
      );

      await adapter.resolveKnownComputer(device);

      verifyNever(
        mockComputerRepo.findByBluetoothAddress(
          any,
          diverId: anyNamed('diverId'),
        ),
      );
    });

    test(
      'leaves computer null when address belongs to different diver',
      () async {
        final discoveryAdapter = DiveComputerAdapter(
          importService: mockImportService,
          computerRepository: mockComputerRepo,
          diveRepository: mockDiveRepo,
          diverId: diverId,
        );

        // The address exists but belongs to another diver; diver-scoped lookup
        // returns null.
        when(
          mockComputerRepo.findByBluetoothAddress(
            'AA:BB:CC:DD:EE:FF',
            diverId: diverId,
          ),
        ).thenAnswer((_) async => null);

        final device = DiscoveredDevice(
          id: 'device-1',
          name: 'Perdix 2',
          connectionType: DeviceConnectionType.ble,
          address: 'AA:BB:CC:DD:EE:FF',
          discoveredAt: DateTime(2026, 3, 20),
        );

        await discoveryAdapter.resolveKnownComputer(device);

        expect(discoveryAdapter.computer, isNull);
      },
    );

    test('is a no-op when diverId is empty', () async {
      final emptyDiverAdapter = DiveComputerAdapter(
        importService: mockImportService,
        computerRepository: mockComputerRepo,
        diveRepository: mockDiveRepo,
        diverId: '',
      );

      final device = DiscoveredDevice(
        id: 'device-1',
        name: 'Perdix 2',
        connectionType: DeviceConnectionType.ble,
        address: 'AA:BB:CC:DD:EE:FF',
        discoveredAt: DateTime(2026, 3, 20),
      );

      await emptyDiverAdapter.resolveKnownComputer(device);

      verifyNever(
        mockComputerRepo.findByBluetoothAddress(
          any,
          diverId: anyNamed('diverId'),
        ),
      );
      expect(emptyDiverAdapter.computer, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // ensureComputer
  // -------------------------------------------------------------------------

  group('ensureComputer()', () {
    test('creates new computer record in discovery mode', () async {
      final discoveryAdapter = DiveComputerAdapter(
        importService: mockImportService,
        computerRepository: mockComputerRepo,
        diveRepository: mockDiveRepo,
        diverId: diverId,
      );

      final createdComputer = makeComputer(id: 'new-computer-id');
      when(
        mockComputerRepo.createComputer(any),
      ).thenAnswer((_) async => createdComputer);

      final device = DiscoveredDevice(
        id: 'device-1',
        name: 'Perdix 2',
        connectionType: DeviceConnectionType.ble,
        address: 'AA:BB:CC:DD:EE:FF',
        discoveredAt: DateTime(2026, 3, 20),
      );

      await discoveryAdapter.ensureComputer(
        device: device,
        serialNumber: 'SN-99999',
        firmwareVersion: 'v4.0',
      );

      expect(discoveryAdapter.computer, equals(createdComputer));
      verify(mockComputerRepo.createComputer(any)).called(1);
    });

    test(
      'is a no-op when computer already set (known-computer mode)',
      () async {
        final device = DiscoveredDevice(
          id: 'device-1',
          name: 'Perdix 2',
          connectionType: DeviceConnectionType.ble,
          address: 'AA:BB:CC:DD:EE:FF',
          discoveredAt: DateTime(2026, 3, 20),
        );

        await adapter.ensureComputer(device: device);

        verifyNever(mockComputerRepo.createComputer(any));
      },
    );

    test('uses custom device name when set', () async {
      final discoveryAdapter = DiveComputerAdapter(
        importService: mockImportService,
        computerRepository: mockComputerRepo,
        diveRepository: mockDiveRepo,
        diverId: diverId,
      );

      discoveryAdapter.setCustomDeviceName('My Custom Name');

      when(mockComputerRepo.createComputer(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as DiveComputer,
      );

      final device = DiscoveredDevice(
        id: 'device-1',
        name: 'Perdix 2',
        connectionType: DeviceConnectionType.ble,
        address: 'AA:BB:CC:DD:EE:FF',
        discoveredAt: DateTime(2026, 3, 20),
      );

      await discoveryAdapter.ensureComputer(device: device);

      final captured =
          verify(mockComputerRepo.createComputer(captureAny)).captured.single
              as DiveComputer;
      expect(captured.name, equals('My Custom Name'));
    });
  });

  // -------------------------------------------------------------------------
  // setCustomDeviceName
  // -------------------------------------------------------------------------

  group('setCustomDeviceName()', () {
    test('stores trimmed non-empty name', () async {
      final discoveryAdapter = DiveComputerAdapter(
        importService: mockImportService,
        computerRepository: mockComputerRepo,
        diveRepository: mockDiveRepo,
        diverId: diverId,
      );

      discoveryAdapter.setCustomDeviceName('  Custom  ');

      when(mockComputerRepo.createComputer(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as DiveComputer,
      );

      final device = DiscoveredDevice(
        id: 'device-1',
        name: 'Perdix 2',
        connectionType: DeviceConnectionType.ble,
        address: 'AA:BB:CC:DD:EE:FF',
        discoveredAt: DateTime(2026, 3, 20),
      );

      await discoveryAdapter.ensureComputer(device: device);

      final captured =
          verify(mockComputerRepo.createComputer(captureAny)).captured.single
              as DiveComputer;
      expect(captured.name, equals('Custom'));
    });

    test('falls back to device displayName when name is blank', () async {
      final discoveryAdapter = DiveComputerAdapter(
        importService: mockImportService,
        computerRepository: mockComputerRepo,
        diveRepository: mockDiveRepo,
        diverId: diverId,
      );

      discoveryAdapter.setCustomDeviceName('   ');

      when(mockComputerRepo.createComputer(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as DiveComputer,
      );

      final device = DiscoveredDevice(
        id: 'device-1',
        name: 'Perdix 2',
        connectionType: DeviceConnectionType.ble,
        address: 'AA:BB:CC:DD:EE:FF',
        discoveredAt: DateTime(2026, 3, 20),
      );

      await discoveryAdapter.ensureComputer(device: device);

      final captured =
          verify(mockComputerRepo.createComputer(captureAny)).captured.single
              as DiveComputer;
      expect(captured.name, equals('Perdix 2'));
    });

    test('falls back to device displayName when name is null', () async {
      final discoveryAdapter = DiveComputerAdapter(
        importService: mockImportService,
        computerRepository: mockComputerRepo,
        diveRepository: mockDiveRepo,
        diverId: diverId,
      );

      discoveryAdapter.setCustomDeviceName(null);

      when(mockComputerRepo.createComputer(any)).thenAnswer(
        (invocation) async => invocation.positionalArguments[0] as DiveComputer,
      );

      final device = DiscoveredDevice(
        id: 'device-1',
        name: 'Perdix 2',
        connectionType: DeviceConnectionType.ble,
        address: 'AA:BB:CC:DD:EE:FF',
        discoveredAt: DateTime(2026, 3, 20),
      );

      await discoveryAdapter.ensureComputer(device: device);

      final captured =
          verify(mockComputerRepo.createComputer(captureAny)).captured.single
              as DiveComputer;
      expect(captured.name, equals('Perdix 2'));
    });
  });

  // -------------------------------------------------------------------------
  // _updateComputerAfterImport (via performImport)
  // -------------------------------------------------------------------------

  group('_updateComputerAfterImport()', () {
    test('skips incrementDiveCount when zero dives imported', () async {
      final dive = makeDownloadedDive();
      adapter.setDownloadedDives([dive]);
      final bundle = await adapter.buildBundle();

      // Skip all dives (zero imported)
      await adapter.performImport(
        bundle,
        {
          ImportEntityType.dives: {0},
        },
        {
          ImportEntityType.dives: {0: DuplicateAction.skip},
        },
      );

      verifyNever(mockComputerRepo.incrementDiveCount(any, by: anyNamed('by')));
      // updateLastDownload is always called
      verify(mockComputerRepo.updateLastDownload('computer-1')).called(1);
    });

    test(
      'does not update fingerprint when no dives have fingerprints',
      () async {
        final dive = makeDownloadedDive(fingerprint: null);
        adapter.setDownloadedDives([dive]);
        final bundle = await adapter.buildBundle();

        when(
          mockImportService.importDives(
            dives: anyNamed('dives'),
            computer: anyNamed('computer'),
            mode: anyNamed('mode'),
            defaultResolution: anyNamed('defaultResolution'),
            diverId: anyNamed('diverId'),
          ),
        ).thenAnswer(
          (_) async => ImportResult.success(
            imported: 1,
            skipped: 0,
            updated: 0,
            importedDiveIds: ['id'],
            importedDives: [dive],
          ),
        );

        await adapter.performImport(bundle, {
          ImportEntityType.dives: {0},
        }, {});

        verifyNever(mockComputerRepo.updateLastFingerprint(any, any));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // defaultTagName
  // ---------------------------------------------------------------------------

  group('defaultTagName', () {
    test('uses computer name from knownComputer when no custom name set', () {
      // adapter is constructed with knownComputer = makeComputer(name: 'My Perdix')
      // _computer is null initially, _customDeviceName is null
      // defaultTagName: _customDeviceName ?? _computer?.name ?? _displayName
      // _displayName = knownComputer.displayName = 'My Perdix'
      final tagName = adapter.defaultTagName;

      expect(tagName, matches(RegExp(r'^My Perdix Import \d{4}-\d{2}-\d{2}$')));
    });

    test('uses custom device name when set', () {
      adapter.setCustomDeviceName('Reef Runner');
      final tagName = adapter.defaultTagName;

      expect(tagName, startsWith('Reef Runner Import '));
      expect(
        tagName,
        matches(RegExp(r'^Reef Runner Import \d{4}-\d{2}-\d{2}$')),
      );
    });

    test('falls back to display name when no computer or custom name', () {
      final noComputer = DiveComputerAdapter(
        importService: mockImportService,
        computerRepository: mockComputerRepo,
        diveRepository: mockDiveRepo,
        diverId: diverId,
      );
      final tagName = noComputer.defaultTagName;

      expect(
        tagName,
        matches(RegExp(r'^Dive Computer Import \d{4}-\d{2}-\d{2}$')),
      );
    });

    test('pads month and day with leading zeros', () {
      final tagName = adapter.defaultTagName;
      final datePart = tagName.split('Import ').last;
      final parts = datePart.split('-');

      expect(parts, hasLength(3));
      expect(parts[0].length, 4); // year
      expect(parts[1].length, 2); // zero-padded month
      expect(parts[2].length, 2); // zero-padded day
    });
  });
}
