import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/import_wizard/domain/adapters/import_source_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/models/import_phase.dart';
import 'package:submersion/features/import_wizard/domain/models/tag_selection.dart';
import 'package:submersion/features/import_wizard/domain/models/unified_import_result.dart';
import 'package:submersion/features/import_wizard/presentation/providers/import_wizard_providers.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

@GenerateNiceMocks([MockSpec<ImportSourceAdapter>(), MockSpec<TagRepository>()])
import 'import_wizard_notifier_test.mocks.dart';

// ---------------------------------------------------------------------------
// Helpers for pendingDuplicateReview bundle tests.
// ---------------------------------------------------------------------------

/// Minimal adapter impl used by setBundle-pending tests.
///
/// The tests only exercise [ImportWizardNotifier.setBundle], which reads
/// only [supportedDuplicateActions] and [defaultTagName] off the adapter.
/// All other members fall through [noSuchMethod] and throw if accidentally
/// reached — catching any behavioral drift.
class _TestAdapter implements ImportSourceAdapter {
  @override
  String get defaultTagName => 'Test Import';

  @override
  Set<DuplicateAction> get supportedDuplicateActions => const {
    DuplicateAction.skip,
    DuplicateAction.importAsNew,
    DuplicateAction.consolidate,
  };

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

ImportBundle _bundleWithProbableDiveDuplicate({required int index}) {
  return ImportBundle(
    source: const ImportSourceInfo(
      type: ImportSourceType.uddf,
      displayName: 'probable.uddf',
    ),
    groups: {
      ImportEntityType.dives: EntityGroup(
        items: [const EntityItem(title: 'Dive 1', subtitle: '')],
        duplicateIndices: {index},
        matchResults: {
          index: const DiveMatchResult(
            diveId: 'existing-dive',
            score: 0.85,
            timeDifferenceMs: 0,
          ),
        },
      ),
    },
  );
}

ImportBundle _bundleWithPossibleDiveDuplicate({required int index}) {
  return ImportBundle(
    source: const ImportSourceInfo(
      type: ImportSourceType.uddf,
      displayName: 'possible.uddf',
    ),
    groups: {
      ImportEntityType.dives: EntityGroup(
        items: [const EntityItem(title: 'Dive 1', subtitle: '')],
        duplicateIndices: {index},
        matchResults: {
          index: const DiveMatchResult(
            diveId: 'existing-dive',
            score: 0.6,
            timeDifferenceMs: 0,
          ),
        },
      ),
    },
  );
}

ImportBundle _bundleWithUnscoredSiteDuplicate({required int index}) {
  return ImportBundle(
    source: const ImportSourceInfo(
      type: ImportSourceType.uddf,
      displayName: 'sites.uddf',
    ),
    groups: {
      ImportEntityType.sites: EntityGroup(
        items: [const EntityItem(title: 'Site A', subtitle: '')],
        duplicateIndices: {index},
      ),
    },
  );
}

ImportBundle _bundleWithOneCleanAndOneDuplicateDive() {
  return const ImportBundle(
    source: ImportSourceInfo(
      type: ImportSourceType.uddf,
      displayName: 'mixed.uddf',
    ),
    groups: {
      ImportEntityType.dives: EntityGroup(
        items: [
          EntityItem(title: 'Dive 1', subtitle: ''),
          EntityItem(title: 'Dive 2', subtitle: ''),
        ],
        duplicateIndices: {1},
        matchResults: {
          1: DiveMatchResult(
            diveId: 'existing-dive',
            score: 0.85,
            timeDifferenceMs: 0,
          ),
        },
      ),
    },
  );
}

ImportBundle _bundleWithOneCleanDive() {
  return const ImportBundle(
    source: ImportSourceInfo(
      type: ImportSourceType.uddf,
      displayName: 'clean.uddf',
    ),
    groups: {
      ImportEntityType.dives: EntityGroup(
        items: [EntityItem(title: 'Dive 1', subtitle: '')],
      ),
    },
  );
}

void main() {
  group('ImportWizardNotifier', () {
    late MockImportSourceAdapter mockAdapter;
    late MockTagRepository mockTagRepo;
    late ImportWizardNotifier notifier;

    // Test data helpers
    ImportBundle buildBundle({
      List<EntityItem>? diveItems,
      Set<int> diveDuplicateIndices = const {},
      Map<int, DiveMatchResult>? diveMatchResults,
      List<EntityItem>? siteItems,
      Set<int> siteDuplicateIndices = const {},
    }) {
      final groups = <ImportEntityType, EntityGroup>{};

      if (diveItems != null) {
        groups[ImportEntityType.dives] = EntityGroup(
          items: diveItems,
          duplicateIndices: diveDuplicateIndices,
          matchResults: diveMatchResults,
        );
      }

      if (siteItems != null) {
        groups[ImportEntityType.sites] = EntityGroup(
          items: siteItems,
          duplicateIndices: siteDuplicateIndices,
        );
      }

      return ImportBundle(
        source: const ImportSourceInfo(
          type: ImportSourceType.uddf,
          displayName: 'test.uddf',
        ),
        groups: groups,
      );
    }

    EntityItem makeItem(String title) => EntityItem(title: title, subtitle: '');

    DiveMatchResult makeMatchResult(double score) => DiveMatchResult(
      diveId: 'existing-dive',
      score: score,
      timeDifferenceMs: 0,
    );

    setUp(() {
      mockAdapter = MockImportSourceAdapter();
      mockTagRepo = MockTagRepository();
      when(mockAdapter.sourceType).thenReturn(ImportSourceType.uddf);
      when(mockAdapter.displayName).thenReturn('test.uddf');
      when(mockAdapter.acquisitionSteps).thenReturn([]);
      when(
        mockAdapter.supportedDuplicateActions,
      ).thenReturn({DuplicateAction.skip, DuplicateAction.importAsNew});
      notifier = ImportWizardNotifier(
        mockAdapter,
        tagRepository: mockTagRepo,
        diverId: 'diver-1',
      );
    });

    tearDown(() {
      notifier.dispose();
    });

    // -------------------------------------------------------------------------
    // setBundle
    // -------------------------------------------------------------------------

    group('setBundle', () {
      test('stores the bundle in state', () {
        final bundle = buildBundle(
          diveItems: [makeItem('Dive 1'), makeItem('Dive 2')],
        );

        notifier.setBundle(bundle);

        expect(notifier.state.bundle, same(bundle));
      });

      test('initializes selections: all non-duplicate items selected', () {
        final bundle = buildBundle(
          diveItems: [
            makeItem('Dive 1'),
            makeItem('Dive 2'),
            makeItem('Dive 3'),
          ],
          // index 1 is a duplicate
          diveDuplicateIndices: {1},
        );

        notifier.setBundle(bundle);

        final selections = notifier.state.selections[ImportEntityType.dives]!;
        expect(selections, contains(0));
        expect(selections, isNot(contains(1)));
        expect(selections, contains(2));
      });

      test('initializes selections for multiple entity types', () {
        final bundle = buildBundle(
          diveItems: [makeItem('Dive 1'), makeItem('Dive 2')],
          diveDuplicateIndices: {0},
          siteItems: [makeItem('Site A'), makeItem('Site B')],
          siteDuplicateIndices: {},
        );

        notifier.setBundle(bundle);

        final diveSelections =
            notifier.state.selections[ImportEntityType.dives]!;
        final siteSelections =
            notifier.state.selections[ImportEntityType.sites]!;

        expect(diveSelections, equals({1}));
        expect(siteSelections, equals({0, 1}));
      });

      test(
        'probable duplicate (score >= 0.7) goes into pending, NOT auto-skipped',
        () {
          final bundle = buildBundle(
            diveItems: [makeItem('Dive 1')],
            diveDuplicateIndices: {0},
            diveMatchResults: {0: makeMatchResult(0.85)},
          );

          notifier.setBundle(bundle);

          // No auto-default action is written — the user must decide.
          expect(
            notifier.state.duplicateActions[ImportEntityType.dives],
            anyOf(isNull, isEmpty),
          );
          // The index is instead recorded as pending review.
          expect(
            notifier.state.pendingFor(ImportEntityType.dives),
            equals({0}),
          );
        },
      );

      test('possible duplicate (0.5 <= score < 0.7) goes into pending, '
          'NOT auto-imported-as-new', () {
        final bundle = buildBundle(
          diveItems: [makeItem('Dive 1')],
          diveDuplicateIndices: {0},
          diveMatchResults: {0: makeMatchResult(0.6)},
        );

        notifier.setBundle(bundle);

        expect(
          notifier.state.duplicateActions[ImportEntityType.dives],
          anyOf(isNull, isEmpty),
        );
        expect(notifier.state.pendingFor(ImportEntityType.dives), equals({0}));
      });

      test('exactly 0.7 score goes into pending, NOT auto-skipped', () {
        final bundle = buildBundle(
          diveItems: [makeItem('Dive 1')],
          diveDuplicateIndices: {0},
          diveMatchResults: {0: makeMatchResult(0.7)},
        );

        notifier.setBundle(bundle);

        expect(
          notifier.state.duplicateActions[ImportEntityType.dives],
          anyOf(isNull, isEmpty),
        );
        expect(notifier.state.pendingFor(ImportEntityType.dives), equals({0}));
      });

      test('handles bundle with no duplicates — empty duplicateActions', () {
        final bundle = buildBundle(
          diveItems: [makeItem('Dive 1'), makeItem('Dive 2')],
        );

        notifier.setBundle(bundle);

        final actions = notifier.state.duplicateActions[ImportEntityType.dives];
        // No duplicates → no actions needed and no pending review either.
        expect(actions, anyOf(isNull, isEmpty));
        expect(notifier.state.hasPendingReviews, isFalse);
      });

      test('updates currentStep to 1 (review step)', () {
        final bundle = buildBundle(diveItems: [makeItem('Dive 1')]);

        notifier.setBundle(bundle);

        expect(notifier.state.currentStep, equals(1));
      });
    });

    // -------------------------------------------------------------------------
    // toggleSelection
    // -------------------------------------------------------------------------

    group('toggleSelection', () {
      test('deselects a selected item', () {
        final bundle = buildBundle(
          diveItems: [makeItem('Dive 1'), makeItem('Dive 2')],
        );
        notifier.setBundle(bundle);
        expect(notifier.state.selections[ImportEntityType.dives], contains(0));

        notifier.toggleSelection(ImportEntityType.dives, 0);

        expect(
          notifier.state.selections[ImportEntityType.dives],
          isNot(contains(0)),
        );
      });

      test('selects a deselected item', () {
        final bundle = buildBundle(
          diveItems: [makeItem('Dive 1')],
          diveDuplicateIndices: {0},
        );
        notifier.setBundle(bundle);
        expect(
          notifier.state.selections[ImportEntityType.dives],
          isNot(contains(0)),
        );

        notifier.toggleSelection(ImportEntityType.dives, 0);

        expect(notifier.state.selections[ImportEntityType.dives], contains(0));
      });

      test('toggle does not affect other entity types', () {
        final bundle = buildBundle(
          diveItems: [makeItem('Dive 1')],
          siteItems: [makeItem('Site A')],
        );
        notifier.setBundle(bundle);

        notifier.toggleSelection(ImportEntityType.dives, 0);

        expect(notifier.state.selections[ImportEntityType.sites], contains(0));
      });
    });

    // -------------------------------------------------------------------------
    // selectAll / deselectAll
    // -------------------------------------------------------------------------

    group('selectAll', () {
      test('selects all non-duplicate items', () {
        final bundle = buildBundle(
          diveItems: [
            makeItem('Dive 1'),
            makeItem('Dive 2'),
            makeItem('Dive 3'),
          ],
          diveDuplicateIndices: {1},
        );
        notifier.setBundle(bundle);

        // First deselect all
        notifier.deselectAll(ImportEntityType.dives);
        expect(notifier.state.selections[ImportEntityType.dives], isEmpty);

        notifier.selectAll(ImportEntityType.dives);

        final selections = notifier.state.selections[ImportEntityType.dives]!;
        expect(selections, contains(0));
        expect(selections, isNot(contains(1))); // duplicate excluded
        expect(selections, contains(2));
      });
    });

    group('deselectAll', () {
      test('clears all selections for entity type', () {
        final bundle = buildBundle(
          diveItems: [makeItem('Dive 1'), makeItem('Dive 2')],
        );
        notifier.setBundle(bundle);
        expect(
          notifier.state.selections[ImportEntityType.dives]!.length,
          equals(2),
        );

        notifier.deselectAll(ImportEntityType.dives);

        expect(notifier.state.selections[ImportEntityType.dives], isEmpty);
      });

      test(
        'does not affect duplicate indices after deselectAll then selectAll',
        () {
          final bundle = buildBundle(
            diveItems: [makeItem('Dive 1'), makeItem('Dive 2')],
            diveDuplicateIndices: {0},
          );
          notifier.setBundle(bundle);

          notifier.deselectAll(ImportEntityType.dives);
          notifier.selectAll(ImportEntityType.dives);

          final selections = notifier.state.selections[ImportEntityType.dives]!;
          expect(selections, isNot(contains(0)));
          expect(selections, contains(1));
        },
      );
    });

    // -------------------------------------------------------------------------
    // setDuplicateAction
    // -------------------------------------------------------------------------

    group('setDuplicateAction', () {
      test('sets action for a specific duplicate index', () {
        final bundle = buildBundle(
          diveItems: [makeItem('Dive 1')],
          diveDuplicateIndices: {0},
          diveMatchResults: {0: makeMatchResult(0.85)},
        );
        notifier.setBundle(bundle);
        // Initially no recorded action — index is pending review until the
        // user decides.
        expect(
          notifier.state.duplicateActions[ImportEntityType.dives],
          anyOf(isNull, isEmpty),
        );

        notifier.setDuplicateAction(
          ImportEntityType.dives,
          0,
          DuplicateAction.importAsNew,
        );

        expect(
          notifier.state.duplicateActions[ImportEntityType.dives]![0],
          equals(DuplicateAction.importAsNew),
        );
      });

      test('does not affect actions for other indices', () {
        final bundle = buildBundle(
          diveItems: [makeItem('Dive 1'), makeItem('Dive 2')],
          diveDuplicateIndices: {0, 1},
          diveMatchResults: {
            0: makeMatchResult(0.85),
            1: makeMatchResult(0.85),
          },
        );
        notifier.setBundle(bundle);

        notifier.setDuplicateAction(
          ImportEntityType.dives,
          0,
          DuplicateAction.importAsNew,
        );

        // Index 0 got an explicit action; index 1 is still pending (no action).
        expect(
          notifier.state.duplicateActions[ImportEntityType.dives]![0],
          equals(DuplicateAction.importAsNew),
        );
        expect(
          notifier.state.duplicateActions[ImportEntityType.dives]![1],
          isNull,
        );
      });
    });

    // -------------------------------------------------------------------------
    // performImport
    // -------------------------------------------------------------------------

    group('performImport', () {
      test('sets isImporting to true during import', () async {
        final bundle = buildBundle(diveItems: [makeItem('Dive 1')]);
        notifier.setBundle(bundle);

        const importResult = UnifiedImportResult(
          importedCounts: {ImportEntityType.dives: 1},
          consolidatedCount: 0,
          skippedCount: 0,
        );

        final isImportingValues = <bool>[];
        notifier.addListener((state) {
          isImportingValues.add(state.isImporting);
        });

        when(
          mockAdapter.performImport(
            any,
            any,
            any,
            retainSourceDiveNumbers: anyNamed('retainSourceDiveNumbers'),
            onProgress: anyNamed('onProgress'),
          ),
        ).thenAnswer((_) async {
          // Capture during import — state should be importing
          return importResult;
        });

        await notifier.performImport();

        expect(isImportingValues, contains(true));
        expect(notifier.state.isImporting, isFalse);
      });

      test(
        'delegates to adapter with correct selections and actions',
        () async {
          final bundle = buildBundle(
            diveItems: [makeItem('Dive 1'), makeItem('Dive 2')],
            diveDuplicateIndices: {1},
            diveMatchResults: {1: makeMatchResult(0.85)},
            siteItems: [makeItem('Site A')],
          );
          notifier.setBundle(bundle);
          // setBundle no longer writes auto-default actions. The user must
          // explicitly resolve the pending duplicate before import.
          notifier.setDuplicateAction(
            ImportEntityType.dives,
            1,
            DuplicateAction.skip,
          );

          const importResult = UnifiedImportResult(
            importedCounts: {ImportEntityType.dives: 1},
            consolidatedCount: 0,
            skippedCount: 1,
          );

          when(
            mockAdapter.performImport(
              any,
              any,
              any,
              onProgress: anyNamed('onProgress'),
            ),
          ).thenAnswer((_) async => importResult);

          await notifier.performImport();

          final captured = verify(
            mockAdapter.performImport(
              captureAny,
              captureAny,
              captureAny,
              retainSourceDiveNumbers: anyNamed('retainSourceDiveNumbers'),
              onProgress: anyNamed('onProgress'),
            ),
          ).captured;

          final passedBundle = captured[0] as ImportBundle;
          final passedSelections =
              captured[1] as Map<ImportEntityType, Set<int>>;
          final passedActions =
              captured[2] as Map<ImportEntityType, Map<int, DuplicateAction>>;

          expect(passedBundle, same(bundle));
          expect(passedSelections[ImportEntityType.dives], equals({0}));
          expect(passedSelections[ImportEntityType.sites], equals({0}));
          expect(
            passedActions[ImportEntityType.dives]![1],
            equals(DuplicateAction.skip),
          );
        },
      );

      test('stores result after successful import', () async {
        final bundle = buildBundle(diveItems: [makeItem('Dive 1')]);
        notifier.setBundle(bundle);

        const importResult = UnifiedImportResult(
          importedCounts: {ImportEntityType.dives: 1},
          consolidatedCount: 0,
          skippedCount: 0,
        );

        when(
          mockAdapter.performImport(
            any,
            any,
            any,
            retainSourceDiveNumbers: anyNamed('retainSourceDiveNumbers'),
            onProgress: anyNamed('onProgress'),
          ),
        ).thenAnswer((_) async => importResult);

        await notifier.performImport();

        expect(notifier.state.importResult, same(importResult));
        expect(notifier.state.isImporting, isFalse);
        expect(notifier.state.error, isNull);
      });

      test('sets error on import failure', () async {
        final bundle = buildBundle(diveItems: [makeItem('Dive 1')]);
        notifier.setBundle(bundle);

        when(
          mockAdapter.performImport(
            any,
            any,
            any,
            retainSourceDiveNumbers: anyNamed('retainSourceDiveNumbers'),
            onProgress: anyNamed('onProgress'),
          ),
        ).thenThrow(Exception('DB error'));

        await notifier.performImport();

        expect(notifier.state.error, isNotNull);
        expect(notifier.state.isImporting, isFalse);
        expect(notifier.state.importResult, isNotNull);
        expect(notifier.state.importResult!.errorMessage, isNotNull);
      });

      test('advances to summary step on success', () async {
        final bundle = buildBundle(diveItems: [makeItem('Dive 1')]);
        notifier.setBundle(bundle);

        const importResult = UnifiedImportResult(
          importedCounts: {ImportEntityType.dives: 1},
          consolidatedCount: 0,
          skippedCount: 0,
        );

        when(
          mockAdapter.performImport(
            any,
            any,
            any,
            retainSourceDiveNumbers: anyNamed('retainSourceDiveNumbers'),
            onProgress: anyNamed('onProgress'),
          ),
        ).thenAnswer((_) async => importResult);

        await notifier.performImport();

        // Should advance past the importing step
        expect(notifier.state.currentStep, greaterThan(1));
      });

      test('updates progress via onProgress callback', () async {
        final bundle = buildBundle(diveItems: [makeItem('Dive 1')]);
        notifier.setBundle(bundle);

        const importResult = UnifiedImportResult(
          importedCounts: {ImportEntityType.dives: 1},
          consolidatedCount: 0,
          skippedCount: 0,
        );

        when(
          mockAdapter.performImport(
            any,
            any,
            any,
            retainSourceDiveNumbers: anyNamed('retainSourceDiveNumbers'),
            onProgress: anyNamed('onProgress'),
          ),
        ).thenAnswer((invocation) async {
          final onProgress =
              invocation.namedArguments[#onProgress]
                  as void Function(ImportPhase, int, int)?;
          onProgress?.call(ImportPhase.dives, 1, 3);
          return importResult;
        });

        // Track intermediate states to verify progress was applied.
        final phases = <ImportPhase?>[];
        notifier.addListener((state) {
          if (state.importPhase != null) {
            phases.add(state.importPhase);
          }
        });

        await notifier.performImport();

        // Verify progress state was actually updated.
        expect(phases, contains(ImportPhase.dives));
        expect(notifier.state.importResult, isNotNull);
      });

      test('does nothing when no bundle is set', () async {
        // No setBundle called
        await notifier.performImport();

        verifyNever(
          mockAdapter.performImport(
            any,
            any,
            any,
            retainSourceDiveNumbers: anyNamed('retainSourceDiveNumbers'),
            onProgress: anyNamed('onProgress'),
          ),
        );
        expect(notifier.state.isImporting, isFalse);
      });

      test('sets importResult with error when no bundle is set', () async {
        await notifier.performImport();

        expect(notifier.state.importResult, isNotNull);
        expect(
          notifier.state.importResult!.errorMessage,
          equals('No import data available'),
        );
        expect(notifier.state.importResult!.importedCounts, isEmpty);
        expect(notifier.state.importResult!.consolidatedCount, equals(0));
        expect(notifier.state.importResult!.skippedCount, equals(0));
      });

      test('sets importResult with error message on import failure', () async {
        final bundle = buildBundle(diveItems: [makeItem('Dive 1')]);
        notifier.setBundle(bundle);

        when(
          mockAdapter.performImport(
            any,
            any,
            any,
            retainSourceDiveNumbers: anyNamed('retainSourceDiveNumbers'),
            onProgress: anyNamed('onProgress'),
          ),
        ).thenThrow(Exception('Database connection lost'));

        await notifier.performImport();

        expect(notifier.state.importResult, isNotNull);
        expect(notifier.state.importResult!.errorMessage, isNotNull);
        expect(
          notifier.state.importResult!.errorMessage,
          contains('Import failed'),
        );
        expect(
          notifier.state.importResult!.errorMessage,
          contains('Database connection lost'),
        );
        expect(notifier.state.importResult!.importedCounts, isEmpty);
        expect(notifier.state.importResult!.consolidatedCount, equals(0));
        expect(notifier.state.importResult!.skippedCount, equals(0));
      });

      test('error field is set alongside importResult on failure', () async {
        final bundle = buildBundle(diveItems: [makeItem('Dive 1')]);
        notifier.setBundle(bundle);

        when(
          mockAdapter.performImport(
            any,
            any,
            any,
            retainSourceDiveNumbers: anyNamed('retainSourceDiveNumbers'),
            onProgress: anyNamed('onProgress'),
          ),
        ).thenThrow(Exception('IO failure'));

        await notifier.performImport();

        // Both error and importResult should be populated.
        expect(notifier.state.error, contains('Import failed'));
        expect(notifier.state.importResult, isNotNull);
        expect(notifier.state.importResult!.errorMessage, isNotNull);
        expect(notifier.state.isImporting, isFalse);
      });

      test('applies import tags to all imported dives after import', () async {
        final bundle = buildBundle(diveItems: [makeItem('Dive 1')]);
        notifier.setBundle(bundle);

        const tag = TagSelection(name: 'Vacation');
        notifier.addImportTag(tag);

        const importResult = UnifiedImportResult(
          importedCounts: {ImportEntityType.dives: 1},
          consolidatedCount: 0,
          skippedCount: 0,
          importedDiveIds: ['dive-1'],
        );

        when(
          mockAdapter.performImport(
            any,
            any,
            any,
            retainSourceDiveNumbers: anyNamed('retainSourceDiveNumbers'),
            onProgress: anyNamed('onProgress'),
          ),
        ).thenAnswer((_) async => importResult);

        when(
          mockTagRepo.getOrCreateTag('Vacation', diverId: 'diver-1'),
        ).thenAnswer(
          (_) async => Tag(
            id: 'tag-new',
            name: 'Vacation',
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        );
        when(mockTagRepo.addTagToDive(any, any)).thenAnswer((_) async {});

        await notifier.performImport();

        verify(
          mockTagRepo.getOrCreateTag('Vacation', diverId: 'diver-1'),
        ).called(1);
        verify(mockTagRepo.addTagToDive('dive-1', 'tag-new')).called(1);
      });

      test(
        'uses existing tag ID directly without calling getOrCreateTag',
        () async {
          final bundle = buildBundle(diveItems: [makeItem('Dive 1')]);
          notifier.setBundle(bundle);

          const tag = TagSelection(
            existingTagId: 'tag-existing',
            name: 'Existing',
          );
          notifier.addImportTag(tag);

          const importResult = UnifiedImportResult(
            importedCounts: {ImportEntityType.dives: 1},
            consolidatedCount: 0,
            skippedCount: 0,
            importedDiveIds: ['dive-1'],
          );

          when(
            mockAdapter.performImport(
              any,
              any,
              any,
              retainSourceDiveNumbers: anyNamed('retainSourceDiveNumbers'),
              onProgress: anyNamed('onProgress'),
            ),
          ).thenAnswer((_) async => importResult);

          when(mockTagRepo.addTagToDive(any, any)).thenAnswer((_) async {});

          await notifier.performImport();

          verifyNever(mockTagRepo.getOrCreateTag(any));
          verify(mockTagRepo.addTagToDive('dive-1', 'tag-existing')).called(1);
        },
      );

      test('skips tag application when importTags is empty', () async {
        final bundle = buildBundle(diveItems: [makeItem('Dive 1')]);
        notifier.setBundle(bundle);

        const importResult = UnifiedImportResult(
          importedCounts: {ImportEntityType.dives: 1},
          consolidatedCount: 0,
          skippedCount: 0,
          importedDiveIds: ['dive-1'],
        );

        when(
          mockAdapter.performImport(
            any,
            any,
            any,
            retainSourceDiveNumbers: anyNamed('retainSourceDiveNumbers'),
            onProgress: anyNamed('onProgress'),
          ),
        ).thenAnswer((_) async => importResult);

        await notifier.performImport();

        verifyNever(mockTagRepo.getOrCreateTag(any));
        verifyNever(mockTagRepo.addTagToDive(any, any));
      });
    });

    // -------------------------------------------------------------------------
    // reset
    // -------------------------------------------------------------------------

    group('reset', () {
      test('returns to initial state', () {
        final bundle = buildBundle(diveItems: [makeItem('Dive 1')]);
        notifier.setBundle(bundle);
        expect(notifier.state.bundle, isNotNull);

        notifier.reset();

        expect(notifier.state.bundle, isNull);
        expect(notifier.state.currentStep, equals(0));
        expect(notifier.state.selections, isEmpty);
        expect(notifier.state.duplicateActions, isEmpty);
        expect(notifier.state.isImporting, isFalse);
        expect(notifier.state.importResult, isNull);
        expect(notifier.state.error, isNull);
        expect(notifier.state.importTags, isEmpty);
      });
    });

    // -------------------------------------------------------------------------
    // Import tags
    // -------------------------------------------------------------------------

    group('initializeDefaultTag', () {
      test('adds default tag from adapter when bundle is set', () {
        when(
          mockAdapter.defaultTagName,
        ).thenReturn('test.uddf Import 2026-03-26');
        final bundle = buildBundle(diveItems: [makeItem('Dive 1')]);
        notifier.setBundle(bundle);

        notifier.initializeDefaultTag();

        expect(notifier.state.importTags.length, equals(1));
        expect(
          notifier.state.importTags.first.name,
          equals('test.uddf Import 2026-03-26'),
        );
        expect(notifier.state.importTags.first.isNew, isTrue);
      });

      test('does not add duplicate default tag on repeated calls', () {
        when(
          mockAdapter.defaultTagName,
        ).thenReturn('test.uddf Import 2026-03-26');
        final bundle = buildBundle(diveItems: [makeItem('Dive 1')]);
        notifier.setBundle(bundle);

        notifier.initializeDefaultTag();
        notifier.initializeDefaultTag();

        expect(notifier.state.importTags.length, equals(1));
      });
    });

    group('addImportTag', () {
      test('appends a tag to the list', () {
        const tag = TagSelection(name: 'Vacation');
        notifier.addImportTag(tag);

        expect(notifier.state.importTags, contains(tag));
      });

      test('ignores duplicate tag names case-insensitively', () {
        const tag1 = TagSelection(name: 'Vacation');
        const tag2 = TagSelection(name: 'vacation');
        notifier.addImportTag(tag1);
        notifier.addImportTag(tag2);

        expect(notifier.state.importTags.length, equals(1));
      });

      test('allows tags with different names', () {
        const tag1 = TagSelection(name: 'Vacation');
        const tag2 = TagSelection(name: 'Training');
        notifier.addImportTag(tag1);
        notifier.addImportTag(tag2);

        expect(notifier.state.importTags.length, equals(2));
      });
    });

    group('removeImportTag', () {
      test('removes tag at given index', () {
        const tag1 = TagSelection(name: 'Vacation');
        const tag2 = TagSelection(name: 'Training');
        notifier.addImportTag(tag1);
        notifier.addImportTag(tag2);

        notifier.removeImportTag(0);

        expect(notifier.state.importTags.length, equals(1));
        expect(notifier.state.importTags.first.name, equals('Training'));
      });

      test('no-op for out of range index', () {
        const tag = TagSelection(name: 'Vacation');
        notifier.addImportTag(tag);

        notifier.removeImportTag(5);

        expect(notifier.state.importTags.length, equals(1));
      });
    });

    // -------------------------------------------------------------------------
    // State immutability
    // -------------------------------------------------------------------------

    group('state immutability', () {
      test('toggleSelection returns a new state instance', () {
        final bundle = buildBundle(diveItems: [makeItem('Dive 1')]);
        notifier.setBundle(bundle);
        final before = notifier.state;

        notifier.toggleSelection(ImportEntityType.dives, 0);

        expect(notifier.state, isNot(same(before)));
      });
    });
  });

  // ---------------------------------------------------------------------------
  // setBundle populates pendingDuplicateReview
  // ---------------------------------------------------------------------------

  group('setBundle populates pendingDuplicateReview', () {
    test('probable dive duplicate goes into pending, NOT duplicateActions', () {
      final bundle = _bundleWithProbableDiveDuplicate(index: 0);
      final container = ProviderContainer(
        overrides: [
          importWizardNotifierProvider.overrideWith(
            (ref) => ImportWizardNotifier(_TestAdapter()),
          ),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(importWizardNotifierProvider.notifier);

      notifier.setBundle(bundle);

      final state = container.read(importWizardNotifierProvider);
      expect(state.pendingFor(ImportEntityType.dives), {0});
      expect(
        state.duplicateActions[ImportEntityType.dives],
        anyOf(isNull, isEmpty),
      );
      expect(state.selections[ImportEntityType.dives], isNot(contains(0)));
    });

    test('possible dive duplicate goes into pending, NOT duplicateActions', () {
      final bundle = _bundleWithPossibleDiveDuplicate(index: 0);
      final container = ProviderContainer(
        overrides: [
          importWizardNotifierProvider.overrideWith(
            (ref) => ImportWizardNotifier(_TestAdapter()),
          ),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(importWizardNotifierProvider.notifier);

      notifier.setBundle(bundle);

      final state = container.read(importWizardNotifierProvider);
      expect(state.pendingFor(ImportEntityType.dives), {0});
      expect(
        state.duplicateActions[ImportEntityType.dives],
        anyOf(isNull, isEmpty),
      );
      expect(state.selections[ImportEntityType.dives], isNot(contains(0)));
    });

    test('non-dive (unscored) duplicate goes into pending', () {
      final bundle = _bundleWithUnscoredSiteDuplicate(index: 0);
      final container = ProviderContainer(
        overrides: [
          importWizardNotifierProvider.overrideWith(
            (ref) => ImportWizardNotifier(_TestAdapter()),
          ),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(importWizardNotifierProvider.notifier);

      notifier.setBundle(bundle);

      final state = container.read(importWizardNotifierProvider);
      expect(state.pendingFor(ImportEntityType.sites), {0});
      expect(state.selections[ImportEntityType.sites], isNot(contains(0)));
    });

    test('non-duplicate rows are NOT pending and ARE selected', () {
      final bundle = _bundleWithOneCleanAndOneDuplicateDive();
      final container = ProviderContainer(
        overrides: [
          importWizardNotifierProvider.overrideWith(
            (ref) => ImportWizardNotifier(_TestAdapter()),
          ),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(importWizardNotifierProvider.notifier);

      notifier.setBundle(bundle);

      final state = container.read(importWizardNotifierProvider);
      // Index 0 = clean (selected), index 1 = duplicate (pending)
      expect(state.selections[ImportEntityType.dives], contains(0));
      expect(state.pendingFor(ImportEntityType.dives), {1});
    });

    test('empty duplicates produce empty pending', () {
      final bundle = _bundleWithOneCleanDive();
      final container = ProviderContainer(
        overrides: [
          importWizardNotifierProvider.overrideWith(
            (ref) => ImportWizardNotifier(_TestAdapter()),
          ),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(importWizardNotifierProvider.notifier);

      notifier.setBundle(bundle);

      final state = container.read(importWizardNotifierProvider);
      expect(state.hasPendingReviews, isFalse);
      expect(state.totalPending, 0);
    });
  });

  group('setDuplicateAction drains pending', () {
    test('skip drains pending and syncs selections', () async {
      final bundle = _bundleWithProbableDiveDuplicate(index: 0);
      final container = ProviderContainer(
        overrides: [
          importWizardNotifierProvider.overrideWith(
            (ref) => ImportWizardNotifier(_TestAdapter()),
          ),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(importWizardNotifierProvider.notifier);
      notifier.setBundle(bundle);

      notifier.setDuplicateAction(
        ImportEntityType.dives,
        0,
        DuplicateAction.skip,
      );

      final state = container.read(importWizardNotifierProvider);
      expect(state.pendingFor(ImportEntityType.dives), isEmpty);
      expect(
        state.duplicateActions[ImportEntityType.dives]?[0],
        DuplicateAction.skip,
      );
      expect(state.selections[ImportEntityType.dives], isNot(contains(0)));
    });

    test('importAsNew drains pending and selects', () async {
      final bundle = _bundleWithProbableDiveDuplicate(index: 0);
      final container = ProviderContainer(
        overrides: [
          importWizardNotifierProvider.overrideWith(
            (ref) => ImportWizardNotifier(_TestAdapter()),
          ),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(importWizardNotifierProvider.notifier);
      notifier.setBundle(bundle);

      notifier.setDuplicateAction(
        ImportEntityType.dives,
        0,
        DuplicateAction.importAsNew,
      );

      final state = container.read(importWizardNotifierProvider);
      expect(state.pendingFor(ImportEntityType.dives), isEmpty);
      expect(
        state.duplicateActions[ImportEntityType.dives]?[0],
        DuplicateAction.importAsNew,
      );
      expect(state.selections[ImportEntityType.dives], contains(0));
    });

    test('consolidate drains pending and selects', () async {
      final bundle = _bundleWithProbableDiveDuplicate(index: 0);
      final container = ProviderContainer(
        overrides: [
          importWizardNotifierProvider.overrideWith(
            (ref) => ImportWizardNotifier(_TestAdapter()),
          ),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(importWizardNotifierProvider.notifier);
      notifier.setBundle(bundle);

      notifier.setDuplicateAction(
        ImportEntityType.dives,
        0,
        DuplicateAction.consolidate,
      );

      final state = container.read(importWizardNotifierProvider);
      expect(state.pendingFor(ImportEntityType.dives), isEmpty);
      expect(
        state.duplicateActions[ImportEntityType.dives]?[0],
        DuplicateAction.consolidate,
      );
      expect(state.selections[ImportEntityType.dives], contains(0));
    });
  });

  group('toggleSelection drains pending', () {
    test('toggleSelection on a pending index drains it', () async {
      final bundle = _bundleWithProbableDiveDuplicate(index: 0);
      final container = ProviderContainer(
        overrides: [
          importWizardNotifierProvider.overrideWith(
            (ref) => ImportWizardNotifier(_TestAdapter()),
          ),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(importWizardNotifierProvider.notifier);
      notifier.setBundle(bundle);

      notifier.toggleSelection(ImportEntityType.dives, 0);

      final state = container.read(importWizardNotifierProvider);
      expect(state.pendingFor(ImportEntityType.dives), isEmpty);
      expect(state.selections[ImportEntityType.dives], contains(0));
    });

    test(
      'toggleSelection on a non-pending index does not change pending',
      () async {
        final bundle = _bundleWithOneCleanAndOneDuplicateDive();
        final container = ProviderContainer(
          overrides: [
            importWizardNotifierProvider.overrideWith(
              (ref) => ImportWizardNotifier(_TestAdapter()),
            ),
          ],
        );
        addTearDown(container.dispose);
        final notifier = container.read(importWizardNotifierProvider.notifier);
        notifier.setBundle(bundle);

        // index 0 = clean (selected), index 1 = pending duplicate
        notifier.toggleSelection(ImportEntityType.dives, 0);

        final state = container.read(importWizardNotifierProvider);
        expect(
          state.pendingFor(ImportEntityType.dives),
          {1},
          reason: 'Pending for duplicate should be unchanged',
        );
        expect(state.selections[ImportEntityType.dives], isNot(contains(0)));
      },
    );
  });

  group('applyBulkAction', () {
    ImportBundle bundleWithTwoPendingDives() {
      return const ImportBundle(
        source: ImportSourceInfo(
          type: ImportSourceType.uddf,
          displayName: 'two-pending.uddf',
        ),
        groups: {
          ImportEntityType.dives: EntityGroup(
            items: [
              EntityItem(title: 'Dive 1', subtitle: ''),
              EntityItem(title: 'Dive 2', subtitle: ''),
            ],
            duplicateIndices: {0, 1},
            matchResults: {
              0: DiveMatchResult(
                diveId: 'e1',
                score: 0.9,
                timeDifferenceMs: 0,
                depthDifferenceMeters: 0.0,
                durationDifferenceSeconds: 0,
              ),
              1: DiveMatchResult(
                diveId: 'e2',
                score: 0.9,
                timeDifferenceMs: 0,
                depthDifferenceMeters: 0.0,
                durationDifferenceSeconds: 0,
              ),
            },
          ),
        },
      );
    }

    ImportBundle bundleWithMixedConfidenceDives() {
      return const ImportBundle(
        source: ImportSourceInfo(
          type: ImportSourceType.uddf,
          displayName: 'mixed-confidence.uddf',
        ),
        groups: {
          ImportEntityType.dives: EntityGroup(
            items: [
              EntityItem(title: 'Dive 1', subtitle: ''),
              EntityItem(title: 'Dive 2', subtitle: ''),
            ],
            duplicateIndices: {0, 1},
            matchResults: {
              0: DiveMatchResult(
                diveId: 'e1',
                score: 0.9, // probable
                timeDifferenceMs: 0,
                depthDifferenceMeters: 0.0,
                durationDifferenceSeconds: 0,
              ),
              1: DiveMatchResult(
                diveId: 'e2',
                score: 0.55, // possible (weak)
                timeDifferenceMs: 600000,
                depthDifferenceMeters: 3.0,
                durationDifferenceSeconds: 480,
              ),
            },
          ),
        },
      );
    }

    test('skip drains all pending for type and sets resolutions', () async {
      final bundle = bundleWithTwoPendingDives();
      final container = ProviderContainer(
        overrides: [
          importWizardNotifierProvider.overrideWith(
            (ref) => ImportWizardNotifier(_TestAdapter()),
          ),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(importWizardNotifierProvider.notifier);
      notifier.setBundle(bundle);

      notifier.applyBulkAction(ImportEntityType.dives, DuplicateAction.skip);

      final state = container.read(importWizardNotifierProvider);
      expect(state.pendingFor(ImportEntityType.dives), isEmpty);
      expect(
        state.duplicateActions[ImportEntityType.dives]?[0],
        DuplicateAction.skip,
      );
      expect(
        state.duplicateActions[ImportEntityType.dives]?[1],
        DuplicateAction.skip,
      );
      expect(state.selections[ImportEntityType.dives], isNot(contains(0)));
      expect(state.selections[ImportEntityType.dives], isNot(contains(1)));
    });

    test('importAsNew drains all pending and selects them', () async {
      final bundle = bundleWithTwoPendingDives();
      final container = ProviderContainer(
        overrides: [
          importWizardNotifierProvider.overrideWith(
            (ref) => ImportWizardNotifier(_TestAdapter()),
          ),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(importWizardNotifierProvider.notifier);
      notifier.setBundle(bundle);

      notifier.applyBulkAction(
        ImportEntityType.dives,
        DuplicateAction.importAsNew,
      );

      final state = container.read(importWizardNotifierProvider);
      expect(state.pendingFor(ImportEntityType.dives), isEmpty);
      expect(
        state.duplicateActions[ImportEntityType.dives]?[0],
        DuplicateAction.importAsNew,
      );
      expect(
        state.duplicateActions[ImportEntityType.dives]?[1],
        DuplicateAction.importAsNew,
      );
      expect(state.selections[ImportEntityType.dives], contains(0));
      expect(state.selections[ImportEntityType.dives], contains(1));
    });

    test(
      'consolidate drains only probable matches, leaves weak pending',
      () async {
        final bundle = bundleWithMixedConfidenceDives();
        final container = ProviderContainer(
          overrides: [
            importWizardNotifierProvider.overrideWith(
              (ref) => ImportWizardNotifier(_TestAdapter()),
            ),
          ],
        );
        addTearDown(container.dispose);
        final notifier = container.read(importWizardNotifierProvider.notifier);
        notifier.setBundle(bundle);

        notifier.applyBulkAction(
          ImportEntityType.dives,
          DuplicateAction.consolidate,
        );

        final state = container.read(importWizardNotifierProvider);
        expect(
          state.pendingFor(ImportEntityType.dives),
          {1},
          reason: 'Weak match (score 0.55) should remain pending',
        );
        expect(
          state.duplicateActions[ImportEntityType.dives]?[0],
          DuplicateAction.consolidate,
        );
        expect(
          state.duplicateActions[ImportEntityType.dives]?.containsKey(1),
          isFalse,
          reason: 'Weak match should not have a recorded action',
        );
      },
    );

    test('no-op when pending for type is empty', () async {
      final bundle = bundleWithTwoPendingDives();
      final container = ProviderContainer(
        overrides: [
          importWizardNotifierProvider.overrideWith(
            (ref) => ImportWizardNotifier(_TestAdapter()),
          ),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(importWizardNotifierProvider.notifier);
      notifier.setBundle(bundle);

      // First drain all pending via bulk skip.
      notifier.applyBulkAction(ImportEntityType.dives, DuplicateAction.skip);
      // Pending is now empty — second call must be a no-op and NOT
      // overwrite the recorded skip action.
      notifier.applyBulkAction(
        ImportEntityType.dives,
        DuplicateAction.importAsNew,
      );

      final state = container.read(importWizardNotifierProvider);
      expect(
        state.duplicateActions[ImportEntityType.dives]?[0],
        DuplicateAction.skip,
        reason: 'Second bulk call should be a no-op once pending is empty',
      );
    });

    test('non-dive bulk action drains pending and updates selection', () async {
      final bundle = _bundleWithUnscoredSiteDuplicate(index: 0);
      final container = ProviderContainer(
        overrides: [
          importWizardNotifierProvider.overrideWith(
            (ref) => ImportWizardNotifier(_TestAdapter()),
          ),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(importWizardNotifierProvider.notifier);
      notifier.setBundle(bundle);

      notifier.applyBulkAction(
        ImportEntityType.sites,
        DuplicateAction.importAsNew,
      );

      final state = container.read(importWizardNotifierProvider);
      expect(state.pendingFor(ImportEntityType.sites), isEmpty);
      expect(state.selections[ImportEntityType.sites], contains(0));
    });
  });

  group('firstPendingLocation', () {
    ImportBundle bundleWithDiveAndSiteDuplicates() {
      return const ImportBundle(
        source: ImportSourceInfo(
          type: ImportSourceType.uddf,
          displayName: 'dive-and-site-dupes.uddf',
        ),
        groups: {
          ImportEntityType.dives: EntityGroup(
            items: [EntityItem(title: 'Dive 1', subtitle: '')],
            duplicateIndices: {0},
            matchResults: {
              0: DiveMatchResult(
                diveId: 'e1',
                score: 0.9,
                timeDifferenceMs: 0,
                depthDifferenceMeters: 0.0,
                durationDifferenceSeconds: 0,
              ),
            },
          ),
          ImportEntityType.sites: EntityGroup(
            items: [EntityItem(title: 'Site A', subtitle: '')],
            duplicateIndices: {0},
          ),
        },
      );
    }

    test('returns null when nothing pending', () {
      final container = ProviderContainer(
        overrides: [
          importWizardNotifierProvider.overrideWith(
            (ref) => ImportWizardNotifier(_TestAdapter()),
          ),
        ],
      );
      addTearDown(container.dispose);

      final loc = container
          .read(importWizardNotifierProvider.notifier)
          .firstPendingLocation();
      expect(loc, isNull);
    });

    test('returns first pending dive when dives have pending', () {
      final bundle = _bundleWithProbableDiveDuplicate(index: 0);
      final container = ProviderContainer(
        overrides: [
          importWizardNotifierProvider.overrideWith(
            (ref) => ImportWizardNotifier(_TestAdapter()),
          ),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(importWizardNotifierProvider.notifier);
      notifier.setBundle(bundle);

      final loc = notifier.firstPendingLocation();

      expect(loc, isNotNull);
      expect(loc!.type, ImportEntityType.dives);
      expect(loc.index, 0);
    });

    test('returns sites location after dive pending is drained', () {
      final bundle = bundleWithDiveAndSiteDuplicates();
      final container = ProviderContainer(
        overrides: [
          importWizardNotifierProvider.overrideWith(
            (ref) => ImportWizardNotifier(_TestAdapter()),
          ),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(importWizardNotifierProvider.notifier);
      notifier.setBundle(bundle);

      // Sanity: dives is the first pending tab before draining.
      final before = notifier.firstPendingLocation();
      expect(before, isNotNull);
      expect(before!.type, ImportEntityType.dives);

      // Drain all dive pending via bulk skip.
      notifier.applyBulkAction(ImportEntityType.dives, DuplicateAction.skip);

      final after = notifier.firstPendingLocation();
      expect(after, isNotNull);
      expect(after!.type, ImportEntityType.sites);
      expect(after.index, 0);
    });
  });
}
