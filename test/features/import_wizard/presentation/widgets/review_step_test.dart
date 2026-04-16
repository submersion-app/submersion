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
import 'package:submersion/features/import_wizard/presentation/widgets/entity_review_list.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/review_step.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

// ---------------------------------------------------------------------------
// Fake adapter
// ---------------------------------------------------------------------------

class _FakeAdapter implements ImportSourceAdapter {
  final Set<DuplicateAction> actions;

  _FakeAdapter({
    this.actions = const {DuplicateAction.skip, DuplicateAction.importAsNew},
  });

  @override
  void resetState() {}

  @override
  ImportSourceType get sourceType => ImportSourceType.uddf;

  @override
  String get displayName => 'test.uddf';

  @override
  String get defaultTagName => 'test.uddf Import 2026-03-26';

  @override
  List<WizardStepDef> get acquisitionSteps => [];

  @override
  Set<DuplicateAction> get supportedDuplicateActions => actions;

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
// Test helpers
// ---------------------------------------------------------------------------

ImportBundle _buildBundle({
  List<EntityItem>? diveItems,
  List<EntityItem>? siteItems,
  Set<int>? diveDuplicateIndices,
  Map<int, DiveMatchResult>? diveMatchResults,
}) {
  final groups = <ImportEntityType, EntityGroup>{};
  if (diveItems != null) {
    groups[ImportEntityType.dives] = EntityGroup(
      items: diveItems,
      duplicateIndices: diveDuplicateIndices ?? const {},
      matchResults: diveMatchResults,
    );
  }
  if (siteItems != null) {
    groups[ImportEntityType.sites] = EntityGroup(
      items: siteItems,
      duplicateIndices: const {},
    );
  }
  return ImportBundle(
    source: const ImportSourceInfo(
      type: ImportSourceType.uddf,
      displayName: 'test.uddf',
    ),
    groups: groups,
  );
}

EntityItem _item(String title) => EntityItem(title: title, subtitle: '');

Widget _buildReviewStep({
  required ImportBundle bundle,
  VoidCallback? onImport,
  Set<DuplicateAction>? adapterActions,
}) {
  final adapter = _FakeAdapter(
    actions:
        adapterActions ?? {DuplicateAction.skip, DuplicateAction.importAsNew},
  );
  final notifier = ImportWizardNotifier(adapter)..setBundle(bundle);

  return ProviderScope(
    overrides: [importWizardNotifierProvider.overrideWith((_) => notifier)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: ReviewStep(onImport: onImport ?? () {})),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ReviewStep - single entity type', () {
    testWidgets('shows TabBar even with one entity type', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final bundle = _buildBundle(
        diveItems: [_item('Dive 1'), _item('Dive 2')],
      );

      await tester.pumpWidget(_buildReviewStep(bundle: bundle));
      await tester.pump();

      expect(find.byType(TabBar), findsOneWidget);
    });

    testWidgets('EntityReviewList is rendered for single type', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final bundle = _buildBundle(
        diveItems: [_item('Dive 1'), _item('Dive 2')],
      );

      await tester.pumpWidget(_buildReviewStep(bundle: bundle));
      await tester.pump();

      expect(find.byType(EntityReviewList), findsOneWidget);
    });

    testWidgets('bottom bar shows Import Selected button', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final bundle = _buildBundle(diveItems: [_item('Dive 1')]);

      await tester.pumpWidget(_buildReviewStep(bundle: bundle));
      await tester.pump();

      expect(find.text('Import Selected'), findsOneWidget);
    });

    testWidgets('bottom bar shows aggregate counts', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final bundle = _buildBundle(
        diveItems: [_item('Dive 1'), _item('Dive 2')],
      );

      await tester.pumpWidget(_buildReviewStep(bundle: bundle));
      await tester.pump();

      // Both dives are selected by default, so "2 new" should appear.
      expect(find.textContaining('new'), findsOneWidget);
    });

    testWidgets('tapping Import Selected fires onImport callback', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var called = false;
      final bundle = _buildBundle(diveItems: [_item('Dive 1')]);

      await tester.pumpWidget(
        _buildReviewStep(bundle: bundle, onImport: () => called = true),
      );
      await tester.pump();

      await tester.tap(find.text('Import Selected'));
      await tester.pump();

      expect(called, isTrue);
    });
  });

  group('ReviewStep - multiple entity types', () {
    testWidgets('TabBar is shown when multiple entity types present', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final bundle = _buildBundle(
        diveItems: [_item('Dive 1')],
        siteItems: [_item('Blue Hole'), _item('Reef')],
      );

      await tester.pumpWidget(_buildReviewStep(bundle: bundle));
      await tester.pump();

      expect(find.byType(TabBar), findsOneWidget);
    });

    testWidgets('TabBar has correct number of tabs', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final bundle = _buildBundle(
        diveItems: [_item('Dive 1')],
        siteItems: [_item('Blue Hole')],
      );

      await tester.pumpWidget(_buildReviewStep(bundle: bundle));
      await tester.pump();

      expect(find.byType(Tab), findsNWidgets(2));
    });

    testWidgets('tab labels include item counts', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final bundle = _buildBundle(
        diveItems: [_item('Dive 1'), _item('Dive 2')],
        siteItems: [_item('Blue Hole')],
      );

      await tester.pumpWidget(_buildReviewStep(bundle: bundle));
      await tester.pump();

      // Dives tab: "Dives (2)", Sites tab: "Sites (1)"
      expect(find.text('Dives (2)'), findsOneWidget);
      expect(find.text('Sites (1)'), findsOneWidget);
    });

    testWidgets('bottom bar is shown in multi-type layout', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final bundle = _buildBundle(
        diveItems: [_item('Dive 1')],
        siteItems: [_item('Blue Hole')],
      );

      await tester.pumpWidget(_buildReviewStep(bundle: bundle));
      await tester.pump();

      expect(find.text('Import Selected'), findsOneWidget);
    });

    testWidgets('bottom bar aggregate counts reflect all entity types', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final bundle = _buildBundle(
        diveItems: [_item('Dive 1'), _item('Dive 2')],
        siteItems: [_item('Blue Hole')],
      );

      await tester.pumpWidget(_buildReviewStep(bundle: bundle));
      await tester.pump();

      // 3 items total, all selected: "3 new"
      expect(find.text('3 new'), findsOneWidget);
    });
  });

  group('ReviewStep - no bundle', () {
    testWidgets('shows loading indicator when bundle is null', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final adapter = _FakeAdapter();
      // Do NOT call setBundle — bundle remains null.
      final notifier = ImportWizardNotifier(adapter);

      final widget = ProviderScope(
        overrides: [importWizardNotifierProvider.overrideWith((_) => notifier)],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ReviewStep(onImport: _noop)),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('ReviewStep - _AggregateCounts replacing', () {
    testWidgets(
      'bottom bar shows replacing count for replaceSource duplicates',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        // 3 items total: items 0 and 1 are non-duplicates, item 2 is a
        // duplicate that we will mark as replaceSource.
        final bundle = _buildBundle(
          diveItems: [_item('Dive 1'), _item('Dive 2'), _item('Dive 3')],
          diveDuplicateIndices: {2},
          diveMatchResults: {
            2: const DiveMatchResult(
              diveId: 'existing-dive-1',
              score: 0.9,
              timeDifferenceMs: 100,
            ),
          },
        );

        final adapter = _FakeAdapter(
          actions: {
            DuplicateAction.skip,
            DuplicateAction.importAsNew,
            DuplicateAction.replaceSource,
          },
        );
        final notifier = ImportWizardNotifier(adapter)..setBundle(bundle);
        // Mark the duplicate as replaceSource
        notifier.setDuplicateAction(
          ImportEntityType.dives,
          2,
          DuplicateAction.replaceSource,
        );

        final widget = ProviderScope(
          overrides: [
            importWizardNotifierProvider.overrideWith((_) => notifier),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ReviewStep(onImport: () {})),
          ),
        );

        await tester.pumpWidget(widget);
        await tester.pump();

        // Should show "2 new, 1 replacing"
        expect(find.textContaining('replacing'), findsOneWidget);
        expect(find.textContaining('2 new'), findsOneWidget);
      },
    );

    testWidgets(
      'bottom bar shows multiple replacing when several duplicates use '
      'replaceSource',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        // 4 items: items 0 is non-duplicate, items 1-3 are duplicates.
        final bundle = _buildBundle(
          diveItems: [
            _item('Dive 1'),
            _item('Dive 2'),
            _item('Dive 3'),
            _item('Dive 4'),
          ],
          diveDuplicateIndices: {1, 2, 3},
          diveMatchResults: {
            1: const DiveMatchResult(
              diveId: 'existing-1',
              score: 0.9,
              timeDifferenceMs: 100,
            ),
            2: const DiveMatchResult(
              diveId: 'existing-2',
              score: 0.9,
              timeDifferenceMs: 200,
            ),
            3: const DiveMatchResult(
              diveId: 'existing-3',
              score: 0.9,
              timeDifferenceMs: 300,
            ),
          },
        );

        final adapter = _FakeAdapter(
          actions: {
            DuplicateAction.skip,
            DuplicateAction.importAsNew,
            DuplicateAction.replaceSource,
          },
        );
        final notifier = ImportWizardNotifier(adapter)..setBundle(bundle);
        // Mark two as replaceSource, one as skip
        notifier.setDuplicateAction(
          ImportEntityType.dives,
          1,
          DuplicateAction.replaceSource,
        );
        notifier.setDuplicateAction(
          ImportEntityType.dives,
          2,
          DuplicateAction.replaceSource,
        );
        notifier.setDuplicateAction(
          ImportEntityType.dives,
          3,
          DuplicateAction.skip,
        );

        final widget = ProviderScope(
          overrides: [
            importWizardNotifierProvider.overrideWith((_) => notifier),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ReviewStep(onImport: () {})),
          ),
        );

        await tester.pumpWidget(widget);
        await tester.pump();

        // Should show "1 new, 2 replacing, 1 skipped"
        expect(find.textContaining('2 replacing'), findsOneWidget);
        expect(find.textContaining('1 new'), findsOneWidget);
        expect(find.textContaining('1 skipped'), findsOneWidget);
      },
    );

    testWidgets(
      'bottom bar shows mixed counts with consolidating and replacing',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        // 3 items: item 0 is non-duplicate, items 1-2 are duplicates.
        final bundle = _buildBundle(
          diveItems: [_item('Dive 1'), _item('Dive 2'), _item('Dive 3')],
          diveDuplicateIndices: {1, 2},
          diveMatchResults: {
            1: const DiveMatchResult(
              diveId: 'existing-1',
              score: 0.9,
              timeDifferenceMs: 100,
            ),
            2: const DiveMatchResult(
              diveId: 'existing-2',
              score: 0.9,
              timeDifferenceMs: 200,
            ),
          },
        );

        final adapter = _FakeAdapter(
          actions: {
            DuplicateAction.skip,
            DuplicateAction.importAsNew,
            DuplicateAction.consolidate,
            DuplicateAction.replaceSource,
          },
        );
        final notifier = ImportWizardNotifier(adapter)..setBundle(bundle);
        notifier.setDuplicateAction(
          ImportEntityType.dives,
          1,
          DuplicateAction.consolidate,
        );
        notifier.setDuplicateAction(
          ImportEntityType.dives,
          2,
          DuplicateAction.replaceSource,
        );

        final widget = ProviderScope(
          overrides: [
            importWizardNotifierProvider.overrideWith((_) => notifier),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ReviewStep(onImport: () {})),
          ),
        );

        await tester.pumpWidget(widget);
        await tester.pump();

        // Should show "1 new, 1 merging, 1 replacing"
        expect(find.textContaining('1 new'), findsOneWidget);
        expect(find.textContaining('1 merging'), findsOneWidget);
        expect(find.textContaining('1 replacing'), findsOneWidget);
      },
    );
  });
}

void _noop() {}
