import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/import_wizard/domain/adapters/import_source_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/models/unified_import_result.dart';
import 'package:submersion/features/import_wizard/domain/models/wizard_step_def.dart';
import 'package:submersion/features/import_wizard/presentation/providers/import_wizard_providers.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/entity_review_list.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/review_step.dart';

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
    void Function(String phase, int current, int total)? onProgress,
  }) => throw UnimplementedError();
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

ImportBundle _buildBundle({
  List<EntityItem>? diveItems,
  List<EntityItem>? siteItems,
}) {
  final groups = <ImportEntityType, EntityGroup>{};
  if (diveItems != null) {
    groups[ImportEntityType.dives] = EntityGroup(
      items: diveItems,
      duplicateIndices: const {},
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
      home: Scaffold(body: ReviewStep(onImport: onImport ?? () {})),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ReviewStep - single entity type', () {
    testWidgets('no TabBar when only one entity type', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final bundle = _buildBundle(
        diveItems: [_item('Dive 1'), _item('Dive 2')],
      );

      await tester.pumpWidget(_buildReviewStep(bundle: bundle));
      await tester.pump();

      expect(find.byType(TabBar), findsNothing);
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
          home: Scaffold(body: ReviewStep(onImport: _noop)),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}

void _noop() {}
