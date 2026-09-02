import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/core/services/garmin_connect/garmin_connect_client.dart';
import 'package:submersion/core/services/garmin_connect/garmin_dive_mapper.dart';
import 'package:submersion/features/dive_computer/data/services/dive_import_service.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart'
    hide DiveMatchResult;
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/dive_consolidation_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/domain/services/unreadable_series_exception.dart';
import 'package:submersion/features/import_wizard/data/adapters/garmin_cloud_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/models/import_cancellation_token.dart';
import 'package:submersion/features/import_wizard/domain/models/import_phase.dart';

@GenerateNiceMocks([
  MockSpec<DiveImportService>(),
  MockSpec<DiveComputerRepository>(),
  MockSpec<DiveRepository>(),
  MockSpec<DiveConsolidationService>(),
])
import 'garmin_cloud_adapter_test.mocks.dart';

GarminParsedDive makeParsedDive({
  DateTime? startTime,
  int durationSeconds = 30 * 60,
  double maxDepth = 18.5,
  String? deviceModel = 'Descent Mk2',
  String? serialNumber = 'SN-1',
  String? firmwareVersion,
}) {
  return GarminParsedDive(
    dive: DownloadedDive(
      startTime: startTime ?? DateTime.utc(2026, 3, 15, 10, 32),
      durationSeconds: durationSeconds,
      maxDepth: maxDepth,
      profile: const [],
    ),
    deviceModel: deviceModel,
    serialNumber: serialNumber,
    firmwareVersion: firmwareVersion,
  );
}

void main() {
  late MockDiveImportService mockImportService;
  late MockDiveComputerRepository mockComputerRepo;
  late MockDiveRepository mockDiveRepo;
  late MockDiveConsolidationService mockConsolidationService;
  late GarminCloudAdapter adapter;

  const diverId = 'diver-1';

  DiveComputer computerFor(String name, String serial) => DiveComputer(
    id: 'computer-$serial',
    name: name,
    diverId: diverId,
    manufacturer: 'Garmin',
    model: name,
    serialNumber: serial,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  setUp(() {
    mockImportService = MockDiveImportService();
    mockComputerRepo = MockDiveComputerRepository();
    mockDiveRepo = MockDiveRepository();
    mockConsolidationService = MockDiveConsolidationService();

    adapter = GarminCloudAdapter(
      importService: mockImportService,
      computerRepository: mockComputerRepo,
      diveRepository: mockDiveRepo,
      consolidationService: mockConsolidationService,
      diverId: diverId,
    );

    when(
      mockDiveRepo.getSourceKeysByDiveId(diverId: anyNamed('diverId')),
    ).thenAnswer((_) async => {});
    when(
      mockComputerRepo.findByHardwareIdentity(
        manufacturer: anyNamed('manufacturer'),
        model: anyNamed('model'),
        serialNumber: anyNamed('serialNumber'),
        diverId: anyNamed('diverId'),
      ),
    ).thenAnswer((_) async => null);
    when(mockComputerRepo.createComputer(any)).thenAnswer((invocation) async {
      final computer = invocation.positionalArguments.first as DiveComputer;
      return computerFor(computer.name, computer.serialNumber ?? computer.name);
    });
  });

  void stubImportAsNew([String diveId = 'new-dive-id']) {
    when(
      mockImportService.importSingleDiveAsNew(
        any,
        computerId: anyNamed('computerId'),
        diverId: anyNamed('diverId'),
        descriptorVendor: anyNamed('descriptorVendor'),
        descriptorProduct: anyNamed('descriptorProduct'),
      ),
    ).thenAnswer((_) async => diveId);
  }

  group('defaultTagName', () {
    String isoDate(DateTime d) =>
        '${d.year}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';

    test("is based on today's date", () {
      // defaultTagName reads its own DateTime.now(). Bracketing the call
      // rather than comparing against a single earlier read keeps this from
      // failing when the two land on opposite sides of midnight.
      final before = DateTime.now();
      final tagName = adapter.defaultTagName;
      final after = DateTime.now();

      expect(
        tagName,
        anyOf(
          'Garmin Connect Import ${isoDate(before)}',
          'Garmin Connect Import ${isoDate(after)}',
        ),
      );
    });
  });

  group('buildBundle()', () {
    test(
      'resolves a computer per dive and returns one entity per dive',
      () async {
        adapter.setParsedDives([makeParsedDive()]);

        final bundle = await adapter.buildBundle();

        expect(bundle.hasType(ImportEntityType.dives), isTrue);
        expect(bundle.groups[ImportEntityType.dives]!.items, hasLength(1));
        verify(mockComputerRepo.createComputer(any)).called(1);
      },
    );

    test(
      'reuses the same computer across dives with the same serial',
      () async {
        adapter.setParsedDives([
          makeParsedDive(startTime: DateTime.utc(2026, 3, 1)),
          makeParsedDive(startTime: DateTime.utc(2026, 3, 2)),
        ]);

        await adapter.buildBundle();

        verify(mockComputerRepo.createComputer(any)).called(1);
      },
    );

    test('resolves separate computers for different devices', () async {
      adapter.setParsedDives([
        makeParsedDive(deviceModel: 'Descent Mk2', serialNumber: 'SN-1'),
        makeParsedDive(deviceModel: 'Descent G1', serialNumber: 'SN-2'),
      ]);

      await adapter.buildBundle();

      verify(mockComputerRepo.createComputer(any)).called(2);
    });

    test(
      'keys the computer cache by device model when no serial was reported',
      () async {
        adapter.setParsedDives([
          makeParsedDive(deviceModel: 'Descent Mk2', serialNumber: null),
          makeParsedDive(deviceModel: 'Descent Mk2', serialNumber: ''),
        ]);

        await adapter.buildBundle();

        // Both dives fall back to the same "Descent Mk2" cache key, so only
        // one computer is created rather than one per dive.
        verify(mockComputerRepo.createComputer(any)).called(1);
      },
    );

    test(
      'reuses a computer already on file instead of creating a duplicate',
      () async {
        final existing = computerFor('Descent Mk2', 'SN-1');
        when(
          mockComputerRepo.findByHardwareIdentity(
            manufacturer: 'Garmin',
            model: 'Descent Mk2',
            serialNumber: 'SN-1',
            diverId: diverId,
          ),
        ).thenAnswer((_) async => existing);

        adapter.setParsedDives([
          makeParsedDive(startTime: DateTime.utc(2026, 3, 1)),
          makeParsedDive(startTime: DateTime.utc(2026, 3, 2)),
        ]);

        await adapter.buildBundle();

        verifyNever(mockComputerRepo.createComputer(any));
      },
    );

    test('falls back to Garmin when the model is present but blank', () async {
      adapter.setParsedDives([
        makeParsedDive(deviceModel: '   ', serialNumber: null),
      ]);

      await adapter.buildBundle();

      // A blank model is the same thing as a missing one, but `?.trim()`
      // yields '' rather than null, so a plain `?? 'Garmin'` never fires and
      // the computer is registered with an empty name.
      final created =
          verify(mockComputerRepo.createComputer(captureAny)).captured.single
              as DiveComputer;
      expect(created.name, 'Garmin');
      expect(created.model, 'Garmin');
    });

    test(
      'stores a blank serial and firmware as null rather than \'\'',
      () async {
        adapter.setParsedDives([
          makeParsedDive(
            deviceModel: 'Descent Mk2',
            serialNumber: '',
            firmwareVersion: '   ',
          ),
        ]);

        await adapter.buildBundle();

        // Matches how DiveComputerRepository.findOrRegisterImportedComputer
        // stores an imported computer, so a cloud import and a file import of
        // the same device do not end up as two differently-shaped rows.
        final created =
            verify(mockComputerRepo.createComputer(captureAny)).captured.single
                as DiveComputer;
        expect(created.serialNumber, isNull);
        expect(created.firmwareVersion, isNull);
      },
    );
  });

  group('checkDuplicates()', () {
    test('flags a high-scoring match as a duplicate', () async {
      adapter.setParsedDives([makeParsedDive()]);
      final bundle = await adapter.buildBundle();

      when(
        mockImportService.detectDuplicate(
          any,
          diverId: anyNamed('diverId'),
          sourceKeysCache: anyNamed('sourceKeysCache'),
        ),
      ).thenAnswer(
        (_) async => const DuplicateResult(
          matchingDiveId: 'existing-dive',
          confidence: DuplicateConfidence.likely,
          score: 0.9,
        ),
      );
      when(
        mockDiveRepo.getComputerIdForDive('existing-dive'),
      ).thenAnswer((_) async => null);

      final updated = await adapter.checkDuplicates(bundle);

      final group = updated.groups[ImportEntityType.dives]!;
      expect(group.duplicateIndices, {0});
      expect(group.matchResults![0]!.diveId, 'existing-dive');
    });

    test('does not flag a low-scoring match', () async {
      adapter.setParsedDives([makeParsedDive()]);
      final bundle = await adapter.buildBundle();

      when(
        mockImportService.detectDuplicate(
          any,
          diverId: anyNamed('diverId'),
          sourceKeysCache: anyNamed('sourceKeysCache'),
        ),
      ).thenAnswer((_) async => DuplicateResult.noMatch());

      final updated = await adapter.checkDuplicates(bundle);

      expect(updated.groups[ImportEntityType.dives]!.duplicateIndices, isEmpty);
    });
  });

  group('performImport()', () {
    test('imports selected dives against their resolved computer', () async {
      adapter.setParsedDives([makeParsedDive()]);
      final bundle = await adapter.buildBundle();

      when(
        mockImportService.importSingleDiveAsNew(
          any,
          computerId: anyNamed('computerId'),
          diverId: anyNamed('diverId'),
          descriptorVendor: anyNamed('descriptorVendor'),
          descriptorProduct: anyNamed('descriptorProduct'),
        ),
      ).thenAnswer((_) async => 'new-dive-id');

      final result = await adapter.performImport(bundle, {
        ImportEntityType.dives: {0},
      }, {});

      expect(result.importedCounts[ImportEntityType.dives], 1);
      expect(result.importedDiveIds, ['new-dive-id']);
      verify(
        mockImportService.importSingleDiveAsNew(
          any,
          computerId: anyNamed('computerId'),
          diverId: diverId,
          descriptorVendor: 'Garmin',
          descriptorProduct: 'Descent Mk2',
        ),
      ).called(1);
      verify(mockComputerRepo.incrementDiveCount(any, by: 1)).called(1);
      verify(mockComputerRepo.updateLastDownload(any)).called(1);
    });

    test('reports progress per dive as it imports', () async {
      adapter.setParsedDives([makeParsedDive(), makeParsedDive()]);
      final bundle = await adapter.buildBundle();
      stubImportAsNew();

      final progress = <(ImportPhase, int, int)>[];
      await adapter.performImport(
        bundle,
        {
          ImportEntityType.dives: {0, 1},
        },
        {},
        onProgress: (phase, current, total) =>
            progress.add((phase, current, total)),
      );

      expect(progress, [(ImportPhase.dives, 1, 2), (ImportPhase.dives, 2, 2)]);
    });

    test('skips a dive whose duplicate action is skip', () async {
      adapter.setParsedDives([makeParsedDive()]);
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

      expect(result.skippedCount, 1);
      expect(result.importedCounts[ImportEntityType.dives], 0);
      verifyNever(
        mockImportService.importSingleDiveAsNew(
          any,
          computerId: anyNamed('computerId'),
          diverId: anyNamed('diverId'),
          descriptorVendor: anyNamed('descriptorVendor'),
          descriptorProduct: anyNamed('descriptorProduct'),
        ),
      );
    });

    test('honors cancellation between dives', () async {
      adapter.setParsedDives([makeParsedDive(), makeParsedDive()]);
      final bundle = await adapter.buildBundle();
      final cancelToken = ImportCancellationToken()..cancel();

      when(
        mockImportService.importSingleDiveAsNew(
          any,
          computerId: anyNamed('computerId'),
          diverId: anyNamed('diverId'),
          descriptorVendor: anyNamed('descriptorVendor'),
          descriptorProduct: anyNamed('descriptorProduct'),
        ),
      ).thenAnswer((_) async => 'new-dive-id');

      final result = await adapter.performImport(
        bundle,
        {
          ImportEntityType.dives: {0, 1},
        },
        {},
        cancelToken: cancelToken,
      );

      expect(result.importedCounts[ImportEntityType.dives], 0);
    });

    test(
      'imports a duplicate marked importAsNew even when unselected',
      () async {
        adapter.setParsedDives([makeParsedDive()]);
        final bundle = await adapter.buildBundle();
        stubImportAsNew();

        final result = await adapter.performImport(bundle, const {}, {
          ImportEntityType.dives: {0: DuplicateAction.importAsNew},
        });

        expect(result.importedCounts[ImportEntityType.dives], 1);
      },
    );

    test('counts an unselected skip action as skipped', () async {
      adapter.setParsedDives([makeParsedDive()]);
      final bundle = await adapter.buildBundle();

      final result = await adapter.performImport(bundle, const {}, {
        ImportEntityType.dives: {0: DuplicateAction.skip},
      });

      expect(result.skippedCount, 1);
    });

    test(
      'imports oldest first so dive numbering stays chronological',
      () async {
        adapter.setParsedDives([
          makeParsedDive(
            startTime: DateTime.utc(2026, 3, 20),
            serialNumber: 'A',
          ),
          makeParsedDive(
            startTime: DateTime.utc(2026, 3, 1),
            serialNumber: 'B',
          ),
        ]);
        final bundle = await adapter.buildBundle();

        final seen = <DateTime>[];
        when(
          mockImportService.importSingleDiveAsNew(
            any,
            computerId: anyNamed('computerId'),
            diverId: anyNamed('diverId'),
            descriptorVendor: anyNamed('descriptorVendor'),
            descriptorProduct: anyNamed('descriptorProduct'),
          ),
        ).thenAnswer((invocation) async {
          seen.add(
            (invocation.positionalArguments.first as DownloadedDive).startTime,
          );
          return 'new-dive-id';
        });

        await adapter.performImport(bundle, {
          ImportEntityType.dives: {0, 1},
        }, {});

        expect(seen, [DateTime.utc(2026, 3, 1), DateTime.utc(2026, 3, 20)]);
      },
    );
  });

  group('performImport() consolidate', () {
    setUp(() {
      adapter.setParsedDives([makeParsedDive()]);
    });

    Future<ImportBundle> bundleWithMatch() async {
      final bundle = await adapter.buildBundle();
      return ImportBundle(
        source: bundle.source,
        groups: {
          ImportEntityType.dives: EntityGroup(
            items: bundle.groups[ImportEntityType.dives]!.items,
            duplicateIndices: const {0},
            matchResults: {
              0: const DiveMatchResult(
                diveId: 'existing-dive',
                score: 0.9,
                timeDifferenceMs: 0,
              ),
            },
          ),
        },
      );
    }

    test('consolidates onto the existing dive as a second source', () async {
      final bundle = await bundleWithMatch();
      when(
        mockDiveRepo.getComputerIdForDive('existing-dive'),
      ).thenAnswer((_) async => 'other-computer');
      stubImportAsNew();

      final result = await adapter.performImport(
        bundle,
        {
          ImportEntityType.dives: {0},
        },
        {
          ImportEntityType.dives: {0: DuplicateAction.consolidate},
        },
      );

      expect(result.consolidatedCount, 1);
      verify(
        mockConsolidationService.apply(
          targetDiveId: 'existing-dive',
          secondaryDiveIds: ['new-dive-id'],
        ),
      ).called(1);
    });

    test(
      'consolidates a duplicate marked consolidate even when unselected',
      () async {
        final bundle = await bundleWithMatch();
        when(
          mockDiveRepo.getComputerIdForDive('existing-dive'),
        ).thenAnswer((_) async => 'other-computer');
        stubImportAsNew();

        final result = await adapter.performImport(bundle, const {}, {
          ImportEntityType.dives: {0: DuplicateAction.consolidate},
        });

        expect(result.consolidatedCount, 1);
      },
    );

    test('skips consolidating onto a dive from the same computer', () async {
      final bundle = await bundleWithMatch();
      // buildBundle() already created the computer, so read back the id the
      // fake repository minted for this dive's serial.
      when(
        mockDiveRepo.getComputerIdForDive('existing-dive'),
      ).thenAnswer((_) async => 'computer-SN-1');

      final result = await adapter.performImport(
        bundle,
        {
          ImportEntityType.dives: {0},
        },
        {
          ImportEntityType.dives: {0: DuplicateAction.consolidate},
        },
      );

      expect(result.consolidatedCount, 0);
      expect(result.skippedCount, 1);
      verifyNever(
        mockConsolidationService.apply(
          targetDiveId: anyNamed('targetDiveId'),
          secondaryDiveIds: anyNamed('secondaryDiveIds'),
        ),
      );
    });

    test('deletes the stranded dive when consolidation fails', () async {
      final bundle = await bundleWithMatch();
      when(
        mockDiveRepo.getComputerIdForDive('existing-dive'),
      ).thenAnswer((_) async => 'other-computer');
      stubImportAsNew();
      when(
        mockConsolidationService.apply(
          targetDiveId: anyNamed('targetDiveId'),
          secondaryDiveIds: anyNamed('secondaryDiveIds'),
        ),
      ).thenThrow(StateError('consolidation blew up'));

      final result = await adapter.performImport(
        bundle,
        {
          ImportEntityType.dives: {0},
        },
        {
          ImportEntityType.dives: {0: DuplicateAction.consolidate},
        },
      );

      expect(result.consolidatedCount, 0);
      expect(result.skippedCount, 1);
      verify(mockDiveRepo.bulkDeleteDives(['new-dive-id'])).called(1);
    });

    test('keeps the imported dive standalone when the PRE-EXISTING target '
        'holds a series this build cannot decode', () async {
      final bundle = await bundleWithMatch();
      when(
        mockDiveRepo.getComputerIdForDive('existing-dive'),
      ).thenAnswer((_) async => 'other-computer');
      stubImportAsNew();
      when(
        mockConsolidationService.apply(
          targetDiveId: anyNamed('targetDiveId'),
          secondaryDiveIds: anyNamed('secondaryDiveIds'),
        ),
      ).thenThrow(const UnreadableSeriesException(['series-1']));

      final result = await adapter.performImport(
        bundle,
        {
          ImportEntityType.dives: {0},
        },
        {
          ImportEntityType.dives: {0: DuplicateAction.consolidate},
        },
      );

      // The refusal is about the target's stored blob, not the download, so
      // the freshly imported dive is kept rather than compensated away.
      expect(result.consolidatedCount, 0);
      expect(result.skippedCount, 0);
      expect(result.importedCounts[ImportEntityType.dives], 1);
      expect(result.importedDiveIds, ['new-dive-id']);
      verifyNever(mockDiveRepo.bulkDeleteDives(any));
    });

    test('does not rethrow when the compensating delete also fails', () async {
      final bundle = await bundleWithMatch();
      when(
        mockDiveRepo.getComputerIdForDive('existing-dive'),
      ).thenAnswer((_) async => 'other-computer');
      stubImportAsNew();
      when(
        mockConsolidationService.apply(
          targetDiveId: anyNamed('targetDiveId'),
          secondaryDiveIds: anyNamed('secondaryDiveIds'),
        ),
      ).thenThrow(StateError('consolidation blew up'));
      when(mockDiveRepo.bulkDeleteDives(any)).thenThrow(StateError('nope'));

      final result = await adapter.performImport(
        bundle,
        {
          ImportEntityType.dives: {0},
        },
        {
          ImportEntityType.dives: {0: DuplicateAction.consolidate},
        },
      );

      expect(result.skippedCount, 1);
    });

    test('replaces the source on an existing dive', () async {
      final bundle = await bundleWithMatch();

      final result = await adapter.performImport(
        bundle,
        {
          ImportEntityType.dives: {0},
        },
        {
          ImportEntityType.dives: {0: DuplicateAction.replaceSource},
        },
      );

      expect(result.updatedCount, 1);
      verify(
        mockImportService.resolveConflict(
          any,
          ConflictResolution.replaceSource,
          any,
          diverId: diverId,
          descriptorVendor: 'Garmin',
          descriptorProduct: 'Descent Mk2',
        ),
      ).called(1);
    });

    test('replaces the source of a duplicate marked replaceSource even when '
        'unselected', () async {
      final bundle = await bundleWithMatch();

      final result = await adapter.performImport(bundle, const {}, {
        ImportEntityType.dives: {0: DuplicateAction.replaceSource},
      });

      expect(result.updatedCount, 1);
    });
  });

  group('adapter metadata', () {
    test('declares the Garmin cloud source type and duplicate actions', () {
      expect(adapter.sourceType, ImportSourceType.garminCloud);
      expect(adapter.displayName, 'Garmin Connect');
      expect(
        adapter.duplicateActionsFor(ImportEntityType.dives),
        adapter.supportedDuplicateActions,
      );
      expect(
        adapter.supportedDuplicateActions,
        contains(DuplicateAction.consolidate),
      );
    });

    test('exposes a sign-in step followed by a fetch step', () {
      final steps = adapter.acquisitionSteps;

      expect(steps.map((s) => s.label), ['Sign In', 'Fetch']);
      // Sign In auto-advances the instant a session is established, but
      // Fetch does not: it lets the diver choose when to move on (via Load
      // More / Next) instead of auto-advancing off the newest page alone.
      expect(steps[0].autoAdvance, isTrue);
      expect(steps[1].autoAdvance, isFalse);
    });

    test('setClient exposes the authenticated client to the fetch step', () {
      final client = GarminConnectClient();
      adapter.setClient(client);

      expect(adapter.client, same(client));
    });

    test('resetState clears the client and the fetched dives', () async {
      adapter.setClient(GarminConnectClient());
      adapter.setParsedDives([makeParsedDive()]);

      adapter.resetState();

      expect(adapter.client, isNull);
      final bundle = await adapter.buildBundle();
      expect(bundle.groups[ImportEntityType.dives]!.items, isEmpty);
    });
  });
}
