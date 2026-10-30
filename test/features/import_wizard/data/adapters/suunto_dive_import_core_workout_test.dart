import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_dive_parser.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_journal.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/domain/services/unreadable_series_exception.dart';
import 'package:submersion/features/import_wizard/data/adapters/suunto_buddy_writer.dart';
import 'package:submersion/features/import_wizard/data/adapters/suunto_cloud_adapter.dart';
import 'package:submersion/features/import_wizard/data/adapters/suunto_journal_writer.dart';
import 'package:submersion/core/domain/visibility/visibility_scale.dart';
import 'package:submersion/features/import_wizard/data/adapters/suunto_route_writer.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/models/unified_import_result.dart';

import 'suunto_cloud_adapter_test.mocks.dart';

/// Records which dive each workout's buddies were brought onto, so every
/// write path in the shared Suunto import core can be checked without a
/// database (issue #3266).
class _RecordingBuddyWriter implements SuuntoBuddyWriter {
  final attached = <(String, SuuntoParsedDive, String)>[];

  @override
  Future<void> attach(
    String diveId,
    SuuntoParsedDive parsed,
    String diverId,
  ) async {
    attached.add((diveId, parsed, diverId));
  }
}

/// Records which dive each workout's journal was written onto (issue #3491).
class _RecordingJournalWriter implements SuuntoJournalWriter {
  final attached = <(String, SuuntoParsedDive, String)>[];

  @override
  Future<void> attach(
    String diveId,
    SuuntoParsedDive parsed,
    String diverId, {
    required VisibilityScale scale,
  }) async {
    attached.add((diveId, parsed, diverId));
  }
}

class _NoRouteWriter implements SuuntoRouteWriter {
  @override
  Future<String?> attach(String diveId, SuuntoParsedDive parsed) async => null;

  @override
  Future<String?> attachIfMissing(
    String diveId,
    SuuntoParsedDive parsed,
  ) async => null;
}

SuuntoParsedDive _parsedWithBuddies() => SuuntoParsedDive(
  dive: DownloadedDive(
    startTime: DateTime.utc(2026, 3, 15, 10, 32),
    durationSeconds: 30 * 60,
    maxDepth: 18.5,
    profile: const [],
  ),
  deviceName: 'Suunto Nautic',
  serialNumber: 'SN-1',
  journal: const SuuntoJournal(buddies: ['Buddy 1', 'Buddy 2']),
);

void main() {
  late MockDiveImportService mockImportService;
  late MockDiveComputerRepository mockComputerRepo;
  late MockDiveRepository mockDiveRepo;
  late MockDiveConsolidationService mockConsolidationService;
  late _RecordingBuddyWriter recorder;
  late _RecordingJournalWriter journalRecorder;
  late SuuntoCloudAdapter adapter;
  late SuuntoParsedDive parsed;

  const diverId = 'diver-1';

  SuuntoCloudAdapter buildAdapter(SuuntoBuddyWriter writer) =>
      SuuntoCloudAdapter(
        importService: mockImportService,
        computerRepository: mockComputerRepo,
        diveRepository: mockDiveRepo,
        consolidationService: mockConsolidationService,
        diverId: diverId,
        routeWriter: _NoRouteWriter(),
        buddyWriter: writer,
        journalWriter: journalRecorder,
      );

  setUp(() {
    mockImportService = MockDiveImportService();
    mockComputerRepo = MockDiveComputerRepository();
    mockDiveRepo = MockDiveRepository();
    mockConsolidationService = MockDiveConsolidationService();
    recorder = _RecordingBuddyWriter();
    journalRecorder = _RecordingJournalWriter();
    adapter = buildAdapter(recorder);
    parsed = _parsedWithBuddies();

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
      return DiveComputer(
        id: 'computer-${computer.serialNumber ?? computer.name}',
        name: computer.name,
        diverId: diverId,
        manufacturer: 'Suunto',
        model: computer.name,
        serialNumber: computer.serialNumber,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
    });
    when(
      mockImportService.importSingleDiveAsNew(
        any,
        computerId: anyNamed('computerId'),
        diverId: anyNamed('diverId'),
        descriptorVendor: anyNamed('descriptorVendor'),
        descriptorProduct: anyNamed('descriptorProduct'),
      ),
    ).thenAnswer((_) async => 'new-dive-id');
  });

  Future<ImportBundle> plainBundle(SuuntoCloudAdapter a) async {
    a.setParsedDives([parsed]);
    return a.buildBundle();
  }

  Future<ImportBundle> bundleWithMatch() async {
    final bundle = await plainBundle(adapter);
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

  Future<UnifiedImportResult> importWith(
    ImportBundle bundle,
    DuplicateAction? action,
  ) => adapter.performImport(
    bundle,
    {
      ImportEntityType.dives: {0},
    },
    {
      if (action != null) ImportEntityType.dives: {0: action},
    },
  );

  test('a new dive gets the workout buddies and journal', () async {
    final result = await importWith(await plainBundle(adapter), null);

    expect(result.updatedExistingDiveIds, isEmpty);
    expect(recorder.attached, [('new-dive-id', parsed, diverId)]);
    expect(journalRecorder.attached, [('new-dive-id', parsed, diverId)]);
  });

  test('replace source brings them onto the matched dive', () async {
    final result = await importWith(
      await bundleWithMatch(),
      DuplicateAction.replaceSource,
    );

    expect(result.updatedExistingDiveIds, ['existing-dive']);
    expect(recorder.attached, [('existing-dive', parsed, diverId)]);
    expect(journalRecorder.attached, [('existing-dive', parsed, diverId)]);
  });

  test('a folded consolidation brings them onto the target', () async {
    when(
      mockDiveRepo.getComputerIdForDive('existing-dive'),
    ).thenAnswer((_) async => 'other-computer');

    final result = await importWith(
      await bundleWithMatch(),
      DuplicateAction.consolidate,
    );

    expect(result.updatedExistingDiveIds, ['existing-dive']);
    expect(recorder.attached, [('existing-dive', parsed, diverId)]);
    expect(journalRecorder.attached, [('existing-dive', parsed, diverId)]);
  });

  test('a dive kept standalone gets them on itself', () async {
    when(
      mockDiveRepo.getComputerIdForDive('existing-dive'),
    ).thenAnswer((_) async => 'other-computer');
    when(
      mockConsolidationService.apply(
        targetDiveId: anyNamed('targetDiveId'),
        secondaryDiveIds: anyNamed('secondaryDiveIds'),
      ),
    ).thenThrow(const UnreadableSeriesException(['series-1']));

    await importWith(await bundleWithMatch(), DuplicateAction.consolidate);

    expect(recorder.attached, [('new-dive-id', parsed, diverId)]);
    expect(journalRecorder.attached, [('new-dive-id', parsed, diverId)]);
  });

  test('a skipped duplicate is left untouched', () async {
    await importWith(await bundleWithMatch(), DuplicateAction.skip);

    expect(recorder.attached, isEmpty);
    expect(journalRecorder.attached, isEmpty);
  });

  test('a same-computer consolidation is left untouched', () async {
    when(
      mockDiveRepo.getComputerIdForDive('existing-dive'),
    ).thenAnswer((_) async => 'computer-SN-1');

    await importWith(await bundleWithMatch(), DuplicateAction.consolidate);

    expect(recorder.attached, isEmpty);
    expect(journalRecorder.attached, isEmpty);
  });
}
