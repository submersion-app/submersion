import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide DiveComputer;
import 'package:submersion/features/dive_computer/data/services/dive_import_service.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart'
    hide DiveMatchResult;
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/dive_consolidation_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/import_wizard/data/adapters/dive_computer_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';

import '../../../../helpers/test_database.dart';

/// End-to-end (real DB, no mocks) coverage of Task 8 Step 7: the
/// [DiveComputerAdapter]'s consolidate path must produce a target dive
/// that carries the secondary download's tanks and events -- full
/// fidelity, not the old hand-rolled copy that only carried a
/// [DiveDataSourcesCompanion] and bare profile points.
void main() {
  late AppDatabase db;
  late DiveRepository diveRepository;
  late DiveComputerRepository computerRepository;
  late DiveConsolidationService consolidationService;

  const diverId = 'diver-1';

  setUp(() async {
    db = await setUpTestDatabase();
    diveRepository = DiveRepository();
    computerRepository = DiveComputerRepository();
    consolidationService = DiveConsolidationService(diveRepository);

    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion(
            id: const Value(diverId),
            name: const Value('Test Diver'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('_consolidateDive folds the downloaded dive\'s tanks and events into '
      'the target dive (full fidelity)', () async {
    // 1. The target dive already exists, downloaded from a primary
    // computer, with one air tank.
    await computerRepository.createComputer(
      DiveComputer.create(
        id: 'primary-computer',
        name: 'Primary Computer',
        diverId: diverId,
      ),
    );

    final entryTime = DateTime.utc(2026, 7, 1, 9);
    await diveRepository.createDive(
      domain.Dive(
        id: 'target-dive',
        dateTime: entryTime,
        entryTime: entryTime,
        runtime: const Duration(minutes: 40),
        maxDepth: 25.0,
        diverId: diverId,
        tanks: [
          const domain.DiveTank(
            id: 'target-tank-air',
            gasMix: domain.GasMix(o2: 21, he: 0),
            startPressure: 200,
            endPressure: 100,
            order: 0,
          ),
        ],
      ),
    );
    await (db.update(db.dives)..where((t) => t.id.equals('target-dive'))).write(
      const DivesCompanion(computerId: Value('primary-computer')),
    );

    // 2. Download a second computer's data for the SAME physical dive
    // (overlapping entry time), carrying a distinct-gas tank (so it is
    // NOT deduped against the target's air tank) and a gas-change event.
    final secondaryComputer = await computerRepository.createComputer(
      DiveComputer.create(
        id: 'secondary-computer',
        name: 'Secondary Computer',
        diverId: diverId,
      ),
    );

    final downloadedDive = DownloadedDive(
      startTime: entryTime,
      durationSeconds: 2400,
      maxDepth: 24.5,
      profile: [
        const ProfileSample(timeSeconds: 0, depth: 0.0),
        const ProfileSample(timeSeconds: 60, depth: 24.5),
      ],
      tanks: const [
        DownloadedTank(
          index: 0,
          o2Percent: 32.0,
          startPressure: 200,
          endPressure: 120,
        ),
      ],
      events: const [DownloadedEvent(timeSeconds: 30, type: 'gaschange')],
    );

    final importService = DiveImportService(
      repository: computerRepository,
      diveRepository: diveRepository,
    );

    final adapter = DiveComputerAdapter(
      importService: importService,
      computerRepository: computerRepository,
      diveRepository: diveRepository,
      consolidationService: consolidationService,
      diverId: diverId,
      knownComputer: secondaryComputer,
    );
    adapter.setDownloadedDives([downloadedDive]);

    // 3. Build a bundle whose only item is flagged as a duplicate of
    // target-dive, then resolve it with DuplicateAction.consolidate --
    // mirroring how the wizard's review step wires a chosen action back
    // into performImport.
    final rawBundle = await adapter.buildBundle();
    final bundleWithDupes = ImportBundle(
      source: rawBundle.source,
      groups: {
        ImportEntityType.dives: EntityGroup(
          items: rawBundle.groups[ImportEntityType.dives]!.items,
          duplicateIndices: {0},
          matchResults: const {
            0: DiveMatchResult(
              diveId: 'target-dive',
              score: 0.9,
              timeDifferenceMs: 0,
              matchedComputerId: 'primary-computer',
            ),
          },
        ),
      },
    );

    final result = await adapter.performImport(
      bundleWithDupes,
      {
        ImportEntityType.dives: {0},
      },
      {
        ImportEntityType.dives: {0: DuplicateAction.consolidate},
      },
    );

    expect(result.consolidatedCount, equals(1));

    // 4. Full fidelity: the target dive now carries the secondary's
    // distinct-gas tank AND its gas-change event -- neither of which the
    // old hand-rolled DiveDataSourcesCompanion copy ever persisted.
    final targetTanks = await (db.select(
      db.diveTanks,
    )..where((t) => t.diveId.equals('target-dive'))).get();
    expect(targetTanks, hasLength(2));
    final secondaryTank = targetTanks.firstWhere(
      (t) => t.id != 'target-tank-air',
    );
    expect(secondaryTank.o2Percent, equals(32.0));
    expect(secondaryTank.startPressure, equals(200.0));
    expect(secondaryTank.endPressure, equals(120.0));
    expect(secondaryTank.computerId, equals('secondary-computer'));

    final targetEvents = await (db.select(
      db.diveProfileEvents,
    )..where((t) => t.diveId.equals('target-dive'))).get();
    expect(targetEvents, hasLength(1));
    expect(targetEvents.single.computerId, equals('secondary-computer'));

    // The secondary's raw download was persisted as a full standalone
    // dive first (via importSingleDiveAsNew), then folded away by
    // DiveConsolidationService.apply -- it must not remain standalone.
    final allDives = await db.select(db.dives).get();
    expect(allDives, hasLength(1));
    expect(allDives.single.id, equals('target-dive'));
  });

  // ---------------------------------------------------------------------------
  // Non-atomic import+consolidate hardening (Task 8, PR review finding 2)
  // ---------------------------------------------------------------------------

  test('consolidating onto a same-computer target is pre-validated and '
      'skipped WITHOUT importing anything', () async {
    await computerRepository.createComputer(
      DiveComputer.create(
        id: 'shared-computer',
        name: 'Shared Computer',
        diverId: diverId,
      ),
    );

    final entryTime = DateTime.utc(2026, 7, 2, 9);
    await diveRepository.createDive(
      domain.Dive(
        id: 'target-dive-same-computer',
        dateTime: entryTime,
        entryTime: entryTime,
        runtime: const Duration(minutes: 40),
        maxDepth: 25.0,
        diverId: diverId,
      ),
    );
    await (db.update(db.dives)
          ..where((t) => t.id.equals('target-dive-same-computer')))
        .write(const DivesCompanion(computerId: Value('shared-computer')));

    final sameComputer = await computerRepository.getComputerById(
      'shared-computer',
    );
    expect(sameComputer, isNotNull);

    final downloadedDive = DownloadedDive(
      startTime: entryTime,
      durationSeconds: 2400,
      maxDepth: 24.5,
      profile: const [],
      tanks: const [],
      events: const [],
    );

    final importService = DiveImportService(
      repository: computerRepository,
      diveRepository: diveRepository,
    );

    final adapter = DiveComputerAdapter(
      importService: importService,
      computerRepository: computerRepository,
      diveRepository: diveRepository,
      consolidationService: consolidationService,
      diverId: diverId,
      knownComputer: sameComputer,
    );
    adapter.setDownloadedDives([downloadedDive]);

    final rawBundle = await adapter.buildBundle();
    final bundleWithDupes = ImportBundle(
      source: rawBundle.source,
      groups: {
        ImportEntityType.dives: EntityGroup(
          items: rawBundle.groups[ImportEntityType.dives]!.items,
          duplicateIndices: {0},
          matchResults: const {
            0: DiveMatchResult(
              diveId: 'target-dive-same-computer',
              score: 0.9,
              timeDifferenceMs: 0,
              matchedComputerId: 'shared-computer',
            ),
          },
        ),
      },
    );

    final result = await adapter.performImport(
      bundleWithDupes,
      {
        ImportEntityType.dives: {0},
      },
      {
        ImportEntityType.dives: {0: DuplicateAction.consolidate},
      },
    );

    // Nothing was imported -- the predictable ArgumentError('sameComputer
    // ...') that DiveConsolidationService.apply would have thrown is
    // avoided entirely by pre-validating the target's computerId first.
    expect(result.consolidatedCount, equals(0));
    expect(result.skippedCount, equals(1));

    final allDives = await db.select(db.dives).get();
    expect(allDives, hasLength(1));
    expect(allDives.single.id, equals('target-dive-same-computer'));
  });

  test('when apply() fails unexpectedly after the import succeeded, the '
      'orphaned standalone dive is deleted (tombstoned) and the loop '
      'continues instead of throwing', () async {
    final secondaryComputer = await computerRepository.createComputer(
      DiveComputer.create(
        id: 'secondary-computer-fail',
        name: 'Secondary Computer',
        diverId: diverId,
      ),
    );

    final entryTime = DateTime.utc(2026, 7, 3, 9);
    final downloadedDive = DownloadedDive(
      startTime: entryTime,
      durationSeconds: 2400,
      maxDepth: 24.5,
      profile: const [],
      tanks: const [],
      events: const [],
    );

    final importService = DiveImportService(
      repository: computerRepository,
      diveRepository: diveRepository,
    );

    final adapter = DiveComputerAdapter(
      importService: importService,
      computerRepository: computerRepository,
      diveRepository: diveRepository,
      consolidationService: consolidationService,
      diverId: diverId,
      knownComputer: secondaryComputer,
    );
    adapter.setDownloadedDives([downloadedDive]);

    final rawBundle = await adapter.buildBundle();
    // The matched "target" dive does not exist -- DiveConsolidationService
    // .apply() will throw ArgumentError('targetDiveId not in selection')
    // AFTER the secondary has already been imported as a standalone dive,
    // exercising the unexpected-failure compensation path (as opposed to
    // the pre-validated same-computer path above).
    final bundleWithDupes = ImportBundle(
      source: rawBundle.source,
      groups: {
        ImportEntityType.dives: EntityGroup(
          items: rawBundle.groups[ImportEntityType.dives]!.items,
          duplicateIndices: {0},
          matchResults: const {
            0: DiveMatchResult(
              diveId: 'nonexistent-target-dive',
              score: 0.9,
              timeDifferenceMs: 0,
            ),
          },
        ),
      },
    );

    final deletionLogBefore = await (db.select(
      db.deletionLog,
    )..where((t) => t.entityType.equals('dives'))).get();

    final result = await adapter.performImport(
      bundleWithDupes,
      {
        ImportEntityType.dives: {0},
      },
      {
        ImportEntityType.dives: {0: DuplicateAction.consolidate},
      },
    );

    // The failure was compensated, not thrown: performImport returned
    // normally and counted it as skipped rather than consolidated.
    expect(result.consolidatedCount, equals(0));
    expect(result.skippedCount, equals(1));

    // No dangling dive row: the standalone import was rolled back via
    // deletion.
    final allDives = await db.select(db.dives).get();
    expect(allDives, isEmpty);

    // The compensating delete went through the tombstone-honoring path
    // (bulkDeleteDives -> SyncRepository.logDeletion), not a bare SQL
    // delete.
    final deletionLogAfter = await (db.select(
      db.deletionLog,
    )..where((t) => t.entityType.equals('dives'))).get();
    expect(deletionLogAfter.length, equals(deletionLogBefore.length + 1));
  });
}
