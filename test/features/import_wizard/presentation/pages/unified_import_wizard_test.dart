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
}
