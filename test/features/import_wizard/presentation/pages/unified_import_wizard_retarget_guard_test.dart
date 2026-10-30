import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/import_wizard/domain/adapters/import_source_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/models/import_cancellation_token.dart';
import 'package:submersion/features/import_wizard/domain/models/import_phase.dart';
import 'package:submersion/features/import_wizard/domain/models/unified_import_result.dart';
import 'package:submersion/features/import_wizard/presentation/pages/unified_import_wizard.dart';
import 'package:submersion/features/import_wizard/presentation/providers/import_wizard_providers.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/review_step.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/wizard/wizard_step_def.dart';

import '../../../../helpers/mock_providers.dart';

// Issue #2050: while a change of profile re-checks the review rows, the
// wizard does not start the import, whichever control asked for it.

final _canAdvance = Provider<bool>((_) => true);

class _OneStepAdapter implements ImportSourceAdapter {
  var imports = 0;

  @override
  void resetState() {}
  @override
  ImportSourceType get sourceType => ImportSourceType.diveComputer;
  @override
  String get displayName => 'Perdix 2';
  @override
  String get defaultTagName => 'Perdix Import';
  @override
  List<WizardStepDef> get acquisitionSteps => [
    WizardStepDef(
      label: 'Download',
      builder: (_) => const Center(child: Text('Step 1')),
      canAdvance: _canAdvance,
    ),
  ];
  @override
  Set<DuplicateAction> get supportedDuplicateActions => {DuplicateAction.skip};
  @override
  Set<DuplicateAction> duplicateActionsFor(ImportEntityType type) =>
      supportedDuplicateActions;
  @override
  Future<ImportBundle> buildBundle() async => const ImportBundle(
    source: ImportSourceInfo(
      type: ImportSourceType.diveComputer,
      displayName: 'Perdix 2',
    ),
    groups: {
      ImportEntityType.dives: EntityGroup(
        items: [EntityItem(title: 'Dive 1', subtitle: '18 m')],
      ),
    },
  );
  @override
  Future<ImportBundle> checkDuplicates(ImportBundle bundle) async => bundle;
  @override
  Future<UnifiedImportResult> performImport(
    ImportBundle bundle,
    Map<ImportEntityType, Set<int>> selections,
    Map<ImportEntityType, Map<int, DuplicateAction>> duplicateActions, {
    bool retainSourceDiveNumbers = false,
    ImportProgressCallback? onProgress,
    ImportCancellationToken? cancelToken,
  }) async {
    imports++;
    return const UnifiedImportResult(
      importedCounts: {},
      consolidatedCount: 0,
      skippedCount: 0,
    );
  }
}

void main() {
  testWidgets('the import waits while a change of profile is re-checked', (
    tester,
  ) async {
    final adapter = _OneStepAdapter();
    late ImportWizardNotifier wizard;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: UnifiedImportWizard(
            adapter: adapter,
            notifierFactoryOverride: (_) =>
                wizard = ImportWizardNotifier(adapter),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.byType(ReviewStep), findsOneWidget);

    wizard.debugSetState(wizard.state.copyWith(isRetargeting: true));
    await tester.pump();
    tester.widget<ReviewStep>(find.byType(ReviewStep)).onImport();
    await tester.pumpAndSettle();

    expect(adapter.imports, 0);
    expect(find.byType(ReviewStep), findsOneWidget);
  });
}
