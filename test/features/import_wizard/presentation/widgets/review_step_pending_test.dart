import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/import_wizard/domain/adapters/import_source_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/models/import_phase.dart';
import 'package:submersion/features/import_wizard/domain/models/unified_import_result.dart';
import 'package:submersion/features/import_wizard/domain/models/wizard_step_def.dart';
import 'package:submersion/features/import_wizard/presentation/providers/import_wizard_providers.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/review_step.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

// ---------------------------------------------------------------------------
// Fake adapter (self-contained; mirrors fixtures from notifier test file).
// ---------------------------------------------------------------------------

class _TestAdapter implements ImportSourceAdapter {
  @override
  void resetState() {}

  @override
  ImportSourceType get sourceType => ImportSourceType.uddf;

  @override
  String get displayName => 'test.uddf';

  @override
  String get defaultTagName => 'Test Import';

  @override
  List<WizardStepDef> get acquisitionSteps => const [];

  @override
  Set<DuplicateAction> get supportedDuplicateActions => const {
    DuplicateAction.skip,
    DuplicateAction.importAsNew,
    DuplicateAction.consolidate,
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
  }) => throw UnimplementedError();
}

// ---------------------------------------------------------------------------
// Bundle fixtures
// ---------------------------------------------------------------------------

ImportBundle _bundleWithOnePendingDive() {
  return const ImportBundle(
    source: ImportSourceInfo(
      type: ImportSourceType.uddf,
      displayName: 'probable.uddf',
    ),
    groups: {
      ImportEntityType.dives: EntityGroup(
        items: [EntityItem(title: 'Dive 1', subtitle: '25 m - 50 min')],
        duplicateIndices: {0},
        matchResults: {
          0: DiveMatchResult(
            diveId: 'existing-dive',
            score: 0.85,
            timeDifferenceMs: 0,
          ),
        },
      ),
    },
  );
}

ImportBundle _bundleWithDiveAndPendingSite() {
  return const ImportBundle(
    source: ImportSourceInfo(
      type: ImportSourceType.uddf,
      displayName: 'dive-and-site.uddf',
    ),
    groups: {
      // Dives tab: one clean dive, no pending.
      ImportEntityType.dives: EntityGroup(
        items: [EntityItem(title: 'Dive 1', subtitle: '25 m - 50 min')],
      ),
      // Sites tab: one pending duplicate site.
      ImportEntityType.sites: EntityGroup(
        items: [EntityItem(title: 'Site A', subtitle: 'GPS: 0, 0')],
        duplicateIndices: {0},
      ),
    },
  );
}

// ---------------------------------------------------------------------------
// Pump helper
// ---------------------------------------------------------------------------

Widget _pumpReview({
  required ProviderContainer container,
  VoidCallback? onImport,
}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: ReviewStep(onImport: onImport ?? _noop)),
    ),
  );
}

ProviderContainer _buildContainer() {
  final container = ProviderContainer(
    overrides: [
      importWizardNotifierProvider.overrideWith(
        (ref) => ImportWizardNotifier(_TestAdapter()),
      ),
    ],
  );
  return container;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ReviewStep - pending-review gating', () {
    testWidgets('Import button is disabled when pending reviews exist', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = _buildContainer();
      addTearDown(container.dispose);

      final notifier = container.read(importWizardNotifierProvider.notifier);
      notifier.setBundle(_bundleWithOnePendingDive());

      await tester.pumpWidget(_pumpReview(container: container));
      await tester.pump();

      final importButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Import Selected'),
      );
      expect(importButton.onPressed, isNull);
    });

    testWidgets('pending hint text shows above the button', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = _buildContainer();
      addTearDown(container.dispose);

      final notifier = container.read(importWizardNotifierProvider.notifier);
      notifier.setBundle(_bundleWithOnePendingDive());

      await tester.pumpWidget(_pumpReview(container: container));
      await tester.pump();

      // "1 duplicate(s) need a decision" (ARB: universalImport_pending_gateHint)
      expect(find.text('1 duplicate(s) need a decision'), findsOneWidget);
      // Warning icon is present on the hint bar (in addition to any
      // needs-decision pill on the card itself).
      expect(find.byIcon(Icons.warning_amber_rounded), findsAtLeastNWidgets(1));
      // Review action button.
      expect(find.widgetWithText(TextButton, 'Review'), findsOneWidget);
    });

    testWidgets('no pending hint when no pending reviews', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = _buildContainer();
      addTearDown(container.dispose);

      final notifier = container.read(importWizardNotifierProvider.notifier);
      // Bundle with no duplicates — no pending.
      notifier.setBundle(
        const ImportBundle(
          source: ImportSourceInfo(
            type: ImportSourceType.uddf,
            displayName: 'clean.uddf',
          ),
          groups: {
            ImportEntityType.dives: EntityGroup(
              items: [EntityItem(title: 'Dive 1', subtitle: '25 m - 50 min')],
            ),
          },
        ),
      );

      await tester.pumpWidget(_pumpReview(container: container));
      await tester.pump();

      // Hint is absent.
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
      expect(find.widgetWithText(TextButton, 'Review'), findsNothing);

      // Button is enabled.
      final importButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Import Selected'),
      );
      expect(importButton.onPressed, isNotNull);
    });

    testWidgets('tapping Review animates DefaultTabController to pending tab', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = _buildContainer();
      addTearDown(container.dispose);

      final notifier = container.read(importWizardNotifierProvider.notifier);
      // Bundle: clean dives tab (index 0), pending sites tab (index 1).
      notifier.setBundle(_bundleWithDiveAndPendingSite());

      await tester.pumpWidget(_pumpReview(container: container));
      await tester.pump();

      // Before: default tab is 0 (Dives).
      final tabsContext = tester.element(find.byType(TabBar));
      var controller = DefaultTabController.of(tabsContext);
      expect(controller.index, 0);

      // Tap Review.
      await tester.tap(find.widgetWithText(TextButton, 'Review'));
      await tester.pumpAndSettle();

      // After: tab has animated to Sites (index 1 — pending tab).
      controller = DefaultTabController.of(tabsContext);
      expect(controller.index, 1);
    });

    testWidgets(
      'draining pending via setDuplicateAction re-enables Import button',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final container = _buildContainer();
        addTearDown(container.dispose);

        final notifier = container.read(importWizardNotifierProvider.notifier);
        notifier.setBundle(_bundleWithOnePendingDive());

        await tester.pumpWidget(_pumpReview(container: container));
        await tester.pump();

        // Initially disabled.
        var importButton = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Import Selected'),
        );
        expect(importButton.onPressed, isNull);

        // Drain pending by setting the duplicate action.
        notifier.setDuplicateAction(
          ImportEntityType.dives,
          0,
          DuplicateAction.importAsNew,
        );
        await tester.pump();

        // Now enabled.
        importButton = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Import Selected'),
        );
        expect(importButton.onPressed, isNotNull);

        // Pending hint gone.
        expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
      },
    );

    testWidgets(
      'draining pending via applyBulkAction(importAsNew) re-enables Import '
      'button',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final container = _buildContainer();
        addTearDown(container.dispose);

        final notifier = container.read(importWizardNotifierProvider.notifier);
        notifier.setBundle(_bundleWithOnePendingDive());

        await tester.pumpWidget(_pumpReview(container: container));
        await tester.pump();

        // Initially disabled.
        var importButton = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Import Selected'),
        );
        expect(importButton.onPressed, isNull);

        // Drain via bulk importAsNew — both drains pending AND adds something
        // to import, so the gate re-enables.
        notifier.applyBulkAction(
          ImportEntityType.dives,
          DuplicateAction.importAsNew,
        );
        await tester.pump();

        importButton = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Import Selected'),
        );
        expect(importButton.onPressed, isNotNull);
      },
    );

    testWidgets(
      'bulk skip on a pending-only bundle leaves Import button disabled',
      (tester) async {
        // Guards the Copilot-requested gate: when the user resolves all
        // pending by skipping everything (and nothing else is queued for
        // import), Import stays disabled because pressing it would be a
        // no-op. Previously the button re-enabled as soon as pending was
        // empty, regardless of whether anything was actually selected.
        await tester.binding.setSurfaceSize(const Size(800, 600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final container = _buildContainer();
        addTearDown(container.dispose);

        final notifier = container.read(importWizardNotifierProvider.notifier);
        notifier.setBundle(_bundleWithOnePendingDive());

        await tester.pumpWidget(_pumpReview(container: container));
        await tester.pump();

        notifier.applyBulkAction(ImportEntityType.dives, DuplicateAction.skip);
        await tester.pump();

        final importButton = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Import Selected'),
        );
        expect(importButton.onPressed, isNull);
      },
    );
  });
}

void _noop() {}
