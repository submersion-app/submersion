import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/dive_consolidation_service.dart';
import 'package:submersion/features/dive_log/data/services/dive_merge_snapshot.dart';
import 'package:submersion/features/universal_import/data/services/import_duplicate_checker.dart';
import 'package:submersion/features/universal_import/presentation/providers/import_consolidation_service.dart';

@GenerateMocks([DiveConsolidationService, DiveRepository])
import 'import_consolidation_service_test.mocks.dart';

const _emptySnapshot = DiveMergeSnapshot(
  mergedDiveId: 'target-dive',
  diveRows: [],
  profileRows: [],
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
  tankPressureRows: [],
  dataSourceRows: [],
  tideRows: [],
  mediaDiveIds: {},
);

void main() {
  late MockDiveConsolidationService mockConsolidationService;
  late MockDiveRepository mockDiveRepository;

  setUp(() {
    mockConsolidationService = MockDiveConsolidationService();
    mockDiveRepository = MockDiveRepository();
    when(
      mockConsolidationService.apply(
        targetDiveId: anyNamed('targetDiveId'),
        secondaryDiveIds: anyNamed('secondaryDiveIds'),
      ),
    ).thenAnswer(
      (invocation) async => DiveConsolidationOutcome(
        targetDiveId: invocation.namedArguments[#targetDiveId] as String,
        snapshot: _emptySnapshot,
      ),
    );
    when(mockDiveRepository.bulkDeleteDives(any)).thenAnswer(
      (invocation) async => invocation.positionalArguments[0] as List<String>,
    );
  });

  group('performConsolidations', () {
    test('returns 0 consolidated for empty indices', () async {
      final summary = await performConsolidations(
        indices: <int>{},
        diveIdByIndex: {0: 'new-dive-1'},
        duplicateResult: const ImportDuplicateResult(
          diveMatches: {
            0: DiveMatchResult(
              diveId: 'existing-dive-1',
              score: 0.9,
              timeDifferenceMs: 100,
            ),
          },
        ),
        consolidationService: mockConsolidationService,
        diveRepository: mockDiveRepository,
      );

      expect(summary.consolidated, 0);
      expect(summary.failed, 0);
      verifyNever(
        mockConsolidationService.apply(
          targetDiveId: anyNamed('targetDiveId'),
          secondaryDiveIds: anyNamed('secondaryDiveIds'),
        ),
      );
    });

    test('returns 0 consolidated when duplicateResult is null', () async {
      final summary = await performConsolidations(
        indices: {0},
        diveIdByIndex: {0: 'new-dive-1'},
        duplicateResult: null,
        consolidationService: mockConsolidationService,
        diveRepository: mockDiveRepository,
      );

      expect(summary.consolidated, 0);
      verifyNever(
        mockConsolidationService.apply(
          targetDiveId: anyNamed('targetDiveId'),
          secondaryDiveIds: anyNamed('secondaryDiveIds'),
        ),
      );
    });

    test(
      'returns 0 consolidated when duplicateResult has no match for index',
      () async {
        final summary = await performConsolidations(
          indices: {0},
          diveIdByIndex: {0: 'new-dive-1'},
          duplicateResult: const ImportDuplicateResult(diveMatches: {}),
          consolidationService: mockConsolidationService,
          diveRepository: mockDiveRepository,
        );

        expect(summary.consolidated, 0);
        verifyNever(
          mockConsolidationService.apply(
            targetDiveId: anyNamed('targetDiveId'),
            secondaryDiveIds: anyNamed('secondaryDiveIds'),
          ),
        );
      },
    );

    test('returns 0 consolidated when diveIdByIndex has no persisted dive id '
        'for index', () async {
      final summary = await performConsolidations(
        indices: {0},
        diveIdByIndex: const {},
        duplicateResult: const ImportDuplicateResult(
          diveMatches: {
            0: DiveMatchResult(
              diveId: 'existing-dive-1',
              score: 0.9,
              timeDifferenceMs: 100,
            ),
          },
        ),
        consolidationService: mockConsolidationService,
        diveRepository: mockDiveRepository,
      );

      expect(summary.consolidated, 0);
      verifyNever(
        mockConsolidationService.apply(
          targetDiveId: anyNamed('targetDiveId'),
          secondaryDiveIds: anyNamed('secondaryDiveIds'),
        ),
      );
    });

    test('folds the freshly-imported dive into the matched dive via '
        'DiveConsolidationService.apply', () async {
      final summary = await performConsolidations(
        indices: {0},
        diveIdByIndex: {0: 'new-dive-1'},
        duplicateResult: const ImportDuplicateResult(
          diveMatches: {
            0: DiveMatchResult(
              diveId: 'existing-dive-1',
              score: 0.9,
              timeDifferenceMs: 100,
            ),
          },
        ),
        consolidationService: mockConsolidationService,
        diveRepository: mockDiveRepository,
      );

      expect(summary.consolidated, 1);
      expect(summary.failed, 0);
      expect(summary.removedDiveIds, {'new-dive-1'});
      verify(
        mockConsolidationService.apply(
          targetDiveId: 'existing-dive-1',
          secondaryDiveIds: ['new-dive-1'],
        ),
      ).called(1);
    });

    test('handles multiple indices, each folded into its own match', () async {
      final summary = await performConsolidations(
        indices: {0, 1},
        diveIdByIndex: {0: 'new-dive-0', 1: 'new-dive-1'},
        duplicateResult: const ImportDuplicateResult(
          diveMatches: {
            0: DiveMatchResult(
              diveId: 'existing-dive-a',
              score: 0.9,
              timeDifferenceMs: 100,
            ),
            1: DiveMatchResult(
              diveId: 'existing-dive-b',
              score: 0.95,
              timeDifferenceMs: 50,
            ),
          },
        ),
        consolidationService: mockConsolidationService,
        diveRepository: mockDiveRepository,
      );

      expect(summary.consolidated, 2);
      expect(summary.removedDiveIds, {'new-dive-0', 'new-dive-1'});
      verify(
        mockConsolidationService.apply(
          targetDiveId: 'existing-dive-a',
          secondaryDiveIds: ['new-dive-0'],
        ),
      ).called(1);
      verify(
        mockConsolidationService.apply(
          targetDiveId: 'existing-dive-b',
          secondaryDiveIds: ['new-dive-1'],
        ),
      ).called(1);
    });

    test('only the matched indices are consolidated; unmatched ones are '
        'silently skipped and do not affect the count', () async {
      final summary = await performConsolidations(
        indices: {0, 1},
        diveIdByIndex: {0: 'new-dive-0', 1: 'new-dive-1'},
        duplicateResult: const ImportDuplicateResult(
          diveMatches: {
            0: DiveMatchResult(
              diveId: 'existing-dive-a',
              score: 0.9,
              timeDifferenceMs: 100,
            ),
          },
        ),
        consolidationService: mockConsolidationService,
        diveRepository: mockDiveRepository,
      );

      expect(summary.consolidated, 1);
      expect(summary.removedDiveIds, {'new-dive-0'});
      verify(
        mockConsolidationService.apply(
          targetDiveId: 'existing-dive-a',
          secondaryDiveIds: ['new-dive-0'],
        ),
      ).called(1);
      verifyNever(
        mockConsolidationService.apply(
          targetDiveId: 'existing-dive-b',
          secondaryDiveIds: anyNamed('secondaryDiveIds'),
        ),
      );
    });

    // -------------------------------------------------------------------
    // Non-atomic import+consolidate hardening (Task 8, PR review finding 2)
    // -------------------------------------------------------------------

    test('when apply() throws, the freshly-imported standalone dive is '
        'deleted and the loop continues to remaining indices', () async {
      when(
        mockConsolidationService.apply(
          targetDiveId: 'existing-dive-a',
          secondaryDiveIds: ['new-dive-0'],
        ),
      ).thenThrow(ArgumentError('targetDiveId not in selection'));

      final summary = await performConsolidations(
        indices: {0, 1},
        diveIdByIndex: {0: 'new-dive-0', 1: 'new-dive-1'},
        duplicateResult: const ImportDuplicateResult(
          diveMatches: {
            0: DiveMatchResult(
              diveId: 'existing-dive-a',
              score: 0.9,
              timeDifferenceMs: 100,
            ),
            1: DiveMatchResult(
              diveId: 'existing-dive-b',
              score: 0.95,
              timeDifferenceMs: 50,
            ),
          },
        ),
        consolidationService: mockConsolidationService,
        diveRepository: mockDiveRepository,
      );

      // Index 0 failed and was compensated; index 1 still succeeded --
      // the exception from index 0 must not abort the loop.
      expect(summary.consolidated, 1);
      expect(summary.failed, 1);
      // Both are gone: new-dive-0 was compensating-deleted, new-dive-1 folded.
      expect(summary.removedDiveIds, {'new-dive-0', 'new-dive-1'});
      verify(mockDiveRepository.bulkDeleteDives(['new-dive-0'])).called(1);
      verifyNever(mockDiveRepository.bulkDeleteDives(['new-dive-1']));
      verify(
        mockConsolidationService.apply(
          targetDiveId: 'existing-dive-b',
          secondaryDiveIds: ['new-dive-1'],
        ),
      ).called(1);
    });

    test(
      'when apply() throws AND the compensating delete also throws, the '
      'loop still continues to remaining indices instead of aborting',
      () async {
        when(
          mockConsolidationService.apply(
            targetDiveId: 'existing-dive-a',
            secondaryDiveIds: ['new-dive-0'],
          ),
        ).thenThrow(ArgumentError('targetDiveId not in selection'));
        when(
          mockDiveRepository.bulkDeleteDives(['new-dive-0']),
        ).thenThrow(Exception('delete failed too'));

        final summary = await performConsolidations(
          indices: {0, 1},
          diveIdByIndex: {0: 'new-dive-0', 1: 'new-dive-1'},
          duplicateResult: const ImportDuplicateResult(
            diveMatches: {
              0: DiveMatchResult(
                diveId: 'existing-dive-a',
                score: 0.9,
                timeDifferenceMs: 100,
              ),
              1: DiveMatchResult(
                diveId: 'existing-dive-b',
                score: 0.95,
                timeDifferenceMs: 50,
              ),
            },
          ),
          consolidationService: mockConsolidationService,
          diveRepository: mockDiveRepository,
        );

        // Index 0's double failure (apply throws, then the compensating
        // delete also throws) must not propagate out of the loop -- index 1
        // still gets processed and succeeds.
        expect(summary.consolidated, 1);
        expect(summary.failed, 1);
        // new-dive-0's fold AND its compensating delete both failed, so it is
        // still standalone -- it must NOT be reported as removed, which is what
        // keeps the caller from hiding a stranded duplicate from the summary.
        expect(summary.removedDiveIds, {'new-dive-1'});
        expect(summary.removedDiveIds, isNot(contains('new-dive-0')));
        verify(mockDiveRepository.bulkDeleteDives(['new-dive-0'])).called(1);
        verify(
          mockConsolidationService.apply(
            targetDiveId: 'existing-dive-b',
            secondaryDiveIds: ['new-dive-1'],
          ),
        ).called(1);
      },
    );
  });
}
