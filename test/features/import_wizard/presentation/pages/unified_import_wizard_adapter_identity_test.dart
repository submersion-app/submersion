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
import 'package:submersion/features/import_wizard/presentation/widgets/review_step.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/wizard/wizard_step_def.dart';

// ---------------------------------------------------------------------------
// Regression coverage for the "Dives (0)" review step after a good download.
//
// A route builder that constructs its ImportSourceAdapter in `build` hands
// the wizard a brand-new, empty adapter whenever the route rebuilds. The
// dive computer download route does exactly that when the post-download
// device-info write ticks the dive_computers table (the by-id provider
// re-emits, the route rebuilds). The wizard must treat the adapter it was
// first given as the session's adapter, and a rebuild while the page
// transition to Review is still animating must not run the acquisition
// step's auto-advance a second time.
// ---------------------------------------------------------------------------

/// Flipped by the test to trigger the auto-advance of the single
/// acquisition step.
final _readyProvider = StateProvider<bool>((_) => false);

class _CountingAdapter implements ImportSourceAdapter {
  _CountingAdapter({required this.itemCount});

  final int itemCount;
  int buildBundleCalls = 0;

  @override
  void resetState() {}

  @override
  ImportSourceType get sourceType => ImportSourceType.uddf;

  @override
  String get displayName => 'Counting Import';

  @override
  String get defaultTagName => 'Counting Import';

  @override
  List<WizardStepDef> get acquisitionSteps => [
    WizardStepDef(
      label: 'Acquire',
      builder: (_) => const Center(child: Text('Acquire')),
      canAdvance: _readyProvider,
      autoAdvance: true,
    ),
  ];

  @override
  Set<DuplicateAction> get supportedDuplicateActions => const {
    DuplicateAction.skip,
    DuplicateAction.importAsNew,
  };

  @override
  Set<DuplicateAction> duplicateActionsFor(ImportEntityType type) =>
      supportedDuplicateActions;

  @override
  Future<ImportBundle> buildBundle() async {
    buildBundleCalls++;
    return ImportBundle(
      source: const ImportSourceInfo(
        type: ImportSourceType.uddf,
        displayName: 'Counting Import',
      ),
      groups: {
        ImportEntityType.dives: EntityGroup(
          items: [
            for (var i = 0; i < itemCount; i++)
              EntityItem(title: 'Dive $i', subtitle: 'subtitle'),
          ],
        ),
      },
    );
  }

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

Widget _buildWizard(ImportSourceAdapter adapter) {
  return MaterialApp(
    // Pinned: the assertions read the English "Dives (n)" tab label.
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: UnifiedImportWizard(adapter: adapter),
  );
}

/// The bundle held by the wizard's own (inner) ProviderScope.
ImportBundle? _wizardBundle(WidgetTester tester) {
  final context = tester.element(find.byType(ReviewStep));
  return ProviderScope.containerOf(
    context,
  ).read(importWizardNotifierProvider).bundle;
}

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  Future<void> pumpWizard(WidgetTester tester, ImportSourceAdapter adapter) {
    return tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _buildWizard(adapter),
      ),
    );
  }

  /// Mounts the wizard, lets both reset post-frame callbacks fire, then
  /// flips the acquisition step's canAdvance so auto-advance kicks off the
  /// bundle build and the page transition to Review.
  Future<void> mountAndAdvance(
    WidgetTester tester,
    ImportSourceAdapter adapter,
  ) async {
    await pumpWizard(tester, adapter);
    await tester.pump();
    await tester.pump();
    await tester.pump();

    container.read(_readyProvider.notifier).state = true;
    // Listener fires -> _onNext -> buildBundle (async) -> animateToPage.
    await tester.pump();
    await tester.pump();
  }

  testWidgets(
    'a rebuild with a different adapter instance mid-transition keeps the '
    'bundle built from the adapter the wizard was first given',
    (tester) async {
      final first = _CountingAdapter(itemCount: 2);
      final replacement = _CountingAdapter(itemCount: 0);

      await mountAndAdvance(tester, first);

      // The 300 ms page animation is still running: _currentPage still
      // points at the acquisition step. Rebuild the wizard with a fresh,
      // empty adapter, exactly what a rebuilding route builder does.
      await tester.pump(const Duration(milliseconds: 100));
      await pumpWizard(tester, replacement);
      await tester.pumpAndSettle();

      expect(
        replacement.buildBundleCalls,
        0,
        reason: 'the replacement adapter must never build the bundle',
      );
      final bundle = _wizardBundle(tester);
      expect(bundle, isNotNull);
      expect(bundle!.groups[ImportEntityType.dives]!.items, hasLength(2));
      expect(find.text('Dives (2)'), findsOneWidget);
    },
  );

  testWidgets(
    'a rebuild mid-transition does not run the acquisition auto-advance '
    'a second time',
    (tester) async {
      final adapter = _CountingAdapter(itemCount: 2);

      await mountAndAdvance(tester, adapter);

      // Force a rebuild while the transition is in flight (same adapter).
      await tester.pump(const Duration(milliseconds: 100));
      await pumpWizard(tester, adapter);
      await tester.pumpAndSettle();

      expect(adapter.buildBundleCalls, 1);
      expect(find.text('Dives (2)'), findsOneWidget);
    },
  );
}
