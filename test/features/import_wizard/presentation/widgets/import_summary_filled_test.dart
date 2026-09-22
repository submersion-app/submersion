import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_computer/data/services/planned_dive_fill_service.dart';
import 'package:submersion/features/dive_log/data/services/dive_merge_snapshot.dart';
import 'package:submersion/features/import_wizard/domain/adapters/import_source_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/models/import_cancellation_token.dart';
import 'package:submersion/features/import_wizard/domain/models/import_phase.dart';
import 'package:submersion/features/import_wizard/domain/models/unified_import_result.dart';
import 'package:submersion/features/import_wizard/presentation/providers/import_wizard_providers.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/import_summary_step.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/wizard/wizard_step_def.dart';

class _FakeAdapter implements ImportSourceAdapter {
  @override
  void resetState() {}

  @override
  ImportSourceType get sourceType => ImportSourceType.diveComputer;

  @override
  String get displayName => 'Perdix';

  @override
  String get defaultTagName => 'Perdix Import';

  @override
  List<WizardStepDef> get acquisitionSteps => [];

  @override
  Set<DuplicateAction> get supportedDuplicateActions => {
    DuplicateAction.skip,
    DuplicateAction.importAsNew,
    DuplicateAction.fillPlanned,
  };

  @override
  Set<DuplicateAction> duplicateActionsFor(ImportEntityType type) =>
      supportedDuplicateActions;

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
    ImportCancellationToken? cancelToken,
  }) => throw UnimplementedError();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

Widget _buildWidget(ImportWizardNotifier notifier) {
  return ProviderScope(
    overrides: [importWizardNotifierProvider.overrideWith((_) => notifier)],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ImportSummaryStep(onDone: () {}, onViewDives: () {}),
      ),
    ),
  );
}

void main() {
  Future<void> pumpWith(WidgetTester tester, UnifiedImportResult result) async {
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final notifier = ImportWizardNotifier(_FakeAdapter());
    notifier.state = notifier.state.copyWith(importResult: result);
    await tester.pumpWidget(_buildWidget(notifier));
    await tester.pump();
  }

  testWidgets('shows the filled row when filledCount > 0', (tester) async {
    await pumpWith(
      tester,
      const UnifiedImportResult(
        importedCounts: {ImportEntityType.dives: 0},
        consolidatedCount: 0,
        filledCount: 2,
        skippedCount: 0,
      ),
    );

    expect(find.byKey(const Key('import_summary_filled_row')), findsOneWidget);
    expect(find.text('Filled planned dives'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('a fill-only import counts as activity', (tester) async {
    await pumpWith(
      tester,
      const UnifiedImportResult(
        importedCounts: {ImportEntityType.dives: 0},
        consolidatedCount: 0,
        filledCount: 1,
        skippedCount: 0,
      ),
    );
    expect(find.text('Successfully Imported'), findsOneWidget);
  });

  testWidgets('hides the filled row when filledCount is 0', (tester) async {
    await pumpWith(
      tester,
      const UnifiedImportResult(
        importedCounts: {ImportEntityType.dives: 3},
        consolidatedCount: 0,
        skippedCount: 0,
      ),
    );
    expect(find.byKey(const Key('import_summary_filled_row')), findsNothing);
  });

  testWidgets('offers Undo fills when outcomes are present', (tester) async {
    await pumpWith(
      tester,
      const UnifiedImportResult(
        importedCounts: {ImportEntityType.dives: 0},
        consolidatedCount: 0,
        filledCount: 1,
        fillOutcomes: [
          PlannedDiveFillOutcome(
            diveId: 'p1',
            snapshot: DiveMergeSnapshot(
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
          ),
        ],
        skippedCount: 0,
      ),
    );
    expect(find.byKey(const Key('import_summary_undo_fills')), findsOneWidget);
    expect(find.text('Undo fills'), findsOneWidget);
  });

  testWidgets('no Undo fills without outcomes', (tester) async {
    await pumpWith(
      tester,
      const UnifiedImportResult(
        importedCounts: {ImportEntityType.dives: 2},
        consolidatedCount: 0,
        skippedCount: 0,
      ),
    );
    expect(find.byKey(const Key('import_summary_undo_fills')), findsNothing);
  });
}
