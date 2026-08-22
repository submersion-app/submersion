import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_dive_parser.dart';
import 'package:submersion/features/dive_computer/data/services/dive_import_service.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart'
    hide DiveMatchResult;
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/dive_consolidation_service.dart';
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

  group('defaultTagName', () {
    test('is based on today\'s date', () {
      final now = DateTime.now();
      final expectedDate =
          '${now.year}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
      expect(adapter.defaultTagName, 'Suunto Cloud Import $expectedDate');
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
  });
}
