import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/domain/models/incoming_dive_data.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/import_wizard/domain/adapters/import_source_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/models/import_phase.dart';
import 'package:submersion/features/import_wizard/domain/models/unified_import_result.dart';
import 'package:submersion/features/import_wizard/domain/models/wizard_step_def.dart';
import 'package:submersion/features/import_wizard/presentation/providers/import_wizard_providers.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/entity_review_list.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/review_step.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
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

EntityItem _diveItem(String title, DateTime startTime) => EntityItem(
  title: title,
  subtitle: '',
  diveData: IncomingDiveData(startTime: startTime),
);

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

/// Builds a ReviewStep with provider overrides for nextDiveNumberProvider
/// and tagsProvider, enabling projected-dive-number and import-options tests.
Widget _buildReviewStepWithProviders({
  required ImportWizardNotifier notifier,
  int? nextDiveNumber,
  VoidCallback? onImport,
}) {
  return ProviderScope(
    overrides: [
      importWizardNotifierProvider.overrideWith((_) => notifier),
      if (nextDiveNumber != null)
        nextDiveNumberProvider.overrideWith((_) async => nextDiveNumber),
      tagsProvider.overrideWith((_) async => const []),
    ],
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

  // -------------------------------------------------------------------------
  // Projected dive numbers
  // -------------------------------------------------------------------------

  group('ReviewStep - projected dive numbers', () {
    testWidgets(
      'shows projected dive number badges for selected non-duplicate dives',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        // Two dives ordered oldest-first, nextDiveNumber = 10.
        // Expect badges #10 and #11.
        final bundle = _buildBundle(
          diveItems: [
            _diveItem('Dive A', DateTime(2026, 1, 1)),
            _diveItem('Dive B', DateTime(2026, 1, 2)),
          ],
        );

        final adapter = _FakeAdapter();
        final notifier = ImportWizardNotifier(adapter)..setBundle(bundle);

        await tester.pumpWidget(
          _buildReviewStepWithProviders(notifier: notifier, nextDiveNumber: 10),
        );
        await tester.pumpAndSettle();

        expect(find.text('#10'), findsOneWidget);
        expect(find.text('#11'), findsOneWidget);
      },
    );

    testWidgets('assigns numbers oldest-first regardless of item order', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Items in reverse chronological order; numbering should still go
      // oldest-first.
      final bundle = _buildBundle(
        diveItems: [
          _diveItem('Newer Dive', DateTime(2026, 6, 15)),
          _diveItem('Older Dive', DateTime(2026, 1, 1)),
        ],
      );

      final adapter = _FakeAdapter();
      final notifier = ImportWizardNotifier(adapter)..setBundle(bundle);

      await tester.pumpWidget(
        _buildReviewStepWithProviders(notifier: notifier, nextDiveNumber: 5),
      );
      await tester.pumpAndSettle();

      // Both badges should be present: #5 for the older, #6 for the newer.
      expect(find.text('#5'), findsOneWidget);
      expect(find.text('#6'), findsOneWidget);
    });

    testWidgets('excludes skipped duplicates from projected dive numbers', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // 3 dives: index 2 is a duplicate marked skip. Only indices 0 and 1
      // should get projected numbers (#1, #2).
      final bundle = _buildBundle(
        diveItems: [
          _diveItem('Dive 1', DateTime(2026, 1, 1)),
          _diveItem('Dive 2', DateTime(2026, 1, 2)),
          _diveItem('Dive 3 (dup)', DateTime(2026, 1, 3)),
        ],
        diveDuplicateIndices: {2},
        diveMatchResults: {
          2: const DiveMatchResult(
            diveId: 'existing-1',
            score: 0.9,
            timeDifferenceMs: 100,
          ),
        },
      );

      final adapter = _FakeAdapter();
      final notifier = ImportWizardNotifier(adapter)..setBundle(bundle);
      notifier.setDuplicateAction(
        ImportEntityType.dives,
        2,
        DuplicateAction.skip,
      );

      await tester.pumpWidget(
        _buildReviewStepWithProviders(notifier: notifier, nextDiveNumber: 1),
      );
      await tester.pumpAndSettle();

      // Only 2 dive number badges, not 3.
      expect(find.text('#1'), findsOneWidget);
      expect(find.text('#2'), findsOneWidget);
      expect(find.text('#3'), findsNothing);
    });

    testWidgets('includes importAsNew duplicates in projected dive numbers', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // 2 dives: index 1 is a duplicate marked importAsNew. Both should
      // get projected numbers.
      final bundle = _buildBundle(
        diveItems: [
          _diveItem('Dive 1', DateTime(2026, 1, 1)),
          _diveItem('Dive 2 (dup)', DateTime(2026, 1, 2)),
        ],
        diveDuplicateIndices: {1},
        diveMatchResults: {
          1: const DiveMatchResult(
            diveId: 'existing-1',
            score: 0.5,
            timeDifferenceMs: 100,
          ),
        },
      );

      final adapter = _FakeAdapter();
      final notifier = ImportWizardNotifier(adapter)..setBundle(bundle);
      notifier.setDuplicateAction(
        ImportEntityType.dives,
        1,
        DuplicateAction.importAsNew,
      );

      await tester.pumpWidget(
        _buildReviewStepWithProviders(notifier: notifier, nextDiveNumber: 20),
      );
      await tester.pumpAndSettle();

      expect(find.text('#20'), findsOneWidget);
      expect(find.text('#21'), findsOneWidget);
    });

    testWidgets(
      'excludes consolidated duplicates from projected dive numbers',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        // 2 dives: index 1 is a duplicate marked consolidate. Only index 0
        // should get a projected number.
        final bundle = _buildBundle(
          diveItems: [
            _diveItem('Dive 1', DateTime(2026, 1, 1)),
            _diveItem('Dive 2 (dup)', DateTime(2026, 1, 2)),
          ],
          diveDuplicateIndices: {1},
          diveMatchResults: {
            1: const DiveMatchResult(
              diveId: 'existing-1',
              score: 0.9,
              timeDifferenceMs: 100,
            ),
          },
        );

        final adapter = _FakeAdapter(
          actions: {
            DuplicateAction.skip,
            DuplicateAction.importAsNew,
            DuplicateAction.consolidate,
          },
        );
        final notifier = ImportWizardNotifier(adapter)..setBundle(bundle);
        notifier.setDuplicateAction(
          ImportEntityType.dives,
          1,
          DuplicateAction.consolidate,
        );

        await tester.pumpWidget(
          _buildReviewStepWithProviders(notifier: notifier, nextDiveNumber: 50),
        );
        await tester.pumpAndSettle();

        // Only 1 dive number badge for the non-duplicate.
        expect(find.text('#50'), findsOneWidget);
        expect(find.text('#51'), findsNothing);
      },
    );

    testWidgets('no dive number badges when nextDiveNumber is unavailable', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final bundle = _buildBundle(
        diveItems: [
          _diveItem('Dive 1', DateTime(2026, 1, 1)),
          _diveItem('Dive 2', DateTime(2026, 1, 2)),
        ],
      );

      // Use the standard builder without nextDiveNumberProvider override.
      await tester.pumpWidget(_buildReviewStep(bundle: bundle));
      await tester.pump();

      // No badges because the provider is not overridden and throws.
      expect(find.text('#1'), findsNothing);
      expect(find.text('#2'), findsNothing);
    });

    testWidgets('no dive number badges when dives group is absent', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Only sites, no dives.
      final bundle = _buildBundle(siteItems: [_item('Blue Hole')]);

      final adapter = _FakeAdapter();
      final notifier = ImportWizardNotifier(adapter)..setBundle(bundle);

      await tester.pumpWidget(
        _buildReviewStepWithProviders(notifier: notifier, nextDiveNumber: 1),
      );
      await tester.pumpAndSettle();

      // No dive number badges at all.
      expect(find.text('#1'), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // Options button visibility
  // -------------------------------------------------------------------------

  group('ReviewStep - Options button', () {
    testWidgets('Options button is visible on dives-only tab', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final bundle = _buildBundle(diveItems: [_item('Dive 1')]);

      final adapter = _FakeAdapter();
      final notifier = ImportWizardNotifier(adapter)..setBundle(bundle);

      await tester.pumpWidget(
        _buildReviewStepWithProviders(notifier: notifier, nextDiveNumber: 1),
      );
      await tester.pumpAndSettle();

      expect(find.text('Options'), findsOneWidget);
    });

    testWidgets('Options button is visible on dives tab in multi-type layout', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final bundle = _buildBundle(
        diveItems: [_item('Dive 1')],
        siteItems: [_item('Blue Hole')],
      );

      final adapter = _FakeAdapter();
      final notifier = ImportWizardNotifier(adapter)..setBundle(bundle);

      await tester.pumpWidget(
        _buildReviewStepWithProviders(notifier: notifier, nextDiveNumber: 1),
      );
      await tester.pumpAndSettle();

      // Initially on Dives tab, Options should be visible.
      expect(find.text('Options'), findsOneWidget);
    });

    testWidgets('Options button is hidden on Sites tab in multi-type layout', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final bundle = _buildBundle(
        diveItems: [_item('Dive 1')],
        siteItems: [_item('Blue Hole')],
      );

      final adapter = _FakeAdapter();
      final notifier = ImportWizardNotifier(adapter)..setBundle(bundle);

      await tester.pumpWidget(
        _buildReviewStepWithProviders(notifier: notifier, nextDiveNumber: 1),
      );
      await tester.pumpAndSettle();

      // Tap the Sites tab.
      await tester.tap(find.text('Sites (1)'));
      await tester.pumpAndSettle();

      // Options button should be gone on the Sites tab.
      expect(find.text('Options'), findsNothing);
    });

    testWidgets('Options button hidden when bundle contains only sites', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // No dives at all.
      final bundle = _buildBundle(siteItems: [_item('Blue Hole')]);

      final adapter = _FakeAdapter();
      final notifier = ImportWizardNotifier(adapter)..setBundle(bundle);

      await tester.pumpWidget(
        _buildReviewStepWithProviders(notifier: notifier, nextDiveNumber: 1),
      );
      await tester.pumpAndSettle();

      expect(find.text('Options'), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // Import Options sheet
  // -------------------------------------------------------------------------

  group('ReviewStep - Import Options sheet', () {
    testWidgets(
      'tapping Options opens bottom sheet with Import Options title',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final bundle = _buildBundle(diveItems: [_item('Dive 1')]);

        final adapter = _FakeAdapter();
        final notifier = ImportWizardNotifier(adapter)..setBundle(bundle);

        await tester.pumpWidget(
          _buildReviewStepWithProviders(notifier: notifier, nextDiveNumber: 1),
        );
        await tester.pumpAndSettle();

        // Tap Options button.
        await tester.tap(find.text('Options'));
        await tester.pumpAndSettle();

        expect(find.text('Import Options'), findsOneWidget);
      },
    );

    testWidgets('Import Options sheet shows retain-dive-numbers switch', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final bundle = _buildBundle(diveItems: [_item('Dive 1')]);

      final adapter = _FakeAdapter();
      final notifier = ImportWizardNotifier(adapter)..setBundle(bundle);

      await tester.pumpWidget(
        _buildReviewStepWithProviders(notifier: notifier, nextDiveNumber: 1),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Options'));
      await tester.pumpAndSettle();

      expect(find.text('Retain source dive numbers'), findsOneWidget);
      expect(find.byType(SwitchListTile), findsOneWidget);
    });

    testWidgets('toggling retain-dive-numbers switch updates notifier state', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final bundle = _buildBundle(diveItems: [_item('Dive 1')]);

      final adapter = _FakeAdapter();
      final notifier = ImportWizardNotifier(adapter)..setBundle(bundle);

      await tester.pumpWidget(
        _buildReviewStepWithProviders(notifier: notifier, nextDiveNumber: 1),
      );
      await tester.pumpAndSettle();

      // Open sheet.
      await tester.tap(find.text('Options'));
      await tester.pumpAndSettle();

      expect(notifier.state.retainSourceDiveNumbers, isFalse);

      // Toggle the switch on.
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(notifier.state.retainSourceDiveNumbers, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // Status text edge cases
  // -------------------------------------------------------------------------

  group('ReviewStep - status text formatting', () {
    testWidgets('shows only skipped count when all items deselected', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final bundle = _buildBundle(
        diveItems: [_item('Dive 1'), _item('Dive 2')],
      );

      final adapter = _FakeAdapter();
      final notifier = ImportWizardNotifier(adapter)..setBundle(bundle);
      notifier.deselectAll(ImportEntityType.dives);

      await tester.pumpWidget(
        _buildReviewStepWithProviders(notifier: notifier),
      );
      await tester.pumpAndSettle();

      // Deselected non-duplicates count as skipping.
      expect(find.text('2 skipped'), findsOneWidget);
      expect(find.textContaining('new'), findsNothing);
    });

    testWidgets(
      'shows only "skipped" when all duplicates skipped and no new items',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        // All items are duplicates.
        final bundle = _buildBundle(
          diveItems: [_item('Dive 1'), _item('Dive 2')],
          diveDuplicateIndices: {0, 1},
          diveMatchResults: {
            0: const DiveMatchResult(
              diveId: 'existing-1',
              score: 0.9,
              timeDifferenceMs: 100,
            ),
            1: const DiveMatchResult(
              diveId: 'existing-2',
              score: 0.9,
              timeDifferenceMs: 200,
            ),
          },
        );

        final adapter = _FakeAdapter();
        final notifier = ImportWizardNotifier(adapter)..setBundle(bundle);
        notifier.setDuplicateAction(
          ImportEntityType.dives,
          0,
          DuplicateAction.skip,
        );
        notifier.setDuplicateAction(
          ImportEntityType.dives,
          1,
          DuplicateAction.skip,
        );

        await tester.pumpWidget(
          _buildReviewStepWithProviders(notifier: notifier),
        );
        await tester.pumpAndSettle();

        expect(find.text('2 skipped'), findsOneWidget);
      },
    );

    testWidgets('shows combined status text with all action types', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // 5 items: 1 non-dup selected, 1 non-dup deselected, and 3 duplicates
      // with different actions.
      final bundle = _buildBundle(
        diveItems: [
          _item('Dive 1'),
          _item('Dive 2'),
          _item('Dive 3 (dup)'),
          _item('Dive 4 (dup)'),
          _item('Dive 5 (dup)'),
        ],
        diveDuplicateIndices: {2, 3, 4},
        diveMatchResults: {
          2: const DiveMatchResult(
            diveId: 'existing-1',
            score: 0.9,
            timeDifferenceMs: 100,
          ),
          3: const DiveMatchResult(
            diveId: 'existing-2',
            score: 0.9,
            timeDifferenceMs: 200,
          ),
          4: const DiveMatchResult(
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
          DuplicateAction.consolidate,
          DuplicateAction.replaceSource,
        },
      );
      final notifier = ImportWizardNotifier(adapter)..setBundle(bundle);
      // Deselect item 1 (non-duplicate -> skipping)
      notifier.toggleSelection(ImportEntityType.dives, 1);
      // Set duplicate actions
      notifier.setDuplicateAction(
        ImportEntityType.dives,
        2,
        DuplicateAction.consolidate,
      );
      notifier.setDuplicateAction(
        ImportEntityType.dives,
        3,
        DuplicateAction.replaceSource,
      );
      notifier.setDuplicateAction(
        ImportEntityType.dives,
        4,
        DuplicateAction.skip,
      );

      await tester.pumpWidget(
        _buildReviewStepWithProviders(notifier: notifier),
      );
      await tester.pumpAndSettle();

      // 1 new (item 0), 1 merging (item 2), 1 replacing (item 3),
      // 2 skipped (items 1 and 4).
      expect(find.textContaining('1 new'), findsOneWidget);
      expect(find.textContaining('1 merging'), findsOneWidget);
      expect(find.textContaining('1 replacing'), findsOneWidget);
      expect(find.textContaining('2 skipped'), findsOneWidget);
    });

    testWidgets(
      'Import Selected button disabled when nothing actionable selected',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final bundle = _buildBundle(
          diveItems: [_item('Dive 1'), _item('Dive 2')],
        );

        final adapter = _FakeAdapter();
        final notifier = ImportWizardNotifier(adapter)..setBundle(bundle);
        notifier.deselectAll(ImportEntityType.dives);

        var called = false;
        await tester.pumpWidget(
          _buildReviewStepWithProviders(
            notifier: notifier,
            onImport: () => called = true,
          ),
        );
        await tester.pumpAndSettle();

        // The button should be present but disabled.
        final button = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Import Selected'),
        );
        expect(button.onPressed, isNull);

        // Tapping should not fire callback.
        await tester.tap(find.text('Import Selected'));
        await tester.pump();
        expect(called, isFalse);
      },
    );
  });
}

void _noop() {}
