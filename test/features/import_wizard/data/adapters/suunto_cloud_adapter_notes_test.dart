import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_dive_parser.dart';
import 'package:submersion/features/dive_computer/data/services/dive_import_service.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart'
    hide DiveMatchResult;
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/dive_consolidation_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/import_wizard/data/adapters/suunto_cloud_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';

@GenerateNiceMocks([
  MockSpec<DiveImportService>(),
  MockSpec<DiveComputerRepository>(),
  MockSpec<DiveRepository>(),
  MockSpec<DiveConsolidationService>(),
])
import 'suunto_cloud_adapter_notes_test.mocks.dart';

/// Issue #2410: the notes the diver wrote in the Suunto app fill a dive's
/// notes only where it has none.
void main() {
  late MockDiveImportService mockImportService;
  late MockDiveComputerRepository mockComputerRepo;
  late MockDiveRepository mockDiveRepo;
  late MockDiveConsolidationService mockConsolidationService;
  late SuuntoCloudAdapter adapter;

  const diverId = 'diver-1';

  SuuntoParsedDive parsed({String? notes}) => SuuntoParsedDive(
    dive: DownloadedDive(
      startTime: DateTime.utc(2026, 3, 15, 10, 32),
      durationSeconds: 30 * 60,
      maxDepth: 18.5,
      profile: const [],
    ),
    deviceName: 'Suunto Ocean',
    serialNumber: 'SN-1',
    notes: notes,
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

    when(mockComputerRepo.createComputer(any)).thenAnswer(
      (_) async => DiveComputer(
        id: 'computer-sn1',
        name: 'Suunto Ocean',
        diverId: diverId,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    );
    when(
      mockImportService.importSingleDiveAsNew(
        any,
        computerId: anyNamed('computerId'),
        diverId: anyNamed('diverId'),
        descriptorVendor: anyNamed('descriptorVendor'),
        descriptorProduct: anyNamed('descriptorProduct'),
        retainSourceDiveNumber: anyNamed('retainSourceDiveNumber'),
      ),
    ).thenAnswer((_) async => 'new-dive-id');
    when(mockDiveRepo.fillNotesIfEmpty(any, any)).thenAnswer((_) async => true);
  });

  Future<ImportBundle> bundleMatching(String existingDiveId) async {
    final bundle = await adapter.buildBundle();
    return ImportBundle(
      source: bundle.source,
      groups: {
        ImportEntityType.dives: EntityGroup(
          items: bundle.groups[ImportEntityType.dives]!.items,
          duplicateIndices: const {0},
          matchResults: {
            0: DiveMatchResult(
              diveId: existingDiveId,
              score: 0.9,
              timeDifferenceMs: 0,
            ),
          },
        ),
      },
    );
  }

  Future<void> importWith(DuplicateAction? action) async {
    final bundle = action == null
        ? await adapter.buildBundle()
        : await bundleMatching('existing-dive');
    await adapter.performImport(
      bundle,
      {
        ImportEntityType.dives: {0},
      },
      {
        if (action != null) ImportEntityType.dives: {0: action},
      },
    );
  }

  test('fill the notes of a dive imported as new', () async {
    adapter.setParsedDives([parsed(notes: 'Turtle at the mooring')]);

    await importWith(null);

    verify(
      mockDiveRepo.fillNotesIfEmpty('new-dive-id', 'Turtle at the mooring'),
    ).called(1);
  });

  test('are not written when the workout has none', () async {
    adapter.setParsedDives([parsed()]);

    await importWith(null);

    verifyNever(mockDiveRepo.fillNotesIfEmpty(any, any));
  });

  test('fill the existing dive a download is consolidated onto', () async {
    adapter.setParsedDives([parsed(notes: 'Turtle at the mooring')]);
    when(
      mockDiveRepo.getComputerIdForDive('existing-dive'),
    ).thenAnswer((_) async => 'other-computer');

    await importWith(DuplicateAction.consolidate);

    verify(
      mockDiveRepo.fillNotesIfEmpty('existing-dive', 'Turtle at the mooring'),
    ).called(1);
  });

  test('fill the existing dive whose source is replaced', () async {
    adapter.setParsedDives([parsed(notes: 'Turtle at the mooring')]);

    await importWith(DuplicateAction.replaceSource);

    verify(
      mockDiveRepo.fillNotesIfEmpty('existing-dive', 'Turtle at the mooring'),
    ).called(1);
  });

  test('are not written onto a dive the diver chose to skip', () async {
    adapter.setParsedDives([parsed(notes: 'Turtle at the mooring')]);

    await importWith(DuplicateAction.skip);

    verifyNever(mockDiveRepo.fillNotesIfEmpty(any, any));
  });

  test('a failed notes write does not fail the import', () async {
    adapter.setParsedDives([parsed(notes: 'Turtle at the mooring')]);
    when(
      mockDiveRepo.fillNotesIfEmpty(any, any),
    ).thenThrow(StateError('database is locked'));
    final bundle = await adapter.buildBundle();

    final result = await adapter.performImport(bundle, {
      ImportEntityType.dives: {0},
    }, {});

    expect(result.importedCounts[ImportEntityType.dives], 1);
  });
}
