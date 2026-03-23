import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/import_wizard/domain/adapters/import_source_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/models/unified_import_result.dart';
import 'package:submersion/features/import_wizard/domain/models/wizard_step_def.dart';
import 'package:submersion/features/import_wizard/presentation/providers/import_wizard_providers.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/import_summary_step.dart';

// ---------------------------------------------------------------------------
// Fake adapter
// ---------------------------------------------------------------------------

class _FakeAdapter implements ImportSourceAdapter {
  @override
  ImportSourceType get sourceType => ImportSourceType.uddf;

  @override
  String get displayName => 'test.uddf';

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
    void Function(String phase, int current, int total)? onProgress,
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
    overrides: [importWizardProvider.overrideWith((_) => notifier)],
    child: MaterialApp(
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
}
