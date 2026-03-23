import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/import_wizard/domain/adapters/import_source_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/models/unified_import_result.dart';
import 'package:submersion/features/import_wizard/domain/models/wizard_step_def.dart';
import 'package:submersion/features/import_wizard/presentation/providers/import_wizard_providers.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/import_progress_step.dart';

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

Widget _buildWidget(ImportWizardNotifier notifier) {
  return ProviderScope(
    overrides: [importWizardProvider.overrideWith((_) => notifier)],
    child: const MaterialApp(home: Scaffold(body: ImportProgressStep())),
  );
}

ImportWizardNotifier _makeNotifier() => ImportWizardNotifier(_FakeAdapter());

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ImportProgressStep', () {
    setUp(() async {
      // Nothing shared between tests.
    });

    testWidgets('shows default phase text when no phase is set', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final notifier = _makeNotifier();

      await tester.pumpWidget(_buildWidget(notifier));
      await tester.pump();

      expect(
        find.byKey(const Key('import_progress_phase_text')),
        findsOneWidget,
      );
      expect(find.text('Importing...'), findsOneWidget);
    });

    testWidgets('shows import phase name from state', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final notifier = _makeNotifier();
      notifier.state = notifier.state.copyWith(importPhase: 'dives');

      await tester.pumpWidget(_buildWidget(notifier));
      await tester.pump();

      expect(find.text('Importing dives...'), findsOneWidget);
    });

    testWidgets('renders circular progress indicator', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final notifier = _makeNotifier();

      await tester.pumpWidget(_buildWidget(notifier));
      await tester.pump();

      expect(find.byKey(const Key('import_progress_circular')), findsOneWidget);
    });

    testWidgets('renders linear progress bar', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final notifier = _makeNotifier();

      await tester.pumpWidget(_buildWidget(notifier));
      await tester.pump();

      expect(find.byKey(const Key('import_progress_linear')), findsOneWidget);
    });

    testWidgets('shows count text when total > 0', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final notifier = _makeNotifier();
      notifier.state = notifier.state.copyWith(
        importPhase: 'dives',
        importCurrent: 8,
        importTotal: 12,
      );

      await tester.pumpWidget(_buildWidget(notifier));
      await tester.pump();

      expect(find.text('8 of 12'), findsOneWidget);
    });

    testWidgets('hides count text when total is 0', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final notifier = _makeNotifier();
      // importTotal defaults to 0

      await tester.pumpWidget(_buildWidget(notifier));
      await tester.pump();

      expect(find.byKey(const Key('import_progress_count_text')), findsNothing);
    });

    testWidgets('shows percentage when total > 0', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final notifier = _makeNotifier();
      notifier.state = notifier.state.copyWith(
        importCurrent: 4,
        importTotal: 8,
      );

      await tester.pumpWidget(_buildWidget(notifier));
      await tester.pump();

      expect(find.text('50%'), findsOneWidget);
    });

    testWidgets('circular indicator has no value when total is 0', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final notifier = _makeNotifier();

      await tester.pumpWidget(_buildWidget(notifier));
      await tester.pump();

      final indicator = tester.widget<CircularProgressIndicator>(
        find.byKey(const Key('import_progress_circular')),
      );
      // Indeterminate when total is 0
      expect(indicator.value, isNull);
    });

    testWidgets('circular indicator has value when total > 0', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final notifier = _makeNotifier();
      notifier.state = notifier.state.copyWith(
        importCurrent: 3,
        importTotal: 12,
      );

      await tester.pumpWidget(_buildWidget(notifier));
      await tester.pump();

      final indicator = tester.widget<CircularProgressIndicator>(
        find.byKey(const Key('import_progress_circular')),
      );
      expect(indicator.value, closeTo(0.25, 0.001));
    });
  });
}
