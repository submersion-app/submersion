import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/features/dive_computer/data/services/dive_import_service.dart';
import 'package:submersion/features/dive_computer/data/services/planned_dive_fill_service.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_log/data/services/dive_merge_snapshot.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/import_wizard/data/adapters/dive_computer_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/models/import_notice.dart';

import 'dive_computer_adapter_test.mocks.dart';

/// Issue #2002: the planned pass in checkDuplicates pairs an otherwise
/// unmatched download with a same-day planned dive of the target profile.
void main() {
  late MockDiveImportService mockImportService;
  late MockDiveComputerRepository mockComputerRepo;
  late MockDiveRepository mockDiveRepo;
  late MockDiveConsolidationService mockConsolidationService;
  late DiveComputerAdapter adapter;

  const diverId = 'diver-1';
  final now = DateTime(2026, 3, 20);
  final computer = DiveComputer(
    id: 'computer-1',
    name: 'My Perdix',
    createdAt: now,
    updatedAt: now,
  );

  DownloadedDive download(DateTime start) => DownloadedDive(
    startTime: start,
    durationSeconds: 47 * 60,
    maxDepth: 32.4,
    profile: const [],
    tanks: const [],
  );

  Dive planned(String id, DateTime at) =>
      Dive(id: id, diverId: diverId, dateTime: at, isPlanned: true);

  setUp(() {
    mockImportService = MockDiveImportService();
    when(
      mockImportService.unmatchedTransmitterSerials,
    ).thenReturn(const <String>[]);
    mockComputerRepo = MockDiveComputerRepository();
    mockDiveRepo = MockDiveRepository();
    mockConsolidationService = MockDiveConsolidationService();
    adapter = DiveComputerAdapter(
      importService: mockImportService,
      computerRepository: mockComputerRepo,
      diveRepository: mockDiveRepo,
      consolidationService: mockConsolidationService,
      diverId: diverId,
      knownComputer: computer,
    );
    when(
      mockDiveRepo.getSourceKeysByDiveId(diverId: anyNamed('diverId')),
    ).thenAnswer((_) async => {});
    when(
      mockImportService.detectDuplicate(
        any,
        diverId: anyNamed('diverId'),
        computerId: anyNamed('computerId'),
        sourceKeysCache: anyNamed('sourceKeysCache'),
      ),
    ).thenAnswer((_) async => DuplicateResult.noMatch());
  });

  group('draft pass (#637)', () {
    Dive draft(String id, DateTime entry, DateTime exit) => Dive(
      id: id,
      diverId: diverId,
      dateTime: entry,
      entryTime: entry,
      exitTime: exit,
      isDraft: true,
    );

    test('a download overlapping a draft fills it as a draft', () async {
      when(mockDiveRepo.getUnfilledDives(diverId: diverId)).thenAnswer(
        (_) async => [
          draft('d1', DateTime(2026, 6, 1, 10), DateTime(2026, 6, 1, 10, 50)),
        ],
      );
      adapter.setDownloadedDives([download(DateTime(2026, 6, 1, 10, 2))]);

      final result = await adapter.checkDuplicates(await adapter.buildBundle());

      final match = result.groups[ImportEntityType.dives]!.matchResults![0]!;
      expect(
        match.fillTarget,
        const FillTarget(diveId: 'd1', kind: FillTargetKind.draft),
      );
      expect(match.diveId, 'd1');
    });

    test('a plan still fills as a plan', () async {
      when(
        mockDiveRepo.getUnfilledDives(diverId: diverId),
      ).thenAnswer((_) async => [planned('p1', DateTime(2026, 6, 1, 9))]);
      adapter.setDownloadedDives([download(DateTime(2026, 6, 1, 14))]);

      final result = await adapter.checkDuplicates(await adapter.buildBundle());

      expect(
        result.groups[ImportEntityType.dives]!.matchResults![0]!.fillTarget,
        const FillTarget(diveId: 'p1', kind: FillTargetKind.plan),
      );
    });

    test('a download fitting two drafts is left for the diver', () async {
      when(mockDiveRepo.getUnfilledDives(diverId: diverId)).thenAnswer(
        (_) async => [
          draft('a', DateTime(2026, 6, 1, 9, 40), DateTime(2026, 6, 1, 10, 5)),
          draft('b', DateTime(2026, 6, 1, 10, 20), DateTime(2026, 6, 1, 11)),
        ],
      );
      adapter.setDownloadedDives([download(DateTime(2026, 6, 1, 10))]);

      final result = await adapter.checkDuplicates(await adapter.buildBundle());

      expect(result.groups[ImportEntityType.dives]!.duplicateIndices, isEmpty);
    });

    test('a real duplicate never becomes a draft fill', () async {
      final dive = download(DateTime(2026, 6, 1, 10, 2));
      when(mockDiveRepo.getUnfilledDives(diverId: diverId)).thenAnswer(
        (_) async => [
          draft('d1', DateTime(2026, 6, 1, 10), DateTime(2026, 6, 1, 10, 50)),
        ],
      );
      when(
        mockImportService.detectDuplicate(
          dive,
          diverId: anyNamed('diverId'),
          computerId: anyNamed('computerId'),
          sourceKeysCache: anyNamed('sourceKeysCache'),
        ),
      ).thenAnswer(
        (_) async => const DuplicateResult(
          matchingDiveId: 'existing-dive-1',
          confidence: DuplicateConfidence.exact,
          score: 1.0,
          matchedExistingSource: true,
        ),
      );
      adapter.setDownloadedDives([dive]);

      final result = await adapter.checkDuplicates(await adapter.buildBundle());

      final match = result.groups[ImportEntityType.dives]!.matchResults![0]!;
      expect(match.fillTarget, isNull);
      expect(match.diveId, 'existing-dive-1');
    });
  });

  group('planned pass', () {
    test(
      'an unmatched download on a planned day gets a plan fill target',
      () async {
        when(
          mockDiveRepo.getUnfilledDives(diverId: diverId),
        ).thenAnswer((_) async => [planned('p1', DateTime(2026, 6, 1, 9))]);
        adapter.setDownloadedDives([download(DateTime(2026, 6, 1, 14))]);
        final bundle = await adapter.buildBundle();

        final result = await adapter.checkDuplicates(bundle);

        final group = result.groups[ImportEntityType.dives]!;
        expect(group.duplicateIndices, {0});
        final match = group.matchResults![0]!;
        expect(match.fillTarget?.diveId, 'p1');
        expect(match.isFill, isTrue);
        expect(match.diveId, 'p1');
        expect(match.matchedExistingSource, isFalse);
      },
    );

    test('a download two days later stays unmatched', () async {
      when(
        mockDiveRepo.getUnfilledDives(diverId: diverId),
      ).thenAnswer((_) async => [planned('p1', DateTime(2026, 6, 1, 9))]);
      adapter.setDownloadedDives([download(DateTime(2026, 6, 3, 9))]);
      final bundle = await adapter.buildBundle();

      final result = await adapter.checkDuplicates(bundle);

      expect(result.groups[ImportEntityType.dives]!.duplicateIndices, isEmpty);
    });

    test('a download the day after the plan is offered as a fill', () async {
      when(
        mockDiveRepo.getUnfilledDives(diverId: diverId),
      ).thenAnswer((_) async => [planned('p1', DateTime(2026, 6, 1, 23))]);
      adapter.setDownloadedDives([download(DateTime(2026, 6, 2, 0, 30))]);
      final bundle = await adapter.buildBundle();

      final result = await adapter.checkDuplicates(bundle);

      final group = result.groups[ImportEntityType.dives]!;
      expect(group.duplicateIndices, {0});
      expect(group.matchResults![0]!.fillTarget?.diveId, 'p1');
    });

    test('a fingerprint hit is never turned into a fill', () async {
      final dive = download(DateTime(2026, 6, 1, 14));
      when(
        mockDiveRepo.getUnfilledDives(diverId: diverId),
      ).thenAnswer((_) async => [planned('p1', DateTime(2026, 6, 1, 9))]);
      when(
        mockImportService.detectDuplicate(
          dive,
          diverId: anyNamed('diverId'),
          computerId: anyNamed('computerId'),
          sourceKeysCache: anyNamed('sourceKeysCache'),
        ),
      ).thenAnswer(
        (_) async => const DuplicateResult(
          matchingDiveId: 'existing-dive-1',
          confidence: DuplicateConfidence.exact,
          score: 1.0,
          matchedExistingSource: true,
        ),
      );
      adapter.setDownloadedDives([dive]);
      final bundle = await adapter.buildBundle();

      final result = await adapter.checkDuplicates(bundle);

      final match = result.groups[ImportEntityType.dives]!.matchResults![0]!;
      expect(match.fillTarget?.diveId, isNull);
      expect(match.diveId, 'existing-dive-1');
      expect(match.matchedExistingSource, isTrue);
    });

    test('two downloads on one day take two plans in time order', () async {
      when(mockDiveRepo.getUnfilledDives(diverId: diverId)).thenAnswer(
        (_) async => [
          planned('pm', DateTime(2026, 6, 1, 13)),
          planned('am', DateTime(2026, 6, 1, 8)),
        ],
      );
      adapter.setDownloadedDives([
        download(DateTime(2026, 6, 1, 14)),
        download(DateTime(2026, 6, 1, 9)),
      ]);
      final bundle = await adapter.buildBundle();

      final result = await adapter.checkDuplicates(bundle);

      final results = result.groups[ImportEntityType.dives]!.matchResults!;
      expect(results[0]!.fillTarget?.diveId, 'pm');
      expect(results[1]!.fillTarget?.diveId, 'am');
    });
  });

  group('performImport with fillPlanned', () {
    late _FakeFillService fillService;

    ImportBundle bundleWithPlannedRow() => const ImportBundle(
      source: ImportSourceInfo(
        type: ImportSourceType.diveComputer,
        displayName: 'Perdix',
      ),
      groups: {
        ImportEntityType.dives: EntityGroup(
          items: [EntityItem(title: 'Dive 0', subtitle: '')],
          duplicateIndices: {0},
          matchResults: {
            0: DiveMatchResult(
              diveId: 'p1',
              score: 1,
              timeDifferenceMs: 0,
              fillTarget: FillTarget(diveId: 'p1', kind: FillTargetKind.plan),
            ),
          },
        ),
      },
    );

    setUp(() {
      fillService = _FakeFillService();
      adapter = DiveComputerAdapter(
        importService: mockImportService,
        computerRepository: mockComputerRepo,
        diveRepository: mockDiveRepo,
        consolidationService: mockConsolidationService,
        diverId: diverId,
        knownComputer: computer,
        fillService: fillService,
      );
      adapter.setDownloadedDives([download(DateTime(2026, 6, 1, 14))]);
    });

    test(
      'routes a fillPlanned row through the fill service and counts it',
      () async {
        final result = await adapter.performImport(
          bundleWithPlannedRow(),
          {
            ImportEntityType.dives: {0},
          },
          {
            ImportEntityType.dives: {0: DuplicateAction.fillPlanned},
          },
        );

        expect(fillService.calls, ['p1']);
        expect(result.filledCount, 1);
        expect(result.fillOutcomes.single.diveId, 'p1');
        expect(result.importedCounts[ImportEntityType.dives], 0);
        expect(result.importedDiveIds, ['p1']);
        verifyNever(
          mockImportService.importSingleDiveAsNew(
            any,
            computerId: anyNamed('computerId'),
            diverId: anyNamed('diverId'),
            descriptorVendor: anyNamed('descriptorVendor'),
            descriptorProduct: anyNamed('descriptorProduct'),
            descriptorModel: anyNamed('descriptorModel'),
            libdivecomputerVersion: anyNamed('libdivecomputerVersion'),
            retainSourceDiveNumber: anyNamed('retainSourceDiveNumber'),
          ),
        );
      },
    );

    test('a fill that kept a role read off a transmitter name adds the '
        'notice (#2595)', () async {
      fillService.nameDerivedRoleTanks = 1;

      final result = await adapter.performImport(
        bundleWithPlannedRow(),
        {
          ImportEntityType.dives: {0},
        },
        {
          ImportEntityType.dives: {0: DuplicateAction.fillPlanned},
        },
      );

      final notice = result.notices.singleWhere(
        (n) => n.kind == ImportNoticeKind.transmitterNameRoles,
      );
      expect(notice.count, 1);
    });

    test('a fill with no such role adds no notice', () async {
      final result = await adapter.performImport(
        bundleWithPlannedRow(),
        {
          ImportEntityType.dives: {0},
        },
        {
          ImportEntityType.dives: {0: DuplicateAction.fillPlanned},
        },
      );

      expect(
        result.notices.where(
          (n) => n.kind == ImportNoticeKind.transmitterNameRoles,
        ),
        isEmpty,
      );
    });

    test('a failed fill imports the download as new instead', () async {
      fillService.fail = true;
      when(
        mockImportService.importSingleDiveAsNew(
          any,
          computerId: anyNamed('computerId'),
          diverId: anyNamed('diverId'),
          descriptorVendor: anyNamed('descriptorVendor'),
          descriptorProduct: anyNamed('descriptorProduct'),
          descriptorModel: anyNamed('descriptorModel'),
          libdivecomputerVersion: anyNamed('libdivecomputerVersion'),
          retainSourceDiveNumber: anyNamed('retainSourceDiveNumber'),
        ),
      ).thenAnswer((_) async => 'new-dive');

      final result = await adapter.performImport(
        bundleWithPlannedRow(),
        {
          ImportEntityType.dives: {0},
        },
        {
          ImportEntityType.dives: {0: DuplicateAction.fillPlanned},
        },
      );

      expect(result.filledCount, 0);
      expect(result.importedCounts[ImportEntityType.dives], 1);
      expect(result.importedDiveIds, ['new-dive']);
    });
  });

  test('withFillTarget repoints the fill and keeps the dive id in step', () {
    const base = DiveMatchResult(
      diveId: 'p1',
      score: 1,
      timeDifferenceMs: 0,
      fillTarget: FillTarget(diveId: 'p1', kind: FillTargetKind.plan),
    );
    final moved = base.withFillTarget(
      const FillTarget(diveId: 'p2', kind: FillTargetKind.plan),
    );
    expect(moved.fillTarget?.diveId, 'p2');
    expect(moved.diveId, 'p2');
    expect(moved.isFill, isTrue);
    expect(moved.score, 1);
  });
}

/// Records fill calls and answers with a canned outcome; the adapter only
/// needs the outcome to count and carry it.
class _FakeFillService implements PlannedDiveFillService {
  final calls = <String>[];
  bool fail = false;
  int nameDerivedRoleTanks = 0;

  @override
  Future<PlannedDiveFillOutcome> fill({
    required String targetDiveId,
    required DownloadedDive dive,
    required String computerId,
    String? descriptorVendor,
    String? descriptorProduct,
    int? descriptorModel,
    String? libdivecomputerVersion,
  }) async {
    calls.add(targetDiveId);
    if (fail) throw StateError('fill failed');
    return PlannedDiveFillOutcome(
      diveId: targetDiveId,
      snapshot: const DiveMergeSnapshot(
        mergedDiveId: 'p1',
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
      assignedDiveNumber: 7,
      nameDerivedRoleTanks: nameDerivedRoleTanks,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}
