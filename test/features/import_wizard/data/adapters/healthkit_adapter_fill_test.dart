import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/features/dive_import/data/services/health_fill_service.dart';
import 'package:submersion/features/dive_import/domain/entities/imported_dive.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/dive_import/domain/services/imported_dive_converter.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/dive_consolidation_service.dart';
import 'package:submersion/features/dive_log/data/services/dive_merge_snapshot.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/domain/services/profile_alignment.dart';
import 'package:submersion/features/import_wizard/data/adapters/healthkit_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';

import 'healthkit_adapter_test.mocks.dart';

class _Computers extends Fake implements DiveComputerRepository {
  @override
  Future<DiveComputer?> findOrRegisterImportedComputer({
    required String model,
    String? manufacturer,
    String? serialNumber,
    String? firmwareVersion,
    String? diverId,
  }) async => DiveComputer(
    id: 'watch',
    name: 'Apple Watch',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  @override
  Future<void> attributeDiveToComputer({
    required String diveId,
    required String computerId,
  }) async {}
}

class _Fill extends Fake implements HealthFillService {
  final calls = <String>[];

  @override
  Future<String> fill({
    required String targetDiveId,
    required ImportedDive workout,
    required String diverId,
  }) async {
    calls.add(targetDiveId);
    return 'filled-$targetDiveId';
  }
}

class _Consolidation extends Fake implements DiveConsolidationService {
  final calls = <(String, List<String>)>[];

  @override
  Future<DiveConsolidationOutcome> apply({
    required String targetDiveId,
    required List<String> secondaryDiveIds,
    ConsolidationAlignment? alignment,
  }) async {
    calls.add((targetDiveId, secondaryDiveIds));
    return DiveConsolidationOutcome(
      targetDiveId: targetDiveId,
      snapshot: const DiveMergeSnapshot(
        mergedDiveId: '',
        diveRows: [],
        tankRows: [],
        weightRows: [],
        customFieldRows: [],
        equipmentRows: [],
        diveTypeRows: [],
        tagRows: [],
        buddyRows: [],
        sightingRows: [],
        eventRows: [],
        gasSwitchRows: [],
        dataSourceRows: [],
        tideRows: [],
        mediaDiveIds: {},
      ),
    );
  }
}

/// The Apple Health import wizard (issue #637) offers what the automatic
/// import does: fill a draft or a plan, or join a downloaded dive.
void main() {
  late MockDiveRepository repo;
  late _Fill fill;
  late _Consolidation consolidation;
  const diverId = 'diver-1';
  final ten = DateTime.utc(2026, 7, 17, 10);

  ImportedDive workout() => ImportedDive(
    sourceId: 'w1',
    source: ImportSource.appleWatch,
    startTime: ten,
    endTime: ten.add(const Duration(minutes: 45)),
    maxDepth: 18,
    profile: const [],
  );

  setUp(() {
    repo = MockDiveRepository();
    fill = _Fill();
    consolidation = _Consolidation();
    when(repo.createDive(any)).thenAnswer(
      (invocation) async => invocation.positionalArguments.first as Dive,
    );
    when(
      repo.getNextDiveNumber(diverId: anyNamed('diverId')),
    ).thenAnswer((_) async => 1);
  });

  HealthKitAdapter adapter(List<Dive> existing) {
    when(repo.getAllDives(diverId: diverId)).thenAnswer((_) async => existing);
    final a = HealthKitAdapter(
      healthService: MockHealthImportService(),
      diveMatcher: const DiveMatcher(),
      converter: const ImportedDiveConverter(),
      diveRepository: repo,
      computerRepository: _Computers(),
      fillService: fill,
      consolidationService: consolidation,
      diverId: diverId,
    );
    a.setParsedDives([workout()]);
    return a;
  }

  test('the wizard offers to fill and to merge', () {
    final actions = adapter(const []).supportedDuplicateActions;

    expect(actions, contains(DuplicateAction.fillPlanned));
    expect(actions, contains(DuplicateAction.consolidate));
  });

  test('a workout over a draft\'s taps is matched to fill it', () async {
    final a = adapter([
      Dive(
        id: 'draft',
        diverId: diverId,
        dateTime: ten,
        entryTime: ten,
        exitTime: ten.add(const Duration(minutes: 50)),
        isDraft: true,
      ),
    ]);

    final bundle = await a.checkDuplicates(await a.buildBundle());

    final match = bundle.groups[ImportEntityType.dives]!.matchResults![0]!;
    expect(
      match.fillTarget,
      const FillTarget(diveId: 'draft', kind: FillTargetKind.draft),
    );
  });

  test('a workout on a plan\'s day is matched to fill the plan, and the '
      'plan is never a fuzzy duplicate', () async {
    final a = adapter([
      Dive(
        id: 'plan',
        diverId: diverId,
        dateTime: ten,
        entryTime: ten,
        maxDepth: 18,
        runtime: const Duration(minutes: 45),
        isPlanned: true,
      ),
    ]);

    final bundle = await a.checkDuplicates(await a.buildBundle());

    final match = bundle.groups[ImportEntityType.dives]!.matchResults![0]!;
    expect(
      match.fillTarget,
      const FillTarget(diveId: 'plan', kind: FillTargetKind.plan),
    );
  });

  test('a downloaded dive it matches names its computer, so the wizard '
      'offers to merge', () async {
    final a = adapter([
      Dive(
        id: 'downloaded',
        diverId: diverId,
        dateTime: ten,
        entryTime: ten,
        exitTime: ten.add(const Duration(minutes: 45)),
        runtime: const Duration(minutes: 45),
        maxDepth: 18,
        computerId: 'perdix',
      ),
    ]);

    final bundle = await a.checkDuplicates(await a.buildBundle());

    final match = bundle.groups[ImportEntityType.dives]!.matchResults![0]!;
    expect(match.matchedComputerId, 'perdix');
    expect(match.score, greaterThanOrEqualTo(0.85));
    expect(bundle.source.currentComputerId, 'watch');
  });

  test('Fill fills the target and Merge joins the downloaded dive', () async {
    final a = adapter([
      Dive(
        id: 'draft',
        diverId: diverId,
        dateTime: ten,
        entryTime: ten,
        exitTime: ten.add(const Duration(minutes: 50)),
        isDraft: true,
      ),
    ]);
    final bundle = await a.checkDuplicates(await a.buildBundle());

    final filled = await a.performImport(
      bundle,
      {
        ImportEntityType.dives: {0},
      },
      {
        ImportEntityType.dives: {0: DuplicateAction.fillPlanned},
      },
    );

    expect(fill.calls, ['draft']);
    expect(filled.filledCount, 1);
    verifyNever(repo.createDive(any));
  });

  test('Merge saves the workout and joins it to the matched dive', () async {
    final a = adapter([
      Dive(
        id: 'downloaded',
        diverId: diverId,
        dateTime: ten,
        entryTime: ten,
        exitTime: ten.add(const Duration(minutes: 45)),
        runtime: const Duration(minutes: 45),
        maxDepth: 18,
        computerId: 'perdix',
      ),
    ]);
    final bundle = await a.checkDuplicates(await a.buildBundle());

    final result = await a.performImport(
      bundle,
      {
        ImportEntityType.dives: {0},
      },
      {
        ImportEntityType.dives: {0: DuplicateAction.consolidate},
      },
    );

    expect(consolidation.calls.single.$1, 'downloaded');
    expect(result.consolidatedCount, 1);
  });
}
