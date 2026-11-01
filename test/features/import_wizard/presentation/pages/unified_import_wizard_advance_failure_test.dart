// The Next button used to drop the future it started. Anything an acquisition
// step threw -- a parse, a database read the duplicate check made -- surfaced
// nowhere, so from the outside the button simply did nothing, however many
// times it was tapped (reported on ScubaBoard against v1.7.6).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/import_wizard/domain/adapters/import_source_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/models/import_cancellation_token.dart';
import 'package:submersion/features/import_wizard/domain/models/import_phase.dart';
import 'package:submersion/features/import_wizard/domain/models/import_step_failure.dart';
import 'package:submersion/features/import_wizard/domain/models/unified_import_result.dart';
import 'package:submersion/features/import_wizard/presentation/pages/unified_import_wizard.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/wizard/wizard_step_def.dart';

final _canAdvance = Provider<bool>((_) => true);

/// One acquisition step whose onBeforeAdvance fails the way a bad parse does.
class _FailingStepAdapter implements ImportSourceAdapter {
  _FailingStepAdapter({
    required this.onAdvance,
    this.duplicateCheck,
    this.onCancelAdvance,
    this.leadingStep = false,
  });

  final Future<void> Function() onAdvance;
  final Future<ImportBundle> Function(ImportBundle)? duplicateCheck;
  final VoidCallback? onCancelAdvance;

  /// Puts a plain step in front, so the Back button shows on the one under
  /// test.
  final bool leadingStep;

  int buildBundleCalls = 0;
  ImportBundle? bundleGivenToWizard;

  @override
  void resetState() {}

  @override
  ImportSourceType get sourceType => ImportSourceType.uddf;

  @override
  String get displayName => 'Test Import';

  @override
  String get defaultTagName => 'Test Import';

  @override
  List<WizardStepDef> get acquisitionSteps => [
    if (leadingStep)
      WizardStepDef(
        label: 'Pick File',
        builder: (_) => const Center(child: Text('Step 0')),
        canAdvance: _canAdvance,
      ),
    WizardStepDef(
      label: 'Confirm Source',
      builder: (_) => const Center(child: Text('Step 1')),
      canAdvance: _canAdvance,
      onBeforeAdvance: onAdvance,
      onCancelAdvance: onCancelAdvance,
    ),
  ];

  @override
  Set<DuplicateAction> get supportedDuplicateActions => {DuplicateAction.skip};

  @override
  Set<DuplicateAction> duplicateActionsFor(ImportEntityType type) =>
      supportedDuplicateActions;

  @override
  Future<ImportBundle> buildBundle() async {
    buildBundleCalls++;
    return const ImportBundle(
      source: ImportSourceInfo(
        type: ImportSourceType.uddf,
        displayName: 'Test Import',
      ),
      groups: {},
    );
  }

  @override
  Future<ImportBundle> checkDuplicates(ImportBundle bundle) async {
    if (duplicateCheck != null) return duplicateCheck!(bundle);
    return bundle;
  }

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

Widget _wizard(ImportSourceAdapter adapter) => ProviderScope(
  child: MaterialApp(
    // flutter_test forwards the host machine's locale list rather than a fixed
    // en_US, and the app ships 11 locales, so an unpinned MaterialApp renders
    // translated on a non-English machine and every assertion below misses.
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: UnifiedImportWizard(adapter: adapter),
  ),
);

Future<void> _tapNext(WidgetTester tester) async {
  await tester.tap(find.text('Next'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows an ImportStepFailure message instead of doing nothing', (
    tester,
  ) async {
    final adapter = _FailingStepAdapter(
      onAdvance: () async => throw const ImportStepFailure(
        'No data could be parsed from the file',
      ),
    );
    await tester.pumpWidget(_wizard(adapter));
    await tester.pumpAndSettle();

    await _tapNext(tester);

    expect(find.text('No data could be parsed from the file'), findsOneWidget);
    // Still on the acquisition step: a failed step must not advance.
    expect(find.text('Step 1'), findsOneWidget);
    expect(adapter.buildBundleCalls, 0);
  });

  testWidgets('a step the diver stopped stays put with nothing to report', (
    tester,
  ) async {
    final adapter = _FailingStepAdapter(
      onAdvance: () async => throw const ImportStepCancelled(),
    );
    await tester.pumpWidget(_wizard(adapter));
    await tester.pumpAndSettle();

    await _tapNext(tester);

    expect(find.text('Step 1'), findsOneWidget);
    expect(adapter.buildBundleCalls, 0);
    // No banner of any kind: nothing went wrong.
    expect(find.byIcon(Icons.error_outline), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Next works again after a step was stopped', (tester) async {
    var attempts = 0;
    final adapter = _FailingStepAdapter(
      onAdvance: () async {
        if (++attempts == 1) throw const ImportStepCancelled();
      },
    );
    await tester.pumpWidget(_wizard(adapter));
    await tester.pumpAndSettle();

    await _tapNext(tester);
    await _tapNext(tester);

    expect(adapter.buildBundleCalls, 1);
  });

  testWidgets('Back stops a step that is still running, and stays back', (
    tester,
  ) async {
    final running = Completer<void>();
    var cancels = 0;
    final adapter = _FailingStepAdapter(
      leadingStep: true,
      onAdvance: () => running.future,
      onCancelAdvance: () {
        cancels++;
        running.completeError(const ImportStepCancelled());
      },
    );
    await tester.pumpWidget(_wizard(adapter));
    await tester.pumpAndSettle();
    await _tapNext(tester);
    expect(find.text('Step 1'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();

    expect(cancels, 1);
    expect(find.text('Step 0'), findsOneWidget);
    expect(find.text('Step 1'), findsNothing);
    expect(adapter.buildBundleCalls, 0);
  });

  testWidgets('Back with no step running stops nothing', (tester) async {
    var cancels = 0;
    final adapter = _FailingStepAdapter(
      leadingStep: true,
      onAdvance: () async {},
      onCancelAdvance: () => cancels++,
    );
    await tester.pumpWidget(_wizard(adapter));
    await tester.pumpAndSettle();
    await _tapNext(tester);

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();

    expect(cancels, 0);
  });

  testWidgets('leaving the wizard stops a step that is still running', (
    tester,
  ) async {
    final running = Completer<void>();
    var cancels = 0;
    final adapter = _FailingStepAdapter(
      onAdvance: () => running.future,
      onCancelAdvance: () {
        cancels++;
        running.completeError(const ImportStepCancelled());
      },
    );
    await tester.pumpWidget(_wizard(adapter));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    expect(cancels, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a message when a step throws something unexpected', (
    tester,
  ) async {
    final adapter = _FailingStepAdapter(
      onAdvance: () async => throw StateError('Database not initialized'),
    );
    await tester.pumpWidget(_wizard(adapter));
    await tester.pumpAndSettle();

    await _tapNext(tester);

    expect(find.textContaining('Database not initialized'), findsOneWidget);
    expect(find.text('Step 1'), findsOneWidget);
  });

  testWidgets(
    'a failing duplicate check still reaches review, with a warning',
    (tester) async {
      final adapter = _FailingStepAdapter(
        onAdvance: () async {},
        duplicateCheck: (_) async => throw StateError('dedupe query blew up'),
      );
      await tester.pumpWidget(_wizard(adapter));
      await tester.pumpAndSettle();

      await _tapNext(tester);

      expect(adapter.buildBundleCalls, 1);
      expect(find.text('Step 1'), findsNothing);
      expect(
        find.textContaining('Duplicate detection could not run'),
        findsOneWidget,
      );
    },
  );
}
