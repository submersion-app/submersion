import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_cloud_client.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_dive_parser.dart';
import 'package:submersion/features/dive_computer/data/services/dive_import_service.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart'
    hide DiveMatchResult;
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/dive_consolidation_service.dart';
import 'package:submersion/features/dive_log/domain/services/unreadable_series_exception.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/import_wizard/data/adapters/suunto_cloud_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/models/import_cancellation_token.dart';

@GenerateNiceMocks([
  MockSpec<DiveImportService>(),
  MockSpec<DiveComputerRepository>(),
  MockSpec<DiveRepository>(),
  MockSpec<DiveConsolidationService>(),
])
import 'suunto_cloud_adapter_test.mocks.dart';

SuuntoParsedDive makeParsedDive({
  DateTime? startTime,
  int durationSeconds = 30 * 60,
  double maxDepth = 18.5,
  String? deviceName = 'Suunto Ocean',
  String? serialNumber = 'SN-1',
}) {
  return SuuntoParsedDive(
    dive: DownloadedDive(
      startTime: startTime ?? DateTime.utc(2026, 3, 15, 10, 32),
      durationSeconds: durationSeconds,
      maxDepth: maxDepth,
      profile: const [],
    ),
    deviceName: deviceName,
    serialNumber: serialNumber,
  );
}

void main() {
  late MockDiveImportService mockImportService;
  late MockDiveComputerRepository mockComputerRepo;
  late MockDiveRepository mockDiveRepo;
  late MockDiveConsolidationService mockConsolidationService;
  late SuuntoCloudAdapter adapter;

  const diverId = 'diver-1';

  DiveComputer computerFor(String name, String serial) => DiveComputer(
    id: 'computer-$serial',
    name: name,
    diverId: diverId,
    manufacturer: 'Suunto',
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

    adapter = SuuntoCloudAdapter(
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
          'Suunto Cloud Import ${isoDate(before)}',
          'Suunto Cloud Import ${isoDate(after)}',
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
        makeParsedDive(deviceName: 'Suunto Ocean', serialNumber: 'SN-1'),
        makeParsedDive(deviceName: 'Suunto EON Steel', serialNumber: 'SN-2'),
      ]);

      await adapter.buildBundle();

      verify(mockComputerRepo.createComputer(any)).called(2);
    });
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
          descriptorVendor: 'Suunto',
          descriptorProduct: 'Suunto Ocean',
        ),
      ).called(1);
      verify(mockComputerRepo.incrementDiveCount(any, by: 1)).called(1);
      verify(mockComputerRepo.updateLastDownload(any)).called(1);
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
          descriptorVendor: 'Suunto',
          descriptorProduct: 'Suunto Ocean',
        ),
      ).called(1);
    });
  });

  group('adapter metadata', () {
    test('declares the Suunto cloud source type and duplicate actions', () {
      expect(adapter.sourceType, ImportSourceType.suuntoCloud);
      expect(adapter.displayName, 'Suunto Cloud');
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
      expect(steps.every((s) => s.autoAdvance), isTrue);
    });

    test('setClient exposes the authenticated client to the fetch step', () {
      final client = SuuntoCloudClient();
      adapter.setClient(client);

      expect(adapter.client, same(client));
    });

    test('resetState clears the client and the fetched dives', () async {
      adapter.setClient(SuuntoCloudClient());
      adapter.setParsedDives([makeParsedDive()]);

      adapter.resetState();

      expect(adapter.client, isNull);
      final bundle = await adapter.buildBundle();
      expect(bundle.groups[ImportEntityType.dives]!.items, isEmpty);
    });
  });
}
