import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import 'package:submersion/features/import_wizard/domain/adapters/import_source_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/models/import_phase.dart';
import 'package:submersion/features/import_wizard/domain/models/unified_import_result.dart';
import 'package:submersion/features/import_wizard/domain/models/wizard_step_def.dart';
import 'package:submersion/features/import_wizard/presentation/providers/import_wizard_providers.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/import_summary_step.dart';

// ---------------------------------------------------------------------------
// Fake adapter
// ---------------------------------------------------------------------------

class _FakeAdapter implements ImportSourceAdapter {
  @override
  void resetState() {}

  @override
  ImportSourceType get sourceType => ImportSourceType.uddf;

  @override
  String get displayName => 'test.uddf';

  @override
  String get defaultTagName => 'test.uddf Import 2026-03-26';

  @override
  List<WizardStepDef> get acquisitionSteps => [];

  @override
  Set<DuplicateAction> get supportedDuplicateActions => {
    DuplicateAction.skip,
    DuplicateAction.importAsNew,
  };

  @override
  Future<ImportBundle> buildBundle() => throw UnimplementedError();

  @override
  Future<ImportBundle> checkDuplicates(ImportBundle bundle) =>
      throw UnimplementedError();

  @override
  Future<UnifiedImportResult> performImport(
    ImportBundle bundle,
    Map<ImportEntityType, Set<int>> selections,
    Map<ImportEntityType, Map<int, DuplicateAction>> duplicateActions, {
    bool retainSourceDiveNumbers = false,
    ImportProgressCallback? onProgress,
  }) => throw UnimplementedError();
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

Widget _buildWidget(
  ImportWizardNotifier notifier, {
  VoidCallback? onDone,
  VoidCallback? onViewDives,
}) {
  return ProviderScope(
    overrides: [importWizardNotifierProvider.overrideWith((_) => notifier)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ImportSummaryStep(
          onDone: onDone ?? () {},
          onViewDives: onViewDives ?? () {},
        ),
      ),
    ),
  );
}

ImportWizardNotifier _makeNotifier() => ImportWizardNotifier(_FakeAdapter());

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ImportSummaryStep - loading state', () {
    testWidgets('shows CircularProgressIndicator when importResult is null', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final notifier = _makeNotifier();
      // importResult is null by default

      await tester.pumpWidget(_buildWidget(notifier));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('ImportSummaryStep - success state', () {
    testWidgets('shows success title', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final notifier = _makeNotifier();
      notifier.state = notifier.state.copyWith(
        importResult: const UnifiedImportResult(
          importedCounts: {ImportEntityType.dives: 5},
          consolidatedCount: 0,
          skippedCount: 0,
        ),
      );

      await tester.pumpWidget(_buildWidget(notifier));
      await tester.pump();

      expect(
        find.byKey(const Key('import_summary_success_title')),
        findsOneWidget,
      );
      expect(find.text('Successfully Imported'), findsOneWidget);
    });

    testWidgets('shows dive count row when dives > 0', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final notifier = _makeNotifier();
      notifier.state = notifier.state.copyWith(
        importResult: const UnifiedImportResult(
          importedCounts: {ImportEntityType.dives: 7},
          consolidatedCount: 0,
          skippedCount: 0,
        ),
      );

      await tester.pumpWidget(_buildWidget(notifier));
      await tester.pump();

      expect(find.text('Dives'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('shows sites count row when sites > 0', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final notifier = _makeNotifier();
      notifier.state = notifier.state.copyWith(
        importResult: const UnifiedImportResult(
          importedCounts: {ImportEntityType.sites: 3},
          consolidatedCount: 0,
          skippedCount: 0,
        ),
      );

      await tester.pumpWidget(_buildWidget(notifier));
      await tester.pump();

      expect(find.text('Sites'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('hides rows for entity types with count 0', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final notifier = _makeNotifier();
      notifier.state = notifier.state.copyWith(
        importResult: const UnifiedImportResult(
          importedCounts: {
            ImportEntityType.dives: 5,
            ImportEntityType.sites: 0,
          },
          consolidatedCount: 0,
          skippedCount: 0,
        ),
      );

      await tester.pumpWidget(_buildWidget(notifier));
      await tester.pump();

      expect(find.text('Dives'), findsOneWidget);
      expect(find.text('Sites'), findsNothing);
    });

    testWidgets('shows consolidated row when consolidatedCount > 0', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final notifier = _makeNotifier();
      notifier.state = notifier.state.copyWith(
        importResult: const UnifiedImportResult(
          importedCounts: {ImportEntityType.dives: 5},
          consolidatedCount: 2,
          skippedCount: 0,
        ),
      );

      await tester.pumpWidget(_buildWidget(notifier));
      await tester.pump();

      expect(
        find.byKey(const Key('import_summary_consolidated_row')),
        findsOneWidget,
      );
      expect(find.text('Consolidated'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('hides consolidated row when consolidatedCount is 0', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final notifier = _makeNotifier();
      notifier.state = notifier.state.copyWith(
        importResult: const UnifiedImportResult(
          importedCounts: {ImportEntityType.dives: 5},
          consolidatedCount: 0,
          skippedCount: 0,
        ),
      );

      await tester.pumpWidget(_buildWidget(notifier));
      await tester.pump();

      expect(
        find.byKey(const Key('import_summary_consolidated_row')),
        findsNothing,
      );
    });

    testWidgets('shows skipped row when skippedCount > 0', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final notifier = _makeNotifier();
      notifier.state = notifier.state.copyWith(
        importResult: const UnifiedImportResult(
          importedCounts: {ImportEntityType.dives: 5},
          consolidatedCount: 0,
          skippedCount: 4,
        ),
      );

      await tester.pumpWidget(_buildWidget(notifier));
      await tester.pump();

      expect(
        find.byKey(const Key('import_summary_skipped_row')),
        findsOneWidget,
      );
      expect(find.text('Skipped'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('hides skipped row when skippedCount is 0', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final notifier = _makeNotifier();
      notifier.state = notifier.state.copyWith(
        importResult: const UnifiedImportResult(
          importedCounts: {ImportEntityType.dives: 5},
          consolidatedCount: 0,
          skippedCount: 0,
        ),
      );

      await tester.pumpWidget(_buildWidget(notifier));
      await tester.pump();

      expect(find.byKey(const Key('import_summary_skipped_row')), findsNothing);
    });

    testWidgets('shows Done and View Dives buttons', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final notifier = _makeNotifier();
      notifier.state = notifier.state.copyWith(
        importResult: const UnifiedImportResult(
          importedCounts: {ImportEntityType.dives: 1},
          consolidatedCount: 0,
          skippedCount: 0,
        ),
      );

      await tester.pumpWidget(_buildWidget(notifier));
      await tester.pump();

      expect(find.text('Done'), findsOneWidget);
      expect(find.text('View Dives'), findsOneWidget);
    });

    testWidgets('tapping Done fires onDone callback', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var doneCalled = false;
      final notifier = _makeNotifier();
      notifier.state = notifier.state.copyWith(
        importResult: const UnifiedImportResult(
          importedCounts: {ImportEntityType.dives: 1},
          consolidatedCount: 0,
          skippedCount: 0,
        ),
      );

      await tester.pumpWidget(
        _buildWidget(notifier, onDone: () => doneCalled = true),
      );
      await tester.pump();

      await tester.tap(find.text('Done'));
      await tester.pump();

      expect(doneCalled, isTrue);
    });

    testWidgets('tapping View Dives fires onViewDives callback', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var viewDivesCalled = false;
      final notifier = _makeNotifier();
      notifier.state = notifier.state.copyWith(
        importResult: const UnifiedImportResult(
          importedCounts: {ImportEntityType.dives: 1},
          consolidatedCount: 0,
          skippedCount: 0,
        ),
      );

      await tester.pumpWidget(
        _buildWidget(notifier, onViewDives: () => viewDivesCalled = true),
      );
      await tester.pump();

      await tester.tap(find.text('View Dives'));
      await tester.pump();

      expect(viewDivesCalled, isTrue);
    });

    testWidgets('shows multiple entity type rows', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final notifier = _makeNotifier();
      notifier.state = notifier.state.copyWith(
        importResult: const UnifiedImportResult(
          importedCounts: {
            ImportEntityType.dives: 10,
            ImportEntityType.sites: 3,
            ImportEntityType.buddies: 2,
          },
          consolidatedCount: 1,
          skippedCount: 5,
        ),
      );

      await tester.pumpWidget(_buildWidget(notifier));
      await tester.pump();

      expect(find.text('Dives'), findsOneWidget);
      expect(find.text('Sites'), findsOneWidget);
      expect(find.text('Buddies'), findsOneWidget);
      expect(find.text('Consolidated'), findsOneWidget);
      expect(find.text('Skipped'), findsOneWidget);
    });
  });

  group('ImportSummaryStep - error state', () {
    testWidgets('shows error message when errorMessage is set', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final notifier = _makeNotifier();
      notifier.state = notifier.state.copyWith(
        importResult: const UnifiedImportResult(
          importedCounts: {},
          consolidatedCount: 0,
          skippedCount: 0,
          errorMessage: 'Failed to connect to database',
        ),
      );

      await tester.pumpWidget(_buildWidget(notifier));
      await tester.pump();

      expect(
        find.byKey(const Key('import_summary_error_message')),
        findsOneWidget,
      );
      expect(find.text('Failed to connect to database'), findsOneWidget);
    });

    testWidgets('does not show success title in error state', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final notifier = _makeNotifier();
      notifier.state = notifier.state.copyWith(
        importResult: const UnifiedImportResult(
          importedCounts: {},
          consolidatedCount: 0,
          skippedCount: 0,
          errorMessage: 'Something went wrong',
        ),
      );

      await tester.pumpWidget(_buildWidget(notifier));
      await tester.pump();

      expect(find.text('Successfully Imported'), findsNothing);
    });

    testWidgets('shows Done button in error state', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final notifier = _makeNotifier();
      notifier.state = notifier.state.copyWith(
        importResult: const UnifiedImportResult(
          importedCounts: {},
          consolidatedCount: 0,
          skippedCount: 0,
          errorMessage: 'Something went wrong',
        ),
      );

      await tester.pumpWidget(_buildWidget(notifier));
      await tester.pump();

      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('does not show View Dives button in error state', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final notifier = _makeNotifier();
      notifier.state = notifier.state.copyWith(
        importResult: const UnifiedImportResult(
          importedCounts: {},
          consolidatedCount: 0,
          skippedCount: 0,
          errorMessage: 'Something went wrong',
        ),
      );

      await tester.pumpWidget(_buildWidget(notifier));
      await tester.pump();

      expect(find.text('View Dives'), findsNothing);
    });

    testWidgets('tapping Done in error state fires onDone callback', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var doneCalled = false;
      final notifier = _makeNotifier();
      notifier.state = notifier.state.copyWith(
        importResult: const UnifiedImportResult(
          importedCounts: {},
          consolidatedCount: 0,
          skippedCount: 0,
          errorMessage: 'Something went wrong',
        ),
      );

      await tester.pumpWidget(
        _buildWidget(notifier, onDone: () => doneCalled = true),
      );
      await tester.pump();

      await tester.tap(find.text('Done'));
      await tester.pump();

      expect(doneCalled, isTrue);
    });
  });

  group('ImportSummaryStep - state.error fallback (importResult is null)', () {
    testWidgets('shows error view when importResult is null but error is set', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final notifier = _makeNotifier();
      // Set error without setting importResult — this is the fallback path
      notifier.state = notifier.state.copyWith(error: 'Import failed: timeout');

      await tester.pumpWidget(_buildWidget(notifier));
      await tester.pump();

      expect(
        find.byKey(const Key('import_summary_error_message')),
        findsOneWidget,
      );
      expect(find.text('Import failed: timeout'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('error fallback shows Done button', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final notifier = _makeNotifier();
      notifier.state = notifier.state.copyWith(error: 'Connection lost');

      await tester.pumpWidget(_buildWidget(notifier));
      await tester.pump();

      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('error fallback does not show View Dives button', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final notifier = _makeNotifier();
      notifier.state = notifier.state.copyWith(error: 'Connection lost');

      await tester.pumpWidget(_buildWidget(notifier));
      await tester.pump();

      expect(find.text('View Dives'), findsNothing);
    });

    testWidgets('error fallback Done button fires onDone callback', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var doneCalled = false;
      final notifier = _makeNotifier();
      notifier.state = notifier.state.copyWith(error: 'Something broke');

      await tester.pumpWidget(
        _buildWidget(notifier, onDone: () => doneCalled = true),
      );
      await tester.pump();

      await tester.tap(find.text('Done'));
      await tester.pump();

      expect(doneCalled, isTrue);
    });

    testWidgets('error fallback shows error icon', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final notifier = _makeNotifier();
      notifier.state = notifier.state.copyWith(error: 'Some error occurred');

      await tester.pumpWidget(_buildWidget(notifier));
      await tester.pump();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });
  });

  group('ImportSummaryStep - no dives imported', () {
    testWidgets('shows No Dives Imported when all counts are zero', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final notifier = _makeNotifier();
      notifier.state = notifier.state.copyWith(
        importResult: const UnifiedImportResult(
          importedCounts: {},
          consolidatedCount: 0,
          skippedCount: 0,
        ),
      );

      await tester.pumpWidget(_buildWidget(notifier));
      await tester.pump();

      expect(find.text('No Dives Imported'), findsOneWidget);
      expect(find.text('Successfully Imported'), findsNothing);
    });

    testWidgets('hides View Dives button when no dives imported', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final notifier = _makeNotifier();
      notifier.state = notifier.state.copyWith(
        importResult: const UnifiedImportResult(
          importedCounts: {},
          consolidatedCount: 0,
          skippedCount: 0,
        ),
      );

      await tester.pumpWidget(_buildWidget(notifier));
      await tester.pump();

      expect(find.text('View Dives'), findsNothing);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('shows All dives were skipped when skippedCount > 0', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final notifier = _makeNotifier();
      notifier.state = notifier.state.copyWith(
        importResult: const UnifiedImportResult(
          importedCounts: {},
          consolidatedCount: 0,
          skippedCount: 10,
        ),
      );

      await tester.pumpWidget(_buildWidget(notifier));
      await tester.pump();

      expect(find.text('No Dives Imported'), findsOneWidget);
      expect(find.text('All dives were skipped.'), findsOneWidget);
    });

    testWidgets(
      'does not show All dives were skipped when there are imported dives',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final notifier = _makeNotifier();
        notifier.state = notifier.state.copyWith(
          importResult: const UnifiedImportResult(
            importedCounts: {ImportEntityType.dives: 3},
            consolidatedCount: 0,
            skippedCount: 5,
          ),
        );

        await tester.pumpWidget(_buildWidget(notifier));
        await tester.pump();

        expect(find.text('All dives were skipped.'), findsNothing);
      },
    );

    testWidgets('consolidated dives count as having new dives', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final notifier = _makeNotifier();
      notifier.state = notifier.state.copyWith(
        importResult: const UnifiedImportResult(
          importedCounts: {},
          consolidatedCount: 3,
          skippedCount: 0,
        ),
      );

      await tester.pumpWidget(_buildWidget(notifier));
      await tester.pump();

      // consolidatedCount > 0 means hasActivity is true
      expect(find.text('Successfully Consolidated'), findsOneWidget);
      expect(find.text('View Dives'), findsOneWidget);
    });
  });

  group('ImportSummaryStep - updated/replaced source data', () {
    testWidgets('shows Successfully Updated when only updatedCount > 0', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final notifier = _makeNotifier();
      notifier.state = notifier.state.copyWith(
        importResult: const UnifiedImportResult(
          importedCounts: {},
          consolidatedCount: 0,
          updatedCount: 3,
          skippedCount: 0,
        ),
      );

      await tester.pumpWidget(_buildWidget(notifier));
      await tester.pump();

      expect(
        find.byKey(const Key('import_summary_success_title')),
        findsOneWidget,
      );
      expect(find.text('Successfully Updated'), findsOneWidget);
    });

    testWidgets('shows Replaced source data row when updatedCount > 0', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final notifier = _makeNotifier();
      notifier.state = notifier.state.copyWith(
        importResult: const UnifiedImportResult(
          importedCounts: {},
          consolidatedCount: 0,
          updatedCount: 5,
          skippedCount: 0,
        ),
      );

      await tester.pumpWidget(_buildWidget(notifier));
      await tester.pump();

      expect(
        find.byKey(const Key('import_summary_updated_row')),
        findsOneWidget,
      );
      expect(find.text('Replaced source data'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('shows View Dives button when only updatedCount > 0', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final notifier = _makeNotifier();
      notifier.state = notifier.state.copyWith(
        importResult: const UnifiedImportResult(
          importedCounts: {},
          consolidatedCount: 0,
          updatedCount: 2,
          skippedCount: 0,
        ),
      );

      await tester.pumpWidget(_buildWidget(notifier));
      await tester.pump();

      expect(find.text('View Dives'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('hides updated row when updatedCount is 0', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final notifier = _makeNotifier();
      notifier.state = notifier.state.copyWith(
        importResult: const UnifiedImportResult(
          importedCounts: {ImportEntityType.dives: 3},
          consolidatedCount: 0,
          updatedCount: 0,
          skippedCount: 0,
        ),
      );

      await tester.pumpWidget(_buildWidget(notifier));
      await tester.pump();

      expect(find.byKey(const Key('import_summary_updated_row')), findsNothing);
    });

    testWidgets(
      'prefers Successfully Imported title when both imported and updated',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final notifier = _makeNotifier();
        notifier.state = notifier.state.copyWith(
          importResult: const UnifiedImportResult(
            importedCounts: {ImportEntityType.dives: 2},
            consolidatedCount: 0,
            updatedCount: 3,
            skippedCount: 0,
          ),
        );

        await tester.pumpWidget(_buildWidget(notifier));
        await tester.pump();

        expect(find.text('Successfully Imported'), findsOneWidget);
        expect(find.text('Successfully Updated'), findsNothing);
        // Both rows should appear
        expect(find.text('Dives'), findsOneWidget);
        expect(
          find.byKey(const Key('import_summary_updated_row')),
          findsOneWidget,
        );
      },
    );
  });

  group('ImportSummaryStep - entity type coverage', () {
    testWidgets('shows equipment row', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final notifier = _makeNotifier();
      notifier.state = notifier.state.copyWith(
        importResult: const UnifiedImportResult(
          importedCounts: {ImportEntityType.equipment: 4},
          consolidatedCount: 0,
          skippedCount: 0,
        ),
      );

      await tester.pumpWidget(_buildWidget(notifier));
      await tester.pump();

      expect(find.text('Equipment'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('shows tags row', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final notifier = _makeNotifier();
      notifier.state = notifier.state.copyWith(
        importResult: const UnifiedImportResult(
          importedCounts: {ImportEntityType.tags: 6},
          consolidatedCount: 0,
          skippedCount: 0,
        ),
      );

      await tester.pumpWidget(_buildWidget(notifier));
      await tester.pump();

      expect(find.text('Tags'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
    });

    testWidgets('shows trips row', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final notifier = _makeNotifier();
      notifier.state = notifier.state.copyWith(
        importResult: const UnifiedImportResult(
          importedCounts: {ImportEntityType.trips: 2},
          consolidatedCount: 0,
          skippedCount: 0,
        ),
      );

      await tester.pumpWidget(_buildWidget(notifier));
      await tester.pump();

      expect(find.text('Trips'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('shows certifications row', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final notifier = _makeNotifier();
      notifier.state = notifier.state.copyWith(
        importResult: const UnifiedImportResult(
          importedCounts: {ImportEntityType.certifications: 1},
          consolidatedCount: 0,
          skippedCount: 0,
        ),
      );

      await tester.pumpWidget(_buildWidget(notifier));
      await tester.pump();

      expect(find.text('Certifications'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('shows dive centers row', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final notifier = _makeNotifier();
      notifier.state = notifier.state.copyWith(
        importResult: const UnifiedImportResult(
          importedCounts: {ImportEntityType.diveCenters: 3},
          consolidatedCount: 0,
          skippedCount: 0,
        ),
      );

      await tester.pumpWidget(_buildWidget(notifier));
      await tester.pump();

      expect(find.text('Dive Centers'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('shows dive types row', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final notifier = _makeNotifier();
      notifier.state = notifier.state.copyWith(
        importResult: const UnifiedImportResult(
          importedCounts: {ImportEntityType.diveTypes: 5},
          consolidatedCount: 0,
          skippedCount: 0,
        ),
      );

      await tester.pumpWidget(_buildWidget(notifier));
      await tester.pump();

      expect(find.text('Dive Types'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('shows equipment sets row', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final notifier = _makeNotifier();
      notifier.state = notifier.state.copyWith(
        importResult: const UnifiedImportResult(
          importedCounts: {ImportEntityType.equipmentSets: 2},
          consolidatedCount: 0,
          skippedCount: 0,
        ),
      );

      await tester.pumpWidget(_buildWidget(notifier));
      await tester.pump();

      expect(find.text('Equipment Sets'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('shows courses row', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final notifier = _makeNotifier();
      notifier.state = notifier.state.copyWith(
        importResult: const UnifiedImportResult(
          importedCounts: {ImportEntityType.courses: 3},
          consolidatedCount: 0,
          skippedCount: 0,
        ),
      );

      await tester.pumpWidget(_buildWidget(notifier));
      await tester.pump();

      expect(find.text('Courses'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });
  });
}
