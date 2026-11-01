// A large file parses on a worker, so the app stays responsive while a step
// runs (#3865). With no sign of that work the screen looked idle, Next looked
// live but did nothing, and Back was undone when the step finished.

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

/// Two steps, because Back only exists from the second one on.
class _TwoStepAdapter implements ImportSourceAdapter {
  _TwoStepAdapter({required this.onSecondStep, this.duplicateCheck});

  final Future<void> Function() onSecondStep;
  final Future<ImportBundle> Function(ImportBundle)? duplicateCheck;

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
    WizardStepDef(
      label: 'Select File',
      builder: (_) => const Center(child: Text('Step 1')),
      canAdvance: _canAdvance,
    ),
    WizardStepDef(
      label: 'Confirm Source',
      builder: (_) => const Center(child: Text('Step 2')),
      canAdvance: _canAdvance,
      onBeforeAdvance: onSecondStep,
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

final _ready = StateProvider<bool>((_) => false);
final _readyToAdvance = Provider<bool>((ref) => ref.watch(_ready));

/// A step that advances itself as soon as [_ready] turns true, and watches the
/// same provider from a widget, so that change rebuilds the step as well.
class _AutoAdvanceAdapter extends _TwoStepAdapter {
  _AutoAdvanceAdapter() : super(onSecondStep: () async {});

  @override
  List<WizardStepDef> get acquisitionSteps => [
    WizardStepDef(
      label: 'Select File',
      builder: (_) => Consumer(
        builder: (_, ref, _) {
          ref.watch(_readyToAdvance);
          return const Center(child: Text('Step 1'));
        },
      ),
      canAdvance: _readyToAdvance,
      autoAdvance: true,
    ),
    ...super.acquisitionSteps.skip(1),
  ];
}

/// Opens the wizard and goes to the second step, ready to tap Next on it.
Future<void> _openSecondStep(
  WidgetTester tester,
  _TwoStepAdapter adapter,
) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: UnifiedImportWizard(adapter: adapter),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Next'));
  await tester.pumpAndSettle();
}

ButtonStyleButton _button(WidgetTester tester, String label) =>
    tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text(label),
        matching: find.bySubtype<ButtonStyleButton>(),
      ),
    );

void main() {
  testWidgets('shows a step at work and holds Next and Back', (tester) async {
    final gate = Completer<void>();
    final adapter = _TwoStepAdapter(onSecondStep: () => gate.future);
    await _openSecondStep(tester, adapter);

    await tester.tap(find.text('Next'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Loading')), findsOneWidget);
    expect(_button(tester, 'Next').enabled, isFalse);
    expect(_button(tester, 'Back').enabled, isFalse);

    gate.complete();
    await tester.pumpAndSettle();

    expect(find.text('Step 2'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('stays at work through the duplicate check', (tester) async {
    final gate = Completer<ImportBundle>();
    final adapter = _TwoStepAdapter(
      onSecondStep: () async {},
      duplicateCheck: (_) => gate.future,
    );
    await _openSecondStep(tester, adapter);

    await tester.tap(find.text('Next'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(_button(tester, 'Back').enabled, isFalse);

    gate.complete(await adapter.buildBundle());
    await tester.pumpAndSettle();

    expect(find.text('Step 2'), findsNothing);
  });

  testWidgets('a step that advances itself goes through the same state', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: UnifiedImportWizard(adapter: _AutoAdvanceAdapter()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    container.read(_ready.notifier).state = true;
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Step 2'), findsOneWidget);
  });

  testWidgets('hands the buttons back when a step fails', (tester) async {
    final gate = Completer<void>();
    final adapter = _TwoStepAdapter(onSecondStep: () => gate.future);
    await _openSecondStep(tester, adapter);

    await tester.tap(find.text('Next'));
    await tester.pump();
    gate.completeError(const ImportStepFailure('No data in that file'));
    await tester.pumpAndSettle();

    expect(find.text('No data in that file'), findsOneWidget);
    expect(find.text('Step 2'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(_button(tester, 'Next').enabled, isTrue);
    expect(_button(tester, 'Back').enabled, isTrue);
  });
}
