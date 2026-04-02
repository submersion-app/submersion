import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/features/import_wizard/domain/adapters/import_source_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/models/import_phase.dart';
import 'package:submersion/features/import_wizard/domain/models/tag_selection.dart';
import 'package:submersion/features/import_wizard/domain/models/unified_import_result.dart';
import 'package:submersion/features/import_wizard/presentation/providers/import_wizard_providers.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

@GenerateNiceMocks([MockSpec<ImportSourceAdapter>(), MockSpec<TagRepository>()])
import 'import_wizard_notifier_test.mocks.dart';

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

      test('initializes duplicate actions: score >= 0.7 gets skip', () {
        final bundle = buildBundle(
          diveItems: [makeItem('Dive 1')],
          diveDuplicateIndices: {0},
          diveMatchResults: {0: makeMatchResult(0.85)},
        );

        notifier.setBundle(bundle);

        final actions =
            notifier.state.duplicateActions[ImportEntityType.dives]!;
        expect(actions[0], equals(DuplicateAction.skip));
      });

      test(
        'initializes duplicate actions: score >= 0.5 and < 0.7 gets importAsNew',
        () {
          final bundle = buildBundle(
            diveItems: [makeItem('Dive 1')],
            diveDuplicateIndices: {0},
            diveMatchResults: {0: makeMatchResult(0.6)},
          );

          notifier.setBundle(bundle);

          final actions =
              notifier.state.duplicateActions[ImportEntityType.dives]!;
          expect(actions[0], equals(DuplicateAction.importAsNew));
        },
      );

      test('initializes duplicate actions: exactly 0.7 gets skip', () {
        final bundle = buildBundle(
          diveItems: [makeItem('Dive 1')],
          diveDuplicateIndices: {0},
          diveMatchResults: {0: makeMatchResult(0.7)},
        );

        notifier.setBundle(bundle);

        final actions =
            notifier.state.duplicateActions[ImportEntityType.dives]!;
        expect(actions[0], equals(DuplicateAction.skip));
      });

      test('handles bundle with no duplicates — empty duplicateActions', () {
        final bundle = buildBundle(
          diveItems: [makeItem('Dive 1'), makeItem('Dive 2')],
        );

        notifier.setBundle(bundle);

        final actions = notifier.state.duplicateActions[ImportEntityType.dives];
        // No match results → no duplicate actions needed
        expect(actions, isNull);
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
        // Initially skip (score >= 0.7)
        expect(
          notifier.state.duplicateActions[ImportEntityType.dives]![0],
          equals(DuplicateAction.skip),
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

        expect(
          notifier.state.duplicateActions[ImportEntityType.dives]![1],
          equals(DuplicateAction.skip),
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
}
