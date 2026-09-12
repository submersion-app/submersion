// The review step seeds each import's tag from the diver's saved auto-tag
// preference (issue #998). SettingsNotifier starts at the defaults, where
// auto-tagging is on, and loads the diver's row asynchronously, so a wizard
// that read the preference before that load landed ignored a saved "off".

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/import_wizard/domain/adapters/import_source_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/models/import_cancellation_token.dart';
import 'package:submersion/features/import_wizard/domain/models/import_phase.dart';
import 'package:submersion/features/import_wizard/domain/models/unified_import_result.dart';
import 'package:submersion/features/import_wizard/presentation/pages/unified_import_wizard.dart';
import 'package:submersion/features/import_wizard/presentation/providers/import_wizard_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/wizard/wizard_step_def.dart';

import '../../../../helpers/mock_providers.dart';

final _canAdvance = Provider<bool>((_) => true);

class _OneStepAdapter implements ImportSourceAdapter {
  @override
  void resetState() {}

  @override
  ImportSourceType get sourceType => ImportSourceType.uddf;

  @override
  String get displayName => 'Test Import';

  @override
  String get defaultTagName => 'Test Import 2026-04-02';

  @override
  List<WizardStepDef> get acquisitionSteps => [
    WizardStepDef(
      label: 'Confirm Source',
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
      type: ImportSourceType.uddf,
      displayName: 'Test Import',
    ),
    groups: {},
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
  }) => throw UnimplementedError();
}

/// Holds the defaults until [finishLoad], the way [SettingsNotifier] does
/// until the diver's row has been read.
class _LateLoadingSettingsNotifier extends MockSettingsNotifier {
  final _load = Completer<void>();

  @override
  Future<void> get initialLoad => _load.future;

  void finishLoad(AppSettings stored) {
    state = stored;
    _load.complete();
  }

  void failLoad() => _load.completeError(StateError('database closed'));
}

void main() {
  late _LateLoadingSettingsNotifier settings;
  late ImportWizardNotifier wizard;

  Future<void> openAndTapNext(WidgetTester tester) async {
    // Built here, inside testWidgets' fake-async zone, not in setUp: a
    // Completer created outside it delivers its completion on the real event
    // loop, which pumpAndSettle never drains.
    settings = _LateLoadingSettingsNotifier();
    final adapter = _OneStepAdapter();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsProvider.overrideWith((ref) => settings)],
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
    // Everything up to the settings read runs here; the load is still out.
    await tester.pumpAndSettle();
  }

  testWidgets('a saved "off" that loads after Next still leaves the import '
      'untagged', (tester) async {
    await openAndTapNext(tester);

    settings.finishLoad(const AppSettings(autoTagImports: false));
    await tester.pumpAndSettle();

    expect(wizard.state.bundle, isNotNull);
    expect(wizard.state.importTags, isEmpty);
    expect(wizard.isAutoTagForThisImportEnabled, isFalse);
  });

  testWidgets('a saved "on" seeds the default tag once the load lands', (
    tester,
  ) async {
    await openAndTapNext(tester);

    settings.finishLoad(const AppSettings());
    await tester.pumpAndSettle();

    expect(
      wizard.state.importTags.map((t) => t.name),
      equals(['Test Import 2026-04-02']),
    );
  });

  testWidgets('a failed load falls back to the defaults and still reaches '
      'review', (tester) async {
    await openAndTapNext(tester);

    settings.failLoad();
    await tester.pumpAndSettle();

    expect(find.text('Step 1'), findsNothing);
    expect(
      wizard.state.importTags.map((t) => t.name),
      equals(['Test Import 2026-04-02']),
    );
  });
}
