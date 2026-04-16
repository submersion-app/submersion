import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/features/dive_computer/data/services/dive_import_service.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart'
    hide DiveMatchResult;
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/import_wizard/data/adapters/dive_computer_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';

@GenerateMocks([DiveImportService, DiveComputerRepository, DiveRepository])
import 'dive_computer_adapter_reimport_test.mocks.dart';

void main() {
  late MockDiveImportService importService;
  late MockDiveComputerRepository computerRepo;
  late MockDiveRepository diveRepo;

  setUp(() {
    importService = MockDiveImportService();
    computerRepo = MockDiveComputerRepository();
    diveRepo = MockDiveRepository();
  });

  group('forceFullDownload field', () {
    test('defaults to false when not specified', () {
      final adapter = DiveComputerAdapter(
        importService: importService,
        computerRepository: computerRepo,
        diveRepository: diveRepo,
        diverId: 'diver-1',
      );
      expect(adapter.forceFullDownload, isFalse);
    });

    test('reflects constructor-provided true', () {
      final adapter = DiveComputerAdapter(
        importService: importService,
        computerRepository: computerRepo,
        diveRepository: diveRepo,
        diverId: 'diver-1',
        forceFullDownload: true,
      );
      expect(adapter.forceFullDownload, isTrue);
    });

    test('reflects constructor-provided false', () {
      final adapter = DiveComputerAdapter(
        importService: importService,
        computerRepository: computerRepo,
        diveRepository: diveRepo,
        diverId: 'diver-1',
        forceFullDownload: false,
      );
      expect(adapter.forceFullDownload, isFalse);
    });
  });

  group('performImport replaceSource', () {
    const diverId = 'diver-1';
    const computerId = 'comp-1';
    const existingDiveId = 'existing-dive-42';

    final testComputer = DiveComputer.create(
      id: computerId,
      name: 'Test Computer',
      diverId: diverId,
      manufacturer: 'TestMfg',
      model: 'TestModel',
    );

    final testDive = DownloadedDive(
      startTime: DateTime(2026, 3, 15, 10, 0),
      durationSeconds: 3000,
      maxDepth: 25.0,
      profile: const [],
    );

    test(
      'calls resolveConflict with replaceSource and returns updatedCount',
      () async {
        final adapter = DiveComputerAdapter(
          importService: importService,
          computerRepository: computerRepo,
          diveRepository: diveRepo,
          diverId: diverId,
        );

        // Provide the computer and downloaded dives to the adapter.
        adapter.setComputer(testComputer);
        adapter.setDownloadedDives([testDive]);

        // Build a bundle with a duplicate match at index 0.
        const matchResult = DiveMatchResult(
          diveId: existingDiveId,
          score: 0.92,
          timeDifferenceMs: 5000,
        );

        const bundle = ImportBundle(
          source: ImportSourceInfo(
            type: ImportSourceType.diveComputer,
            displayName: 'Test Computer',
          ),
          groups: {
            ImportEntityType.dives: EntityGroup(
              items: [
                EntityItem(
                  title: 'Mar 15, 2026',
                  subtitle: '25.0 m max - 50 min',
                ),
              ],
              duplicateIndices: {0},
              matchResults: {0: matchResult},
            ),
          },
        );

        // Stub resolveConflict to return the existing dive ID.
        when(
          importService.resolveConflict(
            any,
            any,
            any,
            diverId: anyNamed('diverId'),
            descriptorVendor: anyNamed('descriptorVendor'),
            descriptorProduct: anyNamed('descriptorProduct'),
            descriptorModel: anyNamed('descriptorModel'),
            libdivecomputerVersion: anyNamed('libdivecomputerVersion'),
          ),
        ).thenAnswer((_) async => existingDiveId);

        // Stub the computer-update methods that run after import.
        when(computerRepo.updateLastDownload(any)).thenAnswer((_) async {});
        when(
          computerRepo.updateLastFingerprint(any, any),
        ).thenAnswer((_) async {});

        // All dives are in selections; index 0 has replaceSource action.
        final result = await adapter.performImport(
          bundle,
          {
            ImportEntityType.dives: {0},
          },
          {
            ImportEntityType.dives: {0: DuplicateAction.replaceSource},
          },
        );

        // Verify resolveConflict was called with the right resolution.
        final captured = verify(
          importService.resolveConflict(
            captureAny,
            captureAny,
            captureAny,
            diverId: captureAnyNamed('diverId'),
            descriptorVendor: anyNamed('descriptorVendor'),
            descriptorProduct: anyNamed('descriptorProduct'),
            descriptorModel: anyNamed('descriptorModel'),
            libdivecomputerVersion: anyNamed('libdivecomputerVersion'),
          ),
        ).captured;

        // captured: [ImportConflict, ConflictResolution, computerId, diverId]
        final conflict = captured[0] as ImportConflict;
        final resolution = captured[1] as ConflictResolution;
        final capturedComputerId = captured[2] as String;

        expect(conflict.existingDiveId, existingDiveId);
        expect(conflict.downloaded, testDive);
        expect(resolution, ConflictResolution.replaceSource);
        expect(capturedComputerId, computerId);

        // Verify the result counts.
        expect(result.updatedCount, 1);
        expect(result.importedCounts[ImportEntityType.dives], 0);
        expect(result.consolidatedCount, 0);
        expect(result.skippedCount, 0);
      },
    );
  });
}
