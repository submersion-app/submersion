import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/import_wizard/data/adapters/universal_adapter.dart';
import 'package:submersion/features/import_wizard/domain/adapters/import_source_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/models/import_cancellation_token.dart';
import 'package:submersion/features/import_wizard/domain/models/import_phase.dart';
import 'package:submersion/features/import_wizard/domain/models/unified_import_result.dart';
import 'package:submersion/features/import_wizard/domain/models/wizard_step_def.dart';
import 'package:submersion/features/import_wizard/presentation/pages/unified_import_wizard.dart';
import 'package:submersion/features/import_wizard/presentation/providers/import_wizard_providers.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

// ---------------------------------------------------------------------------
// Fake adapter (non-preloaded path)
// ---------------------------------------------------------------------------

final _canAdvanceFalse = StateProvider<bool>((_) => false);

class _FakeAdapter implements ImportSourceAdapter {
  bool resetCalled = false;

  @override
  void resetState() {
    resetCalled = true;
  }

  @override
  ImportSourceType get sourceType => ImportSourceType.uddf;

  @override
  String get displayName => 'Test Import';

  @override
  String get defaultTagName => 'Test Import 2026-04-02';

  @override
  List<WizardStepDef> get acquisitionSteps => [
    WizardStepDef(
      label: 'Pick File',
      builder: (_) => const Center(child: Text('Step 1')),
      canAdvance: _canAdvanceFalse,
    ),
  ];

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
    ImportCancellationToken? cancelToken,
  }) => throw UnimplementedError();
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// UDDF bytes recognised by the format detector.
final _uddfBytes = Uint8List.fromList(
  '<?xml version="1.0"?><uddf version="3.2.0"></uddf>'.codeUnits,
);

Widget _buildWizard(ImportSourceAdapter adapter) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: UnifiedImportWizard(adapter: adapter),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('UnifiedImportWizard', () {
    testWidgets('calls resetState on a non-preloaded adapter', (tester) async {
      final adapter = _FakeAdapter();

      await tester.pumpWidget(_buildWizard(adapter));
      // First pump: widget renders.
      await tester.pump();
      // Second pump: first addPostFrameCallback fires (resetState).
      await tester.pump();
      // Third pump: second addPostFrameCallback fires (_resetComplete).
      await tester.pump();

      expect(adapter.resetCalled, isTrue);
    });

    testWidgets('renders acquisition step content', (tester) async {
      await tester.pumpWidget(_buildWizard(_FakeAdapter()));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.text('Step 1'), findsOneWidget);
      expect(find.text('Test Import'), findsOneWidget);
    });

    testWidgets('renders Next button for acquisition step', (tester) async {
      await tester.pumpWidget(_buildWizard(_FakeAdapter()));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.text('Next'), findsOneWidget);
    });

    testWidgets('consumes preloaded state from UniversalAdapter', (
      tester,
    ) async {
      // Use a shared ProviderContainer so state persists across widget
      // rebuilds and the assertion validates real state consumption.
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Pre-load state so the UniversalAdapter sees hasPreloadedState.
      await tester.runAsync(() async {
        final notifier = container.read(
          universalImportNotifierProvider.notifier,
        );
        await notifier.loadFileFromBytes(_uddfBytes, 'dive.uddf');
      });

      expect(
        container.read(universalImportNotifierProvider).wasLoadedExternally,
        isTrue,
      );

      // Build the wizard using the shared container.
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Consumer(
              builder: (context, ref, _) {
                final adapter = UniversalAdapter(ref: ref);
                return UnifiedImportWizard(adapter: adapter);
              },
            ),
          ),
        ),
      );
      // Let post-frame callbacks fire.
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // After the wizard consumes preloaded state, wasLoadedExternally
      // should be cleared in the shared container.
      final state = container.read(universalImportNotifierProvider);
      expect(state.wasLoadedExternally, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // Cancel dialog flow on the import-progress page
  //
  // The wizard's close button (Icons.close in the AppBar) has two distinct
  // behaviors when the user is on the import-progress page:
  // 1. If no cancellation is pending, it confirms with a two-button dialog
  //    and only calls notifier.cancelImport() when the user picks "Cancel
  //    import".
  // 2. If a cancellation is already in flight, it shows a read-only notice
  //    explaining that the current dive will finish before stopping.
  //
  // These tests use initialPageOverride to jump straight to _importIndex so
  // we don't have to drive the adapter through buildBundle/performImport,
  // and notifierFactoryOverride so the inner ProviderScope uses a spy we
  // can assert `cancelImport` call-counts against.
  // -------------------------------------------------------------------------
  group('UnifiedImportWizard cancel dialog', () {
    Widget buildAt(
      int page, {
      required ImportSourceAdapter adapter,
      ImportWizardNotifier Function(Ref ref)? notifierFactory,
    }) {
      return ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: UnifiedImportWizard(
            adapter: adapter,
            initialPageOverride: page,
            notifierFactoryOverride: notifierFactory,
          ),
        ),
      );
    }

    _SpyNotifier makeSpy({bool alreadyCancelling = false}) {
      final spy = _SpyNotifier();
      if (alreadyCancelling) {
        spy.state = spy.state.copyWith(isCancellationRequested: true);
      }
      return spy;
    }

    // Scope "Cancel import" matches to the dialog only — the import-progress
    // page also renders a `TextButton.icon` with label "Cancel import", which
    // otherwise matches and makes finders ambiguous.
    Finder dialogCancelButton() => find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(TextButton, 'Cancel import'),
    );

    testWidgets(
      'close button on import page opens Cancel import? confirm dialog',
      (tester) async {
        final adapter = _FakeAdapter();
        // 1 acquisition step → _importIndex = 2 (0=acq, 1=review, 2=import).
        await tester.pumpWidget(buildAt(2, adapter: adapter));
        // Drain the two post-frame callbacks used by _resetComplete +
        // initialPageOverride before the AppBar is clickable.
        await tester.pump();
        await tester.pump();
        await tester.pump();

        await tester.tap(find.byIcon(Icons.close));
        // Finite pump — ImportProgressStep renders indeterminate progress
        // indicators that prevent pumpAndSettle from ever returning.
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Cancel import?'), findsOneWidget);
        expect(
          find.widgetWithText(TextButton, 'Keep importing'),
          findsOneWidget,
        );
        expect(dialogCancelButton(), findsOneWidget);
      },
    );

    testWidgets(
      'tapping Keep importing dismisses dialog without calling cancelImport',
      (tester) async {
        final spy = makeSpy();
        await tester.pumpWidget(
          buildAt(2, adapter: _FakeAdapter(), notifierFactory: (_) => spy),
        );
        await tester.pump();
        await tester.pump();
        await tester.pump();

        await tester.tap(find.byIcon(Icons.close));
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.widgetWithText(TextButton, 'Keep importing'));
        await tester.pump(const Duration(milliseconds: 300));

        expect(spy.cancelCalls, 0);
        expect(find.text('Cancel import?'), findsNothing);
      },
    );

    testWidgets(
      'tapping Cancel import in confirm dialog calls notifier.cancelImport',
      (tester) async {
        final spy = makeSpy();
        await tester.pumpWidget(
          buildAt(2, adapter: _FakeAdapter(), notifierFactory: (_) => spy),
        );
        await tester.pump();
        await tester.pump();
        await tester.pump();

        await tester.tap(find.byIcon(Icons.close));
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(dialogCancelButton());
        await tester.pump(const Duration(milliseconds: 300));

        expect(spy.cancelCalls, 1);
        expect(find.text('Cancel import?'), findsNothing);
      },
    );

    testWidgets(
      'close button shows Cancelling notice when cancellation already pending',
      (tester) async {
        final spy = makeSpy(alreadyCancelling: true);
        await tester.pumpWidget(
          buildAt(2, adapter: _FakeAdapter(), notifierFactory: (_) => spy),
        );
        await tester.pump();
        await tester.pump();
        await tester.pump();

        await tester.tap(find.byIcon(Icons.close));
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Cancelling'), findsOneWidget);
        expect(
          find.textContaining('Finishing the current dive'),
          findsOneWidget,
        );
        // No confirm buttons — just an OK dismiss.
        expect(find.widgetWithText(TextButton, 'Keep importing'), findsNothing);
        expect(find.widgetWithText(TextButton, 'OK'), findsOneWidget);

        await tester.tap(find.widgetWithText(TextButton, 'OK'));
        await tester.pump(const Duration(milliseconds: 300));

        // The already-cancelling path must not re-invoke cancelImport.
        expect(spy.cancelCalls, 0);
      },
    );
  });
}

/// Notifier spy so we can assert `cancelImport()` is (or isn't) called by
/// the wizard's confirm dialog without driving a real import.
class _SpyNotifier extends ImportWizardNotifier {
  _SpyNotifier() : super(_FakeAdapter());

  int cancelCalls = 0;

  @override
  void cancelImport() {
    cancelCalls++;
    super.cancelImport();
  }
}
