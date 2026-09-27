import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/core/constants/enums.dart' show WeightType;
import 'package:submersion/core/services/garmin_connect/garmin_dive_mapper.dart';
import 'package:submersion/features/dive_computer/data/services/dive_import_service.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart'
    hide DiveMatchResult;
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/dive_consolidation_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/dive_log/domain/services/unreadable_series_exception.dart';
import 'package:submersion/features/import_wizard/data/adapters/garmin_cloud_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/models/import_notice.dart';

@GenerateNiceMocks([
  MockSpec<DiveImportService>(),
  MockSpec<DiveComputerRepository>(),
  MockSpec<DiveRepository>(),
  MockSpec<DiveConsolidationService>(),
])
import 'garmin_cloud_adapter_connect_extras_test.mocks.dart';

/// Issue #2410: what the diver adds in Garmin Connect after the dive (notes,
/// weight), and dives Connect has no FIT file for.
void main() {
  late MockDiveImportService mockImportService;
  late MockDiveComputerRepository mockComputerRepo;
  late MockDiveRepository mockDiveRepo;
  late MockDiveConsolidationService mockConsolidationService;
  late GarminCloudAdapter adapter;

  const diverId = 'diver-1';

  DiveComputer computer(String id, String model) => DiveComputer(
    id: id,
    name: model,
    diverId: diverId,
    manufacturer: 'Garmin',
    model: model,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  GarminParsedDive parsed({
    String? notes,
    double? weightKg,
    bool profileMissing = false,
  }) => GarminParsedDive(
    dive: DownloadedDive(
      startTime: DateTime.utc(2026, 3, 15, 10, 32),
      durationSeconds: 30 * 60,
      maxDepth: 18.5,
      profile: const [],
    ),
    deviceModel: profileMissing ? 'Garmin' : 'Descent Mk2',
    serialNumber: profileMissing ? null : 'SN-1',
    notes: notes,
    weightKg: weightKg,
    profileMissing: profileMissing,
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
      mockComputerRepo.createComputer(any),
    ).thenAnswer((_) async => computer('computer-sn1', 'Descent Mk2'));
    when(
      mockComputerRepo.findOrRegisterImportedComputer(
        model: anyNamed('model'),
        manufacturer: anyNamed('manufacturer'),
        serialNumber: anyNamed('serialNumber'),
        firmwareVersion: anyNamed('firmwareVersion'),
        diverId: anyNamed('diverId'),
      ),
    ).thenAnswer((_) async => computer('computer-connect', 'Connect'));
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
    when(mockDiveRepo.addWeightIfNone(any, any)).thenAnswer((_) async => true);
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

  group('Connect notes', () {
    test('fill the notes of a dive imported as new', () async {
      adapter.setParsedDives([parsed(notes: 'Drift along the wall')]);
      final bundle = await adapter.buildBundle();

      await adapter.performImport(bundle, {
        ImportEntityType.dives: {0},
      }, {});

      verify(
        mockDiveRepo.fillNotesIfEmpty('new-dive-id', 'Drift along the wall'),
      ).called(1);
    });

    test('are not written when Connect has none', () async {
      adapter.setParsedDives([parsed()]);
      final bundle = await adapter.buildBundle();

      await adapter.performImport(bundle, {
        ImportEntityType.dives: {0},
      }, {});

      verifyNever(mockDiveRepo.fillNotesIfEmpty(any, any));
    });

    test('fill the existing dive a download is consolidated onto', () async {
      adapter.setParsedDives([parsed(notes: 'Drift along the wall')]);
      final bundle = await bundleMatching('existing-dive');
      when(
        mockDiveRepo.getComputerIdForDive('existing-dive'),
      ).thenAnswer((_) async => 'other-computer');

      await adapter.performImport(
        bundle,
        {
          ImportEntityType.dives: {0},
        },
        {
          ImportEntityType.dives: {0: DuplicateAction.consolidate},
        },
      );

      // The fold keeps the target's own header, so the notes have to land
      // on the target rather than on the download that is folded away.
      verify(
        mockDiveRepo.fillNotesIfEmpty('existing-dive', 'Drift along the wall'),
      ).called(1);
      verifyNever(mockDiveRepo.fillNotesIfEmpty('new-dive-id', any));
    });

    test(
      'fill the download kept standalone when the fold is refused',
      () async {
        adapter.setParsedDives([parsed(notes: 'Drift along the wall')]);
        final bundle = await bundleMatching('existing-dive');
        when(
          mockDiveRepo.getComputerIdForDive('existing-dive'),
        ).thenAnswer((_) async => 'other-computer');
        when(
          mockConsolidationService.apply(
            targetDiveId: anyNamed('targetDiveId'),
            secondaryDiveIds: anyNamed('secondaryDiveIds'),
          ),
        ).thenThrow(const UnreadableSeriesException(['series-1']));

        await adapter.performImport(
          bundle,
          {
            ImportEntityType.dives: {0},
          },
          {
            ImportEntityType.dives: {0: DuplicateAction.consolidate},
          },
        );

        // The download survives as its own dive, so the notes belong on it.
        verify(
          mockDiveRepo.fillNotesIfEmpty('new-dive-id', 'Drift along the wall'),
        ).called(1);
        verifyNever(mockDiveRepo.fillNotesIfEmpty('existing-dive', any));
      },
    );

    test('fill the existing dive whose source is replaced', () async {
      adapter.setParsedDives([parsed(notes: 'Drift along the wall')]);
      final bundle = await bundleMatching('existing-dive');

      await adapter.performImport(
        bundle,
        {
          ImportEntityType.dives: {0},
        },
        {
          ImportEntityType.dives: {0: DuplicateAction.replaceSource},
        },
      );

      verify(
        mockDiveRepo.fillNotesIfEmpty('existing-dive', 'Drift along the wall'),
      ).called(1);
    });

    test('are not written onto a dive the diver chose to skip', () async {
      adapter.setParsedDives([parsed(notes: 'Drift along the wall')]);
      final bundle = await bundleMatching('existing-dive');

      await adapter.performImport(
        bundle,
        {
          ImportEntityType.dives: {0},
        },
        {
          ImportEntityType.dives: {0: DuplicateAction.skip},
        },
      );

      verifyNever(mockDiveRepo.fillNotesIfEmpty(any, any));
    });

    test('a failed notes write does not fail the import', () async {
      adapter.setParsedDives([
        parsed(notes: 'Drift along the wall'),
        parsed(notes: 'Second dive'),
      ]);
      final bundle = await adapter.buildBundle();
      when(
        mockDiveRepo.fillNotesIfEmpty(any, any),
      ).thenThrow(StateError('database is locked'));

      final result = await adapter.performImport(bundle, {
        ImportEntityType.dives: {0, 1},
      }, {});

      expect(result.importedCounts[ImportEntityType.dives], 2);
    });
  });

  group('Connect weight', () {
    test('is added as a belt weight to a dive imported as new', () async {
      adapter.setParsedDives([parsed(weightKg: 4.5)]);
      final bundle = await adapter.buildBundle();

      await adapter.performImport(bundle, {
        ImportEntityType.dives: {0},
      }, {});

      final weight =
          verify(
                mockDiveRepo.addWeightIfNone('new-dive-id', captureAny),
              ).captured.single
              as DiveWeight;
      expect(weight.amountKg, 4.5);
      expect(weight.weightType, WeightType.belt);
    });

    test('is not added when Connect has none', () async {
      adapter.setParsedDives([parsed()]);
      final bundle = await adapter.buildBundle();

      await adapter.performImport(bundle, {
        ImportEntityType.dives: {0},
      }, {});

      verifyNever(mockDiveRepo.addWeightIfNone(any, any));
    });
  });

  group('dives with no FIT file', () {
    test('share one Garmin Connect computer instead of a new one per '
        'import', () async {
      adapter.setParsedDives([parsed(profileMissing: true)]);
      final bundle = await adapter.buildBundle();

      await adapter.performImport(bundle, {
        ImportEntityType.dives: {0},
      }, {});

      verify(
        mockComputerRepo.findOrRegisterImportedComputer(
          model: 'Connect',
          manufacturer: 'Garmin',
          diverId: diverId,
        ),
      ).called(1);
      verifyNever(mockComputerRepo.createComputer(any));
      verify(
        mockImportService.importSingleDiveAsNew(
          any,
          computerId: 'computer-connect',
          diverId: diverId,
          descriptorVendor: 'Garmin',
          descriptorProduct: anyNamed('descriptorProduct'),
          retainSourceDiveNumber: anyNamed('retainSourceDiveNumber'),
        ),
      ).called(1);
    });

    test('raise the profile notice for each one imported', () async {
      adapter.setParsedDives([
        parsed(profileMissing: true),
        parsed(),
        parsed(profileMissing: true),
      ]);
      final bundle = await adapter.buildBundle();

      final result = await adapter.performImport(bundle, {
        ImportEntityType.dives: {0, 1, 2},
      }, {});

      final notice = result.notices.singleWhere(
        (n) => n.kind == ImportNoticeKind.profileUnreadable,
      );
      expect(notice.count, 2);
    });

    test('raise no profile notice when every dive had a FIT file', () async {
      adapter.setParsedDives([parsed()]);
      final bundle = await adapter.buildBundle();

      final result = await adapter.performImport(bundle, {
        ImportEntityType.dives: {0},
      }, {});

      expect(
        result.notices.where(
          (n) => n.kind == ImportNoticeKind.profileUnreadable,
        ),
        isEmpty,
      );
    });

    test('raise no profile notice for one the diver skipped', () async {
      adapter.setParsedDives([parsed(profileMissing: true)]);
      final bundle = await bundleMatching('existing-dive');

      final result = await adapter.performImport(
        bundle,
        {
          ImportEntityType.dives: {0},
        },
        {
          ImportEntityType.dives: {0: DuplicateAction.skip},
        },
      );

      expect(result.notices, isEmpty);
    });
  });
}
